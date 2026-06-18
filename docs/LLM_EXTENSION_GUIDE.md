# LLM Extension Guide

Use this guide when Codex, Claude, or another AI agent edits this repo.

## Hard Rules

- Keep shell startup fast. Any network or slow command needs a timeout.
- Keep rows aligned. Render a stripped preview before claiming a visual change works.
- Keep personal data out of committed defaults.
- Add config instead of hardcoding one user's machine names, IPs, paths, or aliases.
- Do not mutate firewall rules, SSH settings, system services, or login shell files without showing the user the exact change first.
- Do not add a new section unless it can fail gracefully.
- Do not invent Hermes, OpenClaw, tmux, path, host, or port facts. Ask and configure them.

For the section contract, custom command format, graph rules, and personalization examples, read [SECTION_SDK.md](SECTION_SDK.md).

## Row Layout

Machine rows use this shape:

```text
LABEL BAR      NOW  GRAPH     DETAIL
CPU   ██░░░░░░ 32%  ▁▁▁▁▁▂▂▃  CPU model · clock
```

Keep these columns stable:

- label: 5 characters plus one space
- bar: 8 cells
- percent: 3 digits plus `%`
- graph: 8 cells
- detail: remaining width

Do not add explanatory row labels after the graph. Section headers provide context.

## Adding A Section

1. Add a probe function that returns plain values.
2. Add a render function that accepts missing values.
3. Gate the section behind config.
4. Add a test or smoke render.
5. Run:

```bash
bash -n welcome-board.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
git diff --check
```

## Section Quality Bar

A section is good when:

- It answers a real question in one glance.
- It fits inside the frame.
- It still looks good with missing data.
- It does not make startup feel slower.
- It avoids private project language unless the user configured it.

## Theme Rules

Themes should define colors only. They should not change layout.

Supported themes:

- `cyan-dark`
- `amber-terminal`
- `green-phosphor`
- `light-paper`
- `mono-safe`

Every theme needs a color-stripped render test and one color-preserved manual preview before release.

## Public Release Checklist

Before making this repository public:

- Run a secret scan.
- Remove hardcoded private IPs, private hostnames, and personal names from defaults.
- Move personal shortcuts into example config files.
- Add a license.
- Add installer tests.
- Verify Linux install from a clean temp home.
- Verify macOS behavior or clearly mark macOS as experimental.
