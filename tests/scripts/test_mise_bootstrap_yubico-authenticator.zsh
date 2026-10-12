#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Yubico Authenticator package bootstrap configuration..."
assert_module_package yubico-authenticator mas:1497506650
echo "Yubico Authenticator package bootstrap configuration passed."
