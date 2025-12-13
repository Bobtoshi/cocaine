# Windows PowerShell Launcher - Starts controller + dashboard

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir\..

Write-Host ""
Write-Host " ██████╗ ██████╗  ██████╗ █████╗ ██╗███╗   ██╗███████╗"
Write-Host "██╔════╝██╔═══██╗██╔════╝██╔══██╗██║████╗  ██║██╔════╝"
Write-Host "██║     ██║   ██║██║     ███████║██║██╔██╗ ██║█████╗  "
Write-Host "██║     ██║   ██║██║     ██╔══██║██║██║╚██╗██║██╔══╝  "
Write-Host "╚██████╗╚██████╔╝╚██████╗██║  ██║██║██║ ╚████║███████╗"
Write-Host " ╚═════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝╚══════╝"
Write-Host ""
Write-Host "Starting Dashboard with Controller..."
Write-Host ""

# Check Node.js
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js not found. Please install from https://nodejs.org"
    exit 1
}

# Install dependencies if needed
if (-not (Test-Path "dashboard\node_modules")) {
    Write-Host "[*] Installing dependencies..."
    Set-Location dashboard
    npm install
    Set-Location ..
}

# Create logs directory
if (-not (Test-Path "logs")) {
    New-Item -ItemType Directory -Path "logs" | Out-Null
}

# Start controller in background
Write-Host "[*] Starting controller..."
Set-Location dashboard
Start-Process -NoNewWindow node -ArgumentList "controller.js" -RedirectStandardOutput "..\logs\controller.log" -RedirectStandardError "..\logs\controller.log"
Set-Location ..

# Wait for controller to start
Start-Sleep -Seconds 2

# Start dashboard
Write-Host "[*] Starting dashboard..."
Set-Location dashboard
node server.js

