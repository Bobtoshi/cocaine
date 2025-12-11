#!/bin/bash

# ============================================================================
#  COCAINE - Cryptocurrency Mining Suite
#  Main launcher script
# ============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BIN_DIR="$SCRIPT_DIR/bin"
DATA_DIR="$SCRIPT_DIR/data"
WALLET_DIR="$SCRIPT_DIR/wallets"
DASHBOARD_DIR="$SCRIPT_DIR/dashboard"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_banner() {
    echo ""
    echo -e "${GREEN}"
    echo " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗"
    echo "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝"
    echo "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  "
    echo "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  "
    echo "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗"
    echo " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝"
    echo -e "${NC}"
    echo "                    v1.0.0 'White Line'"
    echo ""
}

check_dependencies() {
    # Check for Node.js
    if ! command -v node &> /dev/null; then
        echo -e "${RED}[!] Node.js is required but not installed.${NC}"
        echo "    Install from: https://nodejs.org/"
        exit 1
    fi

    # Check for npm
    if ! command -v npm &> /dev/null; then
        echo -e "${RED}[!] npm is required but not installed.${NC}"
        exit 1
    fi
}

setup_directories() {
    mkdir -p "$DATA_DIR"
    mkdir -p "$WALLET_DIR"
}

install_dashboard_deps() {
    if [ ! -d "$DASHBOARD_DIR/node_modules" ]; then
        echo "[*] Installing dashboard dependencies..."
        cd "$DASHBOARD_DIR"
        npm install --quiet
        cd "$SCRIPT_DIR"
    fi
}

is_daemon_running() {
    curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" 2>/dev/null | grep -q '"status":"OK"'
}

start_daemon() {
    if is_daemon_running; then
        echo -e "${GREEN}[+] Daemon already running${NC}"
        return
    fi

    echo "[*] Starting daemon..."
    "$BIN_DIR/cocained" \
        --data-dir "$DATA_DIR" \
        --log-level 1 \
        --rpc-bind-ip 0.0.0.0 \
        --rpc-bind-port 19081 \
        --confirm-external-bind \
        --detach

    # Wait for daemon to start
    for i in {1..30}; do
        if is_daemon_running; then
            echo -e "${GREEN}[+] Daemon started successfully${NC}"
            return
        fi
        sleep 1
    done

    echo -e "${RED}[!] Failed to start daemon${NC}"
    exit 1
}

stop_daemon() {
    echo "[*] Stopping daemon..."
    pkill -f cocained 2>/dev/null || true
    sleep 2
    echo -e "${GREEN}[+] Daemon stopped${NC}"
}

start_dashboard() {
    echo "[*] Starting dashboard..."
    cd "$DASHBOARD_DIR"

    # Export paths for the dashboard
    export COCAINE_BIN_DIR="$BIN_DIR"
    export COCAINE_WALLET_DIR="$WALLET_DIR"

    node server.js
}

