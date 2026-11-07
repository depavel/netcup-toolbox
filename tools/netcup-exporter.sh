#!/usr/bin/env bash
# Netcup Prometheus textfile exporter.
# Emits local host metrics and ICMP latency to the 5 official Netcup test IPs.
# Designed for node_exporter's textfile collector, run from cron or a timer.
#
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools
#
# No Netcup credentials are required. Missing measurements are omitted (or
# reported with a *_probe_success 0 gauge), never converted to a fake zero.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_VERSION="0.4.0"
TEXTFILE=""
NO_LATENCY=false

DATACENTERS=(
  "nue|Nuremberg (DE)|188.68.56.104"
  "vie|Vienna (AT)|89.58.16.1"
  "ams|Amsterdam (NL)|152.53.104.2"
  "man|Manassas (US)|152.53.68.2"
  "sin|Singapore (SG)|217.146.9.10"
)

usage() {
  cat <<'EOF'
Usage: netcup-exporter.sh [options]

Options:
  --textfile <path>    Write metrics atomically to <path> (default: stdout)
  --no-latency         Skip the 5 ICMP latency probes
  --version            Print the script version
  -h, --help           Show this help

Prometheus example:
  sudo install -d -m 0755 /var/lib/node_exporter/textfile
  netcup-exporter.sh --textfile /var/lib/node_exporter/textfile/netcup.prom

Cron example:
  */5 * * * * /usr/local/bin/netcup-exporter.sh --textfile /var/lib/node_exporter/textfile/netcup.prom
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

escape_label() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

parse_ping() {
  awk '
    /min\/avg\/max/ {
      line = $0
      sub(/^.*= */, "", line)
      if (split(line, parts, "/") >= 3) {
        value = parts[2]
        gsub(/[^0-9.]/, "", value)
        print value
        found = 1
      }
    }
    END { if (!found) exit 1 }
  '
}

parse_steal() {
  awk 'NF > 0 { print $NF }' | tail -1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --textfile)
        [ "$#" -ge 2 ] || fail "--textfile requires a path"
        TEXTFILE="$2"
        shift 2
        ;;
      --no-latency) NO_LATENCY=true; shift ;;
      --version) echo "$SCRIPT_VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
}

emit_metric() {
  local name="$1" help="$2" type="$3" value="$4" labels="${5:-}"
  printf '# HELP %s %s\n# TYPE %s %s\n' "$name" "$help" "$name" "$type"
  if [ -n "$labels" ]; then
    printf '%s{%s} %s\n' "$name" "$labels" "$value"
  else
    printf '%s %s\n' "$name" "$value"
  fi
}

build_metrics() {
  local hostname uptime load1 load5 load15 mem_available disk_available bbr steal
  hostname=$(hostname 2>/dev/null || echo unknown)
  hostname=$(escape_label "$hostname")

  emit_metric netcup_exporter_info 'Exporter build information' gauge 1 "version=\"${SCRIPT_VERSION}\",hostname=\"${hostname}\""

  if [ -r /proc/uptime ]; then
    uptime=$(awk '{printf "%.0f", $1}' /proc/uptime)
    emit_metric netcup_uptime_seconds 'Host uptime in seconds' gauge "$uptime"
  fi

  if [ -r /proc/loadavg ]; then
    read -r load1 load5 load15 _ < /proc/loadavg
    emit_metric netcup_load1 '1-minute load average' gauge "$load1"
    emit_metric netcup_load5 '5-minute load average' gauge "$load5"
    emit_metric netcup_load15 '15-minute load average' gauge "$load15"
  fi

  if [ -r /proc/meminfo ]; then
    mem_available=$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo)
    if [ -n "$mem_available" ]; then
      emit_metric netcup_memory_available_bytes 'Available memory in bytes' gauge "$mem_available"
    fi
  fi

  if command -v df >/dev/null 2>&1; then
    disk_available=$(df -B1 / | awk 'NR == 2 {print $4}')
    if [[ "$disk_available" =~ ^[0-9]+$ ]]; then
      emit_metric netcup_filesystem_available_bytes 'Available bytes on /' gauge "$disk_available" 'mountpoint="/"'
    fi
  fi

  if command -v sysctl >/dev/null 2>&1; then
    bbr=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || true)
    if [ -n "$bbr" ]; then
      if [ "$bbr" = "bbr" ]; then
        emit_metric netcup_bbr_enabled 'TCP BBR congestion control enabled' gauge 1
      else
        emit_metric netcup_bbr_enabled 'TCP BBR congestion control enabled' gauge 0
      fi
    fi
  fi

  if command -v vmstat >/dev/null 2>&1; then
    steal=$(vmstat 1 2 2>/dev/null | parse_steal || true)
    if [[ "$steal" =~ ^[0-9]+$ ]]; then
      emit_metric netcup_cpu_steal_percent 'CPU steal percentage from vmstat' gauge "$steal"
    else
      emit_metric netcup_cpu_steal_probe_success 'Whether the CPU steal probe succeeded' gauge 0
    fi
  else
    emit_metric netcup_cpu_steal_probe_success 'Whether the CPU steal probe succeeded' gauge 0
  fi

  if [ "$NO_LATENCY" = true ]; then
    return 0
  fi

  printf '# HELP netcup_latency_ms ICMP round-trip time in milliseconds\n'
  printf '# TYPE netcup_latency_ms gauge\n'
  printf '# HELP netcup_latency_probe_success Whether the ICMP latency probe succeeded\n'
  printf '# TYPE netcup_latency_probe_success gauge\n'

  local entry id location ip output avg
  if ! command -v ping >/dev/null 2>&1; then
    for entry in "${DATACENTERS[@]}"; do
      IFS='|' read -r id location ip <<< "$entry"
      printf 'netcup_latency_probe_success{datacenter="%s"} 0\n' "$id"
    done
    return 0
  fi

  for entry in "${DATACENTERS[@]}"; do
    IFS='|' read -r id location ip <<< "$entry"
    output=$(ping -c 1 -W 1 "$ip" 2>&1 || true)
    if avg=$(printf '%s\n' "$output" | parse_ping); then
      printf 'netcup_latency_ms{datacenter="%s",location="%s"} %s\n' "$id" "$(escape_label "$location")" "$avg"
      printf 'netcup_latency_probe_success{datacenter="%s"} 1\n' "$id"
    else
      printf 'netcup_latency_probe_success{datacenter="%s"} 0\n' "$id"
    fi
  done
}

if [ "${1:-}" = "--self-test" ]; then
  SAMPLE='rtt min/avg/max/mdev = 30.2/31.6/32.6/0.8 ms'
  [ "$(printf '%s\n' "$SAMPLE" | parse_ping)" = '31.6' ] || { echo 'self-test failed: ping parser' >&2; exit 1; }
  STEAL_SAMPLE=' 1  0 0 0 0 0 0 0 0 0 100 0 0 0 0 0 0.4'
  [ "$(printf '%s\n' "$STEAL_SAMPLE" | parse_steal)" = '0.4' ] || { echo 'self-test failed: steal parser' >&2; exit 1; }
  echo 'self-test OK'
  exit 0
fi

parse_args "$@"

if [ -n "$TEXTFILE" ]; then
  tmp="${TEXTFILE}.tmp.$$"
  trap 'rm -f "$tmp"' EXIT
  build_metrics > "$tmp"
  mv "$tmp" "$TEXTFILE"
  trap - EXIT
else
  build_metrics
fi
