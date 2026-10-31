# Changelog

All notable changes to `netcup-toolbox` are documented here.

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
