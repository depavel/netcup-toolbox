# Changelog

All notable changes to `netcup-toolbox` are documented here.

## 0.2.4 - 2026-10-31

### Changed

- Added the separate VPS pico G11.5s plan (1 vCore, 1 GB RAM, 30 GB SSD,
  EUR 2.21 gross for the 12-month term).
- ARM, VPS pico and VPS nano are marked as voucher-ineligible, matching the
  Netcup cart message: vouchers cannot be redeemed for VPS ARM or VPS Lite.
- Webhosting partner labels now say "30% monthly discount" instead of
  "lifetime", matching Netcup's "monthly price reduction" wording.
- Contract term is included in the public `data/servers.json`.

## 0.2.3 - 2026-10-31

### Fixed

- Corrected VPS 1000 ARM G12.5 to 4 ARM64 vCores, 128 GB NVMe and the
  official EUR 14.50 gross base.
- Replaced the combined "piko / nano" row with the official VPS nano G11.5s
  (2 vCores, 2 GB RAM, 60 GB SSD, EUR 3.69 gross for the 6-month term).
- Added the minimum contract term to `data/servers.json`.

## 0.2.2 - 2026-10-31

### Fixed

- vGPU catalogue prices now match the official Netcup cards: RS 2000 vGPU 7
  starts at EUR 121.77 gross, RS 4000 vGPU 14 at EUR 232.43 gross.
- Webhosting 2000/4000/8000 use the exact net base so the calculated gross
  price matches Netcup's EUR 4.03/8.10/13.17.
- The calculator self-test now asserts the official Webhosting 4000 value
  (EUR 8.10), not the previous EUR 8.11.

## 0.2.1 - 2026-10-31

### Fixed

- `netcup-init.sh` detects an IPv6-only SSH listener via `/proc/net/tcp6` and
  reads the distribution/codename from `/etc/os-release` instead of relying on
  `lsb_release`.
- The public `data/servers.json` no longer contains voucher series prefixes;
  only the reusable universal code is published.

## 0.2.0 - 2026-10-31

### Fixed

- `netcup-calc.sh` now uses Netcup's ceiling rounding rule for VAT instead of
  half-up rounding. Example: RS 500 G12.5 at 19% DE is EUR 12.93, not EUR 12.92.
- `netcup-vlan.sh` now defaults to MTU 1500 and rejects jumbo frames, matching
  Netcup Cloud vLAN. The site's VLAN generator uses the same value.
- `netcup-ping.sh` now parses both iputils and BusyBox ping summaries. The
  duplicate root-level `netcup-ping.sh` was removed.
- `netcup-dns-sync.sh` now checks every API status, validates the detected
  public IPv4 address, refuses to guess between multiple A records, and
  preserves the full DNS record object in `updateDnsRecords`.
- `netcup-init.sh` no longer runs a full system upgrade by default, supports a
  custom SSH port, verifies that SSH is listening before enabling UFW, and
  supports `--dry-run`. The Docker/UFW bypass is documented.

### Changed

- Single-use voucher codes are no longer published in the README. The
  repository lists the reusable new-customer code and links to the site's
  dispenser, so a reader cannot burn a one-time code before a visitor claims it.
- Data files are generated from the site catalog. `data/benchmarks.json` is
  labelled as an aggregated extract, not raw YABS logs.
- README commands are pinned to a release tag instead of `main`.
- Added CI (shellcheck, syntax checks, self-tests, JSON validation, checksums),
  `SECURITY.md`, and release checksums.

## 0.1.0 - 2026-10-30

- Initial public release: ping, init, vLAN, DDNS, and VAT calculator scripts;
  server and benchmark datasets.
