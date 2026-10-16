#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing stow package bootstrap configuration..."
assert_module_package stow brew:stow
echo "stow package bootstrap configuration passed."
