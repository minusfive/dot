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

Tests global mise configuration, generated profile selection, repository-scoped lifecycle wiring, initialization phase ordering, and Git ignore bootstrap behavior.

The source file `home/.config/git/ignore` is not a repository `.gitignore`. Mise links it to `$XDG_CONFIG_HOME/git/ignore`, where Git reads the global excludes file. The test uses a temporary home to verify that mise installs this source file and that its patterns affect Git.

The target fixture links repository sources at `dev/personal/dot/home`. It isolates `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, and all `MISE_*_DIR` values. It trusts both fixture configuration files. It runs `mise -C <fixture-repository> -E <profile> bootstrap --only dotfiles --yes` for both profiles. Status queries set `MISE_SAFE=1` and `MISE_NO_HOOKS=1`. The fixture does not install packages or change host paths.

The `test_fixture_dir` helper creates unique hidden directories under the repository root. Each test removes its fixture on exit.

#### `test_mise_bootstrap_lifecycle.zsh`

Tests the native bootstrap command, profile previews, environment setup, failure boundaries, and retired task removal.

#### `test_mise_task_bootstrap.zsh`

Tests the `bootstrap:pre-packages`, `bootstrap:pre-dotfiles`, and `bootstrap:post-tools` lifecycle tasks, including profile validation, profile confirmation, tool upgrades, and reshim behavior.

#### `test_mise_bootstrap_compatibility.zsh`

Tests `scripts/install-mise.zsh` help, official installation checks, clean-home acquisition, and source-safe environment setup.

#### `test_mise_task_gh_auth_login.zsh`

Tests hostname forwarding, idempotent authentication, failed login handling, control-plane ownership, and the authentication dependency boundary.

#### `test_mise_task_git_auth_setup.zsh`

Tests profile and hostname selection, separate authentication stores, helper reset behavior, explicit failure paths, and control-plane ownership.

#### `test_git_config_check.zsh`

Tests domain parsing, hostname matching, tracked Git config ownership, shared-host helper rejection, pre-commit integration, and value redaction.

#### `test_mise_bootstrap_copilot.zsh`

Tests the Copilot module ownership, LSP and safe-settings merges, shared-instruction, statusline, and orchestrator links, and runtime preservation.

#### `test_mise_bootstrap_agents.zsh`

Tests the shared agent files, durable evaluation metadata, relative links, and generated-output exclusions.

#### `test_mise_bootstrap_claude.zsh`

Tests the Claude settings, shared skills source, statusline and orchestrator links, generated-output exclusion, and runtime preservation.

#### `test_mise_bootstrap_opencode.zsh`

Tests the personal-only OpenCode Homebrew package, tracked configuration, plugin links, and preserved target-local runtime dependencies.

#### `test_mise_bootstrap_gh.zsh`

Tests GitHub package and post-packages hook declarations, files, directories, source paths, permissions, token-free configuration, and `GH_CONFIG_DIR` merge entries.

#### `test_mise_bootstrap_hammerspoon.zsh`

The test covers `Hammerspoon` source links. It runs the `post-dotfiles` hook with a `defaults` stub. The stub records the configured target without changing macOS defaults.

#### `test_mise_bootstrap_editorconfig.zsh`

The test covers the global EditorConfig link in an isolated home fixture.

The remaining migrated application boundaries use focused tests when they have behavior beyond declaration checks. Current behavior tests cover `1password`, `bat`, `btop`, `coreutils`, `curl`, `delta`, `editorconfig`, `fd`, `findutils`, `fzf`, `ghostty`, `git`, `gnu-sed`, `hammerspoon`, `harper`, `lazygit`, `nvim`, `p10k`, `ripgrep`, `tmux`, `vivid`, `wezterm`, `yarn`, `yazi`, and `zsh`.

The `1password` test applies the `XDG` target in an isolated home fixture. It inspects the `SSH` configuration without requiring the live agent socket.

The `Oh My Zsh` test covers its custom plugin repositories. The `Neovim` test covers the LazyVim repository.

`test_mise_bootstrap_modules.zsh` covers declaration-only package and tool modules. It checks the module declaration, control-plane link, and native environment selection in one data-driven test. Personal-only package modules also check that the work environment excludes them.

#### `test_mise_bootstrap_brew.zsh`

Tests Homebrew adoption and shared profile selection for `brew.toml`.

#### `test_mise_bootstrap_macos.zsh`

The test covers native macOS preferences, the `post-defaults` hook, platform loading, and remaining imperative OS operations in a fixture preview.

Manual macOS operations are exposed as global mise tasks under the `macos:` prefix.

#### `test_mise_task_bootstrap_post_dotfiles_cleanup.zsh`

The cleanup task scans the union of resolved work and personal targets and historical roots. It removes broken repository links and valid old links only when their target and source exactly match `cleanup.migrations`. The fixture covers active `symlink-each` children, profile-specific active links, mismatched and external sources, unrelated valid links, runtime files, and active edit blocks.

The cleanup task uses `cleanup.paths`, `cleanup.migrations`, and `cleanup.blocks`. The inventory task updates only the historical paths and block declarations; the literal migration manifest remains unchanged.

#### `test_mise_task_bootstrap_post_dotfiles_cleanup_inventory.zsh`

The inventory test covers the union of resolved work and personal targets, paths relative to `HOME`, historical paths, and preservation of `cleanup.migrations`. It asserts that the task does not store custom `XDG` paths or rewrite `cleanup.blocks`.

The fixture unsets `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, and `MISE_CONFIG_DIR` during status queries. It stores only paths relative to `HOME` in `cleanup.paths`.

#### `test_mise_task_pr_review_watch.zsh`

Tests transactional review-watch add, remove, and poll actions with isolated `gh` stubs, including paginated comment collection, timestamp cutoffs, normalized check statuses, malformed data warnings, state preservation, atomic writes, lock handling, merged/closed cleanup, and stable JSON output.

#### `test_mise_bootstrap_packages.zsh`

Tests the shared package maintenance hook and profile selection for `packages.toml`.

#### `test_mise_bootstrap_modules.zsh`

Tests declaration-only package and tool modules, including shared and personal profile selection.

Use a separate `test_mise_bootstrap_<module>.zsh` file when a module needs behavior, ownership, runtime exclusion, syntax, or lifecycle assertions beyond the shared declaration contract.

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
2. Add declaration-only package, tool, and profile cases to `test_mise_bootstrap_modules.zsh`
3. Add a separate focused test for behavior that the shared declaration contract does not cover
4. Handle missing dependencies gracefully
5. Provide clear success/failure indicators
6. Include usage examples in test output

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
