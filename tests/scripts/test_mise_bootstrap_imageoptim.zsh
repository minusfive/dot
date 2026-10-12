#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing ImageOptim package bootstrap configuration..."
assert_module_package imageoptim brew-cask:imageoptim
echo "ImageOptim package bootstrap configuration passed."
