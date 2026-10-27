#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

[[ ! -e "scripts/tasks/system/bootstrap.zsh" ]] ||
    fail "retired system bootstrap task remains"
zsh -n scripts/mise-env.zsh || fail "mise environment script has syntax errors"
local __post_dotfiles_task="scripts/tasks/bootstrap/post-dotfiles.zsh"
local __final_task="home/.config/mise/tasks/bootstrap/final.zsh"
[[ -x "$__post_dotfiles_task" ]] || fail "post-dotfiles task is missing or not executable"
[[ -x "$__final_task" ]] || fail "final task is missing or not executable"
zsh -n "$__post_dotfiles_task" || fail "post-dotfiles task has syntax errors"
zsh -n "$__final_task" || fail "final task has syntax errors"
for __command in \
    "mise run bootstrap:post-dotfiles:cleanup:inventory" \
    "mise run bootstrap:post-dotfiles:cleanup"; do
    grep -Fxq "$__command" "$__post_dotfiles_task" ||
        fail "post-dotfiles task is missing: $__command"
done
grep -qF 'mise fix' "$__final_task" || fail "final task is missing mise fix"
grep -qF 'final = "mise run bootstrap:final"' home/.config/mise/conf.d/mise.toml ||
    fail "final bootstrap hook is missing"

local __fixture_dir
__fixture_dir="$(test_fixture_dir mise-lifecycle)" || exit 1
local __mise_bin="$(command -v mise)"
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_config="$__fixture_dir/mise-config"
local __fixture_global_config="$__fixture_dir/global-mise.toml"
mkdir -p "$__fixture_repository" "$__fixture_config"
trap 'rm -rf -- "$__fixture_dir"' EXIT
ln -s "$__root_dir/home" "$__fixture_repository/home"
git -C "$__fixture_repository" init -q
cat > "$__fixture_global_config" <<'EOF'
[settings.dotfiles]
relative_symlinks = true
EOF

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_dir/xdg/config"
    "XDG_DATA_HOME=$__fixture_dir/xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_CEILING_PATHS=$__fixture_repository"
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
    "MISE_NO_HOOKS=1"
    "MISE_AUTO_INSTALL=false"
    "MISE_EXEC_AUTO_INSTALL=false"
    "MISE_NOT_FOUND_AUTO_INSTALL=false"
)
mkdir -p \
    "$__fixture_dir/xdg/config" \
    "$__fixture_dir/xdg/data" \
    "$__fixture_dir/xdg/state" \
    "$__fixture_dir/xdg/cache" \
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
    "$__mise_bin" -C "$__fixture_repository" trust "$__fixture_global_config" >/dev/null ||
    fail "could not trust mise lifecycle fixture config"

local __help="$(
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
        "$__mise_bin" -C "$__fixture_repository" bootstrap --help
)"
print -r -- "$__help" | grep -qF 'Set up this machine from your mise config' ||
    fail "native bootstrap help is unavailable"

for __profile in work personal; do
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
        "$__mise_bin" -E "$__profile" -C "$__fixture_repository" bootstrap --dry-run >/dev/null ||
        fail "native $__profile bootstrap preview failed"
done

echo "Mise bootstrap lifecycle passed."
