#!/usr/bin/env zsh
#MISE description="Move Desktop screenshots to the configured screenshots directory"
#MISE quiet=true
set -euo pipefail

mkdir -p "$MACOS_SCREENSHOTS_DIR"

for __screenshot in "$HOME"/Desktop/Screenshot*(N); do
    mv "$__screenshot" "$MACOS_SCREENSHOTS_DIR/"
done
