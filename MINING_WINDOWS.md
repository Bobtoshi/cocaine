# Mining on Windows - Setup Guide

## Important: Mine Locally, Sync from VPS

**You must run your own local daemon** - mining happens on YOUR computer, not on the VPS. The VPS is only used for blockchain synchronization via P2P.

## Quick Start

1. **Download the pre-built Windows binaries** (NO COMPILATION NEEDED!)
   - Go to: https://github.com/Bobtoshi/cocaine/releases/latest
   - Download: `cocaine-windows-x64.zip`
   - Extract to a folder (e.g., `C:\cocaine`)

2. **Start your local daemon** with the seed node:
   ```cmd
   cocained.exe --data-dir C:\ProgramData\cocaine --rpc-bind-ip 127.0.0.1 --rpc-bind-port 19081 --p2p-bind-ip 127.0.0.1 --p2p-bind-port 19080 --add-exclusive-node 138.68.128.104:19080 --log-level 1
   ```

3. **Wait for sync** - The daemon will sync the blockchain from the VPS seed node. This may take a while.

4. **Check sync status**:
   ```cmd
   curl http://127.0.0.1:19081/get_info
   ```
   Look for `"synchronized": true` in the response.

5. **Start mining** once synchronized:
   ```cmd
   curl -X POST http://127.0.0.1:19081/start_mining -d "{\"miner_address\": \"YOUR_WALLET_ADDRESS\", \"threads_count\": 2, \"do_background_mining\": false, \"ignore_battery\": true}" -H "Content-Type: application/json"
   ```

## Detailed Steps

### Step 1: Create a Wallet (if you don't have one)

```cmd
cocaine-wallet-cli.exe --generate-new-wallet C:\cocaine\mywallet --password "" --mnemonic-language English --daemon-address 127.0.0.1:19081
```

Save your seed phrase! This is your only backup.

### Step 2: Start Local Daemon

The daemon must run locally on your machine. It will connect to the VPS seed node (138.68.128.104:19080) to sync the blockchain.

**Key points:**
- `--rpc-bind-ip 127.0.0.1` - Only accessible locally (for security)
- `--add-exclusive-node 138.68.128.104:19080` - Connect to VPS seed node
- `--p2p-bind-port 19080` - Your local P2P port

### Step 3: Monitor Sync

Check if blockchain is synchronized:
```cmd
curl http://127.0.0.1:19081/get_info | findstr synchronized
```

You should see `"synchronized": true` when ready.

### Step 4: Start Mining

Once synchronized, start mining to your wallet address:
```cmd
curl -X POST http://127.0.0.1:19081/start_mining -d "{\"miner_address\": \"YOUR_WALLET_ADDRESS_HERE\", \"threads_count\": 2, \"do_background_mining\": false, \"ignore_battery\": true}" -H "Content-Type: application/json"
```

Replace `YOUR_WALLET_ADDRESS_HERE` with your actual wallet address.

### Step 5: Check Mining Status

```cmd
curl http://127.0.0.1:19081/mining_status
```

### Step 6: Stop Mining

```cmd
curl -X POST http://127.0.0.1:19081/stop_mining
```

## Troubleshooting

### "Busy" or "Syncing" Error

- Your daemon is still syncing the blockchain
- Wait for `"synchronized": true` before mining
- Check sync progress: `curl http://127.0.0.1:19081/get_info`

### Cannot Connect to Seed Node

- Check your firewall allows outbound connections on port 19080
- Verify the VPS is running: `ping 138.68.128.104`
- The VPS RPC port (19081) is closed - this is intentional! Only P2P (19080) is open.

### Mining Not Working

- Make sure your local daemon is running
- Verify you're mining to a valid wallet address
- Check daemon logs for errors

## Notes

- **Mining happens on YOUR computer** - your CPU/GPU does the work
- **VPS is only for sync** - it provides the blockchain data via P2P
- **RPC is local only** - port 19081 is only accessible on your machine (127.0.0.1)
- **P2P connects to VPS** - port 19080 connects to the seed node for blockchain sync

## Example Full Command Sequence

```cmd
REM 1. Start daemon (in one terminal)
cocained.exe --data-dir C:\ProgramData\cocaine --rpc-bind-ip 127.0.0.1 --rpc-bind-port 19081 --p2p-bind-ip 127.0.0.1 --p2p-bind-port 19080 --add-exclusive-node 138.68.128.104:19080 --log-level 1

REM 2. Wait for sync (check in another terminal)
curl http://127.0.0.1:19081/get_info

REM 3. Start mining (replace with your wallet address)
curl -X POST http://127.0.0.1:19081/start_mining -d "{\"miner_address\": \"5hXeLXSXeW4TYGAWPhCZmAGGeTZRjaLrxfLTS1MyTLCYGeLNfjysvrCBghXyefR121UoTkKTNpFFVX4gW2pqAPnZSWw5Nyw\", \"threads_count\": 2, \"do_background_mining\": false, \"ignore_battery\": true}" -H "Content-Type: application/json"

REM 4. Check status
curl http://127.0.0.1:19081/mining_status
```

