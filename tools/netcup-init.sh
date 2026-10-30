#!/usr/bin/env bash
# ==============================================================================
# Netcup Server Bootstrap & Hardening Tool
# Configures TCP BBR (2.5 Gbps), NVMe optimizations, UFW firewall, and Docker.
# Target OS: Debian 12 / Ubuntu 24.04 LTS on Netcup VPS & Root Server
# Repository: https://github.com/depavel/netcup-toolbox
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root (or with sudo)." >&2
  exit 1
fi

INSTALL_DOCKER="${1:-}"

echo "=== 1/5. Updating packages and installing base utilities ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget git ufw htop jq ca-certificates gnupg lsb-release unattended-upgrades

echo "=== 2/5. Enabling TCP BBR Congestion Control & High-IOPS Sysctl ==="
cat << 'EOF' > /etc/sysctl.d/99-netcup-optimizations.conf
# Enable BBR congestion control for max 2.5 Gbps line-rate throughput
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# NVMe disk and virtual memory tuning
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Network stack buffer scaling
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.core.somaxconn = 8192
net.ipv4.tcp_max_syn_backlog = 8192

# File descriptor limits
fs.file-max = 2097152
EOF
sysctl --system > /dev/null

echo "=== 3/5. Configuring UFW Firewall ==="
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw --force enable

echo "=== 4/5. Configuring Automated Security Updates ==="
dpkg-reconfigure -f noninteractive unattended-upgrades

if [ "$INSTALL_DOCKER" = "--with-docker" ] || [ "$INSTALL_DOCKER" = "-d" ]; then
  echo "=== 5/5. Installing Official Docker Engine & Compose ==="
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
  echo "=== 5/5. Skipped Docker installation (pass --with-docker to install) ==="
fi

echo ""
echo "=== Netcup Server Bootstrap Complete ==="
echo "Active TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control)"
echo "Firewall status: $(ufw status | head -n 1)"
echo "Need help finding the right server? Visit: https://netcupgutscheine.com"
