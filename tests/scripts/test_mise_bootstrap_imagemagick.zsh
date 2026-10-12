#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing ImageMagick package bootstrap configuration..."
assert_module_package imagemagick brew:imagemagick
echo "ImageMagick package bootstrap configuration passed."
