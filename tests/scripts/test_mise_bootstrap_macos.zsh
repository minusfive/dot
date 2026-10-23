#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing macOS bootstrap configuration..."

local __config="home/.config/mise/conf.d/macos/mise.macos.toml"
local __control_plane="home/.config/mise/conf.d/mise.toml"

[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/mise/conf.d/macos" = {' "$__control_plane" ||
    fail "control-plane module does not deploy the macOS folder fragment"
grep -qF '[bootstrap.directories."~/Pictures/screenshots"]' "$__config" ||
    fail "screenshots directory declaration is missing"
grep -qF "[bootstrap.macos.dock]" "$__config" ||
    fail "native Dock settings are missing"
grep -qF "[bootstrap.macos.finder]" "$__config" ||
    fail "native Finder settings are missing"
grep -qF '[bootstrap.macos.defaults."com.apple.Safari"]' "$__config" ||
    fail "native Safari settings are missing"
grep -qF 'post-defaults = [' "$__config" ||
    fail "post-defaults hook is missing"
grep -qF 'com.apple.screencapture location' "$__config" &&
    grep -qF '{{ vars.macos_screenshots_dir | quote }}' "$__config" ||
    fail "dynamic screenshot preference hook is missing"
grep -qF 'com.apple.finder NewWindowTarget' "$__config" &&
    grep -qF 'NewWindowTarget -string {{ env.HOME | quote }}' "$__config" ||
    fail "dynamic Finder preference hook is missing"
grep -qF 'auto_env = true' home/.config/mise/miserc.toml ||
    fail "auto_env must load the platform-specific macOS module"
grep -qF 'MACOS_SCREENSHOTS_DIR' "$__config" ||
    fail "shared screenshots path environment is missing"
grep -qF 'MACOS_WALLPAPER_COLOR' "$__config" ||
    fail "shared wallpaper color environment is missing"
grep -qF '[task_config]' "$__config" &&
    grep -qF 'includes = ["tasks"]' "$__config" ||
    fail "macOS task directory include is missing"
if grep -qF '[tasks."macos:' "$__config"; then
    fail "macOS tasks should be discovered from the folder task directory"
fi
for __task_file in \
    "home/.config/mise/conf.d/macos/tasks/macos/wallpaper.zsh" \
    "home/.config/mise/conf.d/macos/tasks/macos/screenshots/migrate.zsh" \
    "home/.config/mise/conf.d/macos/tasks/macos/dock/folders.zsh" \
    "home/.config/mise/conf.d/macos/tasks/macos/safari/restart.zsh" \
    "home/.config/mise/conf.d/macos/tasks/macos/session/logout.zsh"; do
    [[ -x "$__task_file" ]] || fail "macOS task is not executable: $__task_file"
    grep -qF '#MISE description=' "$__task_file" ||
        fail "macOS task description is missing: $__task_file"
    grep -qF '#MISE quiet=true' "$__task_file" ||
        fail "macOS task quiet setting is missing: $__task_file"
done


[[ ! -e scripts/os.zsh ]] || fail "scripts/os.zsh must be removed after task migration"

local __dry_run
__dry_run="$(env MISE_ENV=work MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true mise -C "$__root_dir" bootstrap --dry-run 2>&1)"
print -r -- "$__dry_run" | grep -qF 'mise bootstrap: system defaults' ||
    fail "full bootstrap is missing macOS defaults"
print -r -- "$__dry_run" | grep -qF 'killall Dock Finder SystemUIServer' ||
    fail "macOS post-defaults hook is missing from the full bootstrap"

echo "macOS bootstrap configuration passed."
