#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GitHub Copilot tool module..."
assert_tool_module github-copilot '"npm:@github/copilot" = "latest"'
echo "GitHub Copilot tool module passed."
