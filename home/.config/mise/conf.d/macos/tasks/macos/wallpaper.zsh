#!/usr/bin/env zsh
#MISE description="Apply the configured macOS wallpaper"
#MISE quiet=true
set -euo pipefail

__project_root="$(git -C "${MISE_PROJECT_ROOT:-${MISE_ORIGINAL_CWD:-$PWD}}" rev-parse --show-toplevel)"
wallpaper set "$__project_root/assets/wallpaper.png" --fill-color "$MACOS_WALLPAPER_COLOR"
