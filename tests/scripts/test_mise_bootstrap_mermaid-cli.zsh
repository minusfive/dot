#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Mermaid CLI tool module..."
local __config="home/.config/mise/conf.d/mermaid-cli.toml"
assert_tool_module mermaid-cli '"npm:@mermaid-js/mermaid-cli"'
grep -qF 'PUPPETEER_SKIP_DOWNLOAD = "1"' "$__config" ||
    fail "Puppeteer download setting is missing"
echo "Mermaid CLI tool module passed."
