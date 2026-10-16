#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing go tool module..."
assert_tool_module go 'go = "latest"'
echo "go tool module passed."
