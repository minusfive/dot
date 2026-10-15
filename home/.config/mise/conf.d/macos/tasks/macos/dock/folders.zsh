#!/usr/bin/env zsh
#MISE description="Replace Dock folder tiles with Screenshots and Downloads"
#MISE quiet=true

set -euo pipefail

dockutil --remove all --no-restart
dockutil --add "$MACOS_SCREENSHOTS_DIR" --label "Screenshots" --replacing "Screenshots" \
    --section "others" --view "fan" --display "stack" --sort "dateadded" --no-restart
dockutil --add "$HOME/Downloads" --label "Downloads" --replacing "Downloads" \
    --after "Screenshots" --section "others" --view "fan" --display "stack" --sort "dateadded"
