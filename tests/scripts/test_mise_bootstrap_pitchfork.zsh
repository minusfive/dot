#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing pitchfork tool module..."
assert_tool_module pitchfork 'pitchfork = "latest"'
echo "pitchfork tool module passed."
