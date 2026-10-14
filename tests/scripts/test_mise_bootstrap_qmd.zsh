#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing qmd tool module..."
assert_tool_module qmd '"npm:@tobilu/qmd" = "latest"'
echo "qmd tool module passed."
