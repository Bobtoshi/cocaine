#!/bin/bash
# Start COCAINE seed node with public tunnel
# Run this after restarting your Mac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Starting COCAINE Seed Node ==="

# Kill any existing processes
pkill -f cocained 2>/dev/null
pkill -f "bore local" 2>/dev/null
sleep 2

# Start daemon
echo "[1/2] Starting daemon..."
./build/bin/cocained \
    --data-dir ./data \
    --p2p-bind-port 19080 \
    --rpc-bind-ip 127.0.0.1 \
    --rpc-bind-port 19081 \
    --detach \
    --log-file ./data/cocained.log \
    --log-level 1

sleep 3

# Start tunnel
echo "[2/2] Starting public tunnel..."
nohup bore local 19080 --to bore.pub > ./data/bore.log 2>&1 &
sleep 3

# Get tunnel address
TUNNEL_ADDR=$(grep "listening at" ./data/bore.log | tail -1 | grep -oE "bore.pub:[0-9]+")

echo ""
echo "=== Seed Node Running ==="
echo ""
echo "Local RPC:    http://127.0.0.1:19081"
echo "Public P2P:   $TUNNEL_ADDR"
echo ""
echo "Logs:"
echo "  Daemon: ./data/cocained.log"
echo "  Tunnel: ./data/bore.log"
echo ""
echo "To stop: pkill cocained && pkill bore"
echo ""

# Verify
curl -s http://127.0.0.1:19081/get_info | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'Status: OK | Height: {d[\"height\"]} | Synced: {d[\"synchronized\"]}')" 2>/dev/null || echo "Warning: Daemon not responding yet"
