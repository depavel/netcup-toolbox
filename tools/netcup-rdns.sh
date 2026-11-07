#!/usr/bin/env bash
# Netcup SCP reverse DNS (PTR) manager.
# Uses the SCP REST API with OAuth2 device flow.
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools
#
# Requirements: bash 4+, curl, jq.
# The refresh token is stored under ~/.config/netcup-toolbox/scp-token (mode 600)
# unless NETCUP_SCP_TOKEN_FILE or --token-file points elsewhere.

set -euo pipefail
umask 077
LC_ALL=C
export LC_ALL

SCRIPT_VERSION="0.3.0"
OIDC_BASE="https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect"
API_BASE="https://www.servercontrolpanel.de/scp-core/api/v1"
DEFAULT_TOKEN_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/netcup-toolbox/scp-token"

TOKEN_FILE="${NETCUP_SCP_TOKEN_FILE:-$DEFAULT_TOKEN_FILE}"
DRY_RUN=false
JSON_OUTPUT=false
ASSUME_YES=false
NO_SAVE=false
COMMAND=""
IP=""
RDNS=""

usage() {
  cat <<'EOF'
Usage: netcup-rdns.sh <command> [options]

Commands:
  auth login             Run the OAuth2 device flow and store a refresh token
  auth status            Show whether a refresh token is available
  auth logout            Remove the stored refresh token
  get <ip>               Show the current PTR record for an IPv4 or IPv6 address
  set <ip> <hostname>    Create or replace the PTR record
  delete <ip>            Delete the PTR record (requires --yes)

Options:
  --token-file <path>    Refresh-token file (default: ~/.config/netcup-toolbox/scp-token)
  --json                 Print the raw API response
  --dry-run              Print the request without changing anything
  --yes, -y              Confirm a destructive operation
  --no-save              Do not store the refresh token after `auth login`
  --version              Print the script version
  -h, --help             Show this help

Security:
  A refresh token is password-equivalent. Never commit it, paste it into an
  issue, or print it in a CI log. Add your IP to SCP -> API -> REST API Security.

Examples:
  netcup-rdns.sh auth login
  netcup-rdns.sh get 203.0.113.10
  netcup-rdns.sh set 203.0.113.10 mail.example.com
  netcup-rdns.sh delete 203.0.113.10 --yes
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "'$1' is required"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      auth)
        [ "$#" -ge 2 ] || fail "auth requires login, status, or logout"
        COMMAND="auth:$2"
        shift 2
        ;;
      get|set|delete)
        COMMAND="$1"
        shift
        [ "$#" -ge 1 ] || fail "$COMMAND requires an IP address"
        IP="$1"
        shift
        if [ "$COMMAND" = "set" ]; then
          [ "$#" -ge 1 ] || fail "set requires a hostname"
          RDNS="$1"
          shift
        fi
        ;;
      --token-file)
        [ "$#" -ge 2 ] || fail "--token-file requires a path"
        TOKEN_FILE="$2"
        shift 2
        ;;
      --json) JSON_OUTPUT=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      --yes|-y) ASSUME_YES=true; shift ;;
      --no-save) NO_SAVE=true; shift ;;
      --version) echo "$SCRIPT_VERSION"; exit 0 ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option or command: $1" ;;
    esac
  done
}

is_ipv4() {
  local ip="$1" octet octets
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    [ "$((10#$octet))" -le 255 ] || return 1
  done
}

