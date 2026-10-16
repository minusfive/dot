#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing WhatsApp package bootstrap configuration..."
assert_personal_module_package whatsapp brew-cask:whatsapp
echo "WhatsApp package bootstrap configuration passed."
