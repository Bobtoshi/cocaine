#!/bin/bash

# Cocaine Mining Setup Script
#
# Local mode (builds/starts local daemon + mines locally):
#   ./mine.sh
#
# Remote mode (starts mining on a remote daemon RPC, e.g. VPS):
#   ./mine.sh --remote <host:port> --address <WALLET_ADDRESS> [--threads N]
#
# Notes:
# - "start_mining" makes the *daemon host* mine. If you use --remote, the VPS CPU mines.
# - If you want your client machine to do the hashing, use an external miner (e.g. xmrig) pointed at your VPS.

set -e

REMOTE_RPC=""
REMOTE_ADDRESS=""
REMOTE_THREADS=""

usage() {
  echo ""
  echo "Usage:"
  echo "  Local:  $0"
  echo "  Remote: $0 --remote <host:port> --address <WALLET_ADDRESS> [--threads N]"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 --remote 1.2.3.4:19081 --address 5YourWalletAddressHere --threads 2"
  echo ""
}

# Basic arg parsing
while [ $# -gt 0 ]; do
  case "$1" in
    --remote)
      REMOTE_RPC="$2"; shift 2 ;;
    --address)
      REMOTE_ADDRESS="$2"; shift 2 ;;
    --threads)
      REMOTE_THREADS="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "[!] Unknown argument: $1"; usage; exit 2 ;;
  esac
done

echo ""
echo " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗"
echo "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝"
echo "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  "
echo "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  "
echo "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗"
echo " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝"
echo ""
echo "              COCAINE MINER v1.0"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DAEMON="$SCRIPT_DIR/build/bin/cocained"
WALLET_CLI="$SCRIPT_DIR/build/bin/cocaine-wallet-cli"
DATA_DIR="$SCRIPT_DIR/blockchain"
WALLET_DIR="$SCRIPT_DIR/wallets"

