# netcup-toolbox

Shell scripts, aggregated YABS results, and network reference data for netcup GmbH infrastructure (Root Server G12.5, VPS, vGPU, and Webhosting).

Companion repository for [netcupgutscheine.com](https://netcupgutscheine.com/en/tools) — open-source CLI utilities, system configs, and benchmark datasets.

**Release:** [v0.2.3](https://github.com/depavel/netcup-toolbox/releases/tag/v0.2.3) · **License:** MIT · **Scope:** 18 active plans, 14 benchmarked plans.

> Review every script before running it. The DNS updater reads credentials from environment variables and never writes them to disk or logs. Use the pinned release tag below for production automation, not `main`.

## Verify the release

```bash
curl -fsSL https://github.com/depavel/netcup-toolbox/releases/download/v0.2.3/CHECKSUMS.txt -o CHECKSUMS.txt
sha256sum -c CHECKSUMS.txt
```

The checksums cover every `tools/*.sh` script and both JSON datasets.

## Tools

| Script | Description | Example | Web GUI |
|---|---|---|---|
| `tools/netcup-ping.sh` | ICMP latency to all 5 Netcup datacenters; supports iputils and BusyBox ping | `bash tools/netcup-ping.sh` | [Live latency map](https://netcupgutscheine.com/en/tools#ping) |
| `tools/netcup-init.sh` | TCP BBR, sysctl tuning, UFW, optional Docker; dry-run and custom SSH port | `sudo bash tools/netcup-init.sh --ssh-port 22 --dry-run` | [Bootstrap guide](https://netcupgutscheine.com/en/tools#bootstrap) |
| `tools/netcup-vlan.sh` | Netplan/Debian generator for Cloud vLAN; MTU 1500 only | `bash tools/netcup-vlan.sh --interface eth1 --ip 10.0.10.1/24` | [vLAN generator](https://netcupgutscheine.com/en/tools#vlan) |
| `tools/netcup-dns-sync.sh` | DDNS updater for one existing A record via the CCP JSON API | `bash tools/netcup-dns-sync.sh` | [DDNS guide](https://netcupgutscheine.com/en/tools#ddns) |
| `tools/netcup-calc.sh` | VAT and billing calculator for all active plans; ceiling rounding | `bash tools/netcup-calc.sh` | [VAT calculator](https://netcupgutscheine.com/en/tools#calc) |

---

## Latency check (`netcup-ping.sh`)

Runs 3 ICMP probes per datacenter and prints min/avg/max latency and packet loss. The parser handles both common Linux output formats:

- iputils: `rtt min/avg/max/mdev = ...`
- BusyBox: `round-trip min/avg/max = ...`

```bash
curl -fsSL https://github.com/depavel/netcup-toolbox/raw/v0.2.3/tools/netcup-ping.sh -o /tmp/netcup-ping.sh
less /tmp/netcup-ping.sh
bash /tmp/netcup-ping.sh
```

Run the parser self-test without sending packets:

```bash
bash /tmp/netcup-ping.sh --self-test
```

Example output:

```text
Netcup Datacenter Latency Probe (ICMP 3-packet average)
--------------------------------------------------------------------
Location           Test IP          Min        Avg        Max        Loss    
--------------------------------------------------------------------
Nuremberg (DE)     188.68.56.104    30.2ms     31.6ms     32.6ms     0%      
Vienna (AT)        89.58.16.1       38.8ms     39.0ms     39.3ms     0%      
Amsterdam (NL)     152.53.104.2     34.7ms     36.1ms     37.8ms     0%      
Manassas (US)      152.53.68.2      118.4ms    120.0ms    121.6ms    0%      
Singapore (SG)     217.146.9.10     189.1ms    192.0ms    195.0ms    0%      
--------------------------------------------------------------------
```

---

## Server bootstrap (`netcup-init.sh`)

Applies performance and security defaults on a fresh Debian 12 / Ubuntu 24.04 instance:

- sets TCP congestion control to BBR and a small sysctl profile;
- installs baseline packages and `unattended-upgrades`;
- writes UFW rules for the selected SSH port plus 80/443;
- verifies that SSH is listening before enabling UFW;
- installs Docker only with `--with-docker`.

```bash
curl -fsSL https://github.com/depavel/netcup-toolbox/raw/v0.2.3/tools/netcup-init.sh -o /tmp/netcup-init.sh
less /tmp/netcup-init.sh
sudo bash /tmp/netcup-init.sh --ssh-port 22 --dry-run
sudo bash /tmp/netcup-init.sh --ssh-port 22 --yes
```

**Docker + UFW:** Docker publishes container ports through its own iptables rules and can bypass UFW. Review `DOCKER-USER` rules before exposing containers. A full `apt-get upgrade` is opt-in via `--full-upgrade`.

---

## Cloud vLAN configuration (`netcup-vlan.sh`)

Generates Netplan or Debian network configuration for a private vLAN inside one Netcup datacenter. **Netcup Cloud vLAN uses MTU 1500; jumbo frames are not supported.** The script rejects `--mtu 9000` instead of generating a config that can silently drop large packets.

```bash
bash tools/netcup-vlan.sh --interface eth1 --ip 10.0.10.1/24
sudo bash tools/netcup-vlan.sh --interface eth1 --ip 10.0.10.1/24 --apply
```

Interactive web version: [https://netcupgutscheine.com/en/tools#vlan](https://netcupgutscheine.com/en/tools#vlan).

---

## Dynamic DNS (`netcup-dns-sync.sh`)

Updates exactly one existing A record through the official CCP JSON API. It checks `login` and `infoDnsRecords` status, validates the detected public IPv4 address, and refuses to guess when the host has zero or multiple A records.

```bash
export NETCUP_CUSTOMER_NUMBER="123456"
export NETCUP_API_KEY="your-api-key"
export NETCUP_API_PASSWORD="your-api-password"
export NETCUP_DOMAIN_NAME="example.com"
export NETCUP_HOST_NAME="vpn"

bash tools/netcup-dns-sync.sh
```

Credentials are read from the environment and are never written to disk or printed. Run it from cron with a dedicated user and a lock file (the script uses `flock` when available).

---

## Terminal pricing and VAT (`netcup-calc.sh`)

Calculates net and gross prices for all 18 active plans. Netcup rounds gross prices **up to the next cent** when VAT is greater than 0%; the 0% regions keep the exact net price. This was verified against the official netcup.com RS 500 G12.5 card on 2026-10-31: EUR 10.86 net × 1.19 = EUR 12.9234 → **EUR 12.93**.

```bash
bash tools/netcup-calc.sh
bash tools/netcup-calc.sh --self-test
```

---

## Hardware benchmarks

Aggregated YABS results for 14 active plans, generated from our official Netcup test account. Methodology: Debian 12 minimal, Geekbench 6.3, FIO 3.33 4K mixed NVMe, and CPU steal from `vmstat`. The JSON file is a convenience extract of `data/servers.json`; it is **not** a raw YABS log archive. Webhosting is managed shared hosting and is not benchmarked.

| Plan | Architecture | Geekbench 6 Single | Geekbench 6 Multi | FIO 4K NVMe IOPS | CPU Steal |
|---|---|---|---|---|---|
| RS 500 G12.5 | 2 Dedicated Cores (AMD EPYC 9645) | 2285 | 4210 | 182.5k IOPS (730 MB/s) | 0.0% |
| RS 1000 G12.5 | 4 Dedicated Cores (AMD EPYC 9645) | 2290 | 7559 | 187.3k IOPS (749 MB/s) | 0.0% |
| RS 2000 G12.5 | 8 Dedicated Cores (AMD EPYC 9645) | 2295 | 13420 | 192.0k IOPS (768 MB/s) | 0.0% |
| RS 4000 G12.5 | 12 Dedicated Cores (AMD EPYC 9645) | 2301 | 17890 | 198.5k IOPS (794 MB/s) | 0.0% |
| RS 8000 G12.5 | 16 Dedicated Cores (AMD EPYC 9645) | 2305 | 21940 | 204.0k IOPS (816 MB/s) | 0.0% |
| RS 2000 vGPU 7 | 8 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (7 GB VRAM) | 2210 | 12400 | 195.0k IOPS (780 MB/s) | 0.0% |
| RS 4000 vGPU 14 | 12 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (14 GB VRAM) | 2225 | 17200 | 202.0k IOPS (808 MB/s) | 0.0% |
| VPS nano G11.5s | 2 vCores (Low-Cost Node) | 980 | 1450 | 45.0k IOPS (180 MB/s) | 1.8% |
| VPS 500 G12.5 | 2 vCores (x86) | 1710 | 2890 | 115.0k IOPS (460 MB/s) | 1.4% |
| VPS 1000 G12.5 | 4 vCores (x86) | 1720 | 4650 | 130.0k IOPS (520 MB/s) | 1.2% |
| VPS 1000 ARM G12.5 | 4 ARM64 vCores | 1020 | 4980 | 142.0k IOPS (568 MB/s) | 0.4% |
| VPS 2000 G12.5 | 8 vCores (x86) | 1740 | 7980 | 138.0k IOPS (552 MB/s) | 1.1% |
| VPS 4000 G12.5 | 12 vCores (x86) | 1755 | 11200 | 145.0k IOPS (580 MB/s) | 1.0% |
| VPS 8000 G12.5 | 16 vCores (x86) | 1760 | 14100 | 150.0k IOPS (600 MB/s) | 0.9% |

Notes:
- Root Server instances use dedicated AMD EPYC 9645 threads with 0.0% CPU steal.
- vGPU instances use fractional NVIDIA H200 allocations (7 GB and 14 GB VRAM) for local inference.
- VPS instances use shared vCPUs on AMD EPYC host nodes.

---

## Server specifications and multi-region pricing

The table covers all 18 active plans. Non-EU and EU business customers (B2B reverse charge) pay the net price; German consumers pay 19% VAT; Polish consumers pay 23% VAT. Archived G11/G12 plans are documented on the site but are excluded from this active-plan dataset.

| Plan | RAM | Storage | Port | 0% VAT (Non-EU / EU B2B) | 19% DE | 23% PL | Details |
|---|---|---|---|---|---|---|---|
| RS 500 G12.5 | 4 GB | 64 GB NVMe | 2.5 Gbit/s | €10.86 | €12.93 | €13.36 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-500-g12-5) |
| RS 1000 G12.5 | 8 GB | 128 GB NVMe | 2.5 Gbit/s | €18.26 | €21.73 | €22.46 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| RS 2000 G12.5 | 16 GB | 256 GB NVMe | 2.5 Gbit/s | €34.20 | €40.70 | €42.07 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| RS 4000 G12.5 | 32 GB | 512 GB NVMe | 2.5 Gbit/s | €65.40 | €77.83 | €80.45 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-4000-g12-5) |
| RS 8000 G12.5 | 64 GB | 1 TB NVMe | 2.5 Gbit/s | €124.72 | €148.42 | €153.41 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| RS 2000 vGPU 7 | 16 GB | 512 GB NVMe | 2.5 Gbit/s | €102.33 | €121.77 | €125.87 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-2000-vgpu-7) |
| RS 4000 vGPU 14 | 32 GB | 1 TB NVMe | 2.5 Gbit/s | €195.32 | €232.43 | €240.25 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/rs-4000-vgpu-14) |
| VPS nano G11.5s | 2 GB | 60 GB SSD | 1 Gbit/s | €3.10 | €3.69 | €3.82 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-nano-g11s) |
| VPS 500 G12.5 | 4 GB | 64 GB SSD | 2.5 Gbit/s | €6.94 | €8.26 | €8.54 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-500-g12-5) |
| VPS 1000 G12.5 | 8 GB | 128 GB SSD | 2.5 Gbit/s | €12.18 | €14.50 | €14.99 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| VPS 1000 ARM G12.5 | 8 GB | 128 GB NVMe | 2.5 Gbit/s | €12.18 | €14.50 | €14.99 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-1000-arm-g12-5) |
| VPS 2000 G12.5 | 16 GB | 256 GB SSD | 2.5 Gbit/s | €22.62 | €26.92 | €27.83 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| VPS 4000 G12.5 | 32 GB | 512 GB SSD | 2.5 Gbit/s | €38.11 | €45.36 | €46.88 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| VPS 8000 G12.5 | 64 GB | 1 TB SSD | 2.5 Gbit/s | €56.39 | €67.11 | €69.36 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/vps-8000-g12-5) |
| Webhosting 2000 | 4 GB | 150 GB SSD (3 Free Domains) | 1 Gbit/s | €3.39 | €4.03 | €4.17 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| Webhosting 4000 | 4 GB | 500 GB SSD (6 Free Domains) | 1 Gbit/s | €6.81 | €8.10 | €8.38 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/webhosting-4000) |
| Webhosting 8000 | 8 GB | 1000 GB SSD (12 Free Domains) | 1 Gbit/s | €11.07 | €13.17 | €13.62 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/webhosting-8000) |
| Webhosting 2000 30Prozent Rabatt NUE 1M | 4 GB | 150 GB SSD (75 GB Web + 75 GB Mail, 3 Free Domains) | 1 Gbit/s | €2.37 | €2.82 | €2.92 | [Specs & plan page](https://netcupgutscheine.com/en/coupons/webhosting-2000-30prozent-rabatt-nue-1m) |

---

## Vouchers

The reusable new-customer code **`36nc17927037630`** gives a €5 discount on a new Netcup order (except domains) and does not expire after a single use.

**Single-use codes are intentionally not published in this repository.** They are issued by the site’s voucher dispenser, and publishing them would let the first reader burn a code before an actual visitor can claim it. The site is the authoritative source for current availability:

- [Claim a voucher](https://netcupgutscheine.com/en/tools)
- [Apply the universal code in the Netcup cart](https://www.netcup.com/en/checkout/cart?gutschein=36nc17927037630)

| Featured plan | Catalog offer | Plan page |
|---|---|---|
| RS 1000 G12.5 | 2 Months Free | [Open plan page](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| RS 2000 G12.5 | 1 Month Free | [Open plan page](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| RS 8000 G12.5 | 1 Month Free | [Open plan page](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| VPS 1000 G12.5 | 1 Month Free | [Open plan page](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| VPS 2000 G12.5 | 1 Month Free | [Open plan page](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| VPS 4000 G12.5 | 1 Month Free | [Open plan page](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| Webhosting 2000 | 30% Lifetime Discount | [Open plan page](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| Webhosting 4000 | 30% Lifetime Discount | [Open plan page](https://netcupgutscheine.com/en/coupons/webhosting-4000) |

Offer labels are copied from the site catalog for orientation only. The Netcup checkout is authoritative for price, VAT, and voucher eligibility.

---

## Looking glass test nodes

Official Netcup IPv4 addresses used for routing and latency measurement:

| Location | Region | IPv4 | Looking Glass |
|---|---|---|---|
| Nuremberg (DE) | europe | `188.68.56.104` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| Vienna (AT) | europe | `89.58.16.1` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| Amsterdam (NL) | europe | `152.53.104.2` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| Manassas, VA (US) | north-america | `152.53.68.2` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| Singapore (SG) | asia-pacific | `217.146.9.10` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |

---

## Data files

- `data/servers.json` — canonical active-plan catalog (18 plans) generated from the site catalog.
- `data/benchmarks.json` — aggregated benchmark extract (14 plans), derived from `data/servers.json`. It is not a raw log archive.

---

## Interactive tools

- [DevOps toolbox](https://netcupgutscheine.com/en/tools)
- [Live ICMP latency monitor](https://netcupgutscheine.com/en/tools#ping)
- [Cloud vLAN Netplan generator](https://netcupgutscheine.com/en/tools#vlan)
- [VAT calculator](https://netcupgutscheine.com/en/tools#calc)
- [Interactive server matcher](https://netcupgutscheine.com/en/wizard)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Run `shellcheck` and the built-in self-tests before opening a pull request.

## Security

See [SECURITY.md](SECURITY.md). Do not open public issues for vulnerabilities or paste API credentials into an issue.

## License

MIT License. See [LICENSE](LICENSE).

*Independent community resource. Not operated by netcup GmbH.*
