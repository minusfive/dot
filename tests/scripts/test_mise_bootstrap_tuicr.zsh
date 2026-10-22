#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing tuicr tool module..."
assert_tool_module tuicr '"github:agavra/tuicr" = "latest"'
echo "tuicr tool module passed."
