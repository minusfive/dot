#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing SoftRAID package bootstrap configuration..."
assert_personal_module_package softraid brew-cask:softraid
echo "SoftRAID package bootstrap configuration passed."
