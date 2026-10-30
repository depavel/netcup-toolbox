# Contributing

## Submitting scripts
1. Place script under `tools/<name>.sh`.
2. Must run under `bash` or `sh` without third-party dependencies.
3. Include usage instructions at the top of the file.

## Submitting benchmark data
1. Run YABS on a clean instance:
   ```bash
   curl -sL yabs.sh | bash
   ```
2. Submit a PR or open an issue with the raw output to update `data/benchmarks.json`.
