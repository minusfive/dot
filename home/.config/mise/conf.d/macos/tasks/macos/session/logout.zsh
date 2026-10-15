#!/usr/bin/env zsh
#MISE description="Log out of the current macOS session"
#MISE quiet=true

set -euo pipefail

osascript -e 'tell application "System Events" to log out'
