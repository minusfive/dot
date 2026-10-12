#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing yq package bootstrap configuration..."
assert_module_package yq brew:yq
echo "yq package bootstrap configuration passed."
