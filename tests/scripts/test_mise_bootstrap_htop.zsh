#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing htop package bootstrap configuration..."
assert_module_package htop brew:htop
echo "htop package bootstrap configuration passed."
