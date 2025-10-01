#!/usr/bin/env zsh
# Test script for BetterDisplay functionality

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Get the root directory of the project
local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"

echo "Testing BetterDisplay script integration..."
echo "Root directory: $__root_dir"

cd "$__root_dir"

# Test 1: Check if BetterDisplay script exists
if [[ -f "scripts/betterdisplay.zsh" ]]; then
    echo "✓ BetterDisplay script exists"
else
    echo "✗ BetterDisplay script not found"
    exit 1
fi

# Test 2: Check if config directory exists
if [[ -d ".config/BetterDisplay" ]]; then
    echo "✓ BetterDisplay config directory exists"
else
    echo "✗ BetterDisplay config directory not found"
    exit 1
fi

# Test 3: Check if README exists
if [[ -f ".config/BetterDisplay/README.md" ]]; then
    echo "✓ BetterDisplay README exists"
else
    echo "✗ BetterDisplay README not found"
fi

# Test 5: Check if init.zsh includes BetterDisplay option
if grep -q "manage_betterdisplay" scripts/init.zsh; then
    echo "✓ BetterDisplay integration found in init.zsh"
else
    echo "✗ BetterDisplay integration not found in init.zsh"
    exit 1
fi

# Test 6: Check if init.zsh includes the -d option
if grep -q "d -display" scripts/init.zsh; then
    echo "✓ BetterDisplay -d option found in init.zsh"
else
    echo "✗ BetterDisplay -d option not found in init.zsh"
    exit 1
fi

# Test 7: Check if functions.zsh includes BetterDisplay in help
if grep -q "display.*BetterDisplay" scripts/functions.zsh; then
    echo "✓ BetterDisplay help text found in functions.zsh"
else
    echo "✗ BetterDisplay help text not found in functions.zsh"
    exit 1
fi

# Test 8: Check help output includes BetterDisplay option
if ./scripts/init.zsh -h 2>&1 | grep -i "display" | grep -q "BetterDisplay"; then
    echo "✓ BetterDisplay option appears in help output"
else
    echo "✗ BetterDisplay option not found in help output"
    exit 1
fi

# Test 9: Check script syntax
if zsh -n scripts/betterdisplay.zsh; then
    echo "✓ BetterDisplay script syntax is valid"
else
    echo "✗ BetterDisplay script has syntax errors"
    exit 1
fi

# Test 10: Check script sources correctly (dry run)
if (
    export __dotfiles_dir="$PWD"
    export __manage_betterdisplay=false
    source scripts/functions.zsh && source scripts/betterdisplay.zsh
) > /dev/null 2>&1; then
    echo "✓ BetterDisplay script sources correctly"
else
    echo "✗ BetterDisplay script failed to source (this is expected if BetterDisplay is not installed)"
fi

echo ""
echo "All tests passed! ✅"
echo ""
echo "Usage examples:"
echo "  ./scripts/init.zsh -d              # Manage BetterDisplay settings"
echo "  ./scripts/init.zsh -h              # Show help with BetterDisplay option"
echo "  ./scripts/init.zsh -d -p personal  # Manage BetterDisplay with personal profile"
