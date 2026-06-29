# Security Policy

## Supported Versions

This project is pre-1.0. Security fixes should target the current `main` branch until tagged releases exist.

## Scope

Please report security issues that could affect users of the welcome board, installer, CLI helpers, tests, or documentation.

Relevant examples:

- shell command injection
- unsafe shell startup edits
- accidental secret or environment-value printing
- personal data committed into defaults
- commands that mutate firewall, SSH, service, or port state unexpectedly
- install behavior that writes outside the documented user-owned paths

## Port And Firewall Boundary

No firewall changes are implemented in this version.

Welcome Board is user-local terminal software. It does not install a daemon,
listen on a socket, expose a web UI, enable tunnels, or open ports. The
installer copies files into user-owned paths and prints shell-startup lines for
review instead of editing shell startup files itself.

The `wb` helper refuses unexpected board script paths by default; set
`WELCOME_BOARD_ALLOW_UNTRUSTED_BOARD_FILE=1` only for local development after
reviewing the file.

The port helpers are read-only:

```bash
wb ports scan
wb ports explain
wb ports plan
```

`wb ports scan`, `wb ports explain`, and `wb ports plan` must not run `ufw`, `pfctl`, `iptables`, `nft`, cloud firewall commands, SSH edits, service edits, or any command that closes or opens ports.

## Reporting

If the repository is still private, report issues directly to the repository owner.

If the repository is public, open a GitHub issue for non-sensitive problems. For sensitive findings, request a private contact channel first.

Do not report secrets, tokens, private keys, private IP lists, or exploit payloads in public issues.

## Safe Testing

When testing security behavior:

- use temporary homes and fake command fixtures when possible
- do not run tests against a production shell startup file
- do not enable, disable, or reload a real firewall
- do not change SSH settings
- do not require root privileges

## Maintainer Checklist

Before public release:

- add a `LICENSE`
- keep GitHub Actions green on Linux and macOS
- run the public safety scan from README or release notes
- verify `wb doctor`
- verify port commands are read-only
- confirm GitHub visibility changes have explicit owner approval