is_ipv6() {
  local ip="$1"
  [[ "$ip" == *:* ]] || return 1
  [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
  [ "${#ip}" -le 45 ] || return 1
  [[ "$ip" == *::* ]] || [[ "$ip" =~ ^([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}$ ]]
}

is_hostname() {
  local host="$1"
  [ "${#host}" -le 253 ] || return 1
  [[ "$host" == *.* ]] || return 1
  [[ "$host" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]
}

validate_ip() {
  is_ipv4 "$1" || is_ipv6 "$1" || fail "invalid IPv4 or IPv6 address: $1"
}

api_family() {
  if is_ipv4 "$1"; then echo "ipv4"; else echo "ipv6"; fi
}

load_refresh_token() {
  if [ -n "${NETCUP_REFRESH_TOKEN:-}" ]; then
    printf '%s' "$NETCUP_REFRESH_TOKEN"
    return 0
  fi
  [ -r "$TOKEN_FILE" ] || fail "no refresh token. Run: $0 auth login"
  tr -d '\r\n' < "$TOKEN_FILE"
}

save_refresh_token() {
  local token="$1" dir
  dir=$(dirname "$TOKEN_FILE")
  mkdir -p "$dir"
  printf '%s\n' "$token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
}

device_login() {
  local device_response verification interval expires deadline response error refresh
  device_response=$(curl -sS --max-time 30 -X POST "$OIDC_BASE/auth/device" \
    --data-urlencode 'client_id=scp' \
    --data-urlencode 'scope=offline_access openid')

  verification=$(printf '%s' "$device_response" | jq -r '.verification_uri_complete // empty')
  interval=$(printf '%s' "$device_response" | jq -r '.interval // 5')
  expires=$(printf '%s' "$device_response" | jq -r '.expires_in // 600')
  [ -n "$verification" ] || fail "device flow did not return a verification URL"

  echo "Open this URL in a browser and approve the SCP login:"
  echo "  $verification"
  echo "Waiting for approval (up to ${expires}s)..."

  deadline=$((SECONDS + expires))
  while [ "$SECONDS" -lt "$deadline" ]; do
    response=$(curl -sS --max-time 30 -X POST "$OIDC_BASE/token" \
      --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:device_code' \
      --data-urlencode "device_code=$(printf '%s' "$device_response" | jq -r '.device_code')" \
      --data-urlencode 'client_id=scp')
    error=$(printf '%s' "$response" | jq -r '.error // empty')

    case "$error" in
      '')
        refresh=$(printf '%s' "$response" | jq -r '.refresh_token // empty')
        [ -n "$refresh" ] || fail "device flow succeeded but returned no refresh token"
        if [ "$NO_SAVE" = true ]; then
          echo "Authenticated. Refresh token was not saved (--no-save)."
        else
          save_refresh_token "$refresh"
          echo "Authenticated. Refresh token saved to $TOKEN_FILE (mode 600)."
        fi
        return 0
        ;;
      authorization_pending)
        sleep "$interval"
        ;;
      slow_down)
        interval=$((interval + 5))
        sleep "$interval"
        ;;
      *)
        fail "device flow failed: $error $(printf '%s' "$response" | jq -r '.error_description // empty')"
        ;;
    esac
  done
  fail "device code expired before approval"
}

access_token() {
  local refresh response token new_refresh
  refresh=$(load_refresh_token)
  response=$(curl -sS --max-time 30 -X POST "$OIDC_BASE/token" \
    --data-urlencode 'grant_type=refresh_token' \
    --data-urlencode 'client_id=scp' \
    --data-urlencode "refresh_token=$refresh")

  token=$(printf '%s' "$response" | jq -r '.access_token // empty')
  [ -n "$token" ] || fail "could not exchange the refresh token: $(printf '%s' "$response" | jq -r '.error_description // .error // "unknown error"')"

  new_refresh=$(printf '%s' "$response" | jq -r '.refresh_token // empty')
  if [ -n "$new_refresh" ] && [ "$new_refresh" != "$refresh" ]; then
    save_refresh_token "$new_refresh"
  fi
  printf '%s' "$token"
}

api_request() {
  local method="$1" path="$2" body="${3:-}" token tmp code
  token=$(access_token)
  tmp=$(mktemp)

  local args=(-sS --max-time 30 -o "$tmp" -w '%{http_code}' -X "$method")
  args+=(-H "Authorization: Bearer $token" -H 'Accept: application/json')
  if [ -n "$body" ]; then
    args+=(-H 'Content-Type: application/json' --data-binary "$body")
  fi
  code=$(curl "${args[@]}" "$API_BASE$path")

  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    local error_body
    error_body=$(cat "$tmp")
    rm -f "$tmp"
    fail "SCP API HTTP $code: $error_body"
  fi
  if [ -s "$tmp" ]; then
    cat "$tmp"
  fi
  rm -f "$tmp"
}

