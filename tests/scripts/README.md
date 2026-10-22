# Script Tests

This directory contains tests for the various setup scripts in the `/scripts` directory.

## Available Tests

### BetterDisplay Tests

#### `test_mise_bootstrap_betterdisplay.zsh`

Tests the `BetterDisplay` package and tracked property-list ownership. It also checks local task discovery, the absence of global task links, and the absence of launch-agent or timer declarations.

#### `test_mise_task_betterdisplay_sync.zsh`

Tests the local `betterdisplay:sync` task with isolated command mocks. The cases cover default export, `--import`, `-i`, native confirmation, non-interactive confirmation, property-list validation, source identity checks, backup ordering and errors, application lifecycle, recovery, and the absence of `Git` calls.

### mise Configuration Tests

#### `test_mise_config.zsh`

Tests global mise configuration, rendered profile selection, repository-scoped lifecycle wiring, initialization phase ordering, and Git ignore bootstrap behavior.

The source file `home/.config/git/ignore` is not a repository `.gitignore`. Mise links it to `$XDG_CONFIG_HOME/git/ignore`, where Git reads the global excludes file. The test uses a temporary home to verify that mise installs this source file and that its patterns affect Git.

#### `test_mise_bootstrap_lifecycle.zsh`

Tests the canonical `system:bootstrap` task, native profile choices, confirmation, profile persistence, dry-run behavior, self-update, and failure stops.

#### `test_mise_bootstrap_compatibility.zsh`

Tests `scripts/install-mise.zsh` help, official installation checks, clean-home acquisition, and source-safe environment setup.

#### `test_mise_task_gh_auth_login.zsh`

Tests hostname forwarding, idempotent authentication, failed login handling, control-plane ownership, and the authentication dependency boundary.

#### `test_mise_task_git_auth_setup.zsh`

Tests profile and hostname selection, separate authentication stores, helper reset behavior, explicit failure paths, and control-plane ownership.

#### `test_git_config_check.zsh`

Tests domain parsing, hostname matching, tracked Git config ownership, shared-host helper rejection, pre-commit integration, and value redaction.

#### `test_mise_bootstrap_copilot.zsh`

Tests the Copilot module ownership, exactly nine safe settings, isolated key-level merge behavior, shared-instructions and statusline links, and runtime preservation.

#### `test_mise_bootstrap_agents.zsh`

Tests the shared agent files, durable evaluation metadata, relative links, and generated-output exclusions.

#### `test_mise_bootstrap_claude.zsh`

Tests the Claude settings, canonical shared skills source, statusline link, generated-output exclusion, and runtime preservation.

#### `test_mise_bootstrap_opencode.zsh`

Tests the personal-only OpenCode Homebrew package, tracked configuration, plugin links, and preserved target-local runtime dependencies.

#### `test_mise_bootstrap_gh.zsh`

Tests GitHub package and post-packages hook declarations, files, directories, source paths, permissions, token-free configuration, and `GH_CONFIG_DIR` merge entries.

#### `test_mise_bootstrap_editorconfig.zsh`

Tests the global EditorConfig link.

The remaining migrated application boundaries use the same focused-test pattern: `test_mise_bootstrap_<module>.zsh`. Current module tests cover `1password`, `bat`, `btop`, `coreutils`, `curl`, `delta`, `editorconfig`, `fd`, `findutils`, `fzf`, `ghostty`, `git`, `gnu-sed`, `hammerspoon`, `harper`, `lazygit`, `nvim`, `p10k`, `ripgrep`, `tmux`, `wezterm`, `yarn`, `yazi`, and `zsh`.

The `Oh My Zsh` test covers its custom plugin repositories. The `Neovim` test covers the LazyVim repository.

Each package module has a focused package assertion in its matching module test.

#### `test_mise_bootstrap_brew.zsh`

Tests Homebrew adoption and shared profile selection for `module.brew.toml`.

#### `test_mise_bootstrap_macos.zsh`

Tests native macOS preferences, the post-defaults hook, platform loading, and the remaining imperative OS operations.

Manual macOS operations are exposed as global mise tasks under the `macos:` prefix.

#### `test_mise_task_mise_cleanup.zsh`

Tests that the final cleanup task removes stale repository-managed links and blocks while preserving active and external entries.

The cleanup task uses `cleanup.paths` and `cleanup.blocks`, which the inventory task updates from current and historical module declarations.

#### `test_mise_task_mise_cleanup_inventory.zsh`

Tests that the cleanup inventory includes current and historical paths without widening the scan to the whole development directory.

#### `test_mise_task_pr_review_watch.zsh`

Tests transactional review-watch add, remove, and poll actions with isolated `gh` stubs, including paginated comment collection, timestamp cutoffs, normalized check statuses, malformed data warnings, state preservation, atomic writes, lock handling, merged/closed cleanup, and stable JSON output.

#### `test_mise_bootstrap_packages.zsh`

Tests the shared package maintenance hook and profile selection for `module.packages.toml`.

#### `test_mise_bootstrap_discord.zsh`, `test_mise_bootstrap_softraid.zsh`, `test_mise_bootstrap_whatsapp.zsh`

Tests personal-only package selection for each personal cask module.

#### `test_mise_bootstrap_<module>.zsh`

Tests one `home/.config/mise/conf.d/module.<module>.toml` boundary. The tool-module tests cover `bun`, `delta`, `go`, `github-copilot`, `mermaid-cli`, `mermaid-formatter`, `mise`, `node`, `pitchfork`, `prettier`, `python`, `qmd`, `ruby`, `rumdl`, `rust`, `stylua`, and `tree-sitter`.

#### `test_mise_skill_evals.zsh`

Tests the grouped evaluation init, prepare, and validate tasks, canonical specifications, repository-local workspaces, ignore rules, and symlink rejection.

#### `test_agentic_projects.zsh`

Tests hidden project creation and promotion to a checked-in workspace.

## Running Tests

### Run All Script Tests

```bash
# From project root
zsh tests/scripts/test_mise_bootstrap_betterdisplay.zsh
zsh tests/scripts/test_mise_task_betterdisplay_sync.zsh
zsh tests/scripts/test_git_config_check.zsh
./tests/scripts/test_mise_config.zsh
for test in tests/scripts/test_mise_bootstrap_*.zsh tests/scripts/test_mise_task_*.zsh; do
    zsh "$test"
done
./tests/scripts/test_mise_skill_evals.zsh
./tests/scripts/test_agentic_projects.zsh
```

### Run Individual Test Categories

```bash
# BetterDisplay ownership and task tests
zsh tests/scripts/test_mise_bootstrap_betterdisplay.zsh
zsh tests/scripts/test_mise_task_betterdisplay_sync.zsh
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

The import task uses the `mise` confirmation directive. Tests use isolated `mise` configuration and command mocks.

### External Dependencies

The BetterDisplay task tests do not use the installed application or live settings. They use isolated files and command mocks.

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