# ============================
# Remote mode: mine on a remote daemon (e.g. VPS)
# ============================
if [ -n "$REMOTE_RPC" ] || [ -n "$REMOTE_ADDRESS" ] || [ -n "$REMOTE_THREADS" ]; then
  if [ -z "$REMOTE_RPC" ] || [ -z "$REMOTE_ADDRESS" ]; then
    echo "[!] Remote mode requires --remote <host:port> and --address <WALLET_ADDRESS>"
    usage
    exit 2
  fi

  # Default threads if not provided
  if [ -z "$REMOTE_THREADS" ]; then
    REMOTE_THREADS=2
  fi

  echo ""
  echo "[+] Remote mining request"
  echo "    RPC:     $REMOTE_RPC"
  echo "    Address: $REMOTE_ADDRESS"
  echo "    Threads: $REMOTE_THREADS"
  echo ""

  # Quick connectivity check
  if ! curl -fsS "http://$REMOTE_RPC/json_rpc" \
      -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
      -H "Content-Type: application/json" >/dev/null; then
    echo "[!] Cannot reach remote daemon RPC at http://$REMOTE_RPC"
    echo "[!] Ensure the daemon is started with external RPC enabled (e.g. --rpc-bind-ip 0.0.0.0 --confirm-external-bind)"
    echo "[!] and that firewalls/security-groups allow inbound TCP on the RPC port."
    exit 1
  fi

  # Start mining on the remote daemon host
  RESULT=$(curl -s "http://$REMOTE_RPC/start_mining" -d "{\
    \"miner_address\": \"$REMOTE_ADDRESS\",\
    \"threads_count\": $REMOTE_THREADS,\
    \"do_background_mining\": false,\
    \"ignore_battery\": true\
  }" -H "Content-Type: application/json")

  if echo "$RESULT" | grep -q '"status":"OK"'; then
    echo "[+] Mining started on remote daemon host!"
    echo ""
    echo "[*] Remote mining status (Ctrl+C to exit monitoring):"
    while true; do
      STATUS=$(curl -s "http://$REMOTE_RPC/mining_status" || true)
      SPEED=$(echo "$STATUS" | grep -o '"speed":[0-9]*' | cut -d: -f2)
      HEIGHT=$(curl -s "http://$REMOTE_RPC/json_rpc" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
      printf "\r    Height: %-8s | Speed: %-6s H/s" "${HEIGHT:-?}" "${SPEED:-0}"
      sleep 2
    done
  else
    echo "[!] Failed to start remote mining: $RESULT"
    echo "[!] Note: If your daemon is running with --restricted-rpc, it may block start_mining."
    exit 1
  fi
fi

# Check if binaries exist
if [ ! -f "$DAEMON" ]; then
    echo "[!] Daemon not found at $DAEMON"
    echo "[!] Please build from source first: cd build && cmake .. && make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu) daemon simplewallet"
    exit 1
fi

# Create directories
mkdir -p "$DATA_DIR"
mkdir -p "$WALLET_DIR"

# Function to check if daemon is responding
check_daemon() {
    curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" 2>/dev/null | grep -q '"status":"OK"'
}

# Start daemon if not running
if check_daemon; then
    echo "[+] Daemon already running"
else
    echo "[*] Starting daemon..."

    # Kill any stale process
    pkill -f cocained 2>/dev/null || true
    sleep 2

    "$DAEMON" \
        --data-dir "$DATA_DIR" \
        --log-level 1 \
        --rpc-bind-ip 127.0.0.1 \
        --rpc-bind-port 19081 \
        --confirm-external-bind \
        --detach

    echo "[*] Waiting for daemon to start..."
    for i in {1..30}; do
        if check_daemon; then
            echo "[+] Daemon started successfully"
            break
        fi
        sleep 1
    done

    if ! check_daemon; then
        echo "[!] Failed to start daemon. Check logs at $DATA_DIR/cocaine.log"
        exit 1
    fi
fi

# Get daemon status
echo ""
HEIGHT=$(curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
echo "[+] Current block height: $HEIGHT"

# Check for existing wallet or create new one
WALLET_FILE=""
WALLET_ADDRESS=""

if ls "$WALLET_DIR"/wallet_*.keys 2>/dev/null | head -1 > /dev/null; then
    WALLET_FILE=$(ls "$WALLET_DIR"/wallet_*.keys 2>/dev/null | head -1 | sed 's/.keys$//')
    echo "[+] Found existing wallet: $(basename "$WALLET_FILE")"

    # Get address from wallet
    WALLET_ADDRESS=$("$WALLET_CLI" \
        --wallet-file "$WALLET_FILE" \
        --password "" \
        --daemon-address 127.0.0.1:19081 \
        --command "address" 2>/dev/null | grep -E "^0 +5" | awk '{print $2}')
else
    echo "[*] Creating new wallet..."
    WALLET_FILE="$WALLET_DIR/wallet_$(date +%s)"

    OUTPUT=$("$WALLET_CLI" \
        --generate-new-wallet "$WALLET_FILE" \
        --password "" \
        --mnemonic-language English \
        --daemon-address 127.0.0.1:19081 \
        --command "exit" 2>&1)

    WALLET_ADDRESS=$(echo "$OUTPUT" | grep "Generated new wallet:" | sed 's/.*: //')
    SEED=$(echo "$OUTPUT" | sed -n '/NOTE: the following/,/\*\*\*/p' | grep -v "NOTE:" | grep -v "\*\*\*" | tr '\n' ' ' | xargs)

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                    NEW WALLET CREATED"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Address: $WALLET_ADDRESS"
    echo ""
    echo "SEED PHRASE (SAVE THIS - IT'S YOUR ONLY BACKUP!):"
    echo ""
    echo "$SEED"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
fi

if [ -z "$WALLET_ADDRESS" ]; then
    echo "[!] Could not get wallet address"
    exit 1
fi

echo ""
echo "[+] Mining to: $WALLET_ADDRESS"
echo ""

# Get number of threads
TOTAL_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
DEFAULT_THREADS=$((TOTAL_CORES / 2))
if [ $DEFAULT_THREADS -lt 1 ]; then
    DEFAULT_THREADS=1
fi

read -p "[?] Number of mining threads (1-$TOTAL_CORES) [default: $DEFAULT_THREADS]: " THREADS
THREADS=${THREADS:-$DEFAULT_THREADS}

echo ""
echo "[*] Starting miner with $THREADS threads..."

# Start mining
RESULT=$(curl -s http://127.0.0.1:19081/start_mining -d "{
    \"miner_address\": \"$WALLET_ADDRESS\",
    \"threads_count\": $THREADS,
    \"do_background_mining\": false,
    \"ignore_battery\": true
}" -H "Content-Type: application/json")

if echo "$RESULT" | grep -q '"status":"OK"'; then
    echo "[+] Mining started!"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                     MINING ACTIVE"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "  Address: $WALLET_ADDRESS"
    echo "  Threads: $THREADS"
    echo ""
    echo "  Commands:"
    echo "    Check status:  curl http://127.0.0.1:19081/mining_status"
    echo "    Stop mining:   curl -X POST http://127.0.0.1:19081/stop_mining"
    echo "    Block height:  curl http://127.0.0.1:19081/json_rpc -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_info\"}' -H 'Content-Type: application/json' | grep height"
    echo ""
    echo "  Dashboard: ./start.sh (opens web UI)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Show live mining status
    echo "[*] Mining status (Ctrl+C to exit monitoring):"
    echo ""
    while true; do
        STATUS=$(curl -s http://127.0.0.1:19081/mining_status)
        SPEED=$(echo "$STATUS" | grep -o '"speed":[0-9]*' | cut -d: -f2)
        HEIGHT=$(curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
        printf "\r    Height: %-8s | Speed: %-6s H/s" "$HEIGHT" "$SPEED"
        sleep 2
    done
else
    echo "[!] Failed to start mining: $RESULT"
    exit 1
fi
