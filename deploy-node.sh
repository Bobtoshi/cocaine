#!/bin/bash
# COCAINE Node Deployment Script for Ubuntu 22.04
# Run as root on a fresh VPS

set -e

echo "=== COCAINE Node Deployment ==="
echo ""

# Update system
echo "[1/5] Updating system..."
apt update && apt upgrade -y

# Install dependencies
echo "[2/5] Installing dependencies..."
apt install -y wget tar ufw

# Create cocaine user
echo "[3/5] Creating cocaine user..."
useradd -m -s /bin/bash cocaine || true

# Download latest release
echo "[4/5] Downloading COCAINE binaries..."
cd /home/cocaine
wget -q https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz
tar -xzf cocaine-linux-x64.tar.gz
mv cocaine-linux-x64/* .
rm -rf cocaine-linux-x64 cocaine-linux-x64.tar.gz
chown -R cocaine:cocaine /home/cocaine

# Configure firewall
echo "[5/5] Configuring firewall..."
ufw allow 22/tcp    # SSH
ufw allow 19080/tcp # P2P
ufw --force enable

# Create systemd service
cat > /etc/systemd/system/cocained.service << 'EOF'
[Unit]
Description=COCAINE Daemon
After=network.target

[Service]
Type=simple
User=cocaine
WorkingDirectory=/home/cocaine
ExecStart=/home/cocaine/cocained --data-dir /home/cocaine/.cocaine --p2p-bind-port 19080 --rpc-bind-ip 127.0.0.1 --rpc-bind-port 19081 --non-interactive --log-level 1
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl daemon-reload
systemctl enable cocained
systemctl start cocained

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Node is running!"
echo ""
echo "Seed node address: ${PUBLIC_IP}:19080"
echo ""
echo "Useful commands:"
echo "  systemctl status cocained    # Check status"
echo "  journalctl -u cocained -f    # View logs"
echo "  systemctl restart cocained   # Restart node"
echo ""
echo "Add this to your README as a seed node:"
echo "  ${PUBLIC_IP}:19080"
echo ""
