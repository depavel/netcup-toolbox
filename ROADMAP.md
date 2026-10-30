# Netcup Toolbox — Open Source Roadmap

The mission of **Netcup Toolbox** is to provide an evergreen, community-driven collection of sysadmin scripts, benchmarks, and automation tools for Netcup Root Servers, VPS, and Cloud infrastructure.

## Available Tools

- [x] **`netcup-ping.sh`**: Datacenter ICMP latency tester for all 5 official Netcup Looking Glass nodes.
- [x] **`netcup-init.sh`**: High-performance bootstrap script (TCP BBR 2.5 Gbps, NVMe sysctl tuning, UFW firewall, unattended security updates, optional Docker engine).
- [x] **`netcup-dns-sync.sh`**: Dynamic DNS (DDNS) updater using the official Netcup CCP JSON API.
- [x] **Hardware Benchmarks**: Verified YABS (Geekbench 6, FIO 4K NVMe IOPS, 0.0% CPU Steal) in `data/benchmarks.json`.
- [x] **Community Vouchers**: Verified promotional codes from the Netcup Partner Program.

## Planned Tools (Under Development)

- [ ] **`netcup-cloud-vlan.sh`**:
  - Automated Netplan & systemd-networkd configurator for Netcup Cloud vLAN (free 2.5 Gbps internal private networking between instances).
- [ ] **`netcup-snapshot.sh`**:
  - Automated SCP (Server Control Panel) snapshot rotation and pre-snapshot database freezing.
- [ ] **`netcup-exporter`**:
  - Lightweight Prometheus exporter monitoring Netcup Looking Glass round-trip latency, packet loss, and CPU Steal metrics for Grafana dashboards.
- [ ] **`netcup-matrix-tui`**:
  - Interactive terminal UI (Python/Go/Bash) to filter Netcup servers by budget, RAM, and workload requirements offline.

## Contributions

Have an idea or written a script for Netcup? Open an issue or submit a Pull Request! See [CONTRIBUTING.md](CONTRIBUTING.md).
