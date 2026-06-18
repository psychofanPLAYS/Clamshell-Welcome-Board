# vhs tape — records the welcome board slam-in animation for the README.
# Uses tools/showcase-env.sh so the GIF shows a rich PUBLIC-SAFE board (no real IPs).
Output docs/screenshots/welcome-board.gif
Require bash
Set Shell bash
Set FontFamily "DejaVu Sans Mono"
Set FontSize 13
Set Width 1340
Set Height 1780
Set Padding 20
Set Theme { "name": "wb", "background": "#0c0c10", "foreground": "#cfd2d6", "black": "#0c0c10", "white": "#cfd2d6", "brightWhite": "#ffffff", "cyan": "#5fd7ff", "green": "#5fd787", "yellow": "#ffd75f", "red": "#ff5f87", "blue": "#5f87ff", "magenta": "#ff87d7" }
Set LoopOffset 35%
Hide
Type "bash tools/showcase-env.sh /tmp/wbshow >/dev/null 2>&1" Enter
Type "export WELCOME_BOARD_CONFIG=/tmp/wbshow/config; export PATH=/tmp/wbshow/bin:$PATH" Enter
Type "source welcome-board.sh" Enter
Type "clear" Enter
Sleep 300ms
Show
Sleep 700ms
Type "clamboard --animate"
Sleep 400ms
Enter
Sleep 4500ms
