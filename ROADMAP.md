# Roadmap

Current release: [v0.4.0](https://github.com/depavel/netcup-toolbox/releases/tag/v0.4.0).

## Current tools
- `tools/netcup-ping.sh`: ICMP latency test for the 5 official Netcup test IPs; iputils and BusyBox parsing.
- `tools/netcup-init.sh`: bootstrap with TCP BBR, sysctl tuning, UFW, optional Docker, dry-run, and custom SSH port.
- `tools/netcup-vlan.sh`: Netplan / Debian generator for Cloud vLAN; MTU 1500 only.
- `tools/netcup-dns-sync.sh`: DDNS updater for one existing A record via the Netcup CCP JSON API.
- `tools/netcup-rdns.sh`: IPv4/IPv6 PTR manager via the SCP REST API and OAuth2 device flow.
- `tools/netcup-snapshot.sh`: SCP snapshot list/create/delete/restore/export with guarded destructive actions.
- `tools/netcup-mail-check.sh`: MX, SPF, DMARC, DKIM, PTR, and port 25 checks.
- `tools/netcup-exporter.sh`: Prometheus textfile metrics for host health and Netcup latency.
- `tools/netcup-calc.sh`: terminal VAT and billing calculator for all active plans; ceiling rounding.
- `data/servers.json`: active-plan catalog generated from the site catalog, including availability.
- `data/benchmarks.json`: aggregated YABS extract derived from `data/servers.json`.
- `data/datacenters.json`: official test IPs and region metadata.
- `data/meta.json`: schema version, generation timestamp, and dataset counts.

## v0.3.0 (planned)
- [x] `tools/netcup-rdns.sh`: get/set/delete PTR records for IPv4 and IPv6 via the SCP REST API; verify forward/backward DNS for mail.
- [x] `tools/netcup-snapshot.sh`: snapshot list/create/delete/restore/export via the SCP REST API (OAuth2 device flow), with a dry-run and destructive-action guard.
- [x] `tools/netcup-ping.sh --json`: machine-readable latency output for automation.
- [x] `tools/netcup-calc.sh --json`: machine-readable VAT output and plan filtering.
- [ ] Release archive (`netcup-toolbox-<tag>.tar.gz`) and checksum attached to every GitHub release.
- [ ] Issue/PR templates, Dependabot, release workflow, and a Debian/Ubuntu/Alpine CI matrix.

## v0.4.0 (planned)
- [x] `tools/netcup-mail-check.sh`: MX, SPF, DKIM, DMARC, PTR, and port 25 checks.
- [ ] `tools/netcup-dns.sh`: full-zone export, diff, and restore via the CCP API.
- [x] `tools/netcup-exporter.sh`: Prometheus textfile metrics for host health, BBR, CPU steal, and Netcup latency.
- [ ] `tools/netcup-vlan.sh` and `tools/netcup-init.sh` hardening (network-stack detection, rollback, SSH keys, fail2ban).
- [ ] JSON Schema for `data/*.json` and a scheduled link check.

## Later
- [ ] `tools/netcup-ipv6.sh`, `tools/netcup-doctor.sh`, `tools/netcup-bench.sh`.
- [ ] `tools/netcup-failover.sh`, `tools/netcup-firewall.sh`, `tools/netcup-domains.sh`.

## Quality gates
- CI runs `bash -n`, shellcheck, parser/calculator self-tests, JSON validation, and checksum verification.
- Releases are tagged and include `CHECKSUMS.txt`, a source archive, and the archive checksum.
- Every script supports `--help`; mutating scripts support `--dry-run` and an explicit confirmation flag.
