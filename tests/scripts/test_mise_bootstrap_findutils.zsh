#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing findutils package bootstrap configuration..."
assert_module_package findutils brew:findutils
echo "findutils package bootstrap configuration passed."
