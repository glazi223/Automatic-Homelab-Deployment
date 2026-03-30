#!/bin/bash
# install.sh - Glazar.dev Homelab Orchestrator

echo "🚀 Starting Homelab deployment..."

# --- PHASE 0: Pre-flight Checks (Environment Setup) ---
echo "[0/3] 🔍 Checking environment..."

# OS Detection and Dependency Installation
if command -v pacman &> /dev/null; then
    echo "📦 Arch Linux detected. Installing dependencies via pacman..."
    sudo pacman -Syu --noconfirm curl git ansible python-pip python-requests
    # Na Archu je kvůli novým Python pravidlům potřeba tento flag, aby se proxmoxer nainstaloval globálně
    sudo pip install proxmoxer --break-system-packages 2>/dev/null || pip install proxmoxer
elif command -v apt &> /dev/null; then
    echo "📦 Debian/Ubuntu detected. Installing dependencies via apt..."
    sudo apt update && sudo apt install -y software-properties-common curl git python3-pip
    
    # Check for Ansible, install if missing
    if ! command -v ansible-playbook &> /dev/null; then
        echo "📦 Ansible not found. Installing via PPA..."
        sudo add-apt-repository --yes --update ppa:ansible/ansible
        sudo apt install -y ansible
    else
        echo "✅ Ansible is already installed."
    fi
    # Instalace Python knihoven pro komunikaci s Proxmoxem
    sudo pip3 install proxmoxer requests 2>/dev/null || pip3 install proxmoxer requests
else
    echo "❌ Unsupported package manager. Please install Ansible, python3-pip, and 'proxmoxer' manually."
    exit 1
fi

# --- PHASE 0.5: Inventory Setup ---
INV_FILE="inventory.yml"
if [ ! -f "$INV_FILE" ]; then
    echo "⚠️  $INV_FILE not found! Falling back to inventory.example.yml"
    INV_FILE="inventory.example.yml"
    if [ ! -f "$INV_FILE" ]; then
        echo "❌ Fatal Error: Neither inventory.yml nor inventory.example.yml found in this directory!"
        exit 1
    fi
fi

# Fix permissions for WSL/Windows mounts
# Ansible strictly requires private keys and inventory files NOT to be world-writable
chmod 600 "$INV_FILE" 2>/dev/null || true

# --- PHASE 0.8: User Input ---
read -p "🎮 Do you want to install the Minecraft server? (Requires 16GB+ RAM total) [y/N]: " INSTALL_MC

if [[ "$INSTALL_MC" =~ ^[Yy]$ ]]; then
    MC_VAR="true"
else
    MC_VAR="false"
fi

# --- PHASE 1: Creation ---
echo "[1/3] 🏗️  Provisioning (Proxmox)..."
ansible-playbook -i "$INV_FILE" playbooks/01_provision.yml -e "install_minecraft=$MC_VAR"

if [ $? -ne 0 ]; then
    echo "❌ Error while creating containers! Check the Ansible output above."
    exit 1
fi

# --- PHASE 2: Configuration ---
echo "[2/3] ⚙️  Configuration (Docker & Apps)..."
ansible-playbook -i "$INV_FILE" playbooks/02_services.yml

if [ $? -ne 0 ]; then
    echo "❌ Error during services configuration! Check the Ansible output above."
    exit 1
fi

# --- PHASE 3: Minecraft ---
if [ "$MC_VAR" = "true" ]; then
    echo "[3/3] 🎮 Configuration of game servers..."
    ansible-playbook -i "$INV_FILE" playbooks/03_minecraft.yml
    
    if [ $? -ne 0 ]; then
        echo "❌ Error during Minecraft configuration!"
        exit 1
    fi
else
    echo "[3/3] ⏭️  Skipping Minecraft server configuration..."
fi

echo "------------------------------------------------"
echo "🎉 DONE! Your server ecosystem is up and running."
echo "Check your Cloudflare dashboard for tunnel status."