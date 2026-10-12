#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing coreutils package bootstrap configuration..."
assert_module_package coreutils brew:coreutils
echo "coreutils package bootstrap configuration passed."
