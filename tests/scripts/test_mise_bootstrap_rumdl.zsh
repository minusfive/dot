#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing rumdl tool module..."
assert_tool_module rumdl 'rumdl = "latest"'
echo "rumdl tool module passed."
