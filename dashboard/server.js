const express = require('express');
const fetch = require('node-fetch');
const open = require('open');
const path = require('path');
const { spawn, exec } = require('child_process');
const fs = require('fs');

const app = express();
const PORT = 8080;
const DAEMON_RPC = 'http://127.0.0.1:19081/json_rpc';
const DAEMON_HTTP = 'http://127.0.0.1:19081';
const WALLET_RPC = 'http://127.0.0.1:19083/json_rpc';
const WALLET_DIR = path.join(__dirname, '..', 'wallets');
const DAEMON_BIN = path.join(__dirname, '..', 'build', 'bin', 'cocained');
const WALLET_RPC_BIN = path.join(__dirname, '..', 'build', 'bin', 'cocaine-wallet-rpc');
const DATA_DIR = path.join(__dirname, '..', 'data');
const LOG_FILE = '/tmp/cocained_local.log';

let walletRpcProcess = null;
let currentWalletName = null;
let daemonProcess = null;
let xmrigProcess = null;
let xmrigConfig = null;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Ensure directories exist
if (!fs.existsSync(WALLET_DIR)) fs.mkdirSync(WALLET_DIR, { recursive: true });
if (!fs.existsSync(DATA_DIR)) fs.mkdirSync(DATA_DIR, { recursive: true });

// Helper: Call wallet RPC
async function walletRpc(method, params = {}) {
    const response = await fetch(WALLET_RPC, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: '0', method, params })
    });
    return response.json();
}

// Helper: Call daemon RPC
async function daemonRpc(method, params = {}) {
    const response = await fetch(DAEMON_RPC, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jsonrpc: '2.0', id: '0', method, params })
    });
    return response.json();
}

// Helper: Check if daemon is running
async function isDaemonRunning() {
    try {
        const res = await fetch(DAEMON_HTTP + '/get_info', { timeout: 2000 });
        return res.ok;
    } catch (e) {
        return false;
    }
}

// Helper: Get daemon PID
function getDaemonPid() {
    return new Promise((resolve) => {
        exec('pgrep -f cocained', (err, stdout) => {
            if (err || !stdout.trim()) resolve(null);
            else resolve(stdout.trim().split('\n')[0]);
        });
    });
}

// Start wallet RPC server
function startWalletRpc() {
    return new Promise((resolve, reject) => {
        if (walletRpcProcess) {
            resolve();
            return;
        }

        // Check if wallet-rpc binary exists
        if (!fs.existsSync(WALLET_RPC_BIN)) {
            console.log('[!] Wallet RPC binary not found:', WALLET_RPC_BIN);
            console.log('[!] Wallet functions will not be available');
            resolve();
            return;
        }

        console.log('[*] Starting wallet RPC server...');

        walletRpcProcess = spawn(WALLET_RPC_BIN, [
            '--daemon-address', '127.0.0.1:19081',
            '--rpc-bind-port', '19083',
            '--disable-rpc-login',
            '--wallet-dir', WALLET_DIR,
            '--log-level', '1'
        ]);

        walletRpcProcess.on('error', (err) => {
            console.error('[!] Failed to start wallet RPC:', err.message);
            walletRpcProcess = null;
            resolve();
        });

        walletRpcProcess.stdout.on('data', (data) => {
            const msg = data.toString();
            if (msg.includes('Starting wallet RPC server')) {
                console.log('[+] Wallet RPC server started on port 19083');
                setTimeout(resolve, 1000);
            }
        });

        walletRpcProcess.stderr.on('data', (data) => {
            console.error('[wallet-rpc]', data.toString());
        });

        walletRpcProcess.on('close', (code) => {
            console.log('[!] Wallet RPC server exited with code', code);
            walletRpcProcess = null;
        });

        setTimeout(resolve, 3000);
    });
}

// ==================== DAEMON ENDPOINTS ====================

