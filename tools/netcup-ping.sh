#!/usr/bin/env bash
# Netcup Datacenter Latency Probe (ICMP)
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools#ping
#
# Supports both iputils ping (Debian/Ubuntu) and BusyBox ping.
# Linux only: the -W timeout flag is interpreted differently on macOS/BSD.

set -euo pipefail

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

DATACENTERS=(
  "Nuremberg (DE)|188.68.56.104"
  "Vienna (AT)|89.58.16.1"
  "Amsterdam (NL)|152.53.104.2"
  "Manassas (US)|152.53.68.2"
  "Singapore (SG)|217.146.9.10"
)

# Parses iputils and BusyBox ping summaries.
# iputils:  rtt min/avg/max/mdev = 30.2/31.6/32.6/0.8 ms
# BusyBox:  round-trip min/avg/max = 1.234/2.345/3.456 ms
parse_ping() {
  awk '
    /min\/avg\/max/ {
      line = $0
      sub(/^.*= */, "", line)
      if (split(line, parts, "/") >= 3) {
        min = parts[1]
        avg = parts[2]
        max = parts[3]
        gsub(/[^0-9.]/, "", min)
        gsub(/[^0-9.]/, "", avg)
        gsub(/[^0-9.]/, "", max)
        found = 1
      }
    }
    /packet loss/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /%/) {
          loss = $i
          sub(/%/, "", loss)
          break
        }
      }
    }
    END {
      if (!found) exit 1
      if (loss == "") loss = "?"
      printf "%s %s %s %s\n", min, avg, max, loss
    }
  '
}

if [ "${1:-}" = "--self-test" ]; then
  IPUTILS_SAMPLE='PING 188.68.56.104 (188.68.56.104) 56(84) bytes of data.
64 bytes from 188.68.56.104: icmp_seq=1 ttl=57 time=30.2 ms

--- 188.68.56.104 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2003ms
rtt min/avg/max/mdev = 30.2/31.6/32.6/0.8 ms'
  BUSYBOX_SAMPLE='PING 188.68.56.104 (188.68.56.104): 56 data bytes
64 bytes from 188.68.56.104: seq=0 ttl=57 time=30.2 ms

--- 188.68.56.104 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 1.234/2.345/3.456 ms'
  printf '%s\n' "$IPUTILS_SAMPLE" | parse_ping
  printf '%s\n' "$BUSYBOX_SAMPLE" | parse_ping
  exit 0
fi

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: $0 [--self-test] [--help]"
  echo "Runs 3 ICMP probes per Netcup datacenter and prints min/avg/max/loss."
  exit 0
fi

command -v ping >/dev/null 2>&1 || {
  echo "Error: 'ping' is required (iputils-ping or BusyBox)." >&2
  exit 1
}

echo "Netcup Datacenter Latency Probe (ICMP 3-packet average)"
echo "--------------------------------------------------------------------"
printf "%-18s %-16s %-10s %-10s %-10s %-8s\n" "Location" "Test IP" "Min" "Avg" "Max" "Loss"
echo "--------------------------------------------------------------------"

for entry in "${DATACENTERS[@]}"; do
  IFS="|" read -r NAME IP <<< "$entry"
  PING_OUTPUT=$(ping -c 3 -W 2 "$IP" 2>&1 || true)

  if STATS=$(printf '%s\n' "$PING_OUTPUT" | parse_ping); then
    read -r MIN AVG MAX LOSS <<< "$STATS"

    AVG_INT=${AVG%%.*}
    COLOR="$CYAN"
    case "$AVG_INT" in
      ''|*[!0-9]*) ;;
      *)
        if [ "$AVG_INT" -lt 30 ]; then
          COLOR="$GREEN"
        elif [ "$AVG_INT" -lt 100 ]; then
          COLOR="$YELLOW"
        fi
        ;;
    esac

    printf "%-18s %-16s ${COLOR}%-10s %-10s %-10s${RESET} %-8s\n" \
      "$NAME" "$IP" "${MIN}ms" "${AVG}ms" "${MAX}ms" "${LOSS}%"
  else
    printf "%-18s %-16s ${RED}%-10s %-10s %-10s %-8s${RESET}\n" \
      "$NAME" "$IP" "TIMEOUT" "TIMEOUT" "TIMEOUT" "100%"
  fi
done

echo "--------------------------------------------------------------------"
echo "Lower is better. Test IPs are Netcup's official looking glass nodes."
echo "Interactive map and VAT calculator: https://netcupgutscheine.com/en/tools"
echo ""
