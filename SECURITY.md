# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| `v0.2.x` | Yes |
| `v0.1.x` | No |

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's
private security advisory form on this repository, or email
`info@netcupgutscheine.com` with:

- the affected script and version or commit;
- a minimal reproduction;
- the impact you observed;
- any suggested fix.

Do not include real Netcup API keys, customer numbers, passwords, or private
server addresses in a report.

## Scope and safe use

These scripts can change firewall, network, DNS, and kernel settings. Review
every script before running it, test on a disposable server, and keep an
out-of-band console available.

`netcup-init.sh` can install Docker. Docker publishes container ports through
its own iptables rules and can bypass UFW. Review `DOCKER-USER` rules before
exposing containers.

`netcup-dns-sync.sh` reads credentials from environment variables. It never
writes them to disk or logs, but environment variables can be visible to
privileged local users. Run it as a dedicated user where possible.