print_json_or_text() {
  local json="$1" text="$2"
  if [ "$JSON_OUTPUT" = true ]; then
    printf '%s\n' "$json"
  else
    printf '%s\n' "$text"
  fi
}

cmd_auth_status() {
  if [ -n "${NETCUP_REFRESH_TOKEN:-}" ]; then
    echo "Refresh token: NETCUP_REFRESH_TOKEN is set."
  elif [ -r "$TOKEN_FILE" ]; then
    echo "Refresh token: $TOKEN_FILE"
  else
    echo "No refresh token. Run: $0 auth login"
    exit 1
  fi
}

cmd_auth_logout() {
  if [ -f "$TOKEN_FILE" ]; then
    rm -f "$TOKEN_FILE"
    echo "Removed $TOKEN_FILE"
  else
    echo "No token file at $TOKEN_FILE"
  fi
}

cmd_get() {
  local family response rdns
  validate_ip "$IP"
  family=$(api_family "$IP")
  response=$(api_request GET "/rdns/$family/$IP")
  rdns=$(printf '%s' "$response" | jq -r '.rdns // empty')
  if [ -z "$rdns" ]; then
    print_json_or_text "$response" "$IP: no PTR record"
  else
    print_json_or_text "$response" "$IP: $rdns"
  fi
}

cmd_set() {
  local family payload response
  validate_ip "$IP"
  is_hostname "$RDNS" || fail "invalid PTR hostname: $RDNS"
  family=$(api_family "$IP")
  payload=$(jq -nc --arg ip "$IP" --arg rdns "$RDNS" '{ip: $ip, rdns: $rdns}')

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] POST /rdns/$family $payload"
    return 0
  fi

  response=$(api_request POST "/rdns/$family" "$payload")
  print_json_or_text "$response" "Updated $IP -> $RDNS"
}

cmd_delete() {
  local family response
  validate_ip "$IP"
  family=$(api_family "$IP")

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] DELETE /rdns/$family/$IP"
    return 0
  fi
  [ "$ASSUME_YES" = true ] || fail "delete is destructive; pass --yes to confirm"

  response=$(api_request DELETE "/rdns/$family/$IP")
  print_json_or_text "$response" "Deleted PTR record for $IP"
}

main() {
  require_command curl
  require_command jq
  parse_args "$@"
  [ -n "$COMMAND" ] || { usage >&2; exit 1; }

  case "$COMMAND" in
    auth:login) device_login ;;
    auth:status) cmd_auth_status ;;
    auth:logout) cmd_auth_logout ;;
    get) cmd_get ;;
    set) cmd_set ;;
    delete) cmd_delete ;;
    *) fail "unknown command: $COMMAND" ;;
  esac
}

if [ "${1:-}" = "--self-test" ]; then
  is_ipv4 '203.0.113.10' || { echo 'self-test failed: valid IPv4 rejected' >&2; exit 1; }
  is_ipv4 '999.0.0.1' && { echo 'self-test failed: invalid IPv4 accepted' >&2; exit 1; } || true
  is_ipv6 '2001:db8::1' || { echo 'self-test failed: compressed IPv6 rejected' >&2; exit 1; }
  is_ipv6 '2001:0db8:0000:0000:0000:0000:0000:0001' || { echo 'self-test failed: full IPv6 rejected' >&2; exit 1; }
  is_ipv6 '2001:db8::zz' && { echo 'self-test failed: invalid IPv6 accepted' >&2; exit 1; } || true
  is_hostname 'mail.example.com' || { echo 'self-test failed: valid hostname rejected' >&2; exit 1; }
  is_hostname 'not-a-hostname' && { echo 'self-test failed: invalid hostname accepted' >&2; exit 1; } || true
  echo 'self-test OK'
  exit 0
fi

main "$@"
