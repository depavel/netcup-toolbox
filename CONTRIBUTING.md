# Contributing to Netcup Toolbox

We welcome sysadmin scripts, benchmark logs (YABS), and documentation improvements.

## Adding a New Tool
1. Place your script under `tools/<tool-name>.sh`.
2. Ensure the script is POSIX or Bash compliant, has a `--help` flag or clean usage instructions, and does not require proprietary dependencies.
3. Add a section in `README.md` describing the tool and its usage.

## Submitting Benchmark Logs
1. Run [YABS](https://github.com/masonr/yet-another-bench-script):
   ```bash
   curl -sL yabs.sh | bash
   ```
2. Open an issue or Pull Request updating `data/benchmarks.json`.

## Code of Conduct
Please keep discussions technical, respectful, and fact-based.
