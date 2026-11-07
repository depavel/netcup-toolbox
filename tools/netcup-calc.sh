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
LC_ALL=C
export LC_ALL

SCRIPT_VERSION="0.3.0"
OUTPUT_MODE="table"
PLAN_FILTER=""

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

usage() {
  cat <<'EOF'
Usage: netcup-calc.sh [options]

Options:
  --json              Print a JSON array
  --plan <text>       Only show plans whose name contains <text> (case-insensitive)
  --version           Print the script version
  -h, --help          Show this help message

Examples:
  bash netcup-calc.sh
  bash netcup-calc.sh --plan RS --json
  bash netcup-calc.sh --self-test
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --json) OUTPUT_MODE="json"; shift ;;
      --plan)
        [ "$#" -ge 2 ] || fail "--plan requires a value"
        PLAN_FILTER="$2"
        shift 2
        ;;
      --self-test) SELF_TEST=true; shift ;;
      --version) echo "$SCRIPT_VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
}

SELF_TEST=false
parse_args "$@"

if [ "$SELF_TEST" = true ]; then
  [ "$(calc_price 10.86 0.19)" = "12.93" ] || { echo "self-test failed: RS 500 DE" >&2; exit 1; }
  [ "$(calc_price 6.8067 0.19)" = "8.10" ] || { echo "self-test failed: Webhosting 4000 DE" >&2; exit 1; }
  [ "$(calc_price 10.86 0)" = "10.86" ] || { echo "self-test failed: 0% VAT" >&2; exit 1; }
  echo "self-test OK"
  exit 0
fi

PLANS=(
  "RS 500 G12.5|10.86"
  "RS 1000 G12.5|18.26"
  "RS 2000 G12.5|34.2"
  "RS 4000 G12.5|65.4"
  "RS 8000 G12.5|124.72"
  "RS 2000 vGPU 7|102.3277"
  "RS 4000 vGPU 14|195.3193"
  "VPS nano G11.5s|3.1008"
  "VPS pico G11.5s|1.8571"
  "VPS 500 G12.5|6.94"
  "VPS 1000 G12.5|12.18"
  "VPS 1000 ARM G12.5|12.1848"
  "VPS 2000 G12.5|22.62"
  "VPS 4000 G12.5|38.11"
  "VPS 8000 G12.5|56.39"
  "Webhosting 2000|3.3865"
  "Webhosting 4000|6.8067"
  "Webhosting 8000|11.0672"
  "Webhosting 2000 30Prozent Rabatt NUE 1M|2.3697"
)

if [ "$OUTPUT_MODE" = "table" ]; then
  echo "Netcup Precision Multi-Region VAT & Billing Inspector"
  echo "Official rounding rule: ceiling to the next cent when VAT > 0%"
  echo "--------------------------------------------------------------------------------"
  printf "%-26s %-10s %-10s %-10s %-10s %-14s\n" \
    "Plan" "Net" "19% DE" "20% AT" "23% PL" "0% Non-EU/B2B"
  echo "--------------------------------------------------------------------------------"
elif [ "$OUTPUT_MODE" = "json" ]; then
  printf '[\n'
fi

FIRST=true
MATCHES=0
for item in "${PLANS[@]}"; do
  IFS="|" read -r NAME NET <<< "$item"
  if [ -n "$PLAN_FILTER" ] && [[ "${NAME,,}" != *"${PLAN_FILTER,,}"* ]]; then
    continue
  fi
  MATCHES=$((MATCHES + 1))

  NET_DISPLAY=$(awk -v n="$NET" 'BEGIN { printf "%.2f", n }')
  PDE=$(calc_price "$NET" 0.19)
  PAT=$(calc_price "$NET" 0.20)
  PPL=$(calc_price "$NET" 0.23)
  P0=$(calc_price "$NET" 0)

  case "$OUTPUT_MODE" in
    table)
      printf "%-26s %-10s %-10s %-10s %-10s %-14s\n" \
        "$NAME" "€$NET_DISPLAY" "€$PDE" "€$PAT" "€$PPL" "€$P0"
      ;;
    json)
      [ "$FIRST" = true ] || printf ',\n'
      FIRST=false
      printf '  {"plan":"%s","netEur":"%s","de19":"%s","at20":"%s","pl23":"%s","nonEu0":"%s"}' \
        "$NAME" "$NET_DISPLAY" "$PDE" "$PAT" "$PPL" "$P0"
      ;;
  esac
done

if [ "$MATCHES" -eq 0 ]; then
  fail "no plans matched --plan '$PLAN_FILTER'"
fi

if [ "$OUTPUT_MODE" = "json" ]; then
  printf '\n]\n'
else
  echo "--------------------------------------------------------------------------------"
  echo "Universal New Customer Voucher: 36nc17927037630 (€5 instant discount)"
  echo "Web VAT Calculator: https://netcupgutscheine.com/en/tools#calc"
  echo ""
fi
