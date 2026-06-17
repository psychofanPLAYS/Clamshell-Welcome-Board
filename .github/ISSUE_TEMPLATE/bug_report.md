---
name: Bug report
about: Report a problem with install, setup, rendering, or commands
title: "[Bug]: "
labels: bug
assignees: ""
---

## What Happened

Describe the problem.

## Expected Behavior

Describe what you expected to happen.

## Platform

- OS:
- Shell:
- Terminal:
- `bash --version`:
- `wb doctor` output:

## Steps To Reproduce

```bash
# Paste the smallest command sequence that shows the problem.
```

## Verification

Paste any checks you ran:

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
```

## Safety

Did this involve ports, SSH, firewall settings, services, shell startup files, or private machine details?

Do not paste secrets, tokens, private keys, or sensitive local paths.
