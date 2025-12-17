@echo off
title COCAINE Dashboard
cd /d "%~dp0"

echo.
echo  COCAINE Dashboard v3.0
echo  ======================
echo.

REM Check Node.js
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Node.js not found!
    echo     Please install from https://nodejs.org
    pause
    exit /b 1
)

REM Install dependencies if needed
if not exist "node_modules" (
    echo [*] Installing dependencies...
    call npm install
)

echo.
echo [*] Starting dashboard...
echo.
echo     Dashboard: http://127.0.0.1:8080
echo     Daemon RPC: port 19081
echo.
echo     Press Ctrl+C to stop
echo.

node server.js
pause