show_status() {
    echo ""
    if is_daemon_running; then
        echo -e "Daemon:    ${GREEN}Running${NC}"
        HEIGHT=$(curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
        echo "  Height:  $HEIGHT"
    else
        echo -e "Daemon:    ${RED}Stopped${NC}"
    fi

    MINING=$(curl -s http://127.0.0.1:19081/mining_status 2>/dev/null | grep -o '"active":[a-z]*' | cut -d: -f2)
    if [ "$MINING" = "true" ]; then
        HASHRATE=$(curl -s http://127.0.0.1:19081/mining_status | grep -o '"speed":[0-9]*' | cut -d: -f2)
        echo -e "Mining:    ${GREEN}Active${NC} ($HASHRATE H/s)"
    else
        echo -e "Mining:    ${YELLOW}Inactive${NC}"
    fi
    echo ""
}

show_help() {
    echo "Usage: ./cocaine.sh [command]"
    echo ""
    echo "Commands:"
    echo "  start      Start daemon and dashboard (default)"
    echo "  stop       Stop all services"
    echo "  daemon     Start only the daemon"
    echo "  dashboard  Start only the dashboard"
    echo "  status     Show current status"
    echo "  mine       Quick start mining"
    echo "  wallet     Open wallet CLI"
    echo "  help       Show this help"
    echo ""
}

quick_mine() {
    start_daemon

    echo ""
    echo "[*] Quick Mining Setup"
    echo ""

    # Check for existing wallet
    if ls "$WALLET_DIR"/*.keys 2>/dev/null | head -1 > /dev/null; then
        echo "[+] Found existing wallet"
        WALLET_FILE=$(ls "$WALLET_DIR"/*.keys 2>/dev/null | head -1 | sed 's/.keys$//')

        ADDRESS=$("$BIN_DIR/cocaine-wallet-cli" \
            --wallet-file "$WALLET_FILE" \
            --password "" \
            --daemon-address 127.0.0.1:19081 \
            --command "address" 2>/dev/null | grep -E "^0 +" | awk '{print $2}')
    else
        echo "[*] Creating new wallet..."
        WALLET_FILE="$WALLET_DIR/wallet_$(date +%s)"

        OUTPUT=$("$BIN_DIR/cocaine-wallet-cli" \
            --generate-new-wallet "$WALLET_FILE" \
            --password "" \
            --mnemonic-language English \
            --daemon-address 127.0.0.1:19081 \
            --command "exit" 2>&1)

        ADDRESS=$(echo "$OUTPUT" | grep "Generated new wallet:" | sed 's/.*: //')
        SEED=$(echo "$OUTPUT" | sed -n '/NOTE: the following/,/\*\*\*/p' | grep -v "NOTE:" | grep -v "\*\*\*" | tr '\n' ' ' | xargs)

        echo ""
        echo "════════════════════════════════════════════════════════════"
        echo "                    NEW WALLET CREATED"
        echo "════════════════════════════════════════════════════════════"
        echo ""
        echo -e "${YELLOW}SAVE YOUR SEED PHRASE:${NC}"
        echo ""
        echo "$SEED"
        echo ""
        echo "════════════════════════════════════════════════════════════"
    fi

    if [ -z "$ADDRESS" ]; then
        echo -e "${RED}[!] Could not get wallet address${NC}"
        exit 1
    fi

    echo ""
    echo "[+] Mining to: $ADDRESS"
    echo ""

    # Get thread count
    CORES=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
    DEFAULT=$((CORES / 2))
    [ $DEFAULT -lt 1 ] && DEFAULT=1

    read -p "[?] Mining threads (1-$CORES) [default: $DEFAULT]: " THREADS
    THREADS=${THREADS:-$DEFAULT}

    # Start mining
    RESULT=$(curl -s http://127.0.0.1:19081/start_mining -d "{\"miner_address\":\"$ADDRESS\",\"threads_count\":$THREADS,\"do_background_mining\":false,\"ignore_battery\":true}" -H "Content-Type: application/json")

    if echo "$RESULT" | grep -q '"status":"OK"'; then
        echo ""
        echo -e "${GREEN}[+] Mining started!${NC}"
        echo ""
        echo "  Dashboard: http://localhost:8080"
        echo "  Stop mining: curl -X POST http://127.0.0.1:19081/stop_mining"
        echo ""

        # Monitor
        echo "[*] Mining... (Ctrl+C to stop monitoring)"
        while true; do
            HEIGHT=$(curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" | grep -o '"height":[0-9]*' | cut -d: -f2)
            SPEED=$(curl -s http://127.0.0.1:19081/mining_status | grep -o '"speed":[0-9]*' | cut -d: -f2)
            printf "\r  Height: %-8s | Speed: %-6s H/s" "$HEIGHT" "$SPEED"
            sleep 2
        done
    else
        echo -e "${RED}[!] Failed to start mining${NC}"
        echo "$RESULT"
    fi
}

# ============================================================================
# Main
# ============================================================================

print_banner
check_dependencies
setup_directories
install_dashboard_deps

case "${1:-start}" in
    start)
        start_daemon
        start_dashboard
        ;;
    stop)
        stop_daemon
        pkill -f "node.*server.js" 2>/dev/null || true
        pkill -f cocaine-wallet-rpc 2>/dev/null || true
        echo -e "${GREEN}[+] All services stopped${NC}"
        ;;
    daemon)
        start_daemon
        show_status
        ;;
    dashboard)
        start_dashboard
        ;;
    status)
        show_status
        ;;
    mine)
        quick_mine
        ;;
    wallet)
        "$BIN_DIR/cocaine-wallet-cli" --daemon-address 127.0.0.1:19081
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
