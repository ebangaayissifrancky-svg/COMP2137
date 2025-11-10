#!/bin/bash
# assignment2.sh - COMP2137 Assignment 2 configuration script

set -e
set -u

info() { echo -e "\e[34m[INFO]\e[0m $1"; }
ok()   { echo -e "\e[32m[OK]\e[0m $1"; }
error(){ echo -e "\e[31m[ERROR]\e[0m $1" >&2; }

### 1. Configuring Network ###
info "Checking netplan configuration..."
NETPLAN_FILE=$(grep -rl "192.168.16" /etc/netplan || true)

if [ -n "$NETPLAN_FILE" ]; then
    if ! grep -q "192.168.16.21/24" "$NETPLAN_FILE"; then
        info "Updating IP address in netplan..."
        sed -i 's|192\.168\.16\.[0-9]\+/24|192.168.16.21/24|' "$NETPLAN_FILE"
        netplan apply
        ok "IP changed to 192.168.16.21"
    else
        ok "Network already set to 192.168.16.21"
    fi
else
    error "Netplan file not found!"
fi

### 2. Update /etc/hosts ###
info "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts
echo "192.168.16.21 server1" >> /etc/hosts
ok "/etc/hosts updated."

### 3. Installing required software ###
for pkg in apache2 squid; do
    info "Checking $pkg..."
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        apt-get update -qq
        apt-get install -y $pkg
        ok "$pkg installed."
    else
        ok "$pkg already installed."
    fi
done
systemctl enable apache2 squid
systemctl restart apache2 squid

### 4. users ###
USERS=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)
DENNIS_EXTRA_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for user in "${USERS[@]}"; do
    info "Configuring user $user..."
    if id "$user" &>/dev/null; then
        ok "$user exists."
    else
        useradd -m -s /bin/bash "$user"
        ok "$user created."
    fi

    SSH_DIR="/home/$user/.ssh"
    AUTH_KEYS="$SSH_DIR/authorized_keys"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    chown "$user:$user" "$SSH_DIR"

    if [ ! -f "$SSH_DIR/id_rsa.pub" ]; then
        sudo -u "$user" ssh-keygen -t rsa -N "" -f "$SSH_DIR/id_rsa" >/dev/null
        ok "RSA key created for $user"
    fi
    if [ ! -f "$SSH_DIR/id_ed25519.pub" ]; then
        sudo -u "$user" ssh-keygen -t ed25519 -N "" -f "$SSH_DIR/id_ed25519" >/dev/null
        ok "Ed25519 key created for $user"
    fi

    touch "$AUTH_KEYS"
    chmod 600 "$AUTH_KEYS"
    chown "$user:$user" "$AUTH_KEYS"

    for pub in "$SSH_DIR"/*.pub; do
        grep -qxF "$(cat "$pub")" "$AUTH_KEYS" || cat "$pub" >> "$AUTH_KEYS"
    done

    if [ "$user" = "dennis" ]; then
        grep -qxF "$DENNIS_EXTRA_KEY" "$AUTH_KEYS" || echo "$DENNIS_EXTRA_KEY" >> "$AUTH_KEYS"
        usermod -aG sudo dennis
        ok "Added sudo & extra SSH key for dennis."
    fi
done

ok "All users configured."
info "Assignment 2 setup completed successfully!"
