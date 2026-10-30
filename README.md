# netcup-toolbox

Shell scripts, hardware benchmarks, and network reference data for netcup GmbH cloud infrastructure (Root Server G12.5, VPS, and vGPU instances).

Companion repository for [netcupgutscheine.com](https://netcupgutscheine.com/en/tools) — open-source CLI utilities, system configs, and raw benchmark datasets.

> Review every script before running it. The DNS updater reads credentials from environment variables and never writes them to disk or logs. Prefer a pinned commit or release over `main` for production automation.

## Tools

| Script | Description | Run after clone | Web GUI |
|---|---|---|---|
| `tools/netcup-ping.sh` | Tests ICMP round-trip latency to all 5 netcup datacenters | `bash tools/netcup-ping.sh` | [Live Latency Map](https://netcupgutscheine.com/en/tools#ping) |
| `tools/netcup-init.sh` | Configures TCP BBR, NVMe sysctl, UFW firewall, and installs Docker | `sudo bash tools/netcup-init.sh --with-docker` | [Bootstrap Config](https://netcupgutscheine.com/en/tools#bootstrap) |
| `tools/netcup-vlan.sh` | Netplan & Debian configuration generator for Cloud vLAN (2.5 Gbps) | `bash tools/netcup-vlan.sh --interface eth1 --ip 10.0.10.1/24 --mtu 9000` | [Interactive Generator](https://netcupgutscheine.com/en/tools#vlan) |
| `tools/netcup-dns-sync.sh` | Dynamic DNS (DDNS) client for the netcup CCP JSON DNS API | `bash tools/netcup-dns-sync.sh` | [DDNS Guide](https://netcupgutscheine.com/en/tools#ddns) |
| `tools/netcup-calc.sh` | Terminal 5-region VAT and billing price calculator | `bash tools/netcup-calc.sh` | [VAT Calculator](https://netcupgutscheine.com/en/tools#calc) |

---

## Latency check (netcup-ping.sh)

Runs 3 ICMP ping packets to the verified test nodes and outputs min/avg/max latency and packet loss:

Download the script, review it, then run it:

```bash
curl -fsSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-ping.sh -o /tmp/netcup-ping.sh
less /tmp/netcup-ping.sh
bash /tmp/netcup-ping.sh
```

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

## Server bootstrap (netcup-init.sh)

Applies performance and security defaults on a fresh Debian 12 / Ubuntu 24.04 instance:
- Sets TCP congestion control to BBR (`net.ipv4.tcp_congestion_control = bbr`) for line-rate 2.5 Gbps throughput.
- Tunes virtual memory and file descriptor limits for NVMe drives (`vm.swappiness = 10`, `fs.file-max = 2097152`).
- Enables UFW firewall with default deny on incoming traffic (allows ports 22, 80, 443).
- Activates `unattended-upgrades` for automated security patches.
- Installs official Docker Engine and Compose plugin when called with `--with-docker`.

Download the script, review it, then run it with root:

```bash
curl -fsSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-init.sh -o /tmp/netcup-init.sh
less /tmp/netcup-init.sh
sudo bash /tmp/netcup-init.sh --with-docker
```

---

## Cloud vLAN configuration (netcup-vlan.sh)

Generates production Netplan or Debian network configuration for internal 2.5 Gbps communication between servers in the same datacenter:

```bash
bash tools/netcup-vlan.sh --interface eth1 --ip 10.0.10.1/24 --mtu 9000
```

An interactive web version is available at [https://netcupgutscheine.com/en/tools#vlan](https://netcupgutscheine.com/en/tools#vlan).

---

## Dynamic DNS (netcup-dns-sync.sh)

Updates an A record via netcup's official CCP DNS API for dynamic IP connections:

```bash
export NETCUP_CUSTOMER_NUMBER="123456"
export NETCUP_API_KEY="your-api-key"
export NETCUP_API_PASSWORD="your-api-password"
export NETCUP_DOMAIN_NAME="example.com"
export NETCUP_HOST_NAME="vpn"

bash tools/netcup-dns-sync.sh
```

---

## Terminal pricing & VAT calculator (netcup-calc.sh)

Calculates net and gross prices for all 15 Netcup server plans using the official half-up rounding rule across 5 tax regions:

```bash
bash tools/netcup-calc.sh
```

---

## Hardware benchmarks

Methodology: Debian 12 minimal, standard YABS suite (Geekbench 6.3 + FIO 3.33 4K mixed NVMe IOPS). Raw dataset is in [`data/benchmarks.json`](data/benchmarks.json).

| Plan | Architecture | Geekbench 6 Single | Geekbench 6 Multi | FIO 4K NVMe IOPS | CPU Steal |
|---|---|---|---|---|---|
| RS 500 G12.5 | 2 Dedicated Cores (AMD EPYC 9645) | 2285 | 4210 | 182.5k IOPS (730 MB/s) | 0.0% |
| RS 1000 G12.5 | 4 Dedicated Cores (AMD EPYC 9645) | 2290 | 7559 | 187.3k IOPS (749 MB/s) | 0.0% |
| RS 2000 G12.5 | 8 Dedicated Cores (AMD EPYC 9645) | 2295 | 13420 | 192.0k IOPS (768 MB/s) | 0.0% |
| RS 4000 G12.5 | 12 Dedicated Cores (AMD EPYC 9645) | 2301 | 17890 | 198.5k IOPS (794 MB/s) | 0.0% |
| RS 8000 G12.5 | 16 Dedicated Cores (AMD EPYC 9645) | 2305 | 21940 | 204.0k IOPS (816 MB/s) | 0.0% |
| RS 2000 vGPU 7 | 8 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (7 GB VRAM) | 2210 | 12400 | 195.0k IOPS (780 MB/s) | 0.0% |
| RS 4000 vGPU 14 | 12 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (14 GB VRAM) | 2225 | 17200 | 202.0k IOPS (808 MB/s) | 0.0% |
| VPS piko / nano G11s | 1–2 vCores (Low-Cost Node) | 980 | 1450 | 45.0k IOPS (180 MB/s) | 1.8% |
| VPS 500 G12.5 | 2 vCores (x86) | 1710 | 2890 | 115.0k IOPS (460 MB/s) | 1.4% |
| VPS 1000 G12.5 | 4 vCores (x86) | 1720 | 4650 | 130.0k IOPS (520 MB/s) | 1.2% |
| VPS 1000 ARM G12.5 | 6 ARM64 vCores | 1020 | 4980 | 142.0k IOPS (568 MB/s) | 0.4% |
| VPS 2000 G12.5 | 8 vCores (x86) | 1740 | 7980 | 138.0k IOPS (552 MB/s) | 1.1% |
| VPS 4000 G12.5 | 12 vCores (x86) | 1755 | 11200 | 145.0k IOPS (580 MB/s) | 1.0% |
| VPS 8000 G12.5 | 16 vCores (x86) | 1760 | 14100 | 150.0k IOPS (600 MB/s) | 0.9% |

Notes:
- Root Server instances provide dedicated AMD EPYC 9645 threads with 0.0% CPU steal.
- vGPU instances provide dedicated fractional NVIDIA H200 allocations (7 GB and 14 GB VRAM) for local LLM inference.
- VPS instances use shared vCPUs on AMD EPYC host nodes.

---

## Server specifications & multi-region pricing

Default billing includes German VAT (19%). Non-EU and EU business customers (B2B reverse charge) are billed at net rates (0% VAT):

| Plan | RAM | Storage | Port | 0% VAT (Non-EU / EU B2B) | 19% DE | 23% PL | Details |
|---|---|---|---|---|---|---|---|
| RS 500 G12.5 | 4 GB | 64 GB NVMe | 2.5 Gbit/s | €10.86 | €12.93 | €13.36 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-500-g12-5) |
| RS 1000 G12.5 | 8 GB | 128 GB NVMe | 2.5 Gbit/s | €18.26 | €21.73 | €22.46 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| RS 2000 G12.5 | 16 GB | 256 GB NVMe | 2.5 Gbit/s | €34.20 | €40.70 | €42.07 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| RS 4000 G12.5 | 32 GB | 512 GB NVMe | 2.5 Gbit/s | €65.40 | €77.83 | €80.45 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-4000-g12-5) |
| RS 8000 G12.5 | 64 GB | 1 TB NVMe | 2.5 Gbit/s | €124.72 | €148.42 | €153.41 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| RS 2000 vGPU 7 | 16 GB | 512 GB NVMe | 2.5 Gbit/s | €115.39 | €137.32 | €141.93 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-2000-vgpu-7) |
| RS 4000 vGPU 14 | 32 GB | 1 TB NVMe | 2.5 Gbit/s | €219.66 | €261.40 | €270.19 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/rs-4000-vgpu-14) |
| VPS piko / nano G11s | 2 GB | 30 GB SSD | 1 Gbit/s | €2.99 | €3.56 | €3.68 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-nano-g11s) |
| VPS 500 G12.5 | 4 GB | 64 GB SSD | 2.5 Gbit/s | €6.94 | €8.26 | €8.54 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-500-g12-5) |
| VPS 1000 G12.5 | 8 GB | 128 GB SSD | 2.5 Gbit/s | €12.18 | €14.50 | €14.99 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| VPS 1000 ARM G12.5 | 8 GB | 256 GB NVMe | 2.5 Gbit/s | €10.90 | €12.98 | €13.41 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-1000-arm-g12-5) |
| VPS 2000 G12.5 | 16 GB | 256 GB SSD | 2.5 Gbit/s | €22.62 | €26.92 | €27.83 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| VPS 4000 G12.5 | 32 GB | 512 GB SSD | 2.5 Gbit/s | €38.11 | €45.36 | €46.88 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| VPS 8000 G12.5 | 64 GB | 1 TB SSD | 2.5 Gbit/s | €56.39 | €67.11 | €69.36 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/vps-8000-g12-5) |
| Webhosting 2000 | 4 GB | 150 GB SSD (3 Free Domains) | 1 Gbit/s | €3.39 | €4.04 | €4.17 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| Webhosting 4000 | 4 GB | 500 GB SSD (6 Free Domains) | 1 Gbit/s | €6.81 | €8.11 | €8.38 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/webhosting-4000) |
| Webhosting 8000 | 8 GB | 1000 GB SSD (12 Free Domains) | 1 Gbit/s | €11.07 | €13.18 | €13.62 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/webhosting-8000) |
| Webhosting 2000 30Prozent Rabatt NUE 1M | 4 GB | 150 GB SSD (75 GB Web + 75 GB Mail, 3 Free Domains) | 1 Gbit/s | €2.37 | €2.82 | €2.92 | [Specs & Plan Page](https://netcupgutscheine.com/en/coupons/webhosting-2000-30prozent-rabatt-nue-1m) |

---

## Community promotional vouchers

Partner discount codes from the official Netcup Partner Program. Single-use codes are issued once and synchronized dynamically:

| Plan / Target | Offer | Voucher Code | Status | Cart Link |
|---|---|---|---|---|
| Universal New Customer | €5 discount on cart | `36nc17927037630` | Reusable / All new accounts | [Apply in cart](https://www.netcup.com/en/checkout/cart?gutschein=36nc17927037630) |
| RS 1000 G12.5 | 2 months free (~€36.52 saving) | `6874nc17927979598` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| RS 2000 G12.5 | 1 month free (~€34.20 saving) | `6875nc17927979118` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| RS 8000 G12.5 | 1 month free (~€124.72 saving) | `6876nc17927979338` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| VPS 1000 G12.5 | 1 month free (~€12.18 saving) | `6877nc17927979779` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| VPS 2000 G12.5 | 1 month free (~€22.62 saving) | `6878nc17927979809` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| VPS 4000 G12.5 | 1 month free (~€38.11 saving) | `6879nc17927979869` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| Webhosting 2000 | 30% lifetime discount | `5207nc17927979945` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| Webhosting 4000 | 30% lifetime discount | `5208nc17927980004` | Active | [Redeem](https://netcupgutscheine.com/en/coupons/webhosting-4000) |

Note: If an individual single-use code was already redeemed before the repo synchronized, the universal code `36nc17927037630` remains valid for any new account in the [Netcup Cart](https://www.netcup.com/en/checkout/cart).

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

## Interactive tools

Interactive tools are hosted at [https://netcupgutscheine.com/en/tools](https://netcupgutscheine.com/en/tools):
- DevOps Toolbox: [https://netcupgutscheine.com/en/tools](https://netcupgutscheine.com/en/tools)
- Live ICMP datacenter latency monitor: [https://netcupgutscheine.com/en/tools#ping](https://netcupgutscheine.com/en/tools#ping)
- Cloud vLAN Netplan generator: [https://netcupgutscheine.com/en/tools#vlan](https://netcupgutscheine.com/en/tools#vlan)
- VAT calculator (0% non-EU, 0% reverse charge, 19% DE, 20% AT, 23% PL): [https://netcupgutscheine.com/en/tools#calc](https://netcupgutscheine.com/en/tools#calc)
- Interactive server matcher: [https://netcupgutscheine.com/en/wizard](https://netcupgutscheine.com/en/wizard)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) to submit benchmark logs or script pull requests.

## License

MIT License. See [LICENSE](LICENSE).

*Independent community & partner resource. Not officially operated by netcup GmbH.*
