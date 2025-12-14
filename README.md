# COCAINE (COCA)

```
 ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗
██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝
██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗
██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝
╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗
 ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝
```

## What Is This?

**COCAINE is a Monero fork.** It uses Monero's battle-tested codebase with minimal modifications. This is an experimental/educational project - a meme coin with no financial promises or expectations.

### Why Does This Exist?

This started as a learning project to understand how CryptoNote-based cryptocurrencies work under the hood. The name is intentionally absurd - it's not trying to be the next Bitcoin. It's an experiment in running a small private cryptocurrency network.

### What's Different From Monero?

Very little, by design:
- **Rebranded** - Different name, ticker (COCA), and network ports
- **Fresh genesis block** - New blockchain starting from block 0
- **Single seed node** - Small network, not trying to scale globally
- **Web dashboard** - Added a simple browser-based UI for easier interaction
- **Simplified setup** - Batteries-included packages for quick testing

The core cryptography, privacy features (RingCT, stealth addresses), and consensus mechanism are **unchanged from Monero**. We're not cryptographers and didn't try to "improve" proven security.

### Project Goals

1. **Learn** - Understand cryptocurrency internals by running one
2. **Experiment** - Test modifications in a low-stakes environment
3. **Fun** - It's a meme coin, treat it as such

### What This Is NOT

- Not an investment opportunity
- Not trying to compete with established cryptocurrencies
- Not making any claims about value or returns
- Not audited by security professionals

---

## Security & Trust Considerations

The crypto space has many bad actors. Here's how to evaluate this project:

### Build From Source (Recommended)

Pre-built binaries require trust. If you're security-conscious, **always build from source**. Complete instructions are below.

### Verify The Code

This is a Monero fork. You can compare our code against Monero's to see exactly what changed:

```bash
# Clone both repos and diff them
git clone https://github.com/monero-project/monero.git
git clone https://github.com/bobtoshi/cocaine.git
diff -r monero/src cocaine/src
```

Key files we modified:
- `src/cryptonote_config.h` - Network parameters, ports, name
- `src/p2p/net_node.inl` - Seed node configuration
- `src/checkpoints/checkpoints.cpp` - Removed Monero checkpoints

### What We Didn't Touch

- Cryptographic primitives (RingCT, signatures, hashing)
- Wallet encryption and key derivation
- Privacy features (stealth addresses, ring signatures)
- Consensus rules (beyond genesis block)

---

## Building From Source

### Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install -y build-essential cmake git libboost-all-dev \
  libssl-dev libzmq3-dev libunbound-dev libsodium-dev \
  libhidapi-dev libusb-1.0-0-dev libprotobuf-dev protobuf-compiler \
  pkg-config
```

**Fedora:**
```bash
sudo dnf install -y gcc gcc-c++ cmake git boost-devel openssl-devel \
  zeromq-devel unbound-devel libsodium-devel hidapi-devel \
  libusb1-devel protobuf-devel protobuf-compiler pkg-config
```

**Arch Linux:**
```bash
sudo pacman -S base-devel cmake git boost openssl zeromq \
  unbound libsodium hidapi libusb protobuf
```

**macOS:**
```bash
brew install cmake boost openssl zeromq unbound libsodium \
  hidapi libusb protobuf pkg-config
```

**Windows (MSYS2):**
```bash
pacman -S mingw-w64-x86_64-toolchain mingw-w64-x86_64-cmake \
  mingw-w64-x86_64-boost mingw-w64-x86_64-openssl \
  mingw-w64-x86_64-zeromq mingw-w64-x86_64-libsodium \
  mingw-w64-x86_64-hidapi mingw-w64-x86_64-protobuf git
```

### Build Steps

```bash
# Clone the repository
git clone https://github.com/bobtoshi/cocaine.git
cd cocaine

# Initialize submodules (required - includes cryptographic libraries)
git submodule update --init --force --recursive

# Create build directory
mkdir build && cd build

# Configure (Release build recommended)
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build (adjust -j flag to your CPU cores)
make -j$(nproc)

