#!/bin/bash
# macOS Launcher - Starts controller + dashboard

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR/.."

echo ""
echo " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗"
echo "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝"
echo "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  "
echo "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  "
echo "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗"
echo " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝"
echo ""
echo "Starting Dashboard with Controller..."
echo ""

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "[!] Node.js not found. Please install from https://nodejs.org"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "dashboard/node_modules" ]; then
    echo "[*] Installing dependencies..."
    cd dashboard
    npm install
    cd ..
fi

# Start controller in background
echo "[*] Starting controller..."
cd dashboard
node controller.js > ../logs/controller.log 2>&1 &
CONTROLLER_PID=$!
cd ..

# Wait for controller to start
sleep 2

# Start dashboard
echo "[*] Starting dashboard..."
cd dashboard
node server.js

# Cleanup on exit
trap "kill $CONTROLLER_PID 2>/dev/null" EXIT

