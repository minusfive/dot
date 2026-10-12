#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing vivid package bootstrap configuration..."
assert_module_package vivid brew:vivid
echo "vivid package bootstrap configuration passed."
