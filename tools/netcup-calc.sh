#!/usr/bin/env bash
# Netcup Terminal VAT & Price Calculator
# Repository: https://github.com/depavel/netcup-toolbox
# Web calculator: https://netcupgutscheine.com/en/tools#calc
#
# Netcup rounds gross prices up to the next cent when VAT is greater than 0%.
# Verified against the official netcup.com RS 500 G12.5 card on 2026-10-31:
#   EUR 10.86 net x 1.19 = EUR 12.9234 -> EUR 12.93 (19% DE).
# The 0% regions keep the exact net price.

set -euo pipefail

calc_price() {
  local net="$1"
  local rate="$2"
  awk -v n="$net" -v r="$rate" 'BEGIN {
    if (r == 0) {
      printf "%.2f", n
      exit
    }
    x = n * (1 + r) * 100
    y = int(x)
    if (x > y) y++
    printf "%.2f", y / 100
  }'
}

if [ "${1:-}" = "--self-test" ]; then
  [ "$(calc_price 10.86 0.19)" = "12.93" ] || { echo "self-test failed: RS 500 DE" >&2; exit 1; }
  [ "$(calc_price 6.8067 0.19)" = "8.10" ] || { echo "self-test failed: Webhosting 4000 DE" >&2; exit 1; }
  [ "$(calc_price 10.86 0)" = "10.86" ] || { echo "self-test failed: 0% VAT" >&2; exit 1; }
  echo "self-test OK"
  exit 0
fi

echo "Netcup Precision Multi-Region VAT & Billing Inspector"
echo "Official rounding rule: ceiling to the next cent when VAT > 0%"
echo "--------------------------------------------------------------------------------"
printf "%-26s %-10s %-10s %-10s %-10s %-14s\n" \
  "Plan" "Net" "19% DE" "20% AT" "23% PL" "0% Non-EU/B2B"
echo "--------------------------------------------------------------------------------"

PLANS=(
  "RS 500 G12.5|10.86"
  "RS 1000 G12.5|18.26"
  "RS 2000 G12.5|34.2"
  "RS 4000 G12.5|65.4"
  "RS 8000 G12.5|124.72"
  "RS 2000 vGPU 7|102.3277"
  "RS 4000 vGPU 14|195.3193"
  "VPS piko / nano G11s|2.99"
  "VPS 500 G12.5|6.94"
  "VPS 1000 G12.5|12.18"
  "VPS 1000 ARM G12.5|10.9"
  "VPS 2000 G12.5|22.62"
  "VPS 4000 G12.5|38.11"
  "VPS 8000 G12.5|56.39"
  "Webhosting 2000|3.3865"
  "Webhosting 4000|6.8067"
  "Webhosting 8000|11.0672"
  "Webhosting 2000 30Prozent Rabatt NUE 1M|2.3697"
)

for item in "${PLANS[@]}"; do
  IFS="|" read -r NAME NET <<< "$item"
  NET_DISPLAY=$(awk -v n="$NET" 'BEGIN { printf "%.2f", n }')
  PDE=$(calc_price "$NET" 0.19)
  PAT=$(calc_price "$NET" 0.20)
  PPL=$(calc_price "$NET" 0.23)
  P0=$(calc_price "$NET" 0)
  printf "%-26s %-10s %-10s %-10s %-10s %-14s\n" \
    "$NAME" "€$NET_DISPLAY" "€$PDE" "€$PAT" "€$PPL" "€$P0"
done

echo "--------------------------------------------------------------------------------"
echo "Universal New Customer Voucher: 36nc17927037630 (€5 instant discount)"
echo "Web VAT Calculator: https://netcupgutscheine.com/en/tools#calc"
echo ""
