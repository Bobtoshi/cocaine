#!/bin/bash

# COCAINE Seed Node Deployment Script
# Run this ON the VPS after uploading the source

set -e

echo ""
echo "COCAINE Seed Node Deployment"
echo "============================"
echo ""

# Install build dependencies
echo "[*] Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y build-essential cmake pkg-config \
    libboost-all-dev libssl-dev libzmq3-dev libunbound-dev \
    libsodium-dev libreadline-dev libexpat1-dev \
    libpgm-dev libnorm-dev git

# Initialize submodules
echo "[*] Initializing submodules..."
git submodule update --init --force --recursive

# Build
echo "[*] Building daemon (this takes 10-20 minutes)..."
mkdir -p build
cd build
cmake .. -DBUILD_TESTS=OFF
make -j$(nproc) daemon

echo "[*] Build complete!"

# Create directories
mkdir -p ~/cocaine-data

# Create systemd service
echo "[*] Creating systemd service..."
sudo tee /etc/systemd/system/cocained.service > /dev/null <<EOF
[Unit]
Description=Cocaine Daemon
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$PWD/bin/cocained --data-dir $HOME/cocaine-data --log-level 1 --rpc-bind-ip 0.0.0.0 --rpc-bind-port 19081 --confirm-external-bind --non-interactive
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable cocained
sudo systemctl start cocained

echo ""
echo "================================================"
echo "  COCAINE SEED NODE DEPLOYED!"
echo "================================================"
echo ""
echo "  Status:  sudo systemctl status cocained"
echo "  Logs:    sudo journalctl -u cocained -f"
echo "  Stop:    sudo systemctl stop cocained"
echo "  Start:   sudo systemctl start cocained"
echo ""
echo "  Make sure port 19080 is open in GCP Firewall!"
echo ""
