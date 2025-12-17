# COCAINE Dashboard - Windows Launcher
# Run this script to start the dashboard

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗" -ForegroundColor Green
Write-Host "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝" -ForegroundColor Green
Write-Host "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  " -ForegroundColor Green
Write-Host "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  " -ForegroundColor Green
Write-Host "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗" -ForegroundColor Green
Write-Host " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝" -ForegroundColor Green
Write-Host ""
Write-Host "           COCAINE Dashboard v3.0" -ForegroundColor Cyan
Write-Host ""

# Check Node.js
Write-Host "[*] Checking Node.js..." -ForegroundColor Yellow
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js not found!" -ForegroundColor Red
    Write-Host "    Please install from https://nodejs.org" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$nodeVersion = node --version
Write-Host "    Found Node.js $nodeVersion" -ForegroundColor Gray

# Install dependencies if needed
Set-Location $ScriptDir
if (-not (Test-Path "node_modules")) {
    Write-Host "[*] Installing dependencies..." -ForegroundColor Yellow
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Failed to install dependencies" -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit 1
    }
}

Write-Host ""
Write-Host "[*] Starting dashboard server..." -ForegroundColor Yellow
Write-Host ""
Write-Host "    Dashboard: http://127.0.0.1:8080" -ForegroundColor Cyan
Write-Host "    Daemon RPC: port 19081" -ForegroundColor Gray
Write-Host "    Wallet RPC: port 19083" -ForegroundColor Gray
Write-Host ""
Write-Host "    Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

# Start dashboard
node server.js
