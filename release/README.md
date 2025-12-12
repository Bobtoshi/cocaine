# COCAINE (COCA)

A privacy-focused cryptocurrency with peer-to-peer networking.

```
 ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗
██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝
██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗
██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝
╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗
 ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
```

## Downloads

Download pre-built binaries for your platform:

| Platform | Download |
|----------|----------|
| **Windows x64** | [cocaine-windows-x64.zip](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-windows-x64.zip) |
| **Linux x64** | [cocaine-linux-x64.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz) |
| **macOS** | [cocaine-macos.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-macos.tar.gz) |

[View all releases](https://github.com/Bobtoshi/cocaine/releases)

---

## Quick Start

### Windows

1. Download and extract `cocaine-windows-x64.zip`
2. Open Command Prompt or PowerShell in the extracted folder
3. Start the daemon:
   ```cmd
   cocained.exe
   ```
4. Open a new terminal and create/open your wallet:
   ```cmd
   cocaine-wallet-cli.exe --generate-new-wallet mywallet
   ```
5. Start mining (in the wallet):
   ```
   start_mining 4
   ```
   (Replace `4` with the number of CPU threads you want to use)

### Linux

```bash
# Download and extract
wget https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz
tar -xzvf cocaine-linux-x64.tar.gz
cd cocaine-linux-x64

# Start daemon in background
./cocained --detach

# Create wallet and start mining
./cocaine-wallet-cli --generate-new-wallet mywallet
# In wallet: start_mining 4
```

### macOS (with Dashboard)

For macOS users, we provide a convenient script with a web dashboard:

```bash
# Clone the repo
git clone https://github.com/Bobtoshi/cocaine.git
cd cocaine

# Make executable (first time only)
chmod +x cocaine.sh

# Start mining
./cocaine.sh mine
```

The script will:
1. Start the daemon
2. Create a new wallet (or use existing)
3. Start mining to your wallet

**IMPORTANT**: Save your seed phrase when displayed - it's your only backup!

## Commands

| Command | Description |
|---------|-------------|
| `./cocaine.sh` | Start daemon + dashboard (default) |
| `./cocaine.sh mine` | Quick start mining |
| `./cocaine.sh stop` | Stop all services |
| `./cocaine.sh status` | Show current status |
| `./cocaine.sh daemon` | Start only the daemon |
| `./cocaine.sh dashboard` | Start only the dashboard |
| `./cocaine.sh wallet` | Open wallet CLI |
| `./cocaine.sh help` | Show help |

## Web Dashboard

After starting, open http://localhost:8080 in your browser.

Features:
- Create/restore wallets
- View balance (locked & unlocked)
- Start/stop mining
- Send COCA
- Transaction history
- Block explorer

## Mining Rewards

- Blocks are mined approximately every 2 minutes
- Rewards are locked for 60 blocks (~2 hours) before spendable
- "Locked Balance" = pending mining rewards
- "Unlocked Balance" = spendable funds

## Directory Structure

```
cocaine/
├── cocaine.sh      # Main launcher
├── bin/            # Binaries
│   ├── cocained              # Daemon
│   ├── cocaine-wallet-cli    # Wallet CLI
│   └── cocaine-wallet-rpc    # Wallet RPC server
├── dashboard/      # Web dashboard
├── data/           # Blockchain data (created on first run)
└── wallets/        # Wallet files (created on first run)
```

## Wallet Security

### Seed Phrase
- Your 25-word seed phrase is the ONLY way to recover your wallet
- Write it down and store it safely offline
- Never share your seed phrase with anyone

### Wallet Files
- Wallet files are stored in the `wallets/` directory
- Files with `.keys` extension contain your private keys
- Back up your wallet files regularly

### Password Protection
- When creating a wallet via the dashboard, you can set a password
- The password encrypts your wallet file
- Without the password, you'll need the seed phrase to recover

## Network

COCAINE is a real peer-to-peer network. When you start the daemon:
- It connects to seed nodes to find other miners
- Your blockchain syncs with the network
- Mined coins can be sent to anyone on the network

**Seed Node**: `34.32.101.141:19080`

### Running Your Own Seed Node

To help the network, you can run a public node:
```bash
./bin/cocained --rpc-bind-ip 0.0.0.0 --rpc-bind-port 19081 --confirm-external-bind
```

Make sure port 19080 (P2P) is open on your firewall.

## Ports

| Service | Port | Purpose |
|---------|------|---------|
| P2P | 19080 | Peer connections |
| Daemon RPC | 19081 | Local API |
| Wallet RPC | 19083 | Wallet API |
| Dashboard | 8080 | Web interface |

## Troubleshooting

### Daemon won't start
```bash
# Check if already running
ps aux | grep cocained

# Kill stale processes
pkill -f cocained

# Check logs
cat data/cocaine.log
```

### Dashboard won't load
```bash
# Reinstall dependencies
cd dashboard && rm -rf node_modules && npm install
```

### Mining shows 0 hashrate
- Ensure daemon is fully started
- Check that mining address is valid
- Try restarting mining

### Balance not showing
- Mining rewards are locked for 60 blocks
- Wait for confirmations
- Try refreshing wallet in dashboard

## Technical Specs

| Property | Value |
|----------|-------|
| Ticker | COCA |
| Address Prefix | 5 |
| Block Time | ~2 minutes |
| Mining Algorithm | RandomX |
| Unlock Window | 60 blocks |
| Max Supply | ~18.4 million |

## Building from Source

```bash
# Clone repository
git clone https://github.com/bobtoshi/cocaine.git
cd cocaine

# Initialize submodules
git submodule update --init --force --recursive

# Build
mkdir build && cd build
cmake ..
make -j$(nproc) daemon simplewallet

# Run daemon
./bin/cocained --detach

# Check status
curl http://127.0.0.1:19081/json_rpc -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' -H "Content-Type: application/json"
```

## License

Based on the Monero Project. See LICENSE for details.

## Disclaimer

This software is for educational and experimental purposes. Use at your own risk.
