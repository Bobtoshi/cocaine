#!/bin/bash

echo ""
echo " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗"
echo "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝"
echo "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  "
echo "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  "
echo "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗"
echo " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝"
echo ""
echo "                    COCAINE v1.0"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Create data directories
mkdir -p "$SCRIPT_DIR/blockchain"
mkdir -p "$SCRIPT_DIR/wallets"

# Check if daemon is already running
if pgrep -x "cocained" > /dev/null; then
    echo "[*] Daemon is already running"
else
    echo "[*] Starting Cocaine daemon (connecting to VPS seed node)..."
    "$SCRIPT_DIR/build/bin/cocained" \
        --data-dir "$SCRIPT_DIR/blockchain" \
        --log-level 1 \
        --rpc-bind-ip 127.0.0.1 \
        --rpc-bind-port 19081 \
        --p2p-bind-ip 127.0.0.1 \
        --p2p-bind-port 19080 \
        --add-peer 138.68.128.104:19080 \
        --detach

    echo "[*] Waiting for daemon to start and connect to seed node..."
    sleep 5
fi

# Check daemon status
if curl -s http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json" > /dev/null 2>&1; then
    echo "[+] Daemon is running on port 19081"
else
    echo "[-] Warning: Daemon may not be fully started yet"
fi

echo ""
echo "[*] Starting Dashboard..."
cd "$SCRIPT_DIR/dashboard"
node server.js
