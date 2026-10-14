#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Mermaid formatter tool module..."
assert_tool_module mermaid-formatter '"npm:mermaid-formatter" = "latest"'
echo "Mermaid formatter tool module passed."
