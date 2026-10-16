#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Google Chrome package bootstrap configuration..."
assert_module_package google-chrome brew-cask:google-chrome
echo "Google Chrome package bootstrap configuration passed."
