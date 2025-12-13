# Remote Mining Guide

## Overview

This guide explains how to mine COCAINE when you want to use a remote node (like the VPS seed node) for blockchain sync, but mine on your local machine.

**Key Principle:** Mining always happens where the hashing occurs. The `start_mining` RPC command mines on the machine where the daemon runs.

## Why Not Use Remote `start_mining`?

- ❌ **DO NOT** call `start_mining` on a remote VPS daemon - this mines on the VPS, not your machine
- ✅ **DO** run your own local daemon and mine locally
- ✅ **DO** connect your local daemon to the seed node for blockchain sync

## Option 1: Local Daemon + Seed Node Sync (Recommended)

This is the standard approach - run a local daemon that syncs from the seed node:

```bash
# On Mac/Linux
./mine.sh

# Or manually:
./build/bin/cocained \
    --data-dir ./blockchain \
    --rpc-bind-ip 127.0.0.1 \
    --rpc-bind-port 19081 \
    --p2p-bind-ip 127.0.0.1 \
    --p2p-bind-port 19080 \
    --add-peer 138.68.128.104:19080 \
    --detach

# Then mine locally:
curl -X POST http://127.0.0.1:19081/start_mining \
    -d '{"miner_address":"YOUR_ADDRESS","threads_count":2}' \
    -H "Content-Type: application/json"
```

## Option 2: External Miner (XMRig) with Remote Node

If you want to use an external miner like XMRig while syncing from a remote node:

### Prerequisites
- XMRig installed
- Access to a remote daemon's RPC (if VPS RPC is public) OR use daemon mode

### Setup

1. **Start your local daemon** (connects to seed node for sync):
```bash
./build/bin/cocained \
    --data-dir ./blockchain \
    --rpc-bind-ip 127.0.0.1 \
    --rpc-bind-port 19081 \
    --p2p-bind-ip 127.0.0.1 \
    --p2p-bind-port 19080 \
    --add-peer 138.68.128.104:19080 \
    --detach
```

2. **Configure XMRig** to use your local daemon:
```json
{
    "pools": [{
        "url": "127.0.0.1:19081",
        "user": "YOUR_WALLET_ADDRESS",
        "pass": "x",
        "keepalive": true,
        "daemon": true
    }]
}
```

3. **Run XMRig:**
```bash
xmrig --config=config.json
```

## Option 3: SSH Tunnel to VPS (Advanced)

If the VPS RPC is bound to `127.0.0.1` only, you can create an SSH tunnel:

```bash
# Create SSH tunnel
ssh -L 19081:127.0.0.1:19081 root@138.68.128.104 -N

# In another terminal, use localhost:19081
# But remember: start_mining will still mine on the VPS!
```

**⚠️ WARNING:** Even with an SSH tunnel, `start_mining` on the VPS daemon mines on the VPS, not your machine.

## Security Notes

- VPS RPC should be bound to `127.0.0.1` to prevent remote mining abuse
- Only P2P port (19080) should be publicly accessible for blockchain sync
- Always mine on your own machine for security and control

## Troubleshooting

**"No peers connected"**
- Check network connectivity to seed node: `nc -zv 138.68.128.104 19080`
- Ensure firewall allows outbound connections on port 19080
- Wait 1-2 minutes for peer connections to establish

**"Busy" error when starting mining**
- Daemon may still be syncing: wait for `synchronized: true`
- Check daemon status: `curl http://127.0.0.1:19081/get_info`

**Mining on wrong machine**
- Always verify you're calling `start_mining` against `127.0.0.1:19081` (local)
- Never call it against a remote IP address

