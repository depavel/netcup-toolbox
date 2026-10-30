# Netcup Toolbox — Open-Source Sysadmin Suite & Server Benchmarks

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Datacenters](https://img.shields.io/badge/Datacenters-5%20Verified-emerald.svg)](#1-datacenter-latency-tester-cli)
[![Tools](https://img.shields.io/badge/Tools-Ping%20%7C%20Init%20%7C%20DNS-indigo.svg)](#included-tools)
[![Vouchers](https://img.shields.io/badge/Vouchers-CCP%20Verified-teal.svg)](#community--developer-vouchers)
[![Live Web Hub](https://img.shields.io/badge/Web%20Hub-netcupgutscheine.com-00626d.svg)](https://netcupgutscheine.com)

An evergreen collection of **open-source sysadmin utilities, hardware benchmarks, and community perks** for **netcup GmbH** cloud infrastructure (Root Server Generation 12.5, vGPU AI instances, VPS, and Webhosting).

---

## Included Tools

| Tool | Description | Quick Run |
|---|---|---|
| [`netcup-ping.sh`](tools/netcup-ping.sh) | Test ICMP round-trip latency to all 5 official Netcup datacenters. | `curl -sSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-ping.sh | bash` |
| [`netcup-init.sh`](tools/netcup-init.sh) | Bootstrap a fresh server: enables **TCP BBR (2.5 Gbps)**, NVMe sysctl, UFW, auto-updates & Docker. | `curl -sSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-init.sh | sudo bash -s -- --with-docker` |
| [`netcup-dns-sync.sh`](tools/netcup-dns-sync.sh) | Dynamic DNS (DDNS) client for the official Netcup CCP JSON DNS API. | `NETCUP_DOMAIN_NAME=domain.com ./tools/netcup-dns-sync.sh` |
| [`ROADMAP.md`](ROADMAP.md) | Future planned tools (Cloud vLAN helper, Prometheus exporter, snapshot script). | — |

---

## 1. Datacenter Latency Tester (CLI)

Run an instant ICMP ping probe from your terminal to all 5 official Netcup datacenters (Nuremberg, Vienna, Amsterdam, Manassas, Singapore):

```bash
# Run without cloning (macOS / Linux):
curl -sSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-ping.sh | bash
```

Sample output:
```text
====================================================================
  Netcup Datacenter Latency Probe (ICMP 3-Packet Average)
====================================================================
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

## 2. Server Bootstrap & Hardening Script (`netcup-init.sh`)

When deploying a new Netcup VPS or Root Server, run `netcup-init.sh` to configure optimal networking and security defaults in under 60 seconds:
- **Enables TCP BBR** congestion control to achieve full 2.5 Gbps line-rate throughput;
- **NVMe Tuning**: sets `vm.swappiness=10` and `fs.file-max=2097152`;
- **Firewall**: enables UFW with strict inbound policies (ports 22, 80, 443 only);
- **Security**: activates `unattended-upgrades` for automated zero-day security patches;
- **Optional Docker**: installs official Docker Engine and Docker Compose plugin (`--with-docker`).

```bash
# Run on a fresh Debian 12 / Ubuntu 24.04 Netcup instance:
curl -sSL https://raw.githubusercontent.com/depavel/netcup-toolbox/main/tools/netcup-init.sh | sudo bash -s -- --with-docker
```

---

## 3. Dynamic DNS Updater (`netcup-dns-sync.sh`)

Netcup provides an official DNS API in the Customer Control Panel (CCP). The script `tools/netcup-dns-sync.sh` lets you run Dynamic DNS for your home lab or office servers without paying for third-party DDNS services:

```bash
export NETCUP_CUSTOMER_NUMBER="123456"
export NETCUP_API_KEY="your-api-key"
export NETCUP_API_PASSWORD="your-api-password"
export NETCUP_DOMAIN_NAME="example.com"
export NETCUP_HOST_NAME="vpn" # points vpn.example.com to current public IP

bash tools/netcup-dns-sync.sh
```

---

## 4. Hardware Benchmarks (AMD EPYC 9645 Gen 12.5 & NVIDIA H200 vGPU)

Benchmark methodology: Debian 12 minimal, official YABS suite (Geekbench 6.3 + FIO 3.33 4K mixed NVMe IOPS, direct bare-metal and KVM nodes). Machine-readable JSON data is available in [`data/benchmarks.json`](data/benchmarks.json).

| Plan | Architecture | Geekbench 6 Single | Geekbench 6 Multi | FIO 4K NVMe IOPS | CPU Steal | Compute Tier |
|---|---|---|---|---|---|---|
| **RS 500 G12.5** | 2 Dedicated Cores (AMD EPYC 9645) | **2285** | **4210** | 182.5k IOPS (730 MB/s) | **0.0%** | 100% Dedicated Zen 5 |
| **RS 1000 G12.5** | 4 Dedicated Cores (AMD EPYC 9645) | **2290** | **7559** | 187.3k IOPS (749 MB/s) | **0.0%** | 100% Dedicated Zen 5 |
| **RS 2000 G12.5** | 8 Dedicated Cores (AMD EPYC 9645) | **2295** | **13420** | 192.0k IOPS (768 MB/s) | **0.0%** | 100% Dedicated Zen 5 |
| **RS 4000 G12.5** | 12 Dedicated Cores (AMD EPYC 9645) | **2301** | **17890** | 198.5k IOPS (794 MB/s) | **0.0%** | 100% Dedicated Zen 5 |
| **RS 8000 G12.5** | 16 Dedicated Cores (AMD EPYC 9645) | **2305** | **21940** | 204.0k IOPS (816 MB/s) | **0.0%** | 100% Dedicated Zen 5 |
| **RS 2000 vGPU 7** | 8 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (7 GB VRAM) | **2210** | **12400** | 195.0k IOPS (780 MB/s) | **0.0%** | NVIDIA H200 Tensor Cores |
| **RS 4000 vGPU 14** | 12 Dedicated Cores (AMD EPYC 9535) + NVIDIA H200 (14 GB VRAM) | **2225** | **17200** | 202.0k IOPS (808 MB/s) | **0.0%** | NVIDIA H200 Tensor Cores |
| **VPS piko / nano G11s** | 1–2 vCores (Low-Cost Node) | **980** | **1450** | 45.0k IOPS (180 MB/s) | **1.8%** | Shared vCPU |
| **VPS 500 G12.5** | 2 vCores (x86) | **1710** | **2890** | 115.0k IOPS (460 MB/s) | **1.4%** | Shared vCPU |
| **VPS 1000 G12.5** | 4 vCores (x86) | **1720** | **4650** | 130.0k IOPS (520 MB/s) | **1.2%** | Shared vCPU |
| **VPS 1000 ARM G12.5** | 6 ARM64 vCores | **1020** | **4980** | 142.0k IOPS (568 MB/s) | **0.4%** | Shared vCPU |
| **VPS 2000 G12.5** | 8 vCores (x86) | **1740** | **7980** | 138.0k IOPS (552 MB/s) | **1.1%** | Shared vCPU |
| **VPS 4000 G12.5** | 12 vCores (x86) | **1755** | **11200** | 145.0k IOPS (580 MB/s) | **1.0%** | Shared vCPU |
| **VPS 8000 G12.5** | 16 vCores (x86) | **1760** | **14100** | 150.0k IOPS (600 MB/s) | **0.9%** | Shared vCPU |

### Architecture Highlights
- **Root Server (Dedicated Cores)**: Physische Hardware-Threads des AMD EPYC 9645 (Zen 5 Turin) sind exklusiv für die VM reserviert. **CPU Steal bleibt dauerhaft bei 0.0%**, ideal für PostgreSQL/MySQL, Docker/Dokploy und CI/CD.
- **vGPU Server**: Dedicated Slices der NVIDIA H200 mit 7 GB oder 14 GB VRAM. Ideal für lokalen AI-Inferenz-Betrieb (Ollama, vLLM, DeepSeek R1, Llama 3) ohne teure Egress-Kosten.
- **VPS (Shared vCPU)**: Hervorragendes Preis-Leistungs-Verhältnis für Webdienste, VPN (WireGuard) und Staging-Umgebungen.

---

## 5. Server Catalog & Multi-Region VAT Pricing

Netcup berechnet Preise standardmäßig mit deutscher Mehrwertsteuer (19%). Für internationale Kunden (non-EU) und gewerbliche Kunden im EU-Ausland (B2B Reverse Charge) entfällt die Steuer (0% Netto):

| Plan | RAM | Storage | Port | 0% VAT (Non-EU / EU B2B) | 19% DE | 23% PL | Details & Calculator |
|---|---|---|---|---|---|---|---|
| **RS 500 G12.5** | 4 GB | 64 GB NVMe | 2.5 Gbit/s | **€10.86** | €12.93 | €13.36 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-500-g12-5) |
| **RS 1000 G12.5** | 8 GB | 128 GB NVMe | 2.5 Gbit/s | **€18.26** | €21.73 | €22.46 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| **RS 2000 G12.5** | 16 GB | 256 GB NVMe | 2.5 Gbit/s | **€34.20** | €40.70 | €42.07 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| **RS 4000 G12.5** | 32 GB | 512 GB NVMe | 2.5 Gbit/s | **€65.40** | €77.83 | €80.45 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-4000-g12-5) |
| **RS 8000 G12.5** | 64 GB | 1 TB NVMe | 2.5 Gbit/s | **€124.72** | €148.42 | €153.41 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| **RS 2000 vGPU 7** | 16 GB | 512 GB NVMe | 2.5 Gbit/s | **€115.39** | €137.32 | €141.93 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-2000-vgpu-7) |
| **RS 4000 vGPU 14** | 32 GB | 1 TB NVMe | 2.5 Gbit/s | **€219.66** | €261.40 | €270.19 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/rs-4000-vgpu-14) |
| **VPS piko / nano G11s** | 2 GB | 30 GB SSD | 1 Gbit/s | **€2.99** | €3.56 | €3.68 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-nano-g11s) |
| **VPS 500 G12.5** | 4 GB | 64 GB SSD | 2.5 Gbit/s | **€6.94** | €8.26 | €8.54 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-500-g12-5) |
| **VPS 1000 G12.5** | 8 GB | 128 GB SSD | 2.5 Gbit/s | **€12.18** | €14.50 | €14.99 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| **VPS 1000 ARM G12.5** | 8 GB | 256 GB NVMe | 2.5 Gbit/s | **€10.90** | €12.98 | €13.41 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-1000-arm-g12-5) |
| **VPS 2000 G12.5** | 16 GB | 256 GB SSD | 2.5 Gbit/s | **€22.62** | €26.92 | €27.83 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| **VPS 4000 G12.5** | 32 GB | 512 GB SSD | 2.5 Gbit/s | **€38.11** | €45.36 | €46.88 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| **VPS 8000 G12.5** | 64 GB | 1 TB SSD | 2.5 Gbit/s | **€56.39** | €67.11 | €69.36 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/vps-8000-g12-5) |
| **Webhosting 2000** | 4 GB | 150 GB SSD (3 Free Domains) | 1 Gbit/s | **€3.39** | €4.04 | €4.17 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| **Webhosting 4000** | 4 GB | 500 GB SSD (6 Free Domains) | 1 Gbit/s | **€6.81** | €8.11 | €8.38 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/webhosting-4000) |
| **Webhosting 8000** | 8 GB | 1000 GB SSD (12 Free Domains) | 1 Gbit/s | **€11.07** | €13.18 | €13.62 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/webhosting-8000) |
| **Webhosting 2000 30Prozent Rabatt NUE 1M** | 4 GB | 150 GB SSD (75 GB Web + 75 GB Mail, 3 Free Domains) | 1 Gbit/s | **€2.37** | €2.82 | €2.92 | [Specs & Live Tool](https://netcupgutscheine.com/en/coupons/webhosting-2000-30prozent-rabatt-nue-1m) |

---

## 6. Community & Developer Vouchers

Verified promotional codes from the official Netcup Partner Program. Single-use codes are issued once and synchronized dynamically.

| Plan / Tier | Promo Offer | Partner Voucher Code | Status | Cart Link |
|---|---|---|---|---|
| **Universal New Customer** | **€5 Instant Cart Discount** | `36nc17927037630` | Multi-use / Unlimited | [Apply €5 Code](https://www.netcup.com/en/checkout/cart?gutschein=36nc17927037630) |
| **RS 1000 G12.5** | **2 Months Free (~€36.52 saving)** | `6874nc17927979598` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/rs-1000-g12-5) |
| **RS 2000 G12.5** | **1 Month Free (~€34.20 saving)** | `6875nc17927979118` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/rs-2000-g12-5) |
| **RS 8000 G12.5** | **1 Month Free (~€124.72 saving)** | `6876nc17927979338` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/rs-8000-g12-5) |
| **VPS 1000 G12.5** | **1 Month Free (~€12.18 saving)** | `6877nc17927979779` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/vps-1000-g12-5) |
| **VPS 2000 G12.5** | **1 Month Free (~€22.62 saving)** | `6878nc17927979809` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/vps-2000-g12-5) |
| **VPS 4000 G12.5** | **1 Month Free (~€38.11 saving)** | `6879nc17927979869` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/vps-4000-g12-5) |
| **Webhosting 2000** | **30% Lifetime Discount** | `5207nc17927979945` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/webhosting-2000) |
| **Webhosting 4000** | **30% Lifetime Discount** | `5208nc17927980004` | Verified | [Redeem Code](https://netcupgutscheine.com/en/coupons/webhosting-4000) |

> **Redemption Note**: If a single-use code was already claimed by another community member before repository sync, the universal code `36nc17927037630` works as an unconditional fallback for all new accounts directly in the [Netcup Cart](https://www.netcup.com/en/checkout/cart).

---

## 7. Interactive Web Hub

Explore interactive engineering calculators on **[netcupgutscheine.com](https://netcupgutscheine.com)**:
- **[Live Datacenter Ping & Latency Probe](https://netcupgutscheine.com)**: Automatic ICMP latency measurement with round-trip jitter to all 5 locations.
- **[Precision VAT & Reverse Charge Calculator](https://netcupgutscheine.com)**: Accurate gross/net calculation under DE 19%, AT 20%, PL 23%, and EU B2B 0% Reverse Charge.
- **[Smart Server Matcher Wizard](https://netcupgutscheine.com/en/wizard)**: Select your stack (Docker, Dokploy, Coolify, Ollama AI, Databases) and get optimal RAM/CPU sizing.

---

## 8. Datacenter Looking Glass IPs

Official Netcup / Anexia test IP addresses for network routing and ping tests:

| Location | Region Code | Verified IPv4 | Official Looking Glass |
|---|---|---|---|
| **Nuremberg** (DE) | `europe` | `188.68.56.104` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| **Vienna** (AT) | `europe` | `89.58.16.1` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| **Amsterdam** (NL) | `europe` | `152.53.104.2` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| **Manassas, VA** (US) | `north-america` | `152.53.68.2` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |
| **Singapore** (SG) | `asia-pacific` | `217.146.9.10` | [lookingglass.netcup.net](https://lookingglass.netcup.net/) |

---

## Roadmap & Contributing

See [ROADMAP.md](ROADMAP.md) for planned tools and [CONTRIBUTING.md](CONTRIBUTING.md) on how to submit benchmark logs or new scripts.

## License & Legal Disclaimer

Distributed under the [MIT License](LICENSE).

*Independent community & partner resource. Not officially operated by netcup GmbH.*
