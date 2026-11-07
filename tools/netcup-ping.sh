#!/usr/bin/env bash
# Netcup Datacenter Latency Probe (ICMP)
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools#ping
#
# Supports both iputils ping (Debian/Ubuntu) and BusyBox ping.
# Linux only: the -W timeout flag is interpreted differently on macOS/BSD.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_VERSION="0.3.0"
OUTPUT_MODE="table"
COUNT=3
TIMEOUT=2
FAIL_ON_TIMEOUT=false
NO_COLOR="${NO_COLOR:-false}"

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

usage() {
  cat <<'EOF'
Usage: netcup-ping.sh [options]

Options:
  --json                 Print a JSON array
  --csv                  Print CSV with a header row
  --count <n>            ICMP packets per datacenter (default: 3, max: 10)
  --timeout <seconds>    Per-packet timeout (default: 2)
  --no-color             Disable ANSI colors (also honors NO_COLOR)
  --fail-on-timeout      Exit 1 if any datacenter cannot be measured
  --self-test            Test the ping parser without sending packets
  --version              Print the script version
  -h, --help             Show this help

Examples:
  bash netcup-ping.sh
  bash netcup-ping.sh --json
  bash netcup-ping.sh --count 5 --csv
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

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

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --json) OUTPUT_MODE="json"; shift ;;
      --csv) OUTPUT_MODE="csv"; shift ;;
      --count)
        [ "$#" -ge 2 ] || fail "--count requires a value"
        COUNT="$2"
        shift 2
        ;;
      --timeout)
        [ "$#" -ge 2 ] || fail "--timeout requires a value"
        TIMEOUT="$2"
        shift 2
        ;;
      --no-color) NO_COLOR=true; shift ;;
      --fail-on-timeout) FAIL_ON_TIMEOUT=true; shift ;;
      --self-test) SELF_TEST=true; shift ;;
      --version) echo "$SCRIPT_VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
}

validate_number() {
  local value="$1" name="$2" min="$3" max="$4"
  [[ "$value" =~ ^[0-9]+$ ]] || fail "$name must be a positive integer"
  [ "$value" -ge "$min" ] && [ "$value" -le "$max" ] || fail "$name must be between $min and $max"
}

json_number() {
  local value="$1"
  if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s' "$value"
  else
    printf 'null'
  fi
}

SELF_TEST=false
parse_args "$@"

if [ -n "${NO_COLOR:-}" ] && [ "${NO_COLOR}" != "false" ]; then
  NO_COLOR=true
fi

if [ "$SELF_TEST" = true ]; then
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

validate_number "$COUNT" "--count" 1 10
validate_number "$TIMEOUT" "--timeout" 1 30

command -v ping >/dev/null 2>&1 || fail "'ping' is required (iputils-ping or BusyBox)."

if [ "$OUTPUT_MODE" != "table" ] || [ "$NO_COLOR" = true ] || [ ! -t 1 ]; then
  GREEN=""
  YELLOW=""
  CYAN=""
  RED=""
  RESET=""
fi

FIRST=true
FAILURES=0

if [ "$OUTPUT_MODE" = "table" ]; then
  echo "Netcup Datacenter Latency Probe (ICMP ${COUNT}-packet average)"
  echo "--------------------------------------------------------------------"
  printf "%-18s %-16s %-10s %-10s %-10s %-8s\n" "Location" "Test IP" "Min" "Avg" "Max" "Loss"
  echo "--------------------------------------------------------------------"
elif [ "$OUTPUT_MODE" = "json" ]; then
  printf '[\n'
elif [ "$OUTPUT_MODE" = "csv" ]; then
  echo "location,ip,minMs,avgMs,maxMs,lossPercent,status"
fi

for entry in "${DATACENTERS[@]}"; do
  IFS="|" read -r NAME IP <<< "$entry"
  PING_OUTPUT=$(ping -c "$COUNT" -W "$TIMEOUT" "$IP" 2>&1 || true)

  if STATS=$(printf '%s\n' "$PING_OUTPUT" | parse_ping); then
    read -r MIN AVG MAX LOSS <<< "$STATS"

    case "$OUTPUT_MODE" in
      json)
        [ "$FIRST" = true ] || printf ',\n'
        FIRST=false
        printf '  {"location":"%s","ip":"%s","minMs":%s,"avgMs":%s,"maxMs":%s,"lossPercent":%s,"status":"ok"}' \
          "$NAME" "$IP" "$(json_number "$MIN")" "$(json_number "$AVG")" "$(json_number "$MAX")" "$(json_number "$LOSS")"
        ;;
      csv)
        printf '%s,%s,%s,%s,%s,%s,ok\n' "$NAME" "$IP" "$MIN" "$AVG" "$MAX" "$LOSS"
        ;;
      table)
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
        ;;
    esac
  else
    FAILURES=$((FAILURES + 1))
    case "$OUTPUT_MODE" in
      json)
        [ "$FIRST" = true ] || printf ',\n'
        FIRST=false
        printf '  {"location":"%s","ip":"%s","minMs":null,"avgMs":null,"maxMs":null,"lossPercent":100,"status":"timeout"}' \
          "$NAME" "$IP"
        ;;
      csv)
        printf '%s,%s,,,,100,timeout\n' "$NAME" "$IP"
        ;;
      table)
        printf "%-18s %-16s ${RED}%-10s %-10s %-10s %-8s${RESET}\n" \
          "$NAME" "$IP" "TIMEOUT" "TIMEOUT" "TIMEOUT" "100%"
        ;;
    esac
  fi
done

if [ "$OUTPUT_MODE" = "json" ]; then
  printf '\n]\n'
fi

if [ "$OUTPUT_MODE" = "table" ]; then
  echo "--------------------------------------------------------------------"
  echo "Lower is better. Test IPs are official Netcup reference addresses, not browser probes."
  echo "Interactive map and VAT calculator: https://netcupgutscheine.com/en/tools"
  echo ""
fi

if [ "$FAIL_ON_TIMEOUT" = true ] && [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
