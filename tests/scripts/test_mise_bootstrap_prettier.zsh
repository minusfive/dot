#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing prettier tool module..."
assert_tool_module prettier 'prettier = "latest"'
echo "prettier tool module passed."
