#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Docker Desktop package bootstrap configuration..."
assert_module_package docker-desktop brew-cask:docker-desktop
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/docker-desktop"' home/.config/mise/conf.d/module-docker-desktop.toml ||
    fail "Docker Desktop zshrc edit is missing"
echo "Docker Desktop package bootstrap configuration passed."
