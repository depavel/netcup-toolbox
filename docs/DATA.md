# Data files

All files under `data/` are generated from the site catalog and overwritten on
sync. Do not edit them by hand.

| File | Contents |
|---|---|
| `data/servers.json` | 19 active plans with specs, net price, contract term, voucher eligibility, availability, and benchmark data. |
| `data/benchmarks.json` | Aggregated YABS extract for 14 benchmarked plans. It is not a raw log archive. |
| `data/datacenters.json` | Official Netcup test IPs, region labels, verification dates, and recommended plan IDs for all 5 datacenters. |
| `data/meta.json` | Schema version, generation timestamp, latest availability check, and dataset counts. |

## Availability semantics

`availability` is either `available` or `sold-out`. It is never `null` or an
empty string. `availabilityCheckedAt` is the date of the last manual check.

- `sold-out` means the plan is still listed for specs and benchmarks, but no
  voucher claim or purchase CTA is offered.
- A missing or unknown value is a data error, not "available". The generator
  fails closed if the site catalog does not provide the field.

## Freshness

`data/meta.json` is the machine-readable freshness marker:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-11-07T22:24:30.738Z",
  "availabilityCheckedAt": "2026-11-03",
  "planCount": 19,
  "benchmarkCount": 14,
  "datacenterCount": 5,
  "source": "https://netcupgutscheine.com/en/server"
}
```

`generatedAt` changes on every sync. `availabilityCheckedAt` only changes after
a manual availability check against the Netcup product pages.

## Consuming the data

```bash
jq -r '.[] | select(.availability == "available") | [.id, .netPriceEur] | @tsv' data/servers.json
jq -r '.[] | [.id, .availability, .availabilityCheckedAt] | @tsv' data/servers.json
```

Prices are **net EUR**. Use the site's VAT calculator or `tools/netcup-calc.sh`
for gross prices. The Netcup checkout is authoritative.
