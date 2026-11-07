# Contributing

## Scripts
1. Place scripts under `tools/<name>.sh` and keep them POSIX-friendly Bash.
2. Add `--help` and, where parsing or calculation is involved, `--self-test`.
3. Run `bash -n tools/<name>.sh` and `shellcheck tools/<name>.sh`.
4. Do not require third-party dependencies beyond `curl`, `jq`, and standard Linux tools.
5. Document destructive actions, required privileges, and rollback behavior.
6. Mutating scripts must support `--dry-run` and an explicit confirmation flag.

See [docs/AUTH.md](docs/AUTH.md) for CCP vs SCP REST authentication and
[docs/RELEASE.md](docs/RELEASE.md) for the release checklist.

## Benchmark data
1. Run YABS on a clean instance after reviewing the downloaded script.
2. Record the OS image, kernel, YABS version, and test date.
3. Open a pull request or issue with the raw output; do not edit `data/*.json` by hand.
   The files are generated from the site catalog and are overwritten on sync.

## Security
- Never commit API keys, customer numbers, passwords, private keys, or private server addresses.
- Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).
