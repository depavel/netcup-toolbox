# Authentication

`netcup-toolbox` uses two independent Netcup APIs. Do not mix their credentials.

## CCP API (domains and DNS)

Used by `tools/netcup-dns-sync.sh` and future full-zone DNS tools.

- Endpoint: `https://ccp.netcup.net/run/webservice/servers/endpoint.php?JSON`
- Credentials: customer number, API key, and API password from the CCP under
  **Master Data → API**.
- The script reads `NETCUP_CUSTOMER_NUMBER`, `NETCUP_API_KEY`,
  `NETCUP_API_PASSWORD`, `NETCUP_DOMAIN_NAME`, and `NETCUP_HOST_NAME` from the
  environment. It never writes them to disk or logs.
- Domain registration and contact changes are reseller-only and are **not**
  covered by this repository.

## SCP REST API (servers, snapshots, rDNS, firewall, failover)

Used by snapshot, reverse-DNS, firewall, failover, and metrics tools.

- Base URL: `https://www.servercontrolpanel.de/scp-core/api/v1`
- Authentication: OAuth 2.0 / OpenID Connect device flow against the `scp`
  client. There is **no static API key**.
- Request a device code:

  ```bash
  curl -sS -X POST \
    'https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect/auth/device' \
    -d 'client_id=scp' -d 'scope=offline_access openid'
  ```

- Open `verification_uri_complete` in a browser and approve the grant.
- Exchange the device code:

  ```bash
  curl -sS -X POST \
    'https://www.servercontrolpanel.de/realms/scp/protocol/openid-connect/token' \
    -d 'grant_type=urn:ietf:params:oauth:grant-type:device_code' \
    -d 'device_code=<device-code>' -d 'client_id=scp'
  ```

- Store only the **refresh token**. It remains valid while it is used at least
  once every 30 days; rotate it if it leaks.
- Add the machine's IP address or CIDR range to **SCP → API → REST API
  Security**. Without the allowlist, requests fail before authentication.
- The access token is short-lived (about five minutes). Exchange the refresh
  token for a new access token on every run.

### Token handling rules

- Prefer `NETCUP_REFRESH_TOKEN` or a file under
  `${XDG_CONFIG_HOME:-$HOME/.config}/netcup-toolbox/` with mode `600`.
- Never commit tokens, customer numbers, API passwords, private keys, or server
  addresses to the repository.
- Never print tokens in CI logs. Use repository secrets in GitHub Actions.
- A token is a password equivalent. Revoke it in the SCP account console if it
  was exposed.

## Official documentation

- CCP API: <https://www.netcup.com/en/helpcenter/documentation/domain/our-api>
- SCP REST API: <https://www.netcup.com/en/helpcenter/documentation/servercontrolpanel/api>
- SCP REST API overview: <https://www.netcup.com/en/helpcenter/documentation/server/rest-api>
