#!/usr/bin/env bash
# Netcup Server Provisioning & Hardening Script
# Target: Debian 12 / Ubuntu 24.04 on Netcup Root Server and VPS
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools#bootstrap
#
# Safe defaults:
#   - no full system upgrade unless --full-upgrade is passed
#   - UFW is enabled only after the SSH port is confirmed to be listening
#   - --dry-run prints every action without changing the system
#   - Docker is optional and its UFW bypass is documented

set -euo pipefail

WITH_DOCKER=false
DRY_RUN=false
ASSUME_YES=false
FULL_UPGRADE=false
SSH_PORT=22

usage() {
  cat <<'EOF'
Usage: sudo bash netcup-init.sh [options]

Options:
  --with-docker       Install Docker Engine and Compose plugin
  --ssh-port <port>   SSH port to allow through UFW (default: 22)
  --full-upgrade      Run apt-get upgrade -y (can install a new kernel)
  --dry-run           Print actions without changing the system
  --yes, -y           Do not ask for confirmation before enabling UFW
  -h, --help          Show this help message

Security note:
  Docker publishes container ports through its own iptables rules. Published
  ports can bypass UFW. Review DOCKER-USER rules before exposing containers.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-docker) WITH_DOCKER=true; shift ;;
    --ssh-port)
      [ "$#" -ge 2 ] || { echo "Error: --ssh-port requires a value." >&2; exit 1; }
      SSH_PORT="$2"
      shift 2
      ;;
    --full-upgrade) FULL_UPGRADE=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) ASSUME_YES=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

case "$SSH_PORT" in
  ''|*[!0-9]*) echo "Error: --ssh-port must be a number." >&2; exit 1 ;;
esac
if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
  echo "Error: --ssh-port must be between 1 and 65535." >&2
  exit 1
fi

if [ "$DRY_RUN" != true ] && [ "$(id -u)" -ne 0 ]; then
  echo "Error: root privileges required (or use --dry-run)." >&2
  exit 1
fi

run() {
  if [ "$DRY_RUN" = true ]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

ssh_port_listening() {
  local port_hex
  port_hex=$(printf '%04X' "$SSH_PORT")
  if [ -r /proc/net/tcp ]; then
    awk -v p=":${port_hex}" '$4 == "0A" && $2 ~ p"$" { found = 1 } END { exit !found }' /proc/net/tcp
  elif command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | awk '{ print $4 }' | grep -Eq "[:.]${SSH_PORT}$"
  else
    return 0
  fi
}

if [ "$DRY_RUN" != true ] && ! ssh_port_listening; then
  echo "Error: nothing is listening on TCP port ${SSH_PORT}." >&2
  echo "Refusing to enable UFW and lock you out. Start sshd on that port or pass --ssh-port." >&2
  exit 1
fi

echo "[1/5] Updating package cache and installing baseline packages..."
run env DEBIAN_FRONTEND=noninteractive apt-get update -y
if [ "$FULL_UPGRADE" = true ]; then
  echo "       Full system upgrade requested (--full-upgrade)."
  run env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
else
  echo "       Skipping full upgrade. Use --full-upgrade to opt in."
fi
run env DEBIAN_FRONTEND=noninteractive apt-get install -y \
  curl wget git ufw htop jq ca-certificates gnupg lsb-release unattended-upgrades

echo "[2/5] Applying TCP BBR and sysctl tuning..."
SYSCTL_FILE="/etc/sysctl.d/99-netcup-optimizations.conf"
SYSCTL_CONTENT=$(cat <<'EOF'
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
)

if [ -f "$SYSCTL_FILE" ]; then
  BACKUP="${SYSCTL_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  echo "       Backing up existing $SYSCTL_FILE to $BACKUP"
  run cp -a "$SYSCTL_FILE" "$BACKUP"
fi

if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] would write $SYSCTL_FILE:"
  printf '%s\n' "$SYSCTL_CONTENT"
else
  printf '%s\n' "$SYSCTL_CONTENT" > "$SYSCTL_FILE"
  sysctl --system >/dev/null
fi

echo "[3/5] Setting up UFW firewall..."
run ufw default deny incoming
run ufw default allow outgoing
run ufw allow "${SSH_PORT}/tcp" comment 'SSH'
run ufw allow 80/tcp comment 'HTTP'
run ufw allow 443/tcp comment 'HTTPS'

if [ "$DRY_RUN" = true ]; then
  run ufw --force enable
elif [ "$ASSUME_YES" = true ] || [ ! -t 0 ]; then
  if [ "$ASSUME_YES" = true ]; then
    run ufw --force enable
  else
    echo "       UFW rules written but not enabled (non-interactive shell; pass --yes)."
  fi
else
  read -r -p "Enable UFW now? [y/N] " reply
  case "$reply" in
    y|Y|yes|YES) run ufw --force enable ;;
    *) echo "       UFW rules written but not enabled." ;;
  esac
fi

echo "[4/5] Configuring unattended security updates..."
if [ "$DRY_RUN" = true ]; then
  echo "[dry-run] dpkg-reconfigure -f noninteractive unattended-upgrades"
else
  dpkg-reconfigure -f noninteractive unattended-upgrades
fi

if [ "$WITH_DOCKER" = true ]; then
  echo "[5/5] Installing Docker Engine..."
  echo "       WARNING: Docker-published ports can bypass UFW. Review DOCKER-USER rules." >&2
  run install -m 0755 -d /etc/apt/keyrings
  DISTRO="$(lsb_release -is | tr '[:upper:]' '[:lower:]')"
  CODENAME="$(lsb_release -cs)"
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] install Docker GPG key for ${DISTRO}/${CODENAME}"
    echo "[dry-run] write /etc/apt/sources.list.d/docker.list"
  else
    curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO} ${CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list
  fi
  run env DEBIAN_FRONTEND=noninteractive apt-get update -y
  run env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  run systemctl enable --now docker
else
  echo "[5/5] Docker install skipped (use --with-docker to install)."
fi

if [ "$DRY_RUN" = true ]; then
  echo "Dry run complete. No changes were made."
else
  echo "Done. Active TCP congestion: $(sysctl -n net.ipv4.tcp_congestion_control)"
fi
echo "Interactive DevOps tools & config generators: https://netcupgutscheine.com/en/tools"
