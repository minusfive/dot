#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing macOS bootstrap configuration..."

local __config="home/.config/mise/conf.d/macos/mise.macos.toml"
local __control_plane="home/.config/mise/conf.d/mise.toml"

[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"mise/config/mise/conf.d/macos" = {' "$__control_plane" ||
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

local __fixture_dir="$__root_dir/.test-macos-${PPID}-$$"
[[ ! -e "$__fixture_dir" ]] || fail "macOS fixture path already exists: $__fixture_dir"
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_config="$__fixture_dir/mise-config"
local __fixture_global_config="$__root_dir/home/.config/mise/conf.d/macos/mise.macos.toml"
mkdir -p "$__fixture_repository" "$__fixture_config"
trap 'rm -rf -- "$__fixture_dir"' EXIT
ln -s "$__root_dir/home" "$__fixture_repository/home"

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_home/.config"
    "XDG_DATA_HOME=$__fixture_home/.local/share"
    "XDG_STATE_HOME=$__fixture_home/.local/state"
    "XDG_CACHE_HOME=$__fixture_home/.cache"
    "MISE_CONFIG_DIR=$__fixture_config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=${__fixture_global_config:h}"
    "MISE_CEILING_PATHS=$__root_dir"
    "MISE_DATA_DIR=$__fixture_dir/mise-data"
    "MISE_STATE_DIR=$__fixture_dir/mise-state"
    "MISE_CACHE_DIR=$__fixture_dir/mise-cache"
    "MISE_TMP_DIR=$__fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_dir/system-shims"
    "MISE_ENV_CONF_D=true"
)
mkdir -p \
    "$__fixture_home/.local/share" \
    "$__fixture_home/.local/state" \
    "$__fixture_home/.cache" \
    "$__fixture_dir/mise-data" \
    "$__fixture_dir/mise-state" \
    "$__fixture_dir/mise-cache" \
    "$__fixture_dir/mise-tmp" \
    "$__fixture_dir/system-config" \
    "$__fixture_dir/mise-installs" \
    "$__fixture_dir/mise-install-store" \
    "$__fixture_dir/mise-plugins" \
    "$__fixture_dir/mise-downloads" \
    "$__fixture_dir/mise-shims" \
    "$__fixture_dir/system-data" \
    "$__fixture_dir/system-installs" \
    "$__fixture_dir/system-shims"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_global_config" >/dev/null ||
    fail "could not trust macOS fixture config"

local __dry_run
__dry_run="$(env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    MISE_ENV=work mise -C "$__fixture_repository" bootstrap --dry-run 2>&1)"
print -r -- "$__dry_run" | grep -qF 'mise bootstrap: system defaults' ||
    fail "full bootstrap is missing macOS defaults"
print -r -- "$__dry_run" | grep -qF 'killall Dock Finder SystemUIServer' ||
    fail "macOS post-defaults hook is missing from the full bootstrap"

echo "macOS bootstrap configuration passed."
