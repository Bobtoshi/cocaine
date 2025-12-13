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

### Local Mining via Web Dashboard (Recommended)

**IMPORTANT: All mining happens on YOUR machine, not on a remote server.**

The dashboard uses a controller system that:
- Starts a local daemon that syncs from the seed node (`138.68.128.104:19080`)
- Uses XMRig for CPU mining (not the daemon's built-in miner)
- Mines locally and submits work through your local daemon

**Steps:**
1. Start the dashboard:
   - **macOS:** `cd dashboard && ./start-mac.sh`
   - **Windows:** `cd dashboard && powershell -ExecutionPolicy Bypass -File start-windows.ps1`
   - **Linux:** `cd dashboard && npm start`
2. Open http://localhost:8080 in your browser
3. Go to the **Node** tab and click "Start Node" (waits for peers > 0)
4. Go to the **Mining** tab, enter your wallet address, and click "Start Mining"
5. XMRig will start mining on your machine

**Requirements:**
- Node.js installed (https://nodejs.org)
- XMRig installed (download from https://github.com/xmrig/xmrig/releases)
  - Place `xmrig` binary in the project root, or ensure it's in your PATH

**Note:** The dashboard will show a warning if peers = 0 for 60+ seconds, indicating the node may not be syncing properly.

### Alternative: Command Line Mining

**On Mac/Linux:** Use `./mine.sh` to start a local daemon that syncs from the seed node and mines using the daemon's built-in miner.

### Remote Mining: DO NOT USE `start_mining` on Remote Daemons

**⚠️ CRITICAL:** The `start_mining` RPC command mines on the machine where the daemon runs. 

- **DO NOT** use `start_mining` against a remote VPS/daemon - this mines on the VPS, not your machine
- **DO** run your own local daemon and connect it to the seed node for sync
- **DO** use XMRig (via dashboard controller) or the local daemon's miner for local mining
- The VPS seed node is for blockchain synchronization only, not mining

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
