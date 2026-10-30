#!/usr/bin/env bash
# ==============================================================================
# Netcup Dynamic DNS (DDNS) Updater
# Updates an A / AAAA record using the official Netcup CCP DNS API.
# Requirements: curl, jq
# Repository: https://github.com/depavel/netcup-toolbox
# ==============================================================================

set -euo pipefail

# Configuration parameters (can be passed via environment variables)
CUSTOMER_NUMBER="${NETCUP_CUSTOMER_NUMBER:-}"
API_KEY="${NETCUP_API_KEY:-}"
API_PASSWORD="${NETCUP_API_PASSWORD:-}"
DOMAIN_NAME="${NETCUP_DOMAIN_NAME:-}"
HOST_NAME="${NETCUP_HOST_NAME:-@}"
API_URL="https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON"

if [ -z "$CUSTOMER_NUMBER" ] || [ -z "$API_KEY" ] || [ -z "$API_PASSWORD" ] || [ -z "$DOMAIN_NAME" ]; then
  echo "Usage:" >&2
  echo "  NETCUP_CUSTOMER_NUMBER=123456 \" >&2
  echo "  NETCUP_API_KEY=xxx \" >&2
  echo "  NETCUP_API_PASSWORD=yyy \" >&2
  echo "  NETCUP_DOMAIN_NAME=example.com \" >&2
  echo "  NETCUP_HOST_NAME=subdomain \" >&2
  echo "  ./netcup-dns-sync.sh" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || { echo "Error: 'jq' is required but not installed." >&2; exit 1; }

echo "[Netcup DNS] 1. Detecting public IPv4 address..."
CURRENT_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://ifconfig.co || curl -s4 https://icanhazip.com)

if [ -z "$CURRENT_IP" ]; then
  echo "Error: Failed to determine public IPv4." >&2
  exit 1
fi
echo "[Netcup DNS] Public IP: $CURRENT_IP"

echo "[Netcup DNS] 2. Logging in to Netcup CCP API..."
LOGIN_PAYLOAD=$(jq -n \
  --arg action "login" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apipassword "$API_PASSWORD" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apipassword: $apipassword}}')

LOGIN_RES=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$LOGIN_PAYLOAD")
STATUS=$(echo "$LOGIN_RES" | jq -r '.status // empty')

if [ "$STATUS" != "SUCCESS" ]; then
  echo "Error: Login failed. Response: $LOGIN_RES" >&2
  exit 1
fi

SESSION_ID=$(echo "$LOGIN_RES" | jq -r '.responsedata.apisessionid')

cleanup() {
  echo "[Netcup DNS] Logging out session..."
  LOGOUT_PAYLOAD=$(jq -n \
    --arg action "logout" \
    --arg customernumber "$CUSTOMER_NUMBER" \
    --arg apikey "$API_KEY" \
    --arg apisessionid "$SESSION_ID" \
    '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid}}')
  curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$LOGOUT_PAYLOAD" > /dev/null || true
}
trap cleanup EXIT

echo "[Netcup DNS] 3. Fetching existing DNS records for $DOMAIN_NAME..."
INFO_PAYLOAD=$(jq -n \
  --arg action "infoDnsRecords" \
  --arg customernumber "$CUSTOMER_NUMBER" \
  --arg apikey "$API_KEY" \
  --arg apisessionid "$SESSION_ID" \
  --arg domainname "$DOMAIN_NAME" \
  '{action: $action, param: {customernumber: $customernumber, apikey: $apikey, apisessionid: $apisessionid, domainname: $domainname}}')

INFO_RES=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$INFO_PAYLOAD")
TARGET_RECORD=$(echo "$INFO_RES" | jq --arg host "$HOST_NAME" '.responsedata.dnsrecords[] | select(.hostname == $host and .type == "A")')

if [ -z "$TARGET_RECORD" ]; then
  echo "Error: Could not find an existing 'A' record with hostname '$HOST_NAME' for '$DOMAIN_NAME'." >&2
  exit 1
fi

RECORD_ID=$(echo "$TARGET_RECORD" | jq -r '.id')
EXISTING_DEST=$(echo "$TARGET_RECORD" | jq -r '.destination')

if [ "$EXISTING_DEST" = "$CURRENT_IP" ]; then
  echo "[Netcup DNS] Record '$HOST_NAME.$DOMAIN_NAME' already points to $CURRENT_IP. No change needed."
  exit 0
fi

echo "[Netcup DNS] 4. Updating record $HOST_NAME.$DOMAIN_NAME from $EXISTING_DEST to $CURRENT_IP..."
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

UPDATE_RES=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json" -d "$UPDATE_PAYLOAD")
UPDATE_STATUS=$(echo "$UPDATE_RES" | jq -r '.status // empty')

if [ "$UPDATE_STATUS" != "SUCCESS" ]; then
  echo "Error: DNS update failed. Response: $UPDATE_RES" >&2
  exit 1
fi

echo "[Netcup DNS] Success: $HOST_NAME.$DOMAIN_NAME updated to $CURRENT_IP!"
