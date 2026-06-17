# Port Security Model

This project can help a user understand listening ports and prepare a lockdown discussion, but this version must stay read-only.

## Rule

Never close ports, change firewall rules, edit SSH settings, or block inbound traffic from this repo's current commands. A future mutating version needs a separate design, tests, explicit user approval, and rollback receipts.

## Safe Flow

1. **Scan**
   - Linux: prefer `ss -tulpen` or `ss -tuln`.
   - macOS: prefer `lsof -iTCP -sTCP:LISTEN -P -n` plus UDP where needed.
   - Capture port, protocol, bind address, process name, PID when available, and whether it is loopback-only.

2. **Explain**
   - Group obvious services: SSH, web dev servers, Docker, Postgres, Redis, printer sharing, media servers, Tailscale, and unknown ports.
   - Explain risk in plain language.
   - Do not call a port unsafe just because it is open.

3. **Ask**
   - Ask which ports the user intentionally uses.
   - Offer a generated allowlist.
   - Treat SSH and remote-access tools as high-risk to modify.

4. **Plan**
   - Print a dry-run review plan.
   - Do not write files.
   - Do not print commands that could be pasted blindly.
   - Do not execute anything.

## What The Welcome Board May Show

The board may show a non-mutating summary:

```text
PORTS  open 22/3000/5432 · exposed 22 · loopback 3000/5432
```

It may also show a warning:

```text
PORTS  check 0.0.0.0:3000 · run wb ports scan
```

## What The Welcome Board Must Not Do

- Must not run `ufw enable`, `pfctl`, `iptables`, `nft`, or cloud firewall changes on shell startup.
- Must not block Docker, Tailscale, SSH, or local dev servers automatically.
- Must not infer that every non-loopback listener is malicious.
- Must not print secrets, tokens, or environment values.

## Commands

```bash
wb ports scan       # read-only raw scanner output
wb ports explain    # read-only classification and plain-language notes
wb ports plan       # prints a dry-run plan; writes and applies nothing
```

Current implementation status:

- `scan`, `explain`, and `plan` exist.
- `plan` does not write files and does not print commands such as `ufw enable`.
- `apply` and `rollback` are intentionally refused because they would mutate firewall state.

## Public Repo Requirement

Any port-security feature must ship with tests for:

- Loopback-only listeners.
- LAN-exposed listeners.
- SSH present.
- Unknown process names.
- Dry-run plan generation.
- Refusal to apply without approval.

Any future mutating feature must also test rollback receipt creation, SSH lockout protection, and refusal to run from shell startup.
