#!/usr/bin/env bash
# Netcup SCP snapshot manager.
# Uses the SCP REST API with OAuth2 device flow.
# Repository: https://github.com/depavel/netcup-toolbox
# Web tools: https://netcupgutscheine.com/en/tools
#
# Requirements: bash 4+, curl, jq.
# Destructive actions (delete, restore) require --yes. Revert/restore reboots
# the server and discards data written after the snapshot.

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
WAIT=false
WAIT_TIMEOUT=600
ONLINE_SNAPSHOT=false
DESCRIPTION=""
DISK_NAME=""
COMMAND=""
SERVER_ID=""
SNAPSHOT_NAME=""

usage() {
  cat <<'EOF'
Usage: netcup-snapshot.sh <command> [options]

Commands:
  auth login                  Run the OAuth2 device flow and store a refresh token
  auth status                 Show whether a refresh token is available
  auth logout                 Remove the stored refresh token
  servers                     List SCP servers with id, name, state, and snapshot count
  list <serverId>             List snapshots of a server
  get <serverId> <name>       Show one snapshot
  create <serverId> <name>    Create a snapshot
  dryrun <serverId>           Check whether creating a snapshot is possible
  delete <serverId> <name>    Delete a snapshot (requires --yes)
  restore <serverId> <name>   Revert to a snapshot and reboot (requires --yes)
  export <serverId> <name>    Export a snapshot (server must be shut off)

Options:
  --description <text>        Snapshot description for `create`
  --disk <name>               Disk name for an offline snapshot
  --online                    Request an online snapshot for `create`
  --wait                      Wait for the async task to finish
  --wait-timeout <seconds>    Task polling timeout (default: 600)
  --token-file <path>         Refresh-token file (default: ~/.config/netcup-toolbox/scp-token)
  --json                      Print raw JSON
  --dry-run                   Print the request without changing anything
  --yes, -y                   Confirm a destructive operation
  --no-save                   Do not store the refresh token after `auth login`
  --version                   Print the script version
  -h, --help                  Show this help

Security:
  A refresh token is password-equivalent. Never commit it, paste it into an
  issue, or print it in a CI log. Add your IP to SCP -> API -> REST API Security.

Examples:
  netcup-snapshot.sh servers
  netcup-snapshot.sh create 123456 pre-upgrade --description "before Debian 13" --wait
  netcup-snapshot.sh restore 123456 pre-upgrade --yes --wait
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "'$1' is required"
}

urlencode() {
  jq -rn --arg value "$1" '$value | @uri'
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      auth)
        [ "$#" -ge 2 ] || fail "auth requires login, status, or logout"
        COMMAND="auth:$2"
        shift 2
        ;;
      servers|list|get|create|dryrun|delete|restore|export)
        COMMAND="$1"
        shift
        if [ "$COMMAND" = "servers" ]; then
          continue
        fi
        [ "$#" -ge 1 ] || fail "$COMMAND requires a server id"
        SERVER_ID="$1"
        shift
        if [ "$COMMAND" != "dryrun" ]; then
          [ "$#" -ge 1 ] || fail "$COMMAND requires a snapshot name"
          SNAPSHOT_NAME="$1"
          shift
        fi
        ;;
      --description)
        [ "$#" -ge 2 ] || fail "--description requires a value"
        DESCRIPTION="$2"
        shift 2
        ;;
      --disk)
        [ "$#" -ge 2 ] || fail "--disk requires a value"
        DISK_NAME="$2"
        shift 2
        ;;
      --wait-timeout)
        [ "$#" -ge 2 ] || fail "--wait-timeout requires a value"
        WAIT_TIMEOUT="$2"
        shift 2
        ;;
      --token-file)
        [ "$#" -ge 2 ] || fail "--token-file requires a path"
        TOKEN_FILE="$2"
        shift 2
        ;;
      --online) ONLINE_SNAPSHOT=true; shift ;;
      --wait) WAIT=true; shift ;;
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

validate_server_id() {
  [[ "$SERVER_ID" =~ ^[0-9]+$ ]] && [ "$SERVER_ID" -gt 0 ] || fail "server id must be a positive integer"
}

