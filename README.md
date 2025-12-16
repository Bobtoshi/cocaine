# COCAINE (COCA)

```
 ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗
██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝
██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗
██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝
╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗
 ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
```

A privacy-focused cryptocurrency forked from Monero. Uses RandomX proof-of-work algorithm for CPU mining from genesis block.

## Quick Links

| Resource | Link |
|----------|------|
| **Dashboard (GUI)** | [github.com/Bobtoshi/cocaine-dashboard](https://github.com/Bobtoshi/cocaine-dashboard) |
| **Releases** | [Download Binaries](https://github.com/Bobtoshi/cocaine/releases) |
| **Seed Node** | `138.68.128.104:19080` |

---

## Network Specifications

| Property | Value |
|----------|-------|
| **Ticker** | COCA |
| **Algorithm** | RandomX (CPU mining) |
| **Block Time** | ~2 minutes |
| **Block Reward** | ~70 COCA (decreasing emission) |
| **Unlock Time** | 60 blocks |
| **P2P Port** | 19080 |
| **RPC Port** | 19081 |

---

## Building From Source

### Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y build-essential cmake git libboost-all-dev \
  libssl-dev libzmq3-dev libunbound-dev libsodium-dev libhidapi-dev \
  libusb-1.0-0-dev libprotobuf-dev protobuf-compiler pkg-config
```

**Fedora:**
```bash
sudo dnf install -y gcc gcc-c++ cmake git boost-devel openssl-devel \
  zeromq-devel unbound-devel libsodium-devel hidapi-devel \
  libusb1-devel protobuf-devel protobuf-compiler pkg-config
```

**Arch Linux:**
```bash
sudo pacman -S base-devel cmake git boost openssl zeromq unbound libsodium hidapi libusb protobuf
```

**macOS:**
```bash
brew install cmake boost openssl zeromq unbound libsodium hidapi libusb protobuf pkg-config
```

**Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake mingw-w64-x86_64-boost \
  mingw-w64-x86_64-openssl mingw-w64-x86_64-zeromq mingw-w64-x86_64-libsodium \
  mingw-w64-x86_64-hidapi mingw-w64-x86_64-protobuf git
```

### Build Steps

```bash
git clone --recursive https://github.com/Bobtoshi/cocaine.git
cd cocaine
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release ..
make -j$(nproc)
```

**Binaries output to `build/bin/`:**
- `cocained` - Blockchain daemon
- `cocaine-wallet-cli` - Command-line wallet
- `cocaine-wallet-rpc` - Wallet RPC server

---

## Running

### Start Daemon
```bash
./cocained --data-dir ~/.cocaine --p2p-bind-port 19080 --rpc-bind-ip 127.0.0.1 --rpc-bind-port 19081
```

### Start Mining
```bash
# Via RPC
curl http://127.0.0.1:19081/start_mining?miner_address=YOUR_ADDRESS&threads_count=4
```

### Create Wallet
```bash
./cocaine-wallet-cli --daemon-address 127.0.0.1:19081 --generate-new-wallet mywallet
```

---

## Pre-Built Binaries

| Platform | Download |
|----------|----------|
| **Linux x64** | [cocaine-linux-x64.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz) |
| **macOS** | [cocaine-macos.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-macos.tar.gz) |
| **Windows** | [cocaine-windows-x64.zip](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-windows-x64.zip) |

---

## Dashboard (Web GUI)

For a browser-based interface with wallet management, mining controls, and block explorer:

**[github.com/Bobtoshi/cocaine-dashboard](https://github.com/Bobtoshi/cocaine-dashboard)**

Features:
- Real-time network stats and sync status
- Wallet creation, restore, send/receive
- Mining start/stop with hashrate monitoring
- Block explorer
- Transaction history

---

## RPC Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /get_info` | Network status |
| `GET /mining_status` | Mining status |
| `GET /start_mining?miner_address=X&threads_count=N` | Start mining |
| `GET /stop_mining` | Stop mining |
| `POST /json_rpc` | JSON-RPC interface |

---

## Troubleshooting

**Won't sync?**
- Ensure port 19080 is open
- Check seed node: `nc -zv 138.68.128.104 19080`

**Mining not working?**
- Must be fully synced first
- Check: `curl http://127.0.0.1:19081/mining_status`

**Wallet issues?**
- Ensure daemon is running and synced
- Rescan: use `rescan_bc` in wallet-cli

---

## License

BSD-3-Clause. Based on [Monero](https://github.com/monero-project/monero).

## Disclaimer

Experimental software. Use at your own risk. This is a meme coin with no financial promises.
