#!/usr/bin/env bash
# Netcup Datacenter Latency Probe (ICMP)
# Repository: https://github.com/depavel/netcup-toolbox
# Web: https://netcupgutscheine.com

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

echo "Netcup Datacenter Latency Probe (ICMP 3-packet average)"
echo "--------------------------------------------------------------------"
printf "%-18s %-16s %-10s %-10s %-10s %-8s\n" "Location" "Test IP" "Min" "Avg" "Max" "Loss"
echo "--------------------------------------------------------------------"

DATACENTERS=(
  "Nuremberg (DE)|188.68.56.104"
  "Vienna (AT)|89.58.16.1"
  "Amsterdam (NL)|152.53.104.2"
  "Manassas (US)|152.53.68.2"
  "Singapore (SG)|217.146.9.10"
)

for entry in "${DATACENTERS[@]}"; do
  IFS="|" read -r NAME IP <<< "$entry"
  PING_OUTPUT=$(ping -c 3 -W 2 "$IP" 2>&1 || true)

  if echo "$PING_OUTPUT" | grep -q "min/avg/max"; then
    STATS=$(echo "$PING_OUTPUT" | grep "min/avg/max" | awk -F'=' '{print $2}' | tr -d ' ' | awk -F'/' '{print $1" "$2" "$3}')
    LOSS=$(echo "$PING_OUTPUT" | grep -o "[0-9.]*% packet loss" | awk '{print $1}')
    read -r MIN AVG MAX <<< "$STATS"

    AVG_INT=${AVG%.*}
    if [ "${AVG_INT:-999}" -lt 30 ]; then
      COLOR="$GREEN"
    elif [ "${AVG_INT:-999}" -lt 100 ]; then
      COLOR="$YELLOW"
    else
      COLOR="$CYAN"
    fi

    printf "%-18s %-16s ${COLOR}%-10s %-10s %-10s${RESET} %-8s\n" "$NAME" "$IP" "${MIN}ms" "${AVG}ms" "${MAX}ms" "$LOSS"
  else
    printf "%-18s %-16s ${RED}%-10s %-10s %-10s %-8s${RESET}\n" "$NAME" "$IP" "TIMEOUT" "TIMEOUT" "TIMEOUT" "100%"
  fi
done

echo "--------------------------------------------------------------------"
echo "Web tools (interactive map, VAT calculator): https://netcupgutscheine.com"
echo ""
