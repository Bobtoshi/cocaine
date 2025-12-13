# Instructions for Your Friend (Windows)

**Tell your friend:**

---

## Quick Start - No Compilation Needed! ✅

You don't need to compile anything! Just download the pre-built Windows binaries:

### Step 1: Download
1. Go to: https://github.com/Bobtoshi/cocaine/releases/latest
2. Download: `cocaine-windows-x64.zip`
3. Extract it to a folder (e.g., `C:\cocaine`)

### Step 2: Start Local Daemon (Syncs from VPS)
Open Command Prompt or PowerShell in the extracted folder and run:

```cmd
cocained.exe --data-dir C:\ProgramData\cocaine --rpc-bind-ip 127.0.0.1 --rpc-bind-port 19081 --p2p-bind-ip 127.0.0.1 --p2p-bind-port 19080 --add-exclusive-node 138.68.128.104:19080 --log-level 1
```

**Important:** This starts YOUR local daemon that will sync the blockchain from the VPS seed node. Leave this running.

### Step 3: Wait for Sync
Wait a few minutes for the blockchain to sync. You'll see messages like "Synchronizing with the network..."

### Step 4: Create Wallet (in a NEW terminal)
Open a new Command Prompt window and run:

```cmd
cd C:\cocaine
cocaine-wallet-cli.exe --generate-new-wallet mywallet --password "" --mnemonic-language English --daemon-address 127.0.0.1:19081
```

**SAVE YOUR SEED PHRASE!** This is your only backup.

### Step 5: Start Mining
Once the daemon is synced, start mining:

```cmd
curl -X POST http://127.0.0.1:19081/start_mining -d "{\"miner_address\": \"YOUR_WALLET_ADDRESS_HERE\", \"threads_count\": 2, \"do_background_mining\": false, \"ignore_battery\": true}" -H "Content-Type: application/json"
```

Replace `YOUR_WALLET_ADDRESS_HERE` with your actual wallet address (you'll see it when you create the wallet).

### Step 6: Check Mining Status
```cmd
curl http://127.0.0.1:19081/mining_status
```

---

## Full Guide
For detailed instructions, see: https://github.com/Bobtoshi/cocaine/blob/main/MINING_WINDOWS.md

---

## Key Points:
- ✅ **No compilation needed** - just download the zip file
- ✅ **Mining happens on YOUR computer** - your CPU does the work
- ✅ **VPS is only for blockchain sync** - connects via P2P (port 19080)
- ✅ **RPC is local only** - all mining commands go to your local daemon (127.0.0.1:19081)

---

## Troubleshooting

**"Busy" or "Syncing" error?**
- Your daemon is still syncing. Wait for it to finish (check the daemon window for sync progress).

**Can't connect?**
- Make sure the daemon is running (Step 2)
- Check Windows Firewall allows the daemon
- The VPS RPC port is closed (intentional) - you only use P2P for sync

**Need help?**
- Check the full guide: `MINING_WINDOWS.md`
- Or ask me!

