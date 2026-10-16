#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Obsidian package bootstrap configuration..."
assert_module_package obsidian brew-cask:obsidian
echo "Obsidian package bootstrap configuration passed."