validate_snapshot_name() {
  [ -n "$SNAPSHOT_NAME" ] || fail "snapshot name must not be empty"
  [ "${#SNAPSHOT_NAME}" -le 255 ] || fail "snapshot name must be 255 characters or fewer"
  [[ "$SNAPSHOT_NAME" != */* ]] || fail "snapshot name must not contain '/'"
}

validate_wait_timeout() {
  [[ "$WAIT_TIMEOUT" =~ ^[0-9]+$ ]] && [ "$WAIT_TIMEOUT" -gt 0 ] || fail "--wait-timeout must be a positive integer"
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

print_result() {
  local json="$1" text="$2"
  if [ "$JSON_OUTPUT" = true ]; then
    printf '%s\n' "$json"
  else
    printf '%s\n' "$text"
  fi
}

task_uuid() {
  printf '%s' "$1" | jq -r '.uuid // empty'
}

wait_task() {
  local uuid="$1" deadline state response
  [ -n "$uuid" ] || fail "task response did not contain a uuid"
  deadline=$((SECONDS + WAIT_TIMEOUT))
  echo "Waiting for task $uuid (timeout ${WAIT_TIMEOUT}s)..." >&2

  while [ "$SECONDS" -lt "$deadline" ]; do
    response=$(api_request GET "/tasks/$uuid")
    state=$(printf '%s' "$response" | jq -r '.state // empty')
    case "$state" in
      FINISHED) echo "Task $uuid finished." >&2; return 0 ;;
      ERROR|CANCELED|ROLLBACK)
        fail "task $uuid ended with state $state: $(printf '%s' "$response" | jq -r '.message // empty')"
        ;;
      *) sleep 5 ;;
    esac
  done
  fail "task $uuid did not finish within ${WAIT_TIMEOUT}s"
}

cmd_servers() {
  local response
  response=$(api_request GET '/servers')
  if [ "$JSON_OUTPUT" = true ]; then
    printf '%s\n' "$response"
    return 0
  fi
  printf '%-10s %-24s %-10s %-10s %s\n' 'ID' 'NAME' 'STATE' 'SNAPSHOTS' 'HOSTNAME'
  printf '%s\n' "$response" | jq -r '.[] | [.id, .name, (.serverLiveInfo.state // "UNKNOWN"), (.snapshotCount // 0), (.hostname // "")] | @tsv' |
    while IFS=$'\t' read -r id name state snapshots hostname; do
      printf '%-10s %-24s %-10s %-10s %s\n' "$id" "$name" "$state" "$snapshots" "$hostname"
    done
}

cmd_list() {
  local response
  validate_server_id
  response=$(api_request GET "/servers/$SERVER_ID/snapshots")
  if [ "$JSON_OUTPUT" = true ]; then
    printf '%s\n' "$response"
    return 0
  fi
  printf '%-32s %-20s %-12s %-8s %s\n' 'NAME' 'CREATED' 'STATE' 'ONLINE' 'EXPORTED'
  printf '%s\n' "$response" | jq -r '.[] | [.name, (.creationTime // ""), (.state // ""), (.online | tostring), (.exported | tostring)] | @tsv' |
    while IFS=$'\t' read -r name created state online exported; do
      printf '%-32s %-20s %-12s %-8s %s\n' "$name" "$created" "$state" "$online" "$exported"
    done
}

cmd_get() {
  local response
  validate_server_id
  validate_snapshot_name
  response=$(api_request GET "/servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")")
  print_result "$response" "$(printf '%s' "$response" | jq -r '"\(.name)  \(.state)  created=\(.creationTime // "?")  online=\(.online)  exported=\(.exported)"')"
}

cmd_create() {
  local payload response uuid
  validate_server_id
  validate_snapshot_name
  payload=$(jq -nc \
    --arg name "$SNAPSHOT_NAME" \
    --arg description "$DESCRIPTION" \
    --arg disk "$DISK_NAME" \
    --argjson online "$ONLINE_SNAPSHOT" \
    '$online as $o | {name: $name, onlineSnapshot: $o} +
      (if $description == "" then {} else {description: $description} end) +
      (if $disk == "" then {} else {diskName: $disk} end)')

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] POST /servers/$SERVER_ID/snapshots $payload"
    return 0
  fi

  response=$(api_request POST "/servers/$SERVER_ID/snapshots" "$payload")
  uuid=$(task_uuid "$response")
  if [ "$WAIT" = true ]; then
    wait_task "$uuid"
  fi
  print_result "$response" "Snapshot creation started: $SNAPSHOT_NAME (server $SERVER_ID, task ${uuid:-unknown})"
}

cmd_dryrun() {
  local response payload
  validate_server_id
  payload=$(jq -nc \
    --arg disk "$DISK_NAME" \
    --argjson online "$ONLINE_SNAPSHOT" \
    '{onlineSnapshot: $online} + (if $disk == "" then {} else {diskName: $disk} end)')
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] POST /servers/$SERVER_ID/snapshots:dryrun $payload"
    return 0
  fi
  response=$(api_request POST "/servers/$SERVER_ID/snapshots:dryrun" "$payload")
  print_result "$response" "$(printf '%s' "$response" | jq -r 'if length == 0 then "Snapshot creation is possible." else "Snapshot creation is not possible: " + (map(.code + ": " + (.message // "")) | join("; ")) end')"
}

cmd_delete() {
  local response uuid
  validate_server_id
  validate_snapshot_name

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] DELETE /servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")"
    return 0
  fi
  [ "$ASSUME_YES" = true ] || fail "delete is destructive; pass --yes to confirm"

  response=$(api_request DELETE "/servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")")
  uuid=$(task_uuid "$response")
  if [ "$WAIT" = true ]; then
    wait_task "$uuid"
  fi
  print_result "$response" "Snapshot deletion started: $SNAPSHOT_NAME (server $SERVER_ID, task ${uuid:-unknown})"
}

cmd_restore() {
  local response uuid
  validate_server_id
  validate_snapshot_name

  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] POST /servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")/revert"
    return 0
  fi
  [ "$ASSUME_YES" = true ] || fail "restore is destructive and reboots the server; pass --yes to confirm"

  response=$(api_request POST "/servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")/revert")
  uuid=$(task_uuid "$response")
  if [ "$WAIT" = true ]; then
    wait_task "$uuid"
  fi
  print_result "$response" "Snapshot restore started: $SNAPSHOT_NAME (server $SERVER_ID, task ${uuid:-unknown})"
}

cmd_export() {
  local response uuid
  validate_server_id
  validate_snapshot_name
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] POST /servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")/export"
    return 0
  fi

  response=$(api_request POST "/servers/$SERVER_ID/snapshots/$(urlencode "$SNAPSHOT_NAME")/export")
  uuid=$(task_uuid "$response")
  if [ "$WAIT" = true ]; then
    wait_task "$uuid"
  fi
  print_result "$response" "Snapshot export started: $SNAPSHOT_NAME (server $SERVER_ID, task ${uuid:-unknown}). The server must be shut off; use the SCP UI or API to download the result."
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

main() {
  require_command curl
  require_command jq
  parse_args "$@"
  [ -n "$COMMAND" ] || { usage >&2; exit 1; }
  validate_wait_timeout

  case "$COMMAND" in
    auth:login) device_login ;;
    auth:status) cmd_auth_status ;;
    auth:logout) cmd_auth_logout ;;
    servers) cmd_servers ;;
    list) cmd_list ;;
    get) cmd_get ;;
    create) cmd_create ;;
    dryrun) cmd_dryrun ;;
    delete) cmd_delete ;;
    restore) cmd_restore ;;
    export) cmd_export ;;
    *) fail "unknown command: $COMMAND" ;;
  esac
}

if [ "${1:-}" = "--self-test" ]; then
  require_command jq
  SERVER_ID=123
  validate_server_id
  SNAPSHOT_NAME='pre-upgrade'
  validate_snapshot_name
  SERVER_ID=0
  ( validate_server_id ) 2>/dev/null && { echo 'self-test failed: zero server id accepted' >&2; exit 1; } || true
  SNAPSHOT_NAME='bad/name'
  ( validate_snapshot_name ) 2>/dev/null && { echo 'self-test failed: slash accepted in name' >&2; exit 1; } || true
  WAIT_TIMEOUT=600
  validate_wait_timeout
  encoded=$(urlencode 'pre upgrade')
  [ "$encoded" = 'pre%20upgrade' ] || { echo 'self-test failed: URL encoding' >&2; exit 1; }
  echo 'self-test OK'
  exit 0
fi

main "$@"