// Get daemon info (direct RPC)
app.get('/api/info', async (req, res) => {
    try {
        const response = await fetch(DAEMON_HTTP + '/get_info');
        const data = await response.json();
        res.json({ result: data });
    } catch (error) {
        res.status(500).json({ error: error.message, daemon_running: false });
    }
});

// Start daemon
app.post('/api/daemon/start', async (req, res) => {
    try {
        const running = await isDaemonRunning();
        if (running) {
            return res.json({ status: 'busy', message: 'Daemon already running' });
        }

        console.log('[*] Starting daemon...');

        daemonProcess = spawn(DAEMON_BIN, [
            '--data-dir', DATA_DIR,
            '--p2p-bind-ip', '0.0.0.0',
            '--p2p-bind-port', '19080',
            '--rpc-bind-ip', '127.0.0.1',
            '--rpc-bind-port', '19081',
            '--non-interactive',
            '--log-level', '1'
        ], {
            detached: true,
            stdio: ['ignore', fs.openSync(LOG_FILE, 'a'), fs.openSync(LOG_FILE, 'a')]
        });

        daemonProcess.unref();

        // Wait for daemon to start
        await new Promise(r => setTimeout(r, 3000));

        const nowRunning = await isDaemonRunning();
        if (nowRunning) {
            res.json({ status: 'OK', message: 'Daemon started' });
        } else {
            res.json({ status: 'error', message: 'Daemon failed to start - check logs' });
        }
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Stop daemon
app.post('/api/daemon/stop', async (req, res) => {
    try {
        const pid = await getDaemonPid();
        if (pid) {
            exec(`kill ${pid}`, (err) => {
                if (err) {
                    res.json({ status: 'error', message: 'Failed to stop daemon' });
                } else {
                    res.json({ status: 'OK', message: 'Daemon stopped' });
                }
            });
        } else {
            res.json({ status: 'OK', message: 'Daemon not running' });
        }
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Get daemon status
app.get('/api/daemon/status', async (req, res) => {
    try {
        const running = await isDaemonRunning();
        const pid = await getDaemonPid();
        res.json({ running, pid });
    } catch (error) {
        res.json({ running: false, error: error.message });
    }
});

// Get daemon logs
app.get('/api/daemon/logs', async (req, res) => {
    try {
        const lines = parseInt(req.query.lines) || 50;
        if (fs.existsSync(LOG_FILE)) {
            exec(`tail -${lines} "${LOG_FILE}"`, (err, stdout) => {
                if (err) {
                    res.json({ logs: [] });
                } else {
                    res.json({ logs: stdout.split('\n').filter(l => l.trim()) });
                }
            });
        } else {
            res.json({ logs: ['No log file found'] });
        }
    } catch (error) {
        res.json({ logs: [], error: error.message });
    }
});

// Get last block header
app.get('/api/last_block', async (req, res) => {
    try {
        const data = await daemonRpc('get_last_block_header');
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get block by height
app.get('/api/block/:height', async (req, res) => {
    try {
        const data = await daemonRpc('get_block_header_by_height', {
            height: parseInt(req.params.height)
        });
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get connected peers
app.get('/api/peers', async (req, res) => {
    try {
        const response = await fetch(DAEMON_RPC, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ jsonrpc: '2.0', id: '0', method: 'get_connections' })
        });
        const data = await response.json();
        const connections = data.result?.connections || [];
        res.json({
            connections: connections.map(c => ({
                address: c.address,
                height: c.height,
                incoming: c.incoming,
                state: c.state,
                live_time: c.live_time,
                recv_count: c.recv_count,
                send_count: c.send_count
            }))
        });
    } catch (error) {
        res.json({ connections: [], error: error.message });
    }
});

// Get recent blocks
app.get('/api/blocks/recent', async (req, res) => {
    try {
        // Get current height
        const infoRes = await fetch(DAEMON_HTTP + '/get_info');
        const info = await infoRes.json();
        const currentHeight = info.height;

        // Fetch last 20 blocks
        const blocks = [];
        const count = Math.min(20, currentHeight);

        for (let i = 0; i < count; i++) {
            const height = currentHeight - 1 - i;
            if (height < 0) break;

            const data = await daemonRpc('get_block_header_by_height', { height });
            if (data.result && data.result.block_header) {
                const b = data.result.block_header;
                blocks.push({
                    height: b.height,
                    hash: b.hash,
                    timestamp: b.timestamp,
                    reward: b.reward,
                    difficulty: b.difficulty,
                    size: b.block_size,
                    txs: b.num_txes
                });
            }
        }

        res.json({ blocks });
    } catch (error) {
        res.status(500).json({ error: error.message, blocks: [] });
    }
});

// ==================== XMRIG HELPER FUNCTIONS ====================

// Get XMRig binary path for current platform
function getXmrigPath() {
    const toolsDir = path.join(__dirname, '..', 'tools', 'xmrig');
    const platform = process.platform;

    if (platform === 'darwin') {
        return path.join(toolsDir, 'macos', 'xmrig');
    } else if (platform === 'win32') {
        return path.join(toolsDir, 'windows', 'xmrig.exe');
    } else {
        return path.join(toolsDir, 'linux', 'xmrig');
    }
}

// Check if XMRig is available
function isXmrigAvailable() {
    const xmrigPath = getXmrigPath();
    return fs.existsSync(xmrigPath);
}

// XMRig log file
const XMRIG_LOG = '/tmp/xmrig_cocaine.log';
let xmrigHashrate = 0;
let xmrigAccepted = 0;

// Parse XMRig log for hashrate
function parseXmrigLog() {
    try {
        if (!fs.existsSync(XMRIG_LOG)) return;
        const content = fs.readFileSync(XMRIG_LOG, 'utf8');
        const lines = content.split('\n').slice(-50);

        for (const line of lines.reverse()) {
            // Match: "speed 10s/60s/15m 1234.5 H/s"
            const match = line.match(/speed\s+\S+\s+(\d+\.?\d*)\s+(\w+\/s)/i);
            if (match) {
                let rate = parseFloat(match[1]);
                const unit = match[2].toLowerCase();
                if (unit.includes('kh')) rate *= 1000;
                else if (unit.includes('mh')) rate *= 1000000;
                xmrigHashrate = rate;
                break;
            }
        }

        // Count accepted shares
        xmrigAccepted = (content.match(/accepted/gi) || []).length;
    } catch (e) {
        // Ignore errors
    }
}

// ==================== MINING ENDPOINTS ====================

// Get miner status
app.get('/api/miner/status', async (req, res) => {
    // Check XMRig first
    if (xmrigProcess && !xmrigProcess.killed) {
        parseXmrigLog();
        try {
            const infoRes = await fetch(DAEMON_HTTP + '/get_info');
            const info = await infoRes.json();
            return res.json({
                running: true,
                miner: 'xmrig',
                hashrate: xmrigHashrate,
                threads: xmrigConfig?.threads || 0,
                address: xmrigConfig?.address || '',
                difficulty: info.difficulty || 1,
                accepted: xmrigAccepted
            });
        } catch (e) {
            return res.json({
                running: true,
                miner: 'xmrig',
                hashrate: xmrigHashrate,
                threads: xmrigConfig?.threads || 0,
                address: xmrigConfig?.address || '',
                difficulty: 1,
                accepted: xmrigAccepted
            });
        }
    }

    // Fallback to built-in miner status
    try {
        const response = await fetch(DAEMON_HTTP + '/mining_status');
        const data = await response.json();
        res.json({
            running: data.active,
            miner: 'builtin',
            hashrate: data.speed,
            threads: data.threads_count,
            address: data.address,
            difficulty: data.difficulty
        });
    } catch (error) {
        res.json({ running: false, error: error.message });
    }
});

// Start mining - prefer XMRig, fallback to built-in
app.post('/api/mining/start', async (req, res) => {
    const { address, threads, useBuiltin } = req.body;

    if (!address) {
        return res.status(400).json({ status: 'error', error: 'Mining address required' });
    }

    // Stop any existing mining first
    if (xmrigProcess && !xmrigProcess.killed) {
        xmrigProcess.kill();
        xmrigProcess = null;
    }
    try {
        await fetch(DAEMON_HTTP + '/stop_mining');
    } catch (e) {}

    // Try XMRig first (unless explicitly requesting built-in)
    if (!useBuiltin && isXmrigAvailable()) {
        try {
            const xmrigPath = getXmrigPath();
            const threadCount = threads || Math.max(1, require('os').cpus().length - 1);

            // Create XMRig config for solo mining with RandomX
            const config = {
                "autosave": false,
                "cpu": {
                    "enabled": true,
                    "huge-pages": true,
                    "hw-aes": null,
                    "priority": null,
                    "asm": true,
                    "argon2-impl": null,
                    "max-threads-hint": 100
                },
                "opencl": false,
                "cuda": false,
                "log-file": XMRIG_LOG,
                "pools": [{
                    "algo": "rx/0",
                    "url": "127.0.0.1:19081",
                    "user": address,
                    "pass": "x",
                    "daemon": true,
                    "daemon-poll-interval": 1000
                }],
                "print-time": 10,
                "retries": 5,
                "retry-pause": 5
            };

            const configPath = '/tmp/xmrig_cocaine_config.json';
            fs.writeFileSync(configPath, JSON.stringify(config, null, 2));

            // Clear old log
            if (fs.existsSync(XMRIG_LOG)) fs.unlinkSync(XMRIG_LOG);

            // Start XMRig
            xmrigProcess = spawn(xmrigPath, [
                '--config', configPath,
                '--threads', threadCount.toString(),
                '--no-color'
            ], {
                stdio: ['ignore', 'pipe', 'pipe'],
                detached: false
            });

            // Pipe output to log file
            const logStream = fs.createWriteStream(XMRIG_LOG, { flags: 'a' });
            xmrigProcess.stdout.pipe(logStream);
            xmrigProcess.stderr.pipe(logStream);

            xmrigConfig = { address, threads: threadCount };
            xmrigHashrate = 0;
            xmrigAccepted = 0;

            xmrigProcess.on('exit', (code) => {
                console.log(`[*] XMRig exited with code ${code}`);
                xmrigProcess = null;
                xmrigConfig = null;
            });

            // Wait a moment for XMRig to start
            await new Promise(r => setTimeout(r, 2000));

            return res.json({
                status: 'OK',
                miner: 'xmrig',
                message: 'XMRig started',
                threads: threadCount
            });
        } catch (error) {
            console.error('[!] XMRig start error:', error);
            // Fall through to built-in miner
        }
    }

    // Fallback to built-in miner
    try {
        const response = await fetch(`${DAEMON_HTTP}/start_mining?miner_address=${address}&threads_count=${threads || 2}`);
        const data = await response.json();
        res.json({ ...data, miner: 'builtin' });
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Stop mining
app.post('/api/mining/stop', async (req, res) => {
    // Stop XMRig
    if (xmrigProcess && !xmrigProcess.killed) {
        xmrigProcess.kill();
        xmrigProcess = null;
        xmrigConfig = null;
        xmrigHashrate = 0;
    }

    // Also stop built-in miner
    try {
        const response = await fetch(DAEMON_HTTP + '/stop_mining');
        const data = await response.json();
        res.json({ status: 'OK', ...data });
    } catch (error) {
        res.json({ status: 'OK' });
    }
});

// Mining status (combined endpoint)
app.get('/api/mining/status', async (req, res) => {
    // Check XMRig first
    if (xmrigProcess && !xmrigProcess.killed) {
        parseXmrigLog();
        try {
            const infoRes = await fetch(DAEMON_HTTP + '/get_info');
            const info = await infoRes.json();
            return res.json({
                active: true,
                miner: 'xmrig',
                speed: xmrigHashrate,
                threads_count: xmrigConfig?.threads || 0,
                address: xmrigConfig?.address || '',
                difficulty: info.difficulty || 1,
                accepted: xmrigAccepted
            });
        } catch (e) {
            return res.json({
                active: true,
                miner: 'xmrig',
                speed: xmrigHashrate,
                threads_count: xmrigConfig?.threads || 0,
                address: xmrigConfig?.address || '',
                difficulty: 1
            });
        }
    }

    // Fallback to built-in miner status
    try {
        const response = await fetch(DAEMON_HTTP + '/mining_status');
        const data = await response.json();

        // Get current difficulty for calculations
        const infoRes = await fetch(DAEMON_HTTP + '/get_info');
        const info = await infoRes.json();

        res.json({
            active: data.active || false,
            miner: 'builtin',
            speed: data.speed || 0,
            threads_count: data.threads_count || 0,
            address: data.address || '',
            difficulty: info.difficulty || 1
        });
    } catch (error) {
        res.json({ active: false, speed: 0, threads_count: 0, difficulty: 1 });
    }
});

// Check if XMRig is available
app.get('/api/mining/xmrig-available', (req, res) => {
    res.json({ available: isXmrigAvailable(), path: getXmrigPath() });
});

// ==================== WALLET ENDPOINTS ====================

// List available wallets
app.get('/api/wallet/list', async (req, res) => {
    try {
        const files = fs.readdirSync(WALLET_DIR);
        const wallets = files
            .filter(f => f.endsWith('.keys'))
            .map(f => f.replace('.keys', ''));
        res.json({ wallets, current: currentWalletName });
    } catch (error) {
        res.json({ wallets: [], current: null });
    }
});

// Create new wallet
app.post('/api/wallet/create', async (req, res) => {
    const { name, password } = req.body;

    if (!name || name.length < 1) {
        return res.status(400).json({ error: 'Wallet name required' });
    }

    try {
        await startWalletRpc();

        const data = await walletRpc('create_wallet', {
            filename: name,
            password: password || '',
            language: 'English'
        });

        if (data.error) {
            return res.json({ success: false, error: data.error.message });
        }

        currentWalletName = name;

        const seedData = await walletRpc('query_key', { key_type: 'mnemonic' });
        const addressData = await walletRpc('get_address');

        res.json({
            success: true,
            name: name,
            address: addressData.result?.address,
            seed: seedData.result?.key
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Open existing wallet
app.post('/api/wallet/open', async (req, res) => {
    const { name, filename, password } = req.body;
    const walletName = name || filename;

    if (!walletName) {
        return res.status(400).json({ error: 'Wallet name required' });
    }

    try {
        await startWalletRpc();

        const data = await walletRpc('open_wallet', {
            filename: walletName,
            password: password || ''
        });

        if (data.error) {
            return res.json({ success: false, error: data.error.message });
        }

        currentWalletName = walletName;
        const addressData = await walletRpc('get_address');

        res.json({
            success: true,
            name: walletName,
            address: addressData.result?.address
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Restore wallet from seed
app.post('/api/wallet/restore', async (req, res) => {
    const { name, password, seed } = req.body;

    if (!name || !seed) {
        return res.status(400).json({ error: 'Name and seed required' });
    }

    try {
        await startWalletRpc();

        const data = await walletRpc('restore_deterministic_wallet', {
            filename: name,
            password: password || '',
            seed: seed,
            restore_height: 0,
            language: 'English'
        });

        if (data.error) {
            return res.json({ success: false, error: data.error.message });
        }

        currentWalletName = name;

        res.json({
            success: true,
            name: name,
            address: data.result?.address,
            info: data.result?.info
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get wallet balance
app.get('/api/wallet/balance', async (req, res) => {
    try {
        const data = await walletRpc('get_balance');

        if (data.error) {
            return res.json({ error: data.error.message });
        }

        res.json({
            balance: data.result?.balance || 0,
            unlocked_balance: data.result?.unlocked_balance || 0,
            balance_display: ((data.result?.balance || 0) / 1e12).toFixed(4),
            unlocked_display: ((data.result?.unlocked_balance || 0) / 1e12).toFixed(4)
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get wallet address
app.get('/api/wallet/address', async (req, res) => {
    try {
        const data = await walletRpc('get_address');
        res.json({
            address: data.result?.address,
            addresses: data.result?.addresses
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get transaction history
app.get('/api/wallet/transfers', async (req, res) => {
    try {
        const data = await walletRpc('get_transfers', {
            in: true,
            out: true,
            pending: true,
            pool: true
        });

        if (data.error) {
            return res.json({ error: data.error.message });
        }

        res.json({
            incoming: data.result?.in || [],
            outgoing: data.result?.out || [],
            pending: data.result?.pending || [],
            pool: data.result?.pool || []
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Send transaction
app.post('/api/wallet/send', async (req, res) => {
    const { address, amount, payment_id } = req.body;

    if (!address || !amount) {
        return res.status(400).json({ error: 'Address and amount required' });
    }

    try {
        const atomicAmount = Math.floor(parseFloat(amount) * 1e12);

        const params = {
            destinations: [{ address: address, amount: atomicAmount }],
            priority: 1,
            ring_size: 11,
            get_tx_key: true
        };

        if (payment_id) {
            params.payment_id = payment_id;
        }

        const data = await walletRpc('transfer', params);

        if (data.error) {
            return res.json({ success: false, error: data.error.message });
        }

        res.json({
            success: true,
            tx_hash: data.result?.tx_hash,
            tx_key: data.result?.tx_key,
            fee: (data.result?.fee || 0) / 1e12
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Refresh wallet
app.post('/api/wallet/refresh', async (req, res) => {
    try {
        const data = await walletRpc('refresh');
        res.json({
            blocks_fetched: data.result?.blocks_fetched,
            received_money: data.result?.received_money
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Close wallet
app.post('/api/wallet/close', async (req, res) => {
    try {
        await walletRpc('close_wallet');
        currentWalletName = null;
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Get wallet status
app.get('/api/wallet/status', async (req, res) => {
    try {
        const height = await walletRpc('get_height');
        res.json({
            open: currentWalletName !== null,
            name: currentWalletName,
            height: height.result?.height
        });
    } catch (error) {
        res.json({ open: false, name: null });
    }
});

// ==================== SERVER START ====================

const server = app.listen(PORT, '127.0.0.1', async () => {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗ ║
║    ██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝ ║
║    ██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗   ║
║    ██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝   ║
║    ╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗ ║
║     ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝ ║
║                                                           ║
║                    DASHBOARD v3.0                         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Dashboard running at http://127.0.0.1:${PORT}
Daemon RPC: port 19081
Wallet RPC: port 19083

Press Ctrl+C to stop
`);

    // Start wallet RPC
    try {
        await startWalletRpc();
    } catch (e) {
        console.log('[!] Wallet RPC failed to start:', e.message);
    }

    // Auto-open browser
    setTimeout(() => {
        open(`http://localhost:${PORT}`).catch(() => {});
    }, 500);
});

server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
        console.error(`\n[!] Port ${PORT} is already in use.\n`);
        process.exit(1);
    }
    throw err;
});

// Cleanup on exit
process.on('SIGINT', () => {
    console.log('\n[*] Shutting down...');
    if (walletRpcProcess) {
        walletRpcProcess.kill();
    }
    process.exit(0);
});
