#!/usr/bin/env bash
# Netcup mail DNS and port-25 checker.
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools
#
# Checks MX, SPF, DMARC, DKIM presence, A/AAAA and PTR records, and outbound
# port 25 reachability. This is a presence and reachability check, not a full
# SPF/DKIM/DMARC policy evaluator.

set -euo pipefail
LC_ALL=C
export LC_ALL

SCRIPT_VERSION="0.4.0"
DOMAIN=""
SELECTOR="default"
MX_OVERRIDE=""
JSON_OUTPUT=false
PORT_CHECK=true
STRICT=false

usage() {
  cat <<'EOF'
Usage: netcup-mail-check.sh [options] <domain>

Options:
  --domain <domain>      Domain to check (alternative to the positional argument)
  --selector <name>      DKIM selector (default: default)
  --mx <host[,host]>     Override MX hosts instead of querying DNS
  --json                 Print JSON
  --no-port-check        Skip the outbound TCP/25 reachability check
  --strict               Exit 1 when any warning is found
  --version              Print the script version
  -h, --help             Show this help

Examples:
  bash netcup-mail-check.sh example.com
  bash netcup-mail-check.sh example.com --selector mail --json
  bash netcup-mail-check.sh example.com --mx mx1.example.com,mx2.example.com

Notes:
  - Requires dig (bind9-dnsutils / bind-utils).
  - Port 25 checks from a residential ISP may be blocked by the ISP, not by the
    destination. Use a server with outbound port 25 for a meaningful result.
  - A missing DKIM selector does not prove DKIM is broken; providers use
    different selectors.
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "'$1' is required"
}

is_domain() {
  local domain="$1"
  [ "${#domain}" -le 253 ] || return 1
  [[ "$domain" == *.* ]] || return 1
  [[ "$domain" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

is_hostname() {
  local host="$1"
  [ "${#host}" -le 253 ] || return 1
  [[ "$host" == *.* ]] || return 1
  [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

parse_dmarc_policy() {
  local record="$1"
  printf '%s\n' "$record" | sed -n 's/.*[;[:space:]]p=\([^;[:space:]]*\).*/\1/p' | head -1
}

first_line() {
  sed -n '1p' | sed 's/[[:space:]]*$//'
}

strip_dot() {
  sed 's/\.$//'
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --domain)
        [ "$#" -ge 2 ] || fail "--domain requires a value"
        DOMAIN="$2"
        shift 2
        ;;
      --selector)
        [ "$#" -ge 2 ] || fail "--selector requires a value"
        SELECTOR="$2"
        shift 2
        ;;
      --mx)
        [ "$#" -ge 2 ] || fail "--mx requires a value"
        MX_OVERRIDE="$2"
        shift 2
        ;;
      --json) JSON_OUTPUT=true; shift ;;
      --no-port-check) PORT_CHECK=false; shift ;;
      --strict) STRICT=true; shift ;;
      --version) echo "$SCRIPT_VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      -*) fail "unknown option: $1" ;;
      *)
        [ -z "$DOMAIN" ] || fail "unexpected argument: $1"
        DOMAIN="$1"
        shift
        ;;
    esac
  done
}

check_port_25() {
  local host="$1"
  if timeout 5 bash -c "exec 3<>/dev/tcp/${host}/25" 2>/dev/null; then
    echo "open"
  else
    echo "blocked"
  fi
}

collect_mx() {
  if [ -n "$MX_OVERRIDE" ]; then
    local item
    IFS=',' read -r -a override_hosts <<< "$MX_OVERRIDE"
    for item in "${override_hosts[@]}"; do
      item="${item//[[:space:]]/}"
      [ -n "$item" ] || continue
      printf '0\t%s\n' "$item"
    done
    return 0
  fi
  dig +short MX "$DOMAIN" | sort -n | awk '{print $1 "\t" $2}'
}

