const { app, BrowserWindow, dialog } = require('electron');
const path = require('path');
const { spawn, execSync } = require('child_process');
const fs = require('fs');
const http = require('http');

let mainWindow;
let daemonProcess;
let serverProcess;
const DAEMON_PORT = 19081;
const SERVER_PORT = 8080;

// Get the correct path for resources
function getResourcePath(filename) {
  // Allow overriding the daemon/wallet rpc binaries for debugging packaged builds
  // via env vars (useful when you rebuilt cocained but the packaged app still ships an older one).
  const envKey = filename.toLowerCase().includes('cocained')
    ? 'COCAINE_DAEMON_PATH'
    : (filename.toLowerCase().includes('wallet-rpc') ? 'COCAINE_WALLET_RPC_PATH' : null);

  if (envKey && process.env[envKey]) {
    return process.env[envKey];
  }

  // If packaged, binaries live under Contents/Resources/bin
  if (app.isPackaged) {
    return path.join(process.resourcesPath, 'bin', filename);
  }

  // Dev: binaries live under project-root/bin
  return path.join(__dirname, 'bin', filename);
}

function getDataPath() {
  return path.join(app.getPath('userData'), 'blockchain');
}

function getWalletPath() {
  return path.join(app.getPath('userData'), 'wallets');
}

// Check if daemon is running
async function isDaemonRunning() {
  return new Promise((resolve) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: DAEMON_PORT,
      path: '/get_height',
      method: 'GET',
      timeout: 2000
    }, (res) => {
      resolve(res.statusCode === 200);
    });
    req.on('error', () => resolve(false));
    req.on('timeout', () => { req.destroy(); resolve(false); });
    req.end();
  });
}

// Start the daemon
async function startDaemon() {
  if (await isDaemonRunning()) {
    console.log('Daemon already running');
    return true;
  }

  const daemonPath = getResourcePath(process.platform === 'win32' ? 'cocained.exe' : 'cocained');
  const dataPath = getDataPath();

  // Create data directory
  if (!fs.existsSync(dataPath)) {
    fs.mkdirSync(dataPath, { recursive: true });
  }

  const logFile = path.join(dataPath, 'cocained.log');
  const pidFile = path.join(dataPath, 'cocained.pid');

  // Verify daemon binary exists and is executable
  try {
    if (!fs.existsSync(daemonPath)) {
      throw new Error(`Daemon binary not found at: ${daemonPath}`);
    }
    if (process.platform !== 'win32') {
      try { fs.chmodSync(daemonPath, 0o755); } catch (_) { /* ignore */ }
    }
  } catch (e) {
    console.error('Daemon preflight failed:', e);
    return false;
  }

  const args = [
    '--non-interactive',
    '--data-dir', dataPath,
    '--log-level', '1',
    '--rpc-bind-ip', '127.0.0.1',
    '--rpc-bind-port', String(DAEMON_PORT)
  ];

  console.log('Starting daemon:', daemonPath);
  console.log('Daemon args:', args.join(' '));
  console.log('Data path:', dataPath);
  console.log('Log file:', logFile);

  // Open log file for append and wire stdout/stderr to it
  let outFd;
  try {
    outFd = fs.openSync(logFile, 'a');
  } catch (e) {
    console.error('Failed to open log file:', e);
    return false;
  }

  try {
    daemonProcess = spawn(daemonPath, args, {
      detached: true,
      stdio: ['ignore', outFd, outFd],
      windowsHide: true
    });
  } catch (e) {
    console.error('Failed to spawn daemon:', e);
    try { fs.closeSync(outFd); } catch (_) {}
    return false;
  }

  // Persist pid for stopDaemon()
  try {
    fs.writeFileSync(pidFile, String(daemonProcess.pid), 'utf8');
  } catch (e) {
    console.warn('Failed to write pid file:', e);
  }

  daemonProcess.unref();

  // Wait for daemon to be ready
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 1000));
    if (await isDaemonRunning()) {
      console.log('Daemon started successfully');
      return true;
    }
  }

  console.error('Daemon failed to start in time. Last 40 log lines:');
  try {
    const content = fs.readFileSync(logFile, 'utf8');
    const lines = content.split(/\r?\n/).filter(Boolean);
    console.error(lines.slice(-40).join('\n'));
  } catch (_) {
    // ignore
  }

  return false;
}

// Stop daemon
function stopDaemon() {
  const pidFile = path.join(getDataPath(), 'cocained.pid');

  try {
    if (fs.existsSync(pidFile)) {
      const pid = parseInt(fs.readFileSync(pidFile, 'utf8').trim(), 10);
      if (!Number.isNaN(pid)) {
        console.log('Stopping daemon (PID:', pid, ')...');
        if (process.platform === 'win32') {
          execSync(`taskkill /pid ${pid} /T /F`, { stdio: 'ignore' });
        } else {
          // Kill the whole process group if detached
          try {
            process.kill(-pid, 'SIGTERM');
          } catch (_) {
            // Fallback to killing the pid only
            process.kill(pid, 'SIGTERM');
          }
        }
      }
      fs.unlinkSync(pidFile);
    }
  } catch (err) {
    console.log('Error stopping daemon:', err.message);
  }

  daemonProcess = null;
}

// Start embedded server (uses server.js)
function startServer() {
  // Set environment variables for server.js
  process.env.WALLET_DIR = getWalletPath();
  process.env.WALLET_RPC_BIN = getResourcePath(process.platform === 'win32' ? 'cocaine-wallet-rpc.exe' : 'cocaine-wallet-rpc');

  // Require server.js which starts the Express server
  require('./server.js');
}

// Create window
function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 900,
    minHeight: 600,
    title: 'COCAINE Wallet',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js')
    },
    backgroundColor: '#1a1a2e',
    show: false
  });

  mainWindow.loadURL(`http://127.0.0.1:${SERVER_PORT}`);

  mainWindow.once('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });

  // Remove menu bar on Windows
  if (process.platform === 'win32') {
    mainWindow.setMenu(null);
  }
}

// App lifecycle
app.whenReady().then(async () => {
  // Show loading or splash here if needed

  const daemonStarted = await startDaemon();
  if (!daemonStarted) {
    dialog.showErrorBox('Error', 'Failed to start COCAINE daemon. Please check logs.');
  }

  startServer();
  createWindow();
});

app.on('window-all-closed', () => {
  stopDaemon();
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

app.on('before-quit', () => {
  stopDaemon();
});
