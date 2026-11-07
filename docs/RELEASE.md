# Release process

`netcup-toolbox` releases are generated from the private `netcupcoupon`
repository. Do not edit the public repository by hand; changes made there are
overwritten on the next sync.

## Versioning

- Use semantic versioning: `vMAJOR.MINOR.PATCH`.
- A new script or a user-visible data field is a **minor** release.
- A breaking CLI or JSON change is a **major** release.
- Documentation, checksum, or data-only fixes are a **patch** release.
- Keep `TOOLBOX_RELEASE_TAG` in `src/lib/toolbox.ts` equal to the public tag.

## Sync

From the private repository:

```bash
npm run export:satellite
SATELLITE_RELEASE_TAG=v0.3.0 npm run sync:satellite
```

The sync script rebuilds all generated files, commits them, pushes `main`, and
pushes the tag. The public `Release` workflow then builds
`netcup-toolbox-<tag>.tar.gz`, writes its `.sha256`, verifies `CHECKSUMS.txt`,
and attaches all three assets to the GitHub release.

## Verification

```bash
tag=v0.3.0
curl -fsSLO "https://github.com/depavel/netcup-toolbox/releases/download/${tag}/netcup-toolbox-${tag}.tar.gz"
curl -fsSLO "https://github.com/depavel/netcup-toolbox/releases/download/${tag}/netcup-toolbox-${tag}.tar.gz.sha256"
sha256sum -c "netcup-toolbox-${tag}.tar.gz.sha256"
tar -xzf "netcup-toolbox-${tag}.tar.gz"
cd "netcup-toolbox-${tag}"
sha256sum -c CHECKSUMS.txt
```

## Definition of done

- [ ] `npm run export:satellite` regenerates the public tree.
- [ ] `npm run typecheck`, `npm run lint`, `npm run test`, and the public CI pass.
- [ ] Every new script has `--help` and a `--self-test` where parsing or
      calculation is involved.
- [ ] Mutating scripts support `--dry-run` and an explicit confirmation flag.
- [ ] `README.md`, `ROADMAP.md`, `CHANGELOG.md`, and `data/meta.json` are current.
- [ ] No single-use voucher codes, credentials, origin IPs, or private hostnames
      are present.
- [ ] The release archive and `CHECKSUMS.txt` verify from a clean directory.
