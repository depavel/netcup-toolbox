#!/usr/bin/env bash
# Netcup Dynamic DNS (DDNS) Updater
# Updates exactly one A record via the Netcup CCP JSON API.
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools#ddns
# Requirements: curl, jq, flock (optional, recommended)

set -euo pipefail
umask 077

API_URL="https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

CUSTOMER_NUMBER="${NETCUP_CUSTOMER_NUMBER:-}"
API_KEY="${NETCUP_API_KEY:-}"
API_PASSWORD="${NETCUP_API_PASSWORD:-}"
DOMAIN_NAME="${NETCUP_DOMAIN_NAME:-}"
HOST_NAME="${NETCUP_HOST_NAME:-@}"

usage() {
  cat <<'EOF'
Usage:
  NETCUP_CUSTOMER_NUMBER=123456 \
  NETCUP_API_KEY=xxx \
  NETCUP_API_PASSWORD=yyy \
  NETCUP_DOMAIN_NAME=example.com \
  NETCUP_HOST_NAME=vpn \
  bash netcup-dns-sync.sh

The script updates one existing A record. It refuses to guess when the host
has zero or multiple A records. Credentials are read from the environment and
are never written to disk or printed.
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

is_domain() {
  [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]]
}

is_host() {
  [[ "$1" == "@" || "$1" == "*" || "$1" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]
}

api_call() {
  local payload="$1"
  printf '%s' "$payload" | curl -sS --max-time 20 --retry 2 --retry-delay 2 \
    -X POST "$API_URL" -H "Content-Type: application/json" --data-binary @-
}

if [ -z "$CUSTOMER_NUMBER" ] || [ -z "$API_KEY" ] || [ -z "$API_PASSWORD" ] || [ -z "$DOMAIN_NAME" ]; then
  usage >&2
  exit 1
fi

case "$CUSTOMER_NUMBER" in
  ''|*[!0-9]*) fail "NETCUP_CUSTOMER_NUMBER must contain digits only" ;;
esac
is_domain "$DOMAIN_NAME" || fail "NETCUP_DOMAIN_NAME is not a valid domain: $DOMAIN_NAME"
is_host "$HOST_NAME" || fail "NETCUP_HOST_NAME is not a valid host label: $HOST_NAME"
command -v jq >/dev/null 2>&1 || fail "'jq' is required"

if command -v flock >/dev/null 2>&1; then
  LOCK_FILE="${TMPDIR:-/tmp}/netcup-dns-sync.lock"
  exec 9>"$LOCK_FILE"
  flock -n 9 || fail "another netcup-dns-sync instance is already running"
fi

CURRENT_IP=""
for endpoint in "https://api.ipify.org" "https://icanhazip.com" "https://ifconfig.co"; do
  candidate=$(curl -4 -sS --max-time 10 --retry 1 "$endpoint" 2>/dev/null || true)
  if is_ipv4 "$candidate"; then
    CURRENT_IP="$candidate"
    break
  fi
done
[ -n "$CURRENT_IP" ] || fail "could not detect a valid public IPv4 address"

SESSION_ID=""
cleanup() {
  if [ -n "$SESSION_ID" ]; then
    local logout_payload
    logout_payload=$(jq -n \
      --arg action "logout" \
      --arg customernumber "$CUSTOMER_NUMBER" \
      --arg apikey "$API_KEY" \
      --arg apisessionid "$SESSION_ID" \
      '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid}}')
    api_call "$logout_payload" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

LOGIN_PAYLOAD=$(jq -n \
  --arg action "login" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apipassword "$API_PASSWORD" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apipassword: $apipassword}}')

LOGIN_RES=$(api_call "$LOGIN_PAYLOAD")
LOGIN_STATUS=$(printf '%s' "$LOGIN_RES" | jq -r '.status // empty')
if [ "$LOGIN_STATUS" != "SUCCESS" ]; then
  LOGIN_MESSAGE=$(printf '%s' "$LOGIN_RES" | jq -r '.message // .responsedata // "unknown error"')
  fail "login failed: $LOGIN_MESSAGE"
fi
SESSION_ID=$(printf '%s' "$LOGIN_RES" | jq -r '.responsedata.apisessionid // empty')
[ -n "$SESSION_ID" ] || fail "login succeeded but the API returned no session id"

INFO_PAYLOAD=$(jq -n \
  --arg action "infoDnsRecords" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apisessionid "$SESSION_ID" \
  --arg domainname "$DOMAIN_NAME" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid, domainname: $domainname}}')

INFO_RES=$(api_call "$INFO_PAYLOAD")
INFO_STATUS=$(printf '%s' "$INFO_RES" | jq -r '.status // empty')
if [ "$INFO_STATUS" != "SUCCESS" ]; then
  INFO_MESSAGE=$(printf '%s' "$INFO_RES" | jq -r '.message // .responsedata // "unknown error"')
  fail "infoDnsRecords failed: $INFO_MESSAGE"
fi

RECORDS=$(printf '%s' "$INFO_RES" | jq -c --arg host "$HOST_NAME" \
  '[.responsedata.dnsrecords[] | select(.hostname == $host and .type == "A")]')
RECORD_COUNT=$(printf '%s' "$RECORDS" | jq 'length')

if [ "$RECORD_COUNT" -eq 0 ]; then
  fail "A record '$HOST_NAME.$DOMAIN_NAME' not found"
fi
if [ "$RECORD_COUNT" -gt 1 ]; then
  fail "found $RECORD_COUNT A records for '$HOST_NAME.$DOMAIN_NAME'; refusing to guess which one to update"
fi

TARGET_RECORD=$(printf '%s' "$RECORDS" | jq -c '.[0]')
RECORD_ID=$(printf '%s' "$TARGET_RECORD" | jq -r '.id')
EXISTING_DEST=$(printf '%s' "$TARGET_RECORD" | jq -r '.destination')

if [ "$EXISTING_DEST" = "$CURRENT_IP" ]; then
  echo "Record $HOST_NAME.$DOMAIN_NAME already matches $CURRENT_IP. No update required."
  exit 0
fi

UPDATED_RECORD=$(printf '%s' "$TARGET_RECORD" | jq -c --arg ip "$CURRENT_IP" '.destination = $ip')
UPDATE_PAYLOAD=$(jq -n \
  --arg action "updateDnsRecords" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apisessionid "$SESSION_ID" \
  --arg domainname "$DOMAIN_NAME" \
  --argjson record "$UPDATED_RECORD" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid, domainname: $domainname, dnsrecords: [$record]}}')

UPDATE_RES=$(api_call "$UPDATE_PAYLOAD")
UPDATE_STATUS=$(printf '%s' "$UPDATE_RES" | jq -r '.status // empty')
if [ "$UPDATE_STATUS" != "SUCCESS" ]; then
  UPDATE_MESSAGE=$(printf '%s' "$UPDATE_RES" | jq -r '.message // .responsedata // "unknown error"')
  fail "updateDnsRecords failed: $UPDATE_MESSAGE"
fi

echo "Updated $HOST_NAME.$DOMAIN_NAME to $CURRENT_IP (record id $RECORD_ID)"
echo "Interactive tools & guides: https://netcupgutscheine.com/en/tools"
