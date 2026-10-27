#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Hammerspoon bootstrap configuration..."

local __config="home/.config/mise/conf.d/hammerspoon.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"brew-cask:hammerspoon" = "latest"' "$__config" ||
    fail "Hammerspoon package declaration is missing"
grep -qF '"hammerspoon/config/hammerspoon" = {' "$__config" ||
    fail "Hammerspoon symlink declaration is missing"
grep -qF "defaults write org.hammerspoon.Hammerspoon MJConfigFile {{ (xdg_config_home ~ '/hammerspoon/init.lua') | quote }}" "$__config" ||
    fail "Hammerspoon macOS hook is missing"
grep -qF '"mise/config/mise/conf.d/hammerspoon.toml" = {' home/.config/mise/conf.d/mise.toml ||
    fail "Hammerspoon module is not deployed"
local __source="home/.config/hammerspoon"
local __target="$HOME/.config/hammerspoon"
[[ -f "$__source/.luarc.json" ]] || fail "Hammerspoon local-development source is missing"
[[ ! -e ".config/hammerspoon/.luarc.json" ]] ||
    fail "Hammerspoon local-development source remains under the legacy boundary"
[[ ! -e "$__target/.luarc.json" ]] || fail "repository-only .luarc.json leaked into the target"
local __expected_count="$(git ls-files -- home/.config/hammerspoon | grep -v '^home/.config/hammerspoon/.luarc.json$' | wc -l | tr -d ' ')"
local __source_count="$(find "$__source" -type f ! -name '.luarc.json' | wc -l | tr -d ' ')"
local __link_count="$(find "$__target" -type l | wc -l | tr -d ' ')"
[[ "$__source_count" == "$__expected_count" ]] || fail "Hammerspoon source manifest mismatch"
[[ "$__link_count" == "$__expected_count" ]] || fail "Hammerspoon target link count mismatch"
find "$__target" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} + ||
    fail "Hammerspoon deployed link is absolute"
if command -v luac >/dev/null 2>&1; then
    find "$__source" -type f -name '*.lua' -exec luac -p {} +
fi

local __fixture_dir="$(test_fixture_dir hammerspoon-xdg)"
trap 'rm -rf "$__fixture_dir"' EXIT
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_xdg_config="$__fixture_dir/xdg/config"
local __fixture_mise_config="$__fixture_dir/mise-config"
local __fixture_global_config="$__fixture_dir/global-mise.toml"
local __fixture_bin="$__fixture_dir/bin"
local __defaults_log="$__fixture_dir/defaults.log"
local __fixture_hammerspoon_target="$__fixture_xdg_config/hammerspoon"
local __host_mise_config="$HOME/.config/mise"
mkdir -p "$__fixture_repository" "$__fixture_bin" "$__fixture_mise_config" \
    "$__fixture_dir/data" "$__fixture_dir/state" "$__fixture_dir/cache" \
    "$__fixture_dir/tmp" "$__fixture_dir/system-config" "$__fixture_xdg_config" \
    "$__fixture_dir/xdg/data" "$__fixture_dir/xdg/state" "$__fixture_dir/xdg/cache"
ln -s "$__root_dir/home" "$__fixture_repository/home"
git -C "$__fixture_repository" init -q
cp "$__config" "$__fixture_repository/mise.toml"
printf '[settings.dotfiles]\nrelative_symlinks = true\n' > "$__fixture_global_config"
cat > "$__fixture_bin/defaults" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$DEFAULTS_LOG"
EOF
chmod +x "$__fixture_bin/defaults"
local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_xdg_config"
    "XDG_DATA_HOME=$__fixture_dir/xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_mise_config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_DATA_DIR=$__fixture_dir/data"
    "MISE_STATE_DIR=$__fixture_dir/state"
    "MISE_CACHE_DIR=$__fixture_dir/cache"
    "MISE_TMP_DIR=$__fixture_dir/tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_dir/system-shims"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_CEILING_PATHS=$__fixture_home"
    "DEFAULTS_LOG=$__defaults_log"
    "PATH=$__fixture_bin:$PATH"
)
env -u MISE_ENV -u MISE_AUTO_ENV "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_repository/mise.toml" >/dev/null ||
    fail "could not trust Hammerspoon fixture config"
env -u MISE_ENV -u MISE_AUTO_ENV "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_global_config" >/dev/null ||
    fail "could not trust Hammerspoon fixture global config"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE -u MISE_NO_HOOKS "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" -E work bootstrap --only dotfiles --yes >/dev/null ||
    fail "Hammerspoon fixture bootstrap failed"
[[ -L "$__fixture_hammerspoon_target/init.lua" ]] ||
    fail "Hammerspoon target did not follow XDG_CONFIG_HOME"
printf '%s\n' \
    'write' \
    'org.hammerspoon.Hammerspoon' \
    'MJConfigFile' \
    "$__fixture_hammerspoon_target/init.lua" > "$__fixture_dir/defaults.expected"
cmp -s "$__fixture_dir/defaults.expected" "$__defaults_log" ||
    fail "Hammerspoon hook did not use the configured XDG path"
rm -rf -- "$__fixture_dir"

echo "Hammerspoon bootstrap configuration passed."
