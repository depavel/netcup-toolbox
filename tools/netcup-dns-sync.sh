#!/usr/bin/env bash
# Netcup Dynamic DNS (DDNS) Updater
# Updates an A record via Netcup CCP JSON API.
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools#ddns
# Requirements: curl, jq

set -euo pipefail

CUSTOMER_NUMBER="${NETCUP_CUSTOMER_NUMBER:-}"
API_KEY="${NETCUP_API_KEY:-}"
API_PASSWORD="${NETCUP_API_PASSWORD:-}"
DOMAIN_NAME="${NETCUP_DOMAIN_NAME:-}"
HOST_NAME="${NETCUP_HOST_NAME:-@}"
API_URL="https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

if [ -z "$CUSTOMER_NUMBER" ] || [ -z "$API_KEY" ] || [ -z "$API_PASSWORD" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "Usage:" >&2
  echo "  NETCUP_CUSTOMER_NUMBER=123456" >&2
  echo "  NETCUP_API_KEY=xxx" >&2
  echo "  NETCUP_API_PASSWORD=yyy" >&2
  echo "  NETCUP_DOMAIN_NAME=example.com" >&2
  echo "  NETCUP_HOST_NAME=subdomain" >&2
  echo "  ./netcup-dns-sync.sh" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' required." >&2; exit 1; }

CURRENT_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.co || curl -s4 https://icanhazip.com)

if [ -z "$CURRENT_IP" ]; then
  echo "Error: failed to detect public IPv4." >&2
  exit 1
fi

LOGIN_PAYLOAD=$(jq -n \
  --arg action "login" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apipassword "$API_PASSWORD" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apipassword: $apipassword}}')

LOGIN_RES=$(printf '%s' "$LOGIN_PAYLOAD" | curl -s -X POST "$API_URL" -H "Content-Type: application/json" --data-binary @-)
STATUS=$(echo "$LOGIN_RES" | jq -r '.status // empty')

if [ "$STATUS" != "SUCCESS" ]; then
  echo "Error: login failed: $LOGIN_RES" >&2
  exit 1
fi

SESSION_ID=$(echo "$LOGIN_RES" | jq -r '.responsedata.apisessionid')

cleanup() {
  LOGOUT_PAYLOAD=$(jq -n \
    --arg action "logout" \
    --arg customernumber "$CUSTOMER_NUMBER" \
    --arg apikey "$API_KEY" \
    --arg apisessionid "$SESSION_ID" \
    '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid}}')
  printf '%s' "$LOGOUT_PAYLOAD" | curl -s -X POST "$API_URL" -H "Content-Type: application/json" --data-binary @- > /dev/null || true
}
trap cleanup EXIT

INFO_PAYLOAD=$(jq -n \
  --arg action "infoDnsRecords" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apisessionid "$SESSION_ID" \
  --arg domainname "$DOMAIN_NAME" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid, domainname: $domainname}}')

INFO_RES=$(printf '%s' "$INFO_PAYLOAD" | curl -s -X POST "$API_URL" -H "Content-Type: application/json" --data-binary @-)
TARGET_RECORD=$(echo "$INFO_RES" | jq --arg host "$HOST_NAME" '.responsedata.dnsrecords[] | select(.hostname == $host and .type == "A")')

if [ -z "$TARGET_RECORD" ]; then
  echo "Error: host '$HOST_NAME' record not found for domain '$DOMAIN_NAME'." >&2
  exit 1
fi

RECORD_ID=$(echo "$TARGET_RECORD" | jq -r '.id')
EXISTING_DEST=$(echo "$TARGET_RECORD" | jq -r '.destination')

if [ "$EXISTING_DEST" = "$CURRENT_IP" ]; then
  echo "Record $HOST_NAME.$DOMAIN_NAME already matches $CURRENT_IP. No update required."
  exit 0
fi

UPDATE_PAYLOAD=$(jq -n \
  --arg action "updateDnsRecords" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apisessionid "$SESSION_ID" \
  --arg domainname "$DOMAIN_NAME" \
  --arg id "$RECORD_ID" \
  --arg hostname "$HOST_NAME" \
  --arg destination "$CURRENT_IP" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid, domainname: $domainname, dnsrecords: [{id: $id, hostname: $hostname, type: "A", destination: $destination}]}}')

UPDATE_RES=$(printf '%s' "$UPDATE_PAYLOAD" | curl -s -X POST "$API_URL" -H "Content-Type: application/json" --data-binary @-)
UPDATE_STATUS=$(echo "$UPDATE_RES" | jq -r '.status // empty')

if [ "$UPDATE_STATUS" != "SUCCESS" ]; then
  echo "Error: DNS update failed: $UPDATE_RES" >&2
  exit 1
fi

echo "Updated $HOST_NAME.$DOMAIN_NAME to $CURRENT_IP"
echo "Interactive tools & guides: https://netcupgutscheine.com/en/tools"
