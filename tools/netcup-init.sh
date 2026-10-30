#!/usr/bin/env bash
# Netcup Server Provisioning & Hardening Script
# Target: Debian 12 / Ubuntu 24.04 on Netcup Root Server and VPS
# Repository: https://github.com/depavel/netcup-toolbox

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: root privileges required." >&2
  exit 1
fi

INSTALL_DOCKER="${1:-}"

echo "[1/5] Updating package cache..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git ufw htop jq ca-certificates gnupg lsb-release unattended-upgrades

echo "[2/5] Applying TCP BBR and sysctl tuning..."
cat << 'EOF' > /etc/sysctl.d/99-netcup-optimizations.conf
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192
fs.file-max = 2097152
EOF
sysctl --system > /dev/null

echo "[3/5] Setting up UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "[4/5] Configuring unattended security updates..."
dpkg-reconfigure -f noninteractive unattended-upgrades

if [ "$INSTALL_DOCKER" = "--with-docker" ] || [ "$INSTALL_DOCKER" = "-d" ]; then
  echo "[5/5] Installing Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  DISTRO="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
  CODENAME="$(lsb_release -cs)"
  curl -fsSL "https://download.docker.com/linux/$DISTRO/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
else
  echo "[5/5] Docker install skipped (use --with-docker to install)."
fi

echo "Done. Active TCP congestion: $(sysctl -n net.ipv4.tcp_congestion_control)"