main() {
  parse_args "$@"
  [ -n "$DOMAIN" ] || { usage >&2; exit 1; }
  is_domain "$DOMAIN" || fail "invalid domain: $DOMAIN"
  is_hostname "$SELECTOR.$DOMAIN" || fail "invalid DKIM selector: $SELECTOR"
  require_command dig
  [ "$PORT_CHECK" = false ] || require_command timeout
  [ "$JSON_OUTPUT" = false ] || require_command jq

  local warnings=()
  local mx_rows=()
  local mx_json_rows=()
  local mx_count=0

  while IFS=$'\t' read -r priority host; do
    [ -n "${host:-}" ] || continue
    host=$(printf '%s' "$host" | strip_dot)
    is_hostname "$host" || {
      warnings+=("MX host is not a valid hostname: $host")
      continue
    }

    local ipv4 ipv6 ptr port25
    ipv4=$(dig +short A "$host" | grep -E '^[0-9.]+$' | first_line || true)
    ipv6=$(dig +short AAAA "$host" | grep -E '^[0-9A-Fa-f:]+$' | first_line || true)
    ptr=""
    if [ -n "$ipv4" ]; then
      ptr=$(dig +short -x "$ipv4" | first_line | strip_dot || true)
    elif [ -n "$ipv6" ]; then
      ptr=$(dig +short -x "$ipv6" | first_line | strip_dot || true)
    fi
    if [ "$PORT_CHECK" = true ]; then
      port25=$(check_port_25 "$host")
    else
      port25="skipped"
    fi

    mx_count=$((mx_count + 1))
    mx_rows+=("${priority:-0}|$host|${ipv4:-none}|${ipv6:-none}|${ptr:-none}|$port25")
    if [ "$JSON_OUTPUT" = true ]; then
      mx_json_rows+=("$(jq -nc \
        --argjson priority "${priority:-0}" \
        --arg host "$host" \
        --arg ipv4 "$ipv4" \
        --arg ipv6 "$ipv6" \
        --arg ptr "$ptr" \
        --arg port25 "$port25" \
        '{priority: $priority, host: $host, ipv4: $ipv4, ipv6: $ipv6, ptr: $ptr, port25: $port25}')")
    fi
  done < <(collect_mx)

  if [ "$mx_count" -eq 0 ]; then
    warnings+=("No MX records found for $DOMAIN")
  fi
  if [ "$PORT_CHECK" = true ] && printf '%s\n' "${mx_rows[@]}" | grep -q '|blocked$'; then
    warnings+=("At least one MX host did not accept TCP/25 from this network")
  fi

  local spf_record dmarc_record dkim_record dmarc_policy
  spf_record=$(dig +short TXT "$DOMAIN" | tr -d '"' | grep -i '^v=spf1' | first_line || true)
  dmarc_record=$(dig +short TXT "_dmarc.$DOMAIN" | tr -d '"' | grep -i '^v=DMARC1' | first_line || true)
  dkim_record=$(dig +short TXT "$SELECTOR._domainkey.$DOMAIN" | tr -d '"' | grep -i 'v=DKIM1' | first_line || true)
  dmarc_policy=$(parse_dmarc_policy "$dmarc_record")

  [ -n "$spf_record" ] || warnings+=("No SPF record found for $DOMAIN")
  [ -n "$dmarc_record" ] || warnings+=("No DMARC record found for _dmarc.$DOMAIN")
  [ -n "$dkim_record" ] || warnings+=("No DKIM record found for $SELECTOR._domainkey.$DOMAIN")

  if [ "$JSON_OUTPUT" = true ]; then
    local mx_json warnings_json
    if [ "${#mx_json_rows[@]}" -gt 0 ]; then
      mx_json=$(printf '%s\n' "${mx_json_rows[@]}" | jq -s .)
    else
      mx_json='[]'
    fi
    if [ "${#warnings[@]}" -gt 0 ]; then
      warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
    else
      warnings_json='[]'
    fi
    jq -n \
      --arg domain "$DOMAIN" \
      --argjson mx "$mx_json" \
      --arg spf "$spf_record" \
      --arg dmarc "$dmarc_record" \
      --arg dmarcPolicy "$dmarc_policy" \
      --arg dkimSelector "$SELECTOR" \
      --arg dkim "$dkim_record" \
      --argjson warnings "$warnings_json" \
      '{domain: $domain, mx: $mx, spf: $spf, dmarc: $dmarc, dmarcPolicy: $dmarcPolicy, dkimSelector: $dkimSelector, dkim: $dkim, warnings: $warnings}'
  else
    echo "Mail DNS check: $DOMAIN"
    echo "--------------------------------------------------------------------------"
    if [ "$mx_count" -eq 0 ]; then
      echo "MX: none"
    else
      printf '%-4s %-32s %-16s %-8s %s\n' 'PRIO' 'HOST' 'IPv4' 'PORT25' 'PTR'
      local row priority host ipv4 ipv6 ptr port25
      for row in "${mx_rows[@]}"; do
        IFS='|' read -r priority host ipv4 ipv6 ptr port25 <<< "$row"
        printf '%-4s %-32s %-16s %-8s %s\n' "$priority" "$host" "$ipv4" "$port25" "$ptr"
      done
    fi
    echo "--------------------------------------------------------------------------"
    [ -n "$spf_record" ] && echo "SPF:   $spf_record" || echo "SPF:   missing"
    [ -n "$dmarc_record" ] && echo "DMARC: ${dmarc_policy:-present} — $dmarc_record" || echo "DMARC: missing"
    [ -n "$dkim_record" ] && echo "DKIM:  selector $SELECTOR present" || echo "DKIM:  selector $SELECTOR missing"
    if [ "${#warnings[@]}" -gt 0 ]; then
      echo "--------------------------------------------------------------------------"
      echo "Warnings:"
      printf '  - %s\n' "${warnings[@]}"
    fi
  fi

  if [ "$STRICT" = true ] && [ "${#warnings[@]}" -gt 0 ]; then
    exit 1
  fi
}

if [ "${1:-}" = "--self-test" ]; then
  is_domain 'example.com' || { echo 'self-test failed: valid domain rejected' >&2; exit 1; }
  is_domain 'not-a-domain' && { echo 'self-test failed: invalid domain accepted' >&2; exit 1; } || true
  is_hostname 'mail.example.com' || { echo 'self-test failed: valid hostname rejected' >&2; exit 1; }
  [ "$(parse_dmarc_policy 'v=DMARC1; p=reject; rua=mailto:dmarc@example.com')" = 'reject' ] || {
    echo 'self-test failed: DMARC policy parser' >&2
    exit 1
  }
  [ "$(printf 'mail.example.com.\n' | strip_dot)" = 'mail.example.com' ] || {
    echo 'self-test failed: trailing dot stripper' >&2
    exit 1
  }
  echo 'self-test OK'
  exit 0
fi

main "$@"
