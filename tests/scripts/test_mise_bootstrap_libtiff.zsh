#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing libtiff package bootstrap configuration..."
assert_module_package libtiff brew:libtiff
echo "libtiff package bootstrap configuration passed."
