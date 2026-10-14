#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing stylua tool module..."
assert_tool_module stylua 'stylua = "latest"'
echo "stylua tool module passed."
