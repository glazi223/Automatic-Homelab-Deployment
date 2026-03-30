#!/bin/bash
# create_template.sh
# Run this ON the Proxmox host as root

TEMPLATE_ID=8000
STORAGE="local-lvm"
IMAGE="jammy-server-cloudimg-amd64.img"

# Ask for password once
read -s -p "🔑 Enter the password you will use in inventory.yml: " SERVER_PASSWORD
echo
read -s -p "🔑 Confirm password: " SERVER_PASSWORD_CONFIRM
echo

if [ "$SERVER_PASSWORD" != "$SERVER_PASSWORD_CONFIRM" ]; then
    echo "❌ Passwords do not match!"
    exit 1
fi

echo "⬇️  Downloading Ubuntu 22.04 Cloud Image..."
wget -q https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

echo "💾 Resizing disk to 20GB..."
qemu-img resize "$IMAGE" 20G

echo "🖥️  Creating VM (ID $TEMPLATE_ID)..."
qm create $TEMPLATE_ID \
  --name ubuntu-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26

echo "📦 Importing disk..."
qm importdisk $TEMPLATE_ID "$IMAGE" $STORAGE

echo "⚙️  Configuring hardware and Cloud-Init..."
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-0
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket --vga serial0
qm set $TEMPLATE_ID --agent enabled=1
qm set $TEMPLATE_ID --ciupgrade 0

# Enable snippets on local storage
pvesm set local --content iso,vztmpl,backup,snippets

# Create cloud-init userdata snippet with the provided password
mkdir -p /var/lib/vz/snippets
cat > /var/lib/vz/snippets/userdata.yaml << EOF
#cloud-config
ssh_pwauth: true
disable_root: false
runcmd:
  - echo 'root:${SERVER_PASSWORD}' | chpasswd
  - sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - systemctl restart ssh
EOF

qm set $TEMPLATE_ID --cicustom "user=local:snippets/userdata.yaml"
qm set $TEMPLATE_ID --citype nocloud
qm set $TEMPLATE_ID --ciuser root
qm set $TEMPLATE_ID --cipassword "${SERVER_PASSWORD}"
qm set $TEMPLATE_ID --ipconfig0 ip=dhcp

echo "📋 Converting to template..."
qm template $TEMPLATE_ID

echo "🧹 Cleaning up..."
rm "$IMAGE"

echo "✅ Done! Use the same password you entered for all PASSWORD fields in inventory.yml."