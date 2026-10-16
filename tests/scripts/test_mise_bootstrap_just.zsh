#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing just package bootstrap configuration..."
assert_module_package just brew:just
echo "just package bootstrap configuration passed."
