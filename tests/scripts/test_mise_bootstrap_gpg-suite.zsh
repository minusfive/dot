#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GPG Suite package bootstrap configuration..."
assert_module_package gpg-suite brew-cask:gpg-suite
echo "GPG Suite package bootstrap configuration passed."
