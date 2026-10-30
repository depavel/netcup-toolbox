#!/usr/bin/env bash
# Netcup Cloud vLAN Configuration Generator
# Configures a secondary network interface for private 2.5 Gbps networking.
# Repository: https://github.com/depavel/netcup-toolbox
# Web generator: https://netcupgutscheine.com/en/tools#vlan

set -euo pipefail

IFACE="eth1"
IP_CIDR="10.0.10.1/24"
MTU="9000"
MODE="netplan"
APPLY=false

print_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  -i, --interface <iface>   Interface name (default: eth1)"
  echo "  -a, --ip <cidr>          Private IP address with subnet (default: 10.0.10.1/24)"
  echo "  -m, --mtu <size>         MTU size: 9000 (jumbo) or 1500 (default: 9000)"
  echo "  -f, --mode <mode>        Config format: netplan or debian (default: netplan)"
  echo "  --apply                  Apply configuration immediately (requires root)"
  echo "  -h, --help               Show this help message"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--interface) IFACE="$2"; shift 2 ;;
    -a|--ip) IP_CIDR="$2"; shift 2 ;;
    -m|--mtu) MTU="$2"; shift 2 ;;
    -f|--mode) MODE="$2"; shift 2 ;;
    --apply) APPLY=true; shift ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
  esac
done

if [ "$MODE" = "netplan" ]; then
  CONF_PATH="/etc/netplan/60-cloud-vlan.yaml"
  cat << EOF
# Netcup Cloud vLAN Netplan Configuration
# Target file: $CONF_PATH
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      addresses:
        - ${IP_CIDR}
      mtu: ${MTU}
      routes: []
EOF
  if [ "$APPLY" = true ]; then
    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: root privileges required to write to $CONF_PATH." >&2
      exit 1
    fi
    cat << EOF > "$CONF_PATH"
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      addresses:
        - ${IP_CIDR}
      mtu: ${MTU}
      routes: []
EOF
    chmod 600 "$CONF_PATH"
    netplan apply
    echo "Configuration written to $CONF_PATH and applied."
  fi
else
  CONF_PATH="/etc/network/interfaces.d/${IFACE}"
  cat << EOF
# Netcup Cloud vLAN Debian Configuration
# Target file: $CONF_PATH
auto ${IFACE}
iface ${IFACE} inet static
    address ${IP_CIDR}
    mtu ${MTU}
EOF
  if [ "$APPLY" = true ]; then
    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: root privileges required to write to $CONF_PATH." >&2
      exit 1
    fi
    cat << EOF > "$CONF_PATH"
auto ${IFACE}
iface ${IFACE} inet static
    address ${IP_CIDR}
    mtu ${MTU}
EOF
    ifup "${IFACE}" || true
    echo "Configuration written to $CONF_PATH."
  fi
fi

echo ""
echo "Interactive web configurator: https://netcupgutscheine.com/en/tools#vlan"
