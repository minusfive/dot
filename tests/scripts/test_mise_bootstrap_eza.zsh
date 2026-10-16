#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing eza package bootstrap configuration..."
assert_module_package eza brew:eza
echo "eza package bootstrap configuration passed."
