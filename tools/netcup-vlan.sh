#!/usr/bin/env bash
# Netcup Cloud vLAN Configuration Generator
# Configures a secondary network interface for private 2.5 Gbps networking.
# Repository: https://github.com/depavel/netcup-toolbox
# Web generator: https://netcupgutscheine.com/en/tools#vlan
#
# Netcup Cloud vLAN uses a standard 1500-byte MTU. Jumbo frames are not
# supported on this network; setting MTU 9000 can silently black-hole large
# packets while small pings still succeed.

set -euo pipefail

IFACE="eth1"
IP_CIDR="10.0.10.1/24"
MTU="1500"
MODE="netplan"
APPLY=false

usage() {
  cat <<'EOF'
Usage: bash netcup-vlan.sh [options]

Options:
  -i, --interface <iface>   Interface name from `ip a` (default: eth1)
  -a, --ip <cidr>           Private IPv4 address with prefix (default: 10.0.10.1/24)
  -m, --mtu <size>          MTU size; Netcup Cloud vLAN supports 1500 only
  -f, --mode <mode>         Config format: netplan or debian (default: netplan)
  --apply                   Write the config and apply it (requires root)
  -h, --help                Show this help message

Netcup Cloud vLAN is a Layer 2 network within one datacenter. It does not
support jumbo frames; use MTU 1500 on both servers.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

is_ipv4() {
  local ip="$1" octet
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    [ "$((10#$octet))" -le 255 ] || return 1
  done
}

is_private_ipv4() {
  local ip="$1" a b
  IFS=. read -r a b _ _ <<< "$ip"
  [ "$a" -eq 10 ] && return 0
  [ "$a" -eq 172 ] && [ "$b" -ge 16 ] && [ "$b" -le 31 ] && return 0
  [ "$a" -eq 192 ] && [ "$b" -eq 168 ] && return 0
  return 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -i|--interface)
      [ "$#" -ge 2 ] || fail "$1 requires a value"
      IFACE="$2"; shift 2 ;;
    -a|--ip)
      [ "$#" -ge 2 ] || fail "$1 requires a value"
      IP_CIDR="$2"; shift 2 ;;
    -m|--mtu)
      [ "$#" -ge 2 ] || fail "$1 requires a value"
      MTU="$2"; shift 2 ;;
    -f|--mode)
      [ "$#" -ge 2 ] || fail "$1 requires a value"
      MODE="$2"; shift 2 ;;
    --apply) APPLY=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$IFACE" =~ ^[a-zA-Z0-9_.:-]{1,15}$ ]] || fail "invalid interface name: $IFACE"
[[ "$MODE" == "netplan" || "$MODE" == "debian" ]] || fail "mode must be netplan or debian"
[[ "$MTU" == "1500" ]] || fail "Netcup Cloud vLAN supports MTU 1500 only; jumbo frames are not supported"
[[ "$IP_CIDR" == */* ]] || fail "IP must include a prefix, e.g. 10.0.10.1/24"

IP_ADDR="${IP_CIDR%/*}"
PREFIX="${IP_CIDR#*/}"
is_ipv4 "$IP_ADDR" || fail "invalid IPv4 address: $IP_ADDR"
[[ "$PREFIX" =~ ^[0-9]{1,2}$ ]] || fail "invalid prefix length: $PREFIX"
[ "$PREFIX" -ge 8 ] && [ "$PREFIX" -le 30 ] || fail "prefix length must be between 8 and 30"
is_private_ipv4 "$IP_ADDR" || fail "use an RFC1918 private address (10/8, 172.16/12, 192.168/16)"

if [ "$APPLY" = true ] && [ "$(id -u)" -ne 0 ]; then
  fail "root privileges are required for --apply"
fi

if [ "$MODE" = "netplan" ]; then
  CONF_PATH="/etc/netplan/60-cloud-vlan.yaml"
  CONFIG=$(cat <<EOF
# Netcup Cloud vLAN Netplan Configuration
# Target file: ${CONF_PATH}
# MTU 1500 is required by Netcup Cloud vLAN.
network:
  version: 2
  renderer: networkd
  ethernets:
    ${IFACE}:
      addresses:
        - ${IP_CIDR}
      mtu: ${MTU}
EOF
)
else
  CONF_PATH="/etc/network/interfaces.d/${IFACE}"
  CONFIG=$(cat <<EOF
# Netcup Cloud vLAN Debian Configuration
# Target file: ${CONF_PATH}
# MTU 1500 is required by Netcup Cloud vLAN.
auto ${IFACE}
iface ${IFACE} inet static
    address ${IP_CIDR}
    mtu ${MTU}
EOF
)
fi

printf '%s\n' "$CONFIG"

if [ "$APPLY" != true ]; then
  echo ""
  echo "Preview only. Re-run with --apply to write ${CONF_PATH}."
  echo "Interactive web configurator: https://netcupgutscheine.com/en/tools#vlan"
  exit 0
fi

BACKUP=""
if [ -f "$CONF_PATH" ]; then
  BACKUP="${CONF_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  cp -a "$CONF_PATH" "$BACKUP"
fi

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT
printf '%s\n' "$CONFIG" > "$TMP_FILE"
install -m 600 "$TMP_FILE" "$CONF_PATH"

if [ "$MODE" = "netplan" ]; then
  if ! netplan generate; then
    [ -n "$BACKUP" ] && cp -a "$BACKUP" "$CONF_PATH" || rm -f "$CONF_PATH"
    fail "netplan generate failed; previous configuration restored"
  fi
  if ! netplan apply; then
    [ -n "$BACKUP" ] && cp -a "$BACKUP" "$CONF_PATH" || rm -f "$CONF_PATH"
    fail "netplan apply failed; previous configuration restored"
  fi
  echo "Configuration written to ${CONF_PATH} and applied."
else
  if ! ifup "$IFACE"; then
    [ -n "$BACKUP" ] && cp -a "$BACKUP" "$CONF_PATH" || rm -f "$CONF_PATH"
    fail "ifup ${IFACE} failed; previous configuration restored"
  fi
  echo "Configuration written to ${CONF_PATH} and applied."
fi

echo "Verify with: ip addr show ${IFACE} && ping ${IP_ADDR%.*}.2"
echo "Interactive web configurator: https://netcupgutscheine.com/en/tools#vlan"
