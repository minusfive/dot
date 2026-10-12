#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing dockutil package bootstrap configuration..."
assert_module_package dockutil brew:dockutil
echo "dockutil package bootstrap configuration passed."
