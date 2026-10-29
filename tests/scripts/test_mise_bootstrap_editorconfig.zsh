#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing EditorConfig bootstrap configuration..."

local __config="home/.config/mise/conf.d/editorconfig.toml"
local __source="home/.editorconfig"
[[ -f "$__config" && -f "$__source" ]] || fail "EditorConfig source or declaration is missing"
grep -qF '"~/.editorconfig" = { source = "~/dev/personal/dot/home/.editorconfig", mode = "symlink" }' "$__config" ||
    fail "EditorConfig symlink declaration is missing"

local __fixture_dir
__fixture_dir="$(test_fixture_dir editorconfig)" || exit 1
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_xdg_config="$__fixture_home/.config"
local __fixture_global_config="$__fixture_dir/global-mise.toml"
local __fixture_mise_config="$__fixture_dir/mise-config"
trap 'rm -rf -- "$__fixture_dir"' EXIT
mkdir -p "$__fixture_repository" "$__fixture_xdg_config" "$__fixture_mise_config"
ln -s "$__root_dir/home" "$__fixture_repository/home"
git -C "$__fixture_repository" init -q
cat > "$__fixture_global_config" <<'EOF'
[settings.dotfiles]
relative_symlinks = true

[dotfiles]
"~/.editorconfig" = { source = "~/dev/personal/dot/home/.editorconfig", mode = "symlink" }
EOF

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_xdg_config"
    "XDG_DATA_HOME=$__fixture_dir/xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_mise_config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_CEILING_PATHS=$__fixture_repository"
    "MISE_IGNORED_CONFIG_PATHS=$__fixture_home/.config/mise"
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
    "MISE_NO_HOOKS=1"
)
mkdir -p \
    "$__fixture_dir/xdg/data" "$__fixture_dir/xdg/state" "$__fixture_dir/xdg/cache" \
    "$__fixture_dir/mise-data" "$__fixture_dir/mise-state" "$__fixture_dir/mise-cache" \
    "$__fixture_dir/mise-tmp" "$__fixture_dir/system-config" "$__fixture_dir/mise-installs" \
    "$__fixture_dir/mise-install-store" "$__fixture_dir/mise-plugins" \
    "$__fixture_dir/mise-downloads" "$__fixture_dir/mise-shims" \
    "$__fixture_dir/system-data" "$__fixture_dir/system-installs" "$__fixture_dir/system-shims"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_global_config" >/dev/null ||
    fail "could not trust EditorConfig fixture config"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" -E work bootstrap --only dotfiles --yes >/dev/null ||
    fail "EditorConfig fixture bootstrap failed"

local __target="$__fixture_home/.editorconfig"
local __status="$(
    env -u MISE_ENV -u MISE_AUTO_ENV "${__fixture_env[@]}" \
        MISE_SAFE=1 MISE_NO_HOOKS=1 \
        mise -C "$__fixture_repository" -E work dot status --json
)" || fail "EditorConfig fixture status failed"
print -r -- "$__status" |
    jq -e --arg target "$__target" --arg logical_target "~/.editorconfig" \
        'any(.files[]; (.target == $target or .target == $logical_target) and .mode == "symlink" and .state == "applied")' >/dev/null ||
    fail "EditorConfig target did not resolve to the fixture home"
[[ -L "$__target" ]] || fail "EditorConfig fixture target is not a symlink"
case "$(readlink "$__target")" in
    /*) fail "EditorConfig fixture target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__root_dir/$__source")" ]] ||
    fail "EditorConfig fixture target does not resolve to the tracked source"
echo "EditorConfig bootstrap configuration passed."
