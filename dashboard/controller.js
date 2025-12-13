const express = require('express');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const app = express();
const CONTROLLER_PORT = 8787;
const DAEMON_RPC = 'http://127.0.0.1:19081';
const SEED_NODE = '138.68.128.104:19080';

app.use(express.json());
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

// Process tracking
let daemonProcess = null;
let minerProcess = null;
let daemonPid = null;
let minerPid = null;
let minerConfig = null;

const SCRIPT_DIR = path.join(__dirname, '..');
const DAEMON_BIN = path.join(SCRIPT_DIR, 'build', 'bin', 'cocained');
const DATA_DIR = path.join(SCRIPT_DIR, 'blockchain');
const LOG_DIR = path.join(SCRIPT_DIR, 'logs');
const DAEMON_LOG = path.join(LOG_DIR, 'daemon.log');
const MINER_LOG = path.join(LOG_DIR, 'miner.log');

// Ensure directories exist
[LOG_DIR, DATA_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
});

// Helper: Check if process is running
function isProcessRunning(pid) {
    try {
        process.kill(pid, 0);
        return true;
    } catch (e) {
        return false;
    }
}

// Helper: Read last N lines from log file
function readLogTail(filePath, lines = 50) {
    try {
        if (!fs.existsSync(filePath)) return [];
        const content = fs.readFileSync(filePath, 'utf8');
        const logLines = content.split('\n').filter(l => l.trim());
        return logLines.slice(-lines);
    } catch (e) {
        return [`Error reading log: ${e.message}`];
    }
}

// ==================== DAEMON ENDPOINTS ====================

