#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing tectonic package bootstrap configuration..."
assert_module_package tectonic brew:tectonic
echo "tectonic package bootstrap configuration passed."
