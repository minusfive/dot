#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Discord package bootstrap configuration..."
assert_personal_module_package discord brew-cask:discord
echo "Discord package bootstrap configuration passed."
