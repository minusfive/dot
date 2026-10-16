#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing rust tool module..."
assert_tool_module rust 'rust = "nightly"'
grep -qF 'cargo-binstall = "latest"' home/.config/mise/conf.d/module.rust.toml ||
    fail "cargo-binstall is missing from the Rust module"
echo "rust tool module passed."
