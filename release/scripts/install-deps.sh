#!/bin/bash

# COCAINE - Dependency Installer
# Run this if you need to install Node.js

set -e

echo ""
echo "COCAINE Dependency Installer"
echo "============================="
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

install_nodejs_macos() {
    echo "[*] Installing Node.js on macOS..."

    # Check for Homebrew
    if command -v brew &> /dev/null; then
        echo "[*] Using Homebrew..."
        brew install node
    else
        echo "[*] Homebrew not found. Installing via official installer..."
        echo ""
        echo "Please download and install Node.js from:"
        echo "  https://nodejs.org/en/download/"
        echo ""
        echo "Or install Homebrew first:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        exit 1
    fi
}

install_nodejs_linux() {
    echo "[*] Installing Node.js on Linux..."

    # Detect package manager
    if command -v apt-get &> /dev/null; then
        echo "[*] Using apt..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v dnf &> /dev/null; then
        echo "[*] Using dnf..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v yum &> /dev/null; then
        echo "[*] Using yum..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v pacman &> /dev/null; then
        echo "[*] Using pacman..."
        sudo pacman -S nodejs npm
    else
        echo "[!] Unknown package manager"
        echo "Please install Node.js manually from https://nodejs.org"
        exit 1
    fi
}

# Check if Node.js already installed
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo "[+] Node.js already installed: $NODE_VERSION"

    # Check version
    MAJOR_VERSION=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
    if [ "$MAJOR_VERSION" -lt 16 ]; then
        echo "[!] Node.js version too old. Need v16 or newer."
        echo "[*] Please update Node.js"
    else
        echo "[+] Node.js version OK"
    fi
else
    case "$OS" in
        Darwin)
            install_nodejs_macos
            ;;
        Linux)
            install_nodejs_linux
            ;;
        *)
            echo "[!] Unsupported operating system: $OS"
            echo "Please install Node.js manually from https://nodejs.org"
            exit 1
            ;;
    esac
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm --version)
    echo "[+] npm installed: $NPM_VERSION"
else
    echo "[!] npm not found. Please reinstall Node.js"
    exit 1
fi

echo ""
echo "[+] All dependencies installed!"
echo ""
echo "You can now run: ./cocaine.sh mine"
echo ""
