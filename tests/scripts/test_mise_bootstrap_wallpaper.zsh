#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing wallpaper package bootstrap configuration..."
assert_module_package wallpaper brew:wallpaper
echo "wallpaper package bootstrap configuration passed."
