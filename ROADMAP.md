# Roadmap

Current release: [v0.2.1](https://github.com/depavel/netcup-toolbox/releases/tag/v0.2.1).

## Current tools
- `tools/netcup-ping.sh`: ICMP latency test for the 5 official looking glass nodes; iputils and BusyBox parsing.
- `tools/netcup-init.sh`: bootstrap with TCP BBR, sysctl tuning, UFW, optional Docker, dry-run, and custom SSH port.
- `tools/netcup-vlan.sh`: Netplan / Debian generator for Cloud vLAN; MTU 1500 only.
- `tools/netcup-dns-sync.sh`: DDNS updater for one existing A record via the Netcup CCP JSON API.
- `tools/netcup-calc.sh`: terminal VAT and billing calculator for all active plans; ceiling rounding.
- `data/servers.json`: active-plan catalog generated from the site catalog.
- `data/benchmarks.json`: aggregated YABS extract derived from `data/servers.json`.

## Planned utilities
- `tools/netcup-snapshot.sh`: snapshot management via the SCP API.
- `tools/netcup-exporter.sh`: Prometheus exporter for latency and CPU steal monitoring.

## Quality gates
- CI runs `bash -n`, shellcheck, parser/calculator self-tests, JSON validation, and checksum verification.
- Releases are tagged and include `CHECKSUMS.txt`.
