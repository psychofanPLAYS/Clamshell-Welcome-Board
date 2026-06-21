# Port Security Model

This project can help a user understand listening ports, notice drift, and prepare a lockdown discussion, but this version must stay read-only.

## Rule

Never close ports, change firewall rules, edit SSH settings, or block inbound traffic from this repo's current commands. A future mutating version needs a separate design, tests, explicit user approval, and rollback receipts. Default-deny firewall work belongs in that separate reviewed plan, not in shell startup.

Welcome Board itself must not become a network surface: no daemon, no listening
socket, no public tunnel, no web UI, and no automatic firewall or service
mutation.

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

5. **Snapshot**
   - After the user reviews the listener set, `wb ports snapshot` saves the current summarized listeners as the warning baseline.
   - Later board renders compare the live listener set to that baseline and warn when previously unseen listeners appear.
   - Snapshot does not change firewall rules, services, SSH, or running sockets.

## What The Welcome Board May Show

The board may show a non-mutating summary:

```text
SECURITY  LAN/ALL 2 exposed · SSH:22(sshd) common dev server:8080(python)
```

It may also show a warning:

```text
SECURITY  new open 1 changed · common dev server:8080(python)
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
wb ports snapshot   # saves reviewed listener baseline; no firewall changes
```

Current implementation status:

- `scan`, `explain`, `plan`, and `snapshot` exist.
- `plan` does not write files and does not print commands such as `ufw enable`.
- `snapshot` writes only the reviewed baseline file used for warnings.
- `apply` and `rollback` are intentionally refused because they would mutate firewall state.

## Public Repo Requirement

Any port-security feature must ship with tests for:

- Loopback-only listeners.
- LAN-exposed listeners.
- SSH present.
- Unknown process names.
- Dry-run plan generation.
- Baseline snapshot generation.
- Newly open listener warnings.
- Refusal to apply without approval.

Any future mutating feature must also test rollback receipt creation, SSH lockout protection, and refusal to run from shell startup.
