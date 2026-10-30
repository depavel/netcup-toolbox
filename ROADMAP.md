# Roadmap

Planned tools and ongoing work for netcup-toolbox.

## Current tools
- `tools/netcup-ping.sh`: ICMP latency test for the 5 official looking glass nodes.
- `tools/netcup-init.sh`: Initial system bootstrap (TCP BBR, NVMe sysctl, UFW, auto-updates, Docker).
- `tools/netcup-vlan.sh`: Netplan / systemd-networkd generator for Cloud vLAN (internal 2.5 Gbps network).
- `tools/netcup-dns-sync.sh`: Dynamic DNS updater using Netcup CCP JSON API.
- `tools/netcup-calc.sh`: Terminal VAT and billing price calculator for 5 tax regions.
- `data/benchmarks.json`: Raw YABS test logs and Geekbench 6 scores.
- `data/servers.json`: Catalog specifications and plan parameters.

## Planned utilities
- `tools/netcup-snapshot.sh`: Snapshot management via SCP API.
- `tools/netcup-exporter.sh`: Prometheus node exporter for latency and CPU steal monitoring.
