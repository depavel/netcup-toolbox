#!/usr/bin/env bash
# Netcup Terminal VAT & Price Calculator
# Repository: https://github.com/depavel/netcup-toolbox
# Web calculator: https://netcupgutscheine.com/en/tools#calc

set -euo pipefail

calc_price() {
  local net="$1"
  local rate="$2"
  awk -v n="$net" -v r="$rate" 'BEGIN { printf "%.2f", int(n * (1 + r) * 100 + 0.5) / 100 }'
}

echo "Netcup Precision Multi-Region VAT & Billing Inspector"
echo "Official rounding rule: round half-up at 2 decimals"
echo "--------------------------------------------------------------------------------"
printf "%-22s %-10s %-12s %-10s %-10s %-10s\n" "Plan" "Net (0%)" "Non-EU / B2B" "19% DE" "20% AT" "23% PL"
echo "--------------------------------------------------------------------------------"

PLANS=(
  "RS 500 G12.5|10.86"
  "RS 1000 G12.5|18.26"
  "RS 2000 G12.5|34.20"
  "RS 4000 G12.5|65.40"
  "RS 8000 G12.5|124.72"
  "RS 2000 vGPU 7|115.39"
  "RS 4000 vGPU 14|219.66"
  "VPS piko/nano G11s|2.99"
  "VPS 500 G12.5|6.94"
  "VPS 1000 G12.5|12.18"
  "VPS 1000 ARM G12.5|10.90"
  "VPS 2000 G12.5|22.62"
  "VPS 4000 G12.5|38.11"
  "VPS 8000 G12.5|56.39"
  "Webhosting 2000|3.39"
  "Webhosting 4000|6.81"
  "Webhosting 8000|11.07"
)

for item in "${PLANS[@]}"; do
  IFS="|" read -r NAME NET <<< "$item"
  P0="€$NET"
  PDE="€$(calc_price "$NET" 0.19)"
  PAT="€$(calc_price "$NET" 0.20)"
  PPL="€$(calc_price "$NET" 0.23)"
  printf "%-22s %-10s %-12s %-10s %-10s %-10s\n" "$NAME" "€$NET" "$P0" "$PDE" "$PAT" "$PPL"
done

echo "--------------------------------------------------------------------------------"
echo "Universal New Customer Voucher: 36nc17927037630 (€5 instant discount)"
echo "Web VAT Calculator: https://netcupgutscheine.com/en/tools#calc"
echo ""
