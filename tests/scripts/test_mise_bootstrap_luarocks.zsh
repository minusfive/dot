#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing luarocks package bootstrap configuration..."
assert_module_package luarocks brew:luarocks
echo "luarocks package bootstrap configuration passed."
