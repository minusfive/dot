#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing zoxide package bootstrap configuration..."
assert_module_package zoxide brew:zoxide
echo "zoxide package bootstrap configuration passed."
