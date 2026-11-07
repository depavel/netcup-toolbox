## Summary

<!-- What does this PR change and why? -->

## Type of change

- [ ] Bug fix
- [ ] New tool
- [ ] Data update
- [ ] Documentation / CI
- [ ] Breaking change

## Verification

- [ ] `bash -n tools/*.sh`
- [ ] `shellcheck --severity=warning tools/*.sh`
- [ ] `bash tools/netcup-ping.sh --self-test`
- [ ] `bash tools/netcup-calc.sh --self-test`
- [ ] `sha256sum -c CHECKSUMS.txt`
- [ ] `README.md`, `ROADMAP.md`, and `CHANGELOG.md` are updated

## Safety

- [ ] No single-use voucher codes, API keys, tokens, customer numbers, private
      IPs, or private hostnames are included.
- [ ] Mutating or destructive behavior is documented and guarded by an explicit
      confirmation flag.
- [ ] The change works without a browser session or CAPTCHA bypass.

## Risk

<!-- Read-only, mutating, or destructive? What can go wrong? How can it be rolled back? -->
