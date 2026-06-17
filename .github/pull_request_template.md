## Summary

- TBD

## Expected Behavior

- TBD

## Platform Impact

- Linux:
- macOS:

## Verification

```bash
bash -n welcome-board.sh bin/wb bin/welcomeboard install.sh
python3 -m py_compile codex-claude-daily-update
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

## Safety

- [ ] This keeps port commands read-only unless explicitly approved.
- [ ] This does not change firewall, SSH, service, cron, shell-startup, license, or repository visibility settings.
- [ ] This does not add secrets, private IPs, private hostnames, private paths, or personal defaults.
- [ ] Missing optional tools degrade gracefully.
