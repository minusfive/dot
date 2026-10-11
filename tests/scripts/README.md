# Script Tests

This directory contains tests for the various setup scripts in the `/scripts` directory.

## Available Tests

### BetterDisplay Tests

#### `test_betterdisplay.zsh`

Comprehensive unit tests for BetterDisplay integration:

- ✅ Script file existence
- ✅ Configuration directory structure
- ✅ Documentation files
- ✅ Integration with main init script
- ✅ Help text integration
- ✅ Script syntax validation
- ✅ Script sourcing capability

#### `test_betterdisplay_integration.zsh`

Integration tests for BetterDisplay script execution:

- ✅ Script execution flow
- ✅ Error handling for missing BetterDisplay app
- ⚠️ User interaction simulation (limited)

### mise Configuration Tests

#### `test_mise_config.zsh`

Tests global mise configuration, profile selection, task discovery, initialization phase ordering, and Git ignore bootstrap behavior.

The source file `.config/git/ignore` is not a repository `.gitignore`. GNU Stow links it to `$XDG_CONFIG_HOME/git/ignore`, where Git reads the global excludes file. The test uses a temporary home to verify that Stow installs this source file and that its patterns affect Git.

#### `test_mise_bootstrap_copilot.zsh`

Tests the Copilot module declaration, direct shared-instructions source, statusline link, and runtime preservation.

#### `test_mise_bootstrap_agents.zsh`

Tests the shared agent files, durable evaluation metadata, relative links, and generated-output exclusions.

#### `test_mise_bootstrap_claude.zsh`

Tests the Claude settings, canonical shared skills source, statusline link, generated-output exclusion, and runtime preservation.

#### `test_mise_bootstrap_opencode.zsh`

Tests the tracked OpenCode configuration and plugin links while preserving target-local runtime dependencies.

#### `test_mise_bootstrap_gh.zsh`

Tests GitHub bootstrap files, directories, source paths, permissions, and token-free configuration.

#### `test_mise_bootstrap_packages.zsh`

Tests shared package, cask, Mac App Store, and Homebrew bootstrap configuration.

#### `test_mise_bootstrap_packages_personal.zsh`

Tests personal package and cask separation from shared package configuration.

#### `test_mise_bootstrap_repos.zsh`

Tests repository bootstrap declarations.

#### `test_mise_tools.zsh`

Tests the development tool configuration.

#### `test_mise_migration_artifacts.zsh`

Tests migration decision cleanup and placement validation.

#### `test_agentic_projects.zsh`

Tests hidden project creation and promotion to a checked-in workspace.

## Running Tests

### Run All BetterDisplay Tests

```bash
# From project root
./tests/scripts/test_betterdisplay.zsh
./tests/scripts/test_betterdisplay_integration.zsh
./tests/scripts/test_mise_config.zsh
./tests/scripts/test_mise_bootstrap_copilot.zsh
./tests/scripts/test_mise_bootstrap_agents.zsh
./tests/scripts/test_mise_bootstrap_claude.zsh
./tests/scripts/test_mise_bootstrap_opencode.zsh
./tests/scripts/test_mise_bootstrap_gh.zsh
./tests/scripts/test_mise_bootstrap_packages.zsh
./tests/scripts/test_mise_bootstrap_packages_personal.zsh
./tests/scripts/test_mise_bootstrap_repos.zsh
./tests/scripts/test_mise_tools.zsh
./tests/scripts/test_mise_migration_artifacts.zsh
./tests/scripts/test_agentic_projects.zsh
```

### Run Individual Test Categories

```bash
# Unit tests only
./tests/scripts/test_betterdisplay.zsh

# Integration tests only
./tests/scripts/test_betterdisplay_integration.zsh
```

## Test Results Interpretation

### ✅ Pass

Test completed successfully and verified expected behavior.

### ⚠️ Warning/Inconclusive

Test completed but could not fully verify behavior (often due to missing dependencies or requiring user interaction).

### ✗ Fail

Test failed and indicates an issue that should be addressed.

## Testing Limitations

### User Interaction

Many scripts require user input and confirmation. Integration tests use simulation techniques but may not cover all interaction paths.

### External Dependencies

Some tests depend on external applications (like BetterDisplay) being installed. Tests attempt to handle missing dependencies gracefully.

### System State

Tests may behave differently based on current system configuration and installed software.

## Adding New Tests

When adding tests for new scripts:

1. Follow the naming convention: `test_<scriptname>.zsh`
2. Include both unit tests (file structure, syntax) and integration tests (execution)
3. Handle missing dependencies gracefully
4. Provide clear success/failure indicators
5. Include usage examples in test output

### Test Template

```bash
#!/usr/bin/env zsh
# Test script for <script_name> functionality

set -euo pipefail

local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"

echo "Testing <script_name> integration..."
cd "$__root_dir"

# Test 1: Basic checks
if [[ -f "scripts/<script_name>.zsh" ]]; then
    echo "✓ Script exists"
else
    echo "✗ Script not found"
    exit 1
fi

# Additional tests...

echo "All tests passed! ✅"
```