// Start daemon
app.post('/daemon/start', async (req, res) => {
    // Check if daemon is already running
    try {
        const checkRes = await fetch(`${DAEMON_RPC}/get_info`);
        if (checkRes.ok) {
            return res.json({ status: 'busy', message: 'Daemon already running' });
        }
    } catch (e) {
        // Daemon not running, continue
    }

    // Check if we have a tracked process
    if (daemonPid && isProcessRunning(daemonPid)) {
        return res.json({ status: 'busy', message: 'Daemon already running' });
    }

    try {
        // Kill any stale cocained processes
        const { exec } = require('child_process');
        exec('pkill -f "cocained.*blockchain" || true', () => {});

        const logStream = fs.createWriteStream(DAEMON_LOG, { flags: 'a' });
        
        daemonProcess = spawn(DAEMON_BIN, [
            '--data-dir', DATA_DIR,
            '--log-level', '1',
            '--rpc-bind-ip', '127.0.0.1',
            '--rpc-bind-port', '19081',
            '--p2p-bind-ip', '127.0.0.1',
            '--p2p-bind-port', '19080',
            '--add-exclusive-node', SEED_NODE
        ], {
            cwd: SCRIPT_DIR,
            stdio: ['ignore', logStream, logStream],
            detached: true
        });
        
        daemonPid = daemonProcess.pid;
        daemonProcess.unref(); // Allow parent to exit
        
        daemonProcess.on('exit', (code) => {
            daemonPid = null;
            daemonProcess = null;
        });

        // Wait for daemon to start and verify
        for (let i = 0; i < 10; i++) {
            await new Promise(resolve => setTimeout(resolve, 1000));
            try {
                const checkRes = await fetch(`${DAEMON_RPC}/get_info`);
                if (checkRes.ok) {
                    return res.json({ 
                        status: 'OK', 
                        pid: daemonPid,
                        message: 'Daemon started'
                    });
                }
            } catch (e) {
                // Continue waiting
            }
        }

        res.json({ 
            status: 'OK', 
            pid: daemonPid,
            message: 'Daemon started (verifying...)'
        });
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Stop daemon
app.post('/daemon/stop', async (req, res) => {
    try {
        // Kill tracked process
        if (daemonPid && isProcessRunning(daemonPid)) {
            try {
                process.kill(daemonPid, 'SIGTERM');
            } catch (e) {}
        }
        
        // Also kill any cocained processes
        const { exec } = require('child_process');
        exec('pkill -f "cocained.*blockchain" || true', () => {});
        
        await new Promise(resolve => setTimeout(resolve, 2000));
        
        daemonPid = null;
        daemonProcess = null;
        res.json({ status: 'OK', message: 'Daemon stopped' });
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Get daemon status
app.get('/daemon/status', async (req, res) => {
    try {
        const response = await fetch(`${DAEMON_RPC}/get_info`);
        if (!response.ok) {
            // Check if we have a tracked PID
            if (daemonPid && isProcessRunning(daemonPid)) {
                return res.json({
                    running: true,
                    pid: daemonPid,
                    error: 'Daemon starting...'
                });
            }
            return res.json({
                running: false,
                error: 'Daemon not responding'
            });
        }

        const data = await response.json();
        const peers = (data.outgoing_connections_count || 0) + (data.incoming_connections_count || 0);
        
        // Update tracked PID if we got response but don't have one
        if (!daemonPid) {
            // Try to find the process
            const { exec } = require('child_process');
            exec('pgrep -f "cocained.*blockchain"', (err, stdout) => {
                if (!err && stdout.trim()) {
                    daemonPid = parseInt(stdout.trim());
                }
            });
        }
        
        res.json({
            running: true,
            pid: daemonPid || 'unknown',
            height: data.height,
            synced: data.synchronized,
            peers: peers,
            outgoing: data.outgoing_connections_count || 0,
            incoming: data.incoming_connections_count || 0,
            busy_syncing: data.busy_syncing || false,
            target_height: data.target_height || 0,
            ...data
        });
    } catch (error) {
        res.json({
            running: false,
            error: error.message
        });
    }
});

// Get daemon logs
app.get('/daemon/logs', (req, res) => {
    const lines = parseInt(req.query.lines) || 50;
    const logs = readLogTail(DAEMON_LOG, lines);
    res.json({ logs });
});

// ==================== MINER ENDPOINTS ====================

// Start miner (XMRig)
app.post('/miner/start', async (req, res) => {
    const { address, threads } = req.body;

    if (!address) {
        return res.status(400).json({ status: 'error', error: 'Mining address required' });
    }

    if (minerProcess && isProcessRunning(minerPid)) {
        return res.json({ status: 'busy', message: 'Miner already running' });
    }

    // Check if daemon is running
    try {
        const daemonStatus = await fetch(`${DAEMON_RPC}/get_info`);
        if (!daemonStatus.ok) {
            return res.status(400).json({ 
                status: 'error', 
                error: 'Daemon not running. Start daemon first.' 
            });
        }
    } catch (e) {
        return res.status(400).json({ 
            status: 'error', 
            error: 'Cannot connect to daemon. Start daemon first.' 
        });
    }

    try {
        // Find XMRig binary
        const xmrigPaths = [
            path.join(SCRIPT_DIR, 'xmrig'),
            path.join(SCRIPT_DIR, 'tools', 'xmrig'),
            '/usr/local/bin/xmrig',
            'xmrig' // In PATH
        ];

        let xmrigBin = null;
        for (const xmrigPath of xmrigPaths) {
            if (xmrigPath === 'xmrig' || fs.existsSync(xmrigPath)) {
                xmrigBin = xmrigPath;
                break;
            }
        }

        if (!xmrigBin) {
            return res.status(400).json({
                status: 'error',
                error: 'XMRig not found. Please install XMRig first.',
                install: 'Download from https://github.com/xmrig/xmrig/releases'
            });
        }

        // Create XMRig config
        const xmrigConfig = {
            "autosave": true,
            "cpu": {
                "enabled": true,
                "huge-pages": true,
                "hw-aes": null,
                "priority": null,
                "memory-pool": false,
                "yield": true
            },
            "opencl": false,
            "cuda": false,
            "donate-level": 0,
            "log-file": MINER_LOG,
            "pools": [{
                "algo": "cryptonight",
                "coin": null,
                "url": "127.0.0.1:19081",
                "user": address,
                "pass": "x",
                "rig-id": null,
                "nicehash": false,
                "keepalive": true,
                "enabled": true,
                "tls": false,
                "tls-fingerprint": null,
                "daemon": true,
                "daemon-poll-interval": 1000
            }],
            "retries": 5,
            "retry-pause": 5,
            "print-time": 60,
            "health-print-time": 60,
            "syslog": false,
            "user-agent": null,
            "verbose": 0,
            "colors": false,
            "threads": threads || 2
        };

        const configPath = path.join(LOG_DIR, 'xmrig-config.json');
        fs.writeFileSync(configPath, JSON.stringify(xmrigConfig, null, 2));

        const logStream = fs.createWriteStream(MINER_LOG, { flags: 'a' });

        minerProcess = spawn(xmrigBin, ['--config', configPath], {
            cwd: SCRIPT_DIR,
            stdio: ['ignore', logStream, logStream]
        });

        minerPid = minerProcess.pid;
        minerConfig = { address, threads: threads || 2 };

        minerProcess.on('exit', (code) => {
            minerPid = null;
            minerProcess = null;
            minerConfig = null;
        });

        res.json({
            status: 'OK',
            pid: minerPid,
            address: address,
            threads: threads || 2,
            message: 'Miner started'
        });
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Stop miner
app.post('/miner/stop', async (req, res) => {
    try {
        if (minerPid && isProcessRunning(minerPid)) {
            process.kill(minerPid, 'SIGTERM');
            await new Promise(resolve => setTimeout(resolve, 1000));
        }
        minerPid = null;
        minerProcess = null;
        minerConfig = null;
        res.json({ status: 'OK', message: 'Miner stopped' });
    } catch (error) {
        res.status(500).json({ status: 'error', error: error.message });
    }
});

// Get miner status
app.get('/miner/status', (req, res) => {
    const running = minerPid && isProcessRunning(minerPid);
    
    // Parse XMRig log for hashrate
    const logs = readLogTail(MINER_LOG, 20);
    let hashrate = 0;
    let accepted = 0;
    let rejected = 0;

    for (const line of logs.reverse()) {
        // XMRig log format: "speed 10s/60s/15m 123.4 H/s max 150.0 H/s"
        const speedMatch = line.match(/speed.*?(\d+\.?\d*)\s+H\/s/);
        if (speedMatch) {
            hashrate = parseFloat(speedMatch[1]);
            break;
        }
        // Accepted/rejected shares
        if (line.includes('accepted')) accepted++;
        if (line.includes('rejected')) rejected++;
    }

    res.json({
        running: running,
        pid: minerPid,
        address: minerConfig?.address || null,
        threads: minerConfig?.threads || 0,
        hashrate: hashrate,
        accepted: accepted,
        rejected: rejected
    });
});

// Get miner logs
app.get('/miner/logs', (req, res) => {
    const lines = parseInt(req.query.lines) || 50;
    const logs = readLogTail(MINER_LOG, lines);
    res.json({ logs });
});

// ==================== SERVER START ====================

app.listen(CONTROLLER_PORT, '127.0.0.1', () => {
    console.log(`Controller running on http://127.0.0.1:${CONTROLLER_PORT}`);
});

// Cleanup on exit
process.on('SIGINT', () => {
    console.log('\n[*] Shutting down controller...');
    if (minerPid) process.kill(minerPid, 'SIGTERM');
    if (daemonPid) process.kill(daemonPid, 'SIGTERM');
    process.exit(0);
});

