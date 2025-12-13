#!/bin/bash

# Cocaine Mining Setup Script
#
# Local mode (builds/starts local daemon + mines locally):
#   ./mine.sh
#
# Solo mode (mine on THIS machine against a remote daemon RPC, e.g. your VPS):
#   ./mine.sh --solo <host:port> --address <WALLET_ADDRESS> [--threads N]
#
# Notes:
# - --solo uses an external miner (XMRig) so your local CPU does the hashing.
# - Your VPS daemon just provides block templates and accepts submissions.
# - This does NOT make the VPS CPU mine.

set -e

SOLO_RPC=""
SOLO_ADDRESS=""
SOLO_THREADS=""

usage() {
  echo ""
  echo "Usage:"
  echo "  Local:  $0"
  echo "  Solo:   $0 --solo <host:port> --address <WALLET_ADDRESS> [--threads N]"
  echo ""
  echo "Examples:"
  echo "  $0"
  echo "  $0 --solo 1.2.3.4:19081 --address 5YourWalletAddressHere --threads 2"
  echo ""
}

# Basic arg parsing
while [ $# -gt 0 ]; do
  case "$1" in
    --solo)
      SOLO_RPC="$2"; shift 2 ;;
    --address)
      SOLO_ADDRESS="$2"; shift 2 ;;
    --threads)
      SOLO_THREADS="$2"; shift 2 ;;
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
# Solo mode: mine on THIS machine against a remote daemon (e.g. VPS)
# ============================
if [ -n "$SOLO_RPC" ] || [ -n "$SOLO_ADDRESS" ] || [ -n "$SOLO_THREADS" ]; then
  if [ -z "$SOLO_RPC" ] || [ -z "$SOLO_ADDRESS" ]; then
    echo "[!] Solo mode requires --solo <host:port> and --address <WALLET_ADDRESS>"
    usage
    exit 2
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "[!] curl is required for --solo mode."
    echo "    - macOS: already installed"
    echo "    - Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y curl"
    echo "    - Windows (Git Bash): install Git for Windows (includes curl)"
    exit 1
  fi

  # Default threads if not provided
  if [ -z "$SOLO_THREADS" ]; then
    # Use half cores by default (consistent with local mode)
    TOTAL_CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    SOLO_THREADS=$((TOTAL_CORES / 2))
    if [ "$SOLO_THREADS" -lt 1 ]; then
      SOLO_THREADS=1
    fi
  fi

  echo ""
  echo "[+] Solo mining (local CPU)"
  echo "    Daemon RPC: $SOLO_RPC"
  echo "    Address:    $SOLO_ADDRESS"
  echo "    Threads:    $SOLO_THREADS"
  echo ""

  # Quick daemon reachability check
  if ! curl -fsS "http://$SOLO_RPC/json_rpc" \
      -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
      -H "Content-Type: application/json" >/dev/null; then
    echo "[!] Cannot reach daemon RPC at http://$SOLO_RPC"
    echo "[!] Your VPS daemon must expose RPC to your network (preferably via VPN like Tailscale/WireGuard)."
    echo "[!] If public, ensure --rpc-bind-ip 0.0.0.0 + firewall/security-group allow inbound TCP on the RPC port."
    exit 1
  fi

  TOOLS_DIR="$SCRIPT_DIR/tools/xmrig"
  mkdir -p "$TOOLS_DIR"

  OS="$(uname -s 2>/dev/null || echo Unknown)"
  ARCH="$(uname -m 2>/dev/null || echo Unknown)"

  # Determine xmrig binary name for this shell
  XMRIG_BIN="$TOOLS_DIR/xmrig"
  case "$OS" in
    MINGW*|MSYS*|CYGWIN*)
      XMRIG_BIN="$TOOLS_DIR/xmrig.exe" ;;
  esac

  download_xmrig() {
    echo "[*] Downloading XMRig..."

    # Determine asset pattern
    ASSET_PATTERN=""
    case "$OS" in
      Darwin)
        # Prefer macOS universal/arm64; fall back to x86_64 if needed
        if echo "$ARCH" | grep -qiE 'arm|aarch64'; then
          ASSET_PATTERN='xmrig-.*-macos-arm64\.tar\.gz'
        else
          ASSET_PATTERN='xmrig-.*-macos-x64\.tar\.gz'
        fi
        ;;
      Linux)
        if echo "$ARCH" | grep -qiE 'aarch64|arm64'; then
          ASSET_PATTERN='xmrig-.*-linux-arm64\.tar\.gz'
        else
          ASSET_PATTERN='xmrig-.*-linux-x64\.tar\.gz'
        fi
        ;;
      MINGW*|MSYS*|CYGWIN*)
        ASSET_PATTERN='xmrig-.*-msvc-win64\.zip'
        ;;
      *)
        echo "[!] Unsupported OS for auto-download: $OS"
        echo "[!] Please download XMRig manually and place it at: $XMRIG_BIN"
        return 1
        ;;
    esac

    # Fetch latest release metadata (GitHub API)
    JSON=$(curl -fsS https://api.github.com/repos/xmrig/xmrig/releases/latest) || return 1

    # Extract the first matching browser_download_url
    URL=$(echo "$JSON" | grep -Eo '"browser_download_url"\s*:\s*"[^"]+"' \
      | sed 's/.*"\(https:[^"]\+\)"/\1/' \
      | grep -E "$ASSET_PATTERN" \
      | head -n 1)

    if [ -z "$URL" ]; then
      echo "[!] Could not find a matching XMRig release asset for $OS/$ARCH."
      echo "[!] Please download XMRig manually and place it at: $XMRIG_BIN"
      return 1
    fi

    TMP="$TOOLS_DIR/_xmrig_download"
    rm -rf "$TMP"
    mkdir -p "$TMP"

    FILE="$TMP/asset"
    curl -fL "$URL" -o "$FILE" || return 1

    case "$URL" in
      *.zip)
        if ! command -v unzip >/dev/null 2>&1; then
          echo "[!] unzip is required to extract XMRig on Windows/Git Bash."
          echo "    Install it (e.g. via MSYS2) or download/extract XMRig manually."
          return 1
        fi
        unzip -q "$FILE" -d "$TMP" || return 1
        FOUND=$(find "$TMP" -type f -name 'xmrig.exe' | head -n 1)
        if [ -z "$FOUND" ]; then
          echo "[!] Extraction succeeded but xmrig.exe not found."
          return 1
        fi
        cp "$FOUND" "$XMRIG_BIN" || return 1
        ;;
      *.tar.gz)
        tar -xzf "$FILE" -C "$TMP" || return 1
        FOUND=$(find "$TMP" -type f -name 'xmrig' | head -n 1)
        if [ -z "$FOUND" ]; then
          echo "[!] Extraction succeeded but xmrig not found."
          return 1
        fi
        cp "$FOUND" "$XMRIG_BIN" || return 1
        chmod +x "$XMRIG_BIN" || true
        ;;
      *)
        echo "[!] Unknown archive format: $URL"
        return 1
        ;;
    esac

    echo "[+] XMRig installed at $XMRIG_BIN"
    return 0
  }

  if [ ! -f "$XMRIG_BIN" ]; then
    if ! download_xmrig; then
      echo "[!] Failed to auto-install XMRig."
      echo "[!] Manual install: download XMRig and place binary at: $XMRIG_BIN"
      exit 1
    fi
  fi

  # Run xmrig in daemon mode (solo) against remote RPC
  echo "[*] Starting XMRig (solo/daemon mode)..."
  echo "    Tip: if Windows Defender flags it, you may need to allow it (miners are commonly false-positived)."
  echo ""

  "$XMRIG_BIN" \
    -o "$SOLO_RPC" \
    -u "$SOLO_ADDRESS" \
    -p x \
    --daemon \
    --cpu \
    --threads "$SOLO_THREADS"

  exit 0
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
