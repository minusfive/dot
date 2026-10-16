#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bun tool module..."
assert_tool_module bun 'bun = "latest"'
echo "bun tool module passed."
