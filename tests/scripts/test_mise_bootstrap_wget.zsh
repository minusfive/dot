#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing wget package bootstrap configuration..."
assert_module_package wget brew:wget
echo "wget package bootstrap configuration passed."
