#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing pkl-lsp package bootstrap configuration..."
assert_module_package pkl-lsp brew:pkl-lsp
echo "pkl-lsp package bootstrap configuration passed."