# Binaries will be in build/bin/
ls -la bin/
```

### Build Output

After building, you'll have:
- `cocained` - The daemon (blockchain node)
- `cocaine-wallet-cli` - Command-line wallet
- `cocaine-wallet-rpc` - Wallet RPC server (for web dashboard)

### Verifying Your Build

Compare SHA256 hashes of your build against release binaries (if available):

```bash
sha256sum bin/cocained
sha256sum bin/cocaine-wallet-cli
```

---

## Pre-Built Binaries

If you choose to use pre-built binaries (less secure, but convenient for testing):

| Platform | Download |
|----------|----------|
| **Windows** | [cocaine-windows-x64.zip](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-windows-x64.zip) |
| **Linux** | [cocaine-linux-x64.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-linux-x64.tar.gz) |
| **macOS** | [cocaine-macos.tar.gz](https://github.com/Bobtoshi/cocaine/releases/latest/download/cocaine-macos.tar.gz) |

[View all releases](https://github.com/Bobtoshi/cocaine/releases)

---

## Quick Start

### Requirements
- **Node.js** - Download from https://nodejs.org (required for web dashboard only)

### Running the Pre-Built Package

**Windows:**
1. Download and extract `cocaine-windows-x64.zip`
2. Double-click `start.bat`
3. Open http://localhost:8080

**Linux/macOS:**
```bash
tar -xzvf cocaine-linux-x64.tar.gz  # or cocaine-macos.tar.gz
cd cocaine-linux-x64
./start.sh  # or ./start.command on macOS
```
Then open http://localhost:8080

### Running From Source Build

After building:

```bash
# Terminal 1: Start the daemon
./build/bin/cocained --data-dir ~/.cocaine \
  --p2p-bind-port 19080 \
  --rpc-bind-ip 127.0.0.1 \
  --rpc-bind-port 19081

# Terminal 2: Start the wallet CLI
./build/bin/cocaine-wallet-cli --daemon-address 127.0.0.1:19081
```

---

## Network Specifications

| Property | Value |
|----------|-------|
| **Ticker** | COCA |
| **Block Time** | ~2 minutes |
| **Algorithm** | CryptoNight (CPU-mineable) |
| **Emission** | Standard Monero curve |
| **Unlock Time** | 60 blocks (~2 hours) |
| **P2P Port** | 19080 |
| **RPC Port** | 19081 |
| **Seed Node** | 138.68.128.104:19080 |

---

## Web Dashboard

The dashboard provides a browser-based interface:

- **Dashboard Tab** - Network map, hashrate charts, sync status
- **Wallet Tab** - Create/restore wallets, send/receive COCA
- **Mining Tab** - CPU mining controls
- **Network Tab** - Peer connections, daemon info
- **Explorer Tab** - Browse blocks

---

## Roadmap

This is a hobby project with no strict timeline:

### Completed
- [x] Fork Monero codebase
- [x] Rebrand and reconfigure network
- [x] Launch genesis block
- [x] Web dashboard for easier interaction
- [x] Cross-platform builds (Windows, Linux, macOS)

### Planned (No Promises)
- [ ] Better documentation for wallet usage
- [ ] Mobile-friendly dashboard
- [ ] Block explorer website
- [ ] Testnet for development

### Not Planned
- Exchange listings
- Marketing campaigns
- Token sales or ICO

---

## Troubleshooting

**Daemon won't sync?**
- Check firewall allows port 19080
- Verify seed node is reachable: `nc -zv 138.68.128.104 19080`
- Check logs: daemon prints sync progress

**Mining not working?**
- Must be fully synced first
- Check `mining_status` in dashboard or via RPC

**Wallet issues?**
- Rescan blockchain: wallet command `rescan_bc`
- Check daemon is running and synced

---

## Contributing

This is an open-source project. Feel free to:
- Report bugs via GitHub issues
- Submit pull requests
- Fork and experiment

---

## License

Based on the [Monero Project](https://github.com/monero-project/monero), licensed under BSD-3-Clause. See [LICENSE](LICENSE) for full terms.

## Disclaimer

This is experimental software provided "as is" without warranty. Use at your own risk. This is not financial advice. COCA has no inherent value and should be treated as a learning tool or meme coin, not an investment.
