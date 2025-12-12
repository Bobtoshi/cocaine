const express = require('express');
const path = require('path');
const { spawn } = require('child_process');
const fs = require('fs');
const http = require('http');

const app = express();
const PORT = process.env.PORT || 8080;
const DAEMON_RPC = 'http://127.0.0.1:19081/json_rpc';
const DAEMON_HTTP = 'http://127.0.0.1:19081';
const WALLET_RPC = 'http://127.0.0.1:19083/json_rpc';

// Handle paths for both development and packaged app
function getBasePath() {
    if (process.resourcesPath) {
        return process.resourcesPath;
    }
    return __dirname;
}

const WALLET_DIR = process.env.WALLET_DIR || path.join(getBasePath(), 'wallets');
const WALLET_RPC_BIN = process.env.WALLET_RPC_BIN || path.join(getBasePath(), 'bin', process.platform === 'win32' ? 'cocaine-wallet-rpc.exe' : 'cocaine-wallet-rpc');

// Simple fetch replacement
async function fetch(url, options = {}) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const headers = { ...options.headers };
        if (options.body) {
            headers['Content-Length'] = Buffer.byteLength(options.body);
        }
        const req = http.request({
            hostname: urlObj.hostname,
            port: urlObj.port,
            path: urlObj.pathname,
            method: options.method || 'GET',
            headers: headers
        }, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve({
                    ok: res.statusCode >= 200 && res.statusCode < 300,
                    statusCode: res.statusCode,
                    json: () => Promise.resolve(JSON.parse(data))
                });
            });
        });
        req.on('error', reject);
        if (options.body) req.write(options.body);
        req.end();
    });
}

let walletRpcProcess = null;
let currentWalletName = null;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Ensure wallet directory exists
if (!fs.existsSync(WALLET_DIR)) {
    fs.mkdirSync(WALLET_DIR, { recursive: true });
}

// Helper: Call wallet RPC
async function walletRpc(method, params = {}) {
    const response = await fetch(WALLET_RPC, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            jsonrpc: '2.0',
            id: '0',
            method: method,
            params: params
        })
    });
    return response.json();
}

// Helper: Call daemon RPC
async function daemonRpc(method, params = {}) {
    const response = await fetch(DAEMON_RPC, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            jsonrpc: '2.0',
            id: '0',
            method: method,
            params: params
        })
    });
    return response.json();
}

// Start wallet RPC server
function startWalletRpc() {
    return new Promise((resolve, reject) => {
        if (walletRpcProcess) {
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

        // Timeout fallback
        setTimeout(resolve, 3000);
    });
}

// ==================== DAEMON ENDPOINTS ====================

// Get daemon info
app.get('/api/info', async (req, res) => {
    try {
        const data = await daemonRpc('get_info');
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message, daemon_running: false });
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

// Mining status
app.get('/api/mining_status', async (req, res) => {
    try {
        const response = await fetch(`${DAEMON_HTTP}/mining_status`);
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Start mining
app.post('/api/mining/start', async (req, res) => {
    const { address, threads } = req.body;
    try {
        const response = await fetch(`${DAEMON_HTTP}/start_mining`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                miner_address: address,
                threads_count: threads || 2,
                do_background_mining: false,
                ignore_battery: true
            })
        });
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Stop mining
app.post('/api/mining/stop', async (req, res) => {
    try {
        const response = await fetch(`${DAEMON_HTTP}/stop_mining`, { method: 'POST' });
        const data = await response.json();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
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

        // Get the seed phrase
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
    const { name, password } = req.body;

    try {
        await startWalletRpc();

        const data = await walletRpc('open_wallet', {
            filename: name,
            password: password || ''
        });

        if (data.error) {
            return res.json({ success: false, error: data.error.message });
        }

        currentWalletName = name;
        const addressData = await walletRpc('get_address');

        res.json({
            success: true,
            name: name,
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
            // Convert from atomic units (12 decimals)
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
        // Convert amount to atomic units
        const atomicAmount = Math.floor(parseFloat(amount) * 1e12);

        const params = {
            destinations: [{ address: address, amount: atomicAmount }],
            priority: 1,
            ring_size: 16,
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

// Refresh wallet (sync with blockchain)
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

const server = app.listen(PORT, async () => {
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
║                    DASHBOARD v2.0                         ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

Dashboard running at http://localhost:${PORT}
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

});
// Note: Browser auto-open disabled for Electron app

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
