#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing ghostscript package bootstrap configuration..."
assert_module_package ghostscript brew:ghostscript
echo "ghostscript package bootstrap configuration passed."
