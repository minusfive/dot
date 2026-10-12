#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Docker Desktop package bootstrap configuration..."
assert_module_package docker-desktop brew-cask:docker-desktop
echo "Docker Desktop package bootstrap configuration passed."
