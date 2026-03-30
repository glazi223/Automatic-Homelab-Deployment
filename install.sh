#!/bin/bash
# install.sh - Glazar.dev Homelab Orchestrator

echo "🚀 Starting Homelab deployment..."

# --- PHASE 0: Pre-flight Checks (Environment Setup) ---
echo "[0/3] 🔍 Checking environment..."

# Update and install basic tools
sudo apt update && sudo apt install -y software-properties-common curl git

# Check for Ansible, install if missing
if ! command -v ansible-playbook &> /dev/null; then
    echo "📦 Ansible not found. Installing via PPA..."
    sudo add-apt-repository --yes --update ppa:ansible/ansible
    sudo apt install -y ansible
else
    echo "✅ Ansible is already installed."
fi

# Fix permissions for WSL/Windows mounts
# Ansible strictly requires private keys and inventory files NOT to be world-writable
chmod 600 inventory.yml 2>/dev/null || true

# --- PHASE 0.5: User Input ---
read -p "🎮 Do you want to install the Minecraft server? (Requires 16GB+ RAM total) [y/N]: " INSTALL_MC

if [[ "$INSTALL_MC" =~ ^[Yy]$ ]]; then
    MC_VAR="true"
else
    MC_VAR="false"
fi

# --- PHASE 1: Creation ---
echo "[1/3] 🏗️  Provisioning (Proxmox)..."
ansible-playbook -i inventory.yml playbooks/01_provision.yml -e "install_minecraft=$MC_VAR"

if [ $? -ne 0 ]; then
    echo "❌ Error while creating containers!"
    exit 1
fi

# --- PHASE 2: Configuration ---
echo "[2/3] ⚙️  Configuration (Docker & Apps)..."
ansible-playbook -i inventory.yml playbooks/02_services.yml

if [ $? -ne 0 ]; then
    echo "❌ Error during services configuration!"
    exit 1
fi

# --- PHASE 3: Minecraft ---
if [ "$MC_VAR" = "true" ]; then
    echo "[3/3] 🎮 Configuration of game servers..."
    ansible-playbook -i inventory.yml playbooks/03_minecraft.yml
else
    echo "[3/3] ⏭️  Skipping Minecraft server configuration..."
fi

echo "------------------------------------------------"
echo "🎉 DONE! Your server ecosystem is up and running."
echo "Check your Cloudflare dashboard for tunnel status."