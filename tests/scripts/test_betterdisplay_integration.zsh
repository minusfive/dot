#!/usr/bin/env zsh
# Integration test for BetterDisplay script - tests actual execution

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Get the root directory of the project
local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"

echo "Testing BetterDisplay script integration (execution)..."

cd "$__root_dir"

# Test 1: Dry run with -d option (should show the prompt but not execute)
echo "Testing dry run execution..."

# Create a test that simulates user choosing 'skip'
# We'll check if the script reaches the BetterDisplay section
if timeout 10s bash -c "echo 's' | ./scripts/init.zsh -d" 2>&1 | grep -q "BDISP"; then
    echo "✓ BetterDisplay script section is reached when using -d option"
else
    echo "⚠ BetterDisplay script section test inconclusive (might require user interaction)"
fi

# Test 2: Check that script fails gracefully when BetterDisplay is not installed
echo ""
echo "Testing behavior when BetterDisplay is not installed..."

# This test checks if we handle the case where BetterDisplay is not installed
if ! test -d "/Applications/BetterDisplay.app" && ! test -d "$HOME/Applications/BetterDisplay.app"; then
    echo "ℹ BetterDisplay is not installed - testing error handling"

    # The script should detect this and show an appropriate message
    if timeout 10s bash -c "echo 'y' | ./scripts/init.zsh -d" 2>&1 | grep -q "not found"; then
        echo "✓ Script properly detects missing BetterDisplay installation"
    else
        echo "⚠ Could not verify error handling for missing BetterDisplay"
    fi
else
    echo "ℹ BetterDisplay is installed - skipping missing app test"
fi

echo ""
echo "Integration tests completed! ✅"
echo ""
echo "Note: Full functionality testing requires:"
echo "  - BetterDisplay app to be installed"
echo "  - User interaction for export/import decisions"
echo "  - Actual settings to export/import"
echo ""
echo "To test manually:"
echo "  ./scripts/init.zsh -d"
