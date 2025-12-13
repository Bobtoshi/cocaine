#!/bin/bash

# Cocaine Mining Setup Script
# This script runs a LOCAL daemon that syncs from the VPS seed node
# Mining happens on YOUR machine, not on the VPS
# Run: ./mine.sh

set -e

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
echo "  Mining runs LOCALLY on your machine"
echo "  Blockchain syncs from VPS seed node: 138.68.128.104:19080"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
DAEMON="$SCRIPT_DIR/build/bin/cocained"
WALLET_CLI="$SCRIPT_DIR/build/bin/cocaine-wallet-cli"
DATA_DIR="$SCRIPT_DIR/blockchain"
WALLET_DIR="$SCRIPT_DIR/wallets"
DAEMON_ADDRESS="127.0.0.1:19081"
DAEMON_URL="http://${DAEMON_ADDRESS}"
SEED_NODE="138.68.128.104:19080"

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
    curl -s --max-time 3 "$DAEMON_URL/json_rpc" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" 2>/dev/null | grep -q '"status":"OK"'
}

# Check if local daemon is running
if check_daemon; then
    echo "[+] Local daemon already running"
else
    echo "[*] Starting local daemon (this will sync from VPS seed node)..."
    
    # Kill any stale process
    pkill -f cocained 2>/dev/null || true
    sleep 2

    # Start local daemon with seed node
    "$DAEMON" \
        --data-dir "$DATA_DIR" \
        --log-level 1 \
        --rpc-bind-ip 127.0.0.1 \
        --rpc-bind-port 19081 \
        --p2p-bind-ip 127.0.0.1 \
        --p2p-bind-port 19080 \
        --add-exclusive-node "$SEED_NODE" \
        --detach

    echo "[*] Waiting for daemon to start and connect to seed node..."
    for i in {1..60}; do
        if check_daemon; then
            echo "[+] Local daemon started successfully"
            echo "[*] Syncing blockchain from seed node (this may take a while)..."
            break
        fi
        sleep 1
    done

    if ! check_daemon; then
        echo "[!] Failed to start local daemon. Check logs at $DATA_DIR/cocaine.log"
        exit 1
    fi
fi

# Get daemon status
echo ""
INFO=$(curl -s "$DAEMON_URL/get_info")
HEIGHT=$(echo "$INFO" | grep -o '"height":[0-9]*' | cut -d: -f2)
BUSY=$(echo "$INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('busy_syncing', False))" 2>/dev/null || echo "false")
SYNCED=$(echo "$INFO" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('synchronized', False))" 2>/dev/null || echo "false")

echo "[+] Current block height: $HEIGHT"

if [ "$BUSY" = "True" ] || [ "$SYNCED" != "True" ]; then
    echo "[*] Blockchain is still syncing from seed node..."
    echo "[*] You can start mining now, but it's better to wait for sync to complete"
    read -p "[?] Start mining now anyway? (y/n) [n]: " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "[*] Waiting for sync to complete. Run this script again when ready."
        echo "[*] Monitor sync: watch -n 2 'curl -s http://127.0.0.1:19081/get_info | python3 -c \"import sys,json; d=json.load(sys.stdin); print(f\"Height: {d[\\\"height\\\"]} | Synced: {d.get(\\\"synchronized\\\", False)}\")\"'"
        exit 0
    fi
else
    echo "[+] Blockchain is synchronized!"
fi

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
        --daemon-address "$DAEMON_ADDRESS" \
        --command "address" 2>/dev/null | grep -E "^0 +5" | awk '{print $2}')
else
    echo "[*] Creating new wallet..."
    WALLET_FILE="$WALLET_DIR/wallet_$(date +%s)"

    OUTPUT=$("$WALLET_CLI" \
        --generate-new-wallet "$WALLET_FILE" \
        --password "" \
        --mnemonic-language English \
        --daemon-address "$DAEMON_ADDRESS" \
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
RESULT=$(curl -s "$DAEMON_URL/start_mining" -d "{
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
    echo "    Check status:  curl $DAEMON_URL/mining_status"
    echo "    Stop mining:   curl -X POST $DAEMON_URL/stop_mining"
    echo "    Block height:  curl $DAEMON_URL/json_rpc -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_info\"}' -H 'Content-Type: application/json' | grep height"
    echo ""
    echo "  Dashboard: ./start.sh (opens web UI)"
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Show live mining status
    echo "[*] Mining status (Ctrl+C to exit monitoring):"
    echo ""
    while true; do
        STATUS=$(curl -s "$DAEMON_URL/mining_status")
        SPEED=$(echo "$STATUS" | grep -o '"speed":[0-9]*' | cut -d: -f2)
        HEIGHT=$(curl -s "$DAEMON_URL/json_rpc" -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
        printf "\r    Height: %-8s | Speed: %-6s H/s" "$HEIGHT" "$SPEED"
        sleep 2
    done
else
    echo "[!] Failed to start mining: $RESULT"
    exit 1
fi
