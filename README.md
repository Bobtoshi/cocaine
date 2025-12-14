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

| Platform | Download |
|----------|----------|
| **Windows** | [cocaine-windows-x64.zip](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-windows-x64.zip) |
| **Linux** | [cocaine-linux-x64.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz) |
| **macOS** | [cocaine-macos.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-macos.tar.gz) |

[View all releases](https://github.com/Bobtoshi/cocaine/releases)

## Requirements

- **Node.js** - Download from https://nodejs.org (required for web dashboard)

## Quick Start

### Windows
1. Download and extract `cocaine-windows-x64.zip`
2. Double-click `start.bat`
3. Open http://localhost:8080 in your browser

### Linux
```bash
tar -xzvf cocaine-linux-x64.tar.gz
cd cocaine-linux-x64
./start.sh
```
Then open http://localhost:8080

### macOS
```bash
tar -xzvf cocaine-macos.tar.gz
cd cocaine-macos
./start.command
```
Then open http://localhost:8080

## Web Dashboard

The dashboard provides a complete interface for managing your COCA:

### Features
- **Dashboard Tab** - Live network map, hashrate charts, block times, mining stats
- **Wallet Tab** - Create/restore wallets, view balance, send COCA, transaction history
- **Mining Tab** - Start/stop mining with adjustable CPU threads, real-time hashrate
- **Network Tab** - Connected peers, daemon status, sync progress
- **Explorer Tab** - Browse recent blocks with rewards and difficulty

### Dashboard Highlights
- Global network map showing seed nodes, peers, and active miners
- Real-time hashrate and block time charts
- Live sync status and peer connections
- No scrolling required - everything fits on screen

## Mining

1. Start the dashboard (see Quick Start above)
2. Go to **Wallet** tab and create or open a wallet
3. Go to **Mining** tab
4. Click "Use Wallet" to auto-fill your address
5. Select CPU threads and click "Start Mining"

Your mining progress appears on the network map as an orange dot!

**Note:** Mining rewards are locked for 60 blocks (~2 hours) before they become spendable.

## Network Info

| Setting | Value |
|---------|-------|
| Seed Node | `138.68.128.104:19080` |
| P2P Port | 19080 |
| RPC Port | 19081 |
| Dashboard | http://localhost:8080 |

## Technical Specs

| Property | Value |
|----------|-------|
| Ticker | COCA |
| Block Time | ~2 minutes |
| Algorithm | CryptoNight |
| Unlock Window | 60 blocks |

## Wallet Security

- **Save your seed phrase** - it's the only way to recover your wallet
- Store it offline, never share it
- Wallet files are stored locally on your machine

## Troubleshooting

**Dashboard won't load?**
- Make sure Node.js is installed
- Check that ports 8080 and 19081 aren't in use

**Not syncing?**
- The daemon connects to the seed node automatically
- Wait for blockchain to download on first run
- Check Network tab for peer connections

**Mining not starting?**
- Ensure daemon shows "Synced" status in the header
- Mining won't start until blockchain is synchronized

**Rewards not showing?**
- Rewards are locked for 60 blocks (~2 hours)
- Check dashboard - locked vs unlocked balance

## Building from Source

```bash
git clone https://github.com/bobtoshi/cocaine.git
cd cocaine
git submodule update --init --force --recursive
mkdir build && cd build
cmake ..
make -j$(nproc) daemon simplewallet wallet_rpc_server
```

## License

Based on the Monero Project. See LICENSE for details.
