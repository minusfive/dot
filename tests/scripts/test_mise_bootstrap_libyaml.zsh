#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing libyaml package bootstrap configuration..."
assert_module_package libyaml brew:libyaml
echo "libyaml package bootstrap configuration passed."
