#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing curl package bootstrap configuration..."
assert_module_package curl brew:curl
echo "curl package bootstrap configuration passed."
