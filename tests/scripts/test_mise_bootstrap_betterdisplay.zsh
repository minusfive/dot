#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing BetterDisplay package bootstrap configuration..."
assert_module_package betterdisplay brew-cask:betterdisplay

local __module="home/.config/mise/conf.d/module.betterdisplay.toml"
local __control_plane="home/.config/mise/conf.d/module.mise.toml"
local __export_task="home/.config/mise/tasks/betterdisplay/settings/export.zsh"
local __import_task="home/.config/mise/tasks/betterdisplay/settings/import.zsh"

[[ -x "$__export_task" ]] || fail "export task is not executable"
[[ -x "$__import_task" ]] || fail "import task is not executable"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/export.zsh" = { source = "~/dev/personal/dot/home/.config/mise/tasks/betterdisplay/settings/export.zsh", mode = "symlink" }' "$__control_plane" ||
    fail "export task control-plane link is missing"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/import.zsh" = { source = "~/dev/personal/dot/home/.config/mise/tasks/betterdisplay/settings/import.zsh", mode = "symlink" }' "$__control_plane" ||
    fail "import task control-plane link is missing"
local __task_listing="$(
    env -u MISE_ENV DOT_PROFILE=work MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
        MISE_ENV_CONF_D=true mise -C "$__root_dir" tasks --json
)"
print -r -- "$__task_listing" | grep -qF '"name": "betterdisplay:settings:export"' ||
    fail "export task is not discoverable"
print -r -- "$__task_listing" | grep -qF '"name": "betterdisplay:settings:import"' ||
    fail "import task is not discoverable"

grep -qF '[dotfiles]' "$__module" || fail "BetterDisplay dotfiles declaration is missing"
grep -qF 'source = "~/dev/personal/dot/home/.config/BetterDisplay"' "$__module" ||
    fail "BetterDisplay source path is missing"
grep -qF 'mode = "symlink-each"' "$__module" || fail "BetterDisplay ownership mode changed"
grep -qF 'exclude = ["README.md"]' "$__module" ||
    fail "BetterDisplay README exclusion is missing"
if grep -qiE 'launchd|start_interval|run_at_load' "$__module"; then
    fail "BetterDisplay automatic LaunchAgent declarations remain"
fi
grep -qF 'plutil -lint' scripts/utils/betterdisplay.zsh || fail "plist validation helper is missing"
grep -qF 'XDG_STATE_HOME' scripts/utils/betterdisplay.zsh || fail "runtime backup path is missing"
grep -qF 'BETTERDISPLAY_LOCK_STALE_AFTER' scripts/utils/betterdisplay.zsh || fail "manual-operation lock age bound is missing"
grep -qF 'betterdisplay_acquire_lock' "$__export_task" || fail "export task lock is missing"
grep -qF 'betterdisplay_acquire_lock' "$__import_task" || fail "import task lock is missing"
[[ ! -e scripts/betterdisplay.zsh ]] || fail "legacy BetterDisplay script remains"
if grep -R -qE 'scripts/betterdisplay\.zsh|--display' scripts --exclude='test_*'; then
    fail "legacy BetterDisplay init path remains"
fi
plutil -lint home/.config/BetterDisplay/config.plist >/dev/null || fail "tracked BetterDisplay plist is invalid"

local __fixture="$__root_dir/.agents/test-runs/betterdisplay-dotfiles-$$"
local __home="$__fixture/home"
local __repo="$__home/dev/personal/dot"
local __config="$__home/.config/mise"
local __target="$__home/.config/BetterDisplay"
trap 'rm -rf "$__fixture"' EXIT
mkdir -p "$__home/dev/personal" "$__config/conf.d"
ln -s "$__root_dir" "$__repo"
cp "$__module" "$__config/conf.d/module.betterdisplay.toml"
cat > "$__config/config.toml" <<'EOF'
EOF
cat > "$__config/miserc.toml" <<'EOF'
env_conf_d = true
env = ["betterdisplay"]
EOF
env -u MISE_ENV HOME="$__home" \
    XDG_CONFIG_HOME="$__home/.config" \
    MISE_DATA_DIR="$__fixture/data" \
    MISE_STATE_DIR="$__fixture/state" \
    MISE_CONFIG_DIR="$__config" \
    MISE_CONFIG_ROOT="$__config" \
    MISE_TRUSTED_CONFIG_PATHS="$__root_dir" DOT_PROFILE=work \
    mise -C "$__repo" bootstrap --only dotfiles --yes >/dev/null
[[ -L "$__target/config.plist" ]] || fail "deployed BetterDisplay plist is not a symlink"
[[ "$(realpath "$__target/config.plist")" == "$(realpath home/.config/BetterDisplay/config.plist)" ]] ||
    fail "deployed BetterDisplay plist does not resolve to the tracked source"
[[ ! -e "$__target/README.md" ]] || fail "repository-only BetterDisplay README was deployed"
rm -rf "$__fixture"
trap - EXIT

echo "BetterDisplay package bootstrap configuration passed."
