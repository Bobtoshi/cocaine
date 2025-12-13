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

- **Node.js** - Download from https://nodejs.org (required for web interface)

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

The web interface lets you:
- Create/restore wallets
- View balance (locked & unlocked)
- Start/stop mining
- Send COCA
- View transaction history

## Mining

### Local Mining (Recommended)

**IMPORTANT: Mining happens on YOUR machine, not on a remote server.**

1. Open the dashboard at http://localhost:8080
2. Create or restore a wallet
3. Click "Start Mining"
4. Rewards appear after 60 block confirmations (~2 hours)

**On Mac/Linux:** Use `./mine.sh` to start a local daemon that syncs from the seed node and mines locally.

### Remote Mining: DO NOT USE `start_mining` on Remote Daemons

**⚠️ CRITICAL:** The `start_mining` RPC command mines on the machine where the daemon runs. 

- **DO NOT** use `start_mining` against a remote VPS/daemon - this mines on the VPS, not your machine
- **DO** run your own local daemon and use `start_mining` against `127.0.0.1:19081`
- **DO** connect your local daemon to the seed node (`138.68.128.104:19080`) for blockchain sync
- For remote mining, use external miners (XMRig) in daemon/solo mode - see `tools/mine_remote.md`

**VPS RPC Security:** The VPS RPC port (19081) may be bound to `127.0.0.1` only for safety. This prevents remote mining abuse.

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
- Wallet files are in your data directory

## Troubleshooting

**Dashboard won't load?**
- Make sure Node.js is installed
- Check that ports 8080 and 19081 aren't in use

**Not syncing?**
- The daemon connects to seed node automatically
- Wait for blockchain to download on first run
- On Mac/Linux, ensure `./mine.sh` shows peers > 0
- If peers = 0, check that seed node `138.68.128.104:19080` is reachable

**Mining rewards not showing?**
- Rewards are locked for 60 blocks (~2 hours)
- Check "Locked Balance" in dashboard

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
