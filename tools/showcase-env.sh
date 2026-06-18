#!/usr/bin/env bash
# Populate a directory with a PUBLIC-SAFE demo environment (generic identity +
# mock network/session/automation tools) so the README screenshot + GIF show a
# rich board WITHOUT leaking real IPs, hostnames, or logins.
# Usage: tools/showcase-env.sh <dir>   then:
#   export WELCOME_BOARD_CONFIG=<dir>/config  PATH=<dir>/bin:$PATH
set -euo pipefail
DIR="${1:?usage: showcase-env.sh <dir>}"
mkdir -p "$DIR/bin"

cat > "$DIR/config" <<'CFG'
WB_DISPLAY_NAME="Alex"
WB_SERVICE_PORTS="ssh:22 webdash:6900 embedder:6901 reranker:6902 vector-db:6333 gateway:6913 api:6916 cockpit:36900"
WB_PEERS="laptop|laptop|10.0.0.15:8080 server|server|10.0.0.20:6911"
WB_AUTOMATION_LABEL="ingest · backups · agents"
WB_AUTOMATION_DAILY="digest 07:00 · index 01:30 · sync 03:00"
CFG

cat > "$DIR/bin/hostname" <<'E'
#!/usr/bin/env bash
[ "${1:-}" = "-I" ] && { printf '10.0.0.10\n'; exit 0; }
printf 'workstation\n'
E
cat > "$DIR/bin/tailscale" <<'E'
#!/usr/bin/env bash
cat <<'EOF'
10.0.0.10 workstation user linux -
10.0.0.15 laptop user macOS active
10.0.0.20 server user linux active
EOF
E
cat > "$DIR/bin/who" <<'E'
#!/usr/bin/env bash
printf 'user pts/0 2026-01-01 09:00 (10.0.0.15)\n'
E
cat > "$DIR/bin/ss" <<'E'
#!/usr/bin/env bash
cat <<'EOF'
LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=1,fd=3))
LISTEN 0 128 0.0.0.0:5000 0.0.0.0:* users:(("flask",pid=2,fd=3))
LISTEN 0 128 127.0.0.1:6900 0.0.0.0:* users:(("python",pid=3,fd=3))
LISTEN 0 128 127.0.0.1:6901 0.0.0.0:* users:(("python",pid=4,fd=3))
LISTEN 0 128 127.0.0.1:6902 0.0.0.0:* users:(("python",pid=5,fd=3))
LISTEN 0 128 127.0.0.1:6333 0.0.0.0:* users:(("qdrant",pid=6,fd=3))
LISTEN 0 128 127.0.0.1:6913 0.0.0.0:* users:(("python",pid=7,fd=3))
LISTEN 0 128 127.0.0.1:6916 0.0.0.0:* users:(("python",pid=8,fd=3))
LISTEN 0 128 127.0.0.1:36900 0.0.0.0:* users:(("python",pid=9,fd=3))
EOF
E
cat > "$DIR/bin/tmux" <<'E'
#!/usr/bin/env bash
[ "${1:-}" = "ls" ] && { printf 'work: 2 windows (attached)\nagents: 1 windows\n'; exit 0; }
exit 0
E
cat > "$DIR/bin/systemctl" <<'E'
#!/usr/bin/env bash
case "$*" in
  *show-environment*) exit 0 ;;
  *list-timers*)
    cat <<'EOF'
NEXT                        LEFT       LAST  PASSED UNIT                  ACTIVATES
Tue 2026-01-01 09:05:00 UTC 5min       -     -      indexer.timer         indexer.service
Tue 2026-01-01 09:30:00 UTC 30min      -     -      backup.timer          backup.service
Tue 2026-01-01 10:00:00 UTC 1h         -     -      sync.timer            sync.service
3 timers listed.
EOF
    ;;
  *) exit 0 ;;
esac
E
cat > "$DIR/bin/crontab" <<'E'
#!/usr/bin/env bash
printf '0 7 * * * /usr/local/bin/digest\n30 1 * * * /usr/local/bin/index\n0 3 * * * /usr/local/bin/sync\n0 * * * * /usr/local/bin/agent-loop\n'
E
chmod +x "$DIR/bin"/*
