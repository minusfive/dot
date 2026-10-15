#!/usr/bin/env zsh
#MISE description="Restart Safari when it is running"
#MISE quiet=true
set -euo pipefail

if pgrep -x Safari >/dev/null 2>&1; then
    killall -q Safari 2>/dev/null || true
    sleep 2
    open --background -a Safari
fi
