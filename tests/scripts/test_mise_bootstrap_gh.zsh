#!/usr/bin/env zsh
# Test the GitHub bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GitHub bootstrap configuration..."

local __config="home/.config/mise/conf.d/gh.toml"
[[ -f "$__config" ]] || fail "missing $__config"
assert_module_package gh brew:gh
grep -qF '[bootstrap.hooks]' "$__config" || fail "GitHub post-packages hook is missing"
grep -qF "post-packages = 'gh extension install --force" "$__config" ||
    fail "GitHub post-packages hook phase is missing"
grep -qF 'gh extension install --force "yusukebe/gh-markdown-preview"' "$__config" ||
    fail "GitHub extension install is missing from the post-packages hook"
[[ -f "home/.config/gh/gh-personal.mise.toml" ]] || fail "missing personal GH environment source"
[[ -f "home/.config/gh/gh-work.mise.toml" ]] || fail "missing work GH environment source"
[[ -f "home/.config/gh/personal/hosts.yml" ]] || fail "missing GitHub hosts source"
if grep -qF "oauth_token:" "home/.config/gh/personal/hosts.yml"; then
    fail "GitHub hosts source must not contain an OAuth token"
fi

grep -qF '[bootstrap.directories."~/.config/gh/personal"]' "$__config" || fail "GitHub directory resource is missing"
grep -qF '"gh/config/gh/personal/hosts.yml" = { source = "~/dev/personal/dot/home/.config/gh/personal/hosts.yml", mode = "symlink", variants = [{ default = true, target = "{{ xdg_config_home }}/gh/personal/hosts.yml" }] }' "$__config" ||
    fail "GitHub hosts dotfile resource is missing"
if grep -qF '[bootstrap.files."~/.config/gh/personal/hosts.yml"]' "$__config"; then
    fail "GitHub hosts resource must not remain a bootstrap file"
fi
grep -qF '"mise/config/mise/conf.d/gh.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "mise control-plane module does not deploy gh.toml"
grep -qF 'source = "~/dev/personal/dot/home/.config/gh/personal/hosts.yml"' "$__config" || fail "GitHub hosts source is missing"
grep -qF '"~/dev/personal/mise.toml/gh-config" = { source = "~/dev/personal/dot/home/.config/gh/gh-personal.mise.toml", template = "tera", merge = true }' "$__config" ||
    fail "personal GH_CONFIG_DIR merge entry is missing"
grep -qF '"~/dev/work/mise.toml/gh-config" = { source = "~/dev/personal/dot/home/.config/gh/gh-work.mise.toml", template = "tera", merge = true }' "$__config" ||
    fail "work GH_CONFIG_DIR merge entry is missing"
grep -qF 'GH_CONFIG_DIR = "{{ xdg_config_home }}/gh/personal"' home/.config/gh/gh-personal.mise.toml ||
    fail "personal GH_CONFIG_DIR source is missing"
grep -qF 'GH_CONFIG_DIR = "{{ xdg_config_home }}/gh/work"' home/.config/gh/gh-work.mise.toml ||
    fail "work GH_CONFIG_DIR source is missing"
if grep -qF 'bootstrap-gh.toml' home/.config/mise/conf.d/mise.toml; then
    fail "legacy GitHub declaration is still deployed"
fi
[[ ! -e "home/.config/mise/conf.d/profiles.toml" ]] ||
    fail "retired profile module remains"

local __fixture_dir="$(test_fixture_dir gh-xdg-config)"
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_xdg_config="$__fixture_dir/custom-xdg/config"
local __host_mise_config="$HOME/.config/mise"
mkdir -p "$__fixture_repository" "$__fixture_home/.config/mise" "$__fixture_xdg_config" \
    "$__fixture_dir/data" "$__fixture_dir/state" "$__fixture_dir/cache" \
    "$__fixture_dir/tmp" "$__fixture_dir/system-config" \
    "$__fixture_dir/xdg/data" "$__fixture_dir/xdg/state" "$__fixture_dir/xdg/cache"
trap 'rm -rf -- "$__fixture_dir"' EXIT
git -C "$__fixture_repository" init -q
cp home/.config/gh/gh-work.mise.toml "$__fixture_repository/mise.toml"
cp home/.config/gh/gh-personal.mise.toml "$__fixture_repository/mise.personal.toml"
local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_xdg_config"
    "XDG_DATA_HOME=$__fixture_dir/xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_home/.config/mise"
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
    "MISE_NO_HOOKS=1"
)
for __config in "$__fixture_repository/mise.toml" "$__fixture_repository/mise.personal.toml"; do
    env -u MISE_ENV "${__fixture_env[@]}" \
        mise -C "$__fixture_repository" trust "$__config" >/dev/null ||
        fail "could not trust GH fixture config: $__config"
done
local __work_env="$(
    env -u MISE_ENV "${__fixture_env[@]}" \
        mise -C "$__fixture_repository" -E work env --json
)"
local __personal_env="$(
    env -u MISE_ENV "${__fixture_env[@]}" \
        mise -C "$__fixture_repository" -E personal env --json
)"
print -r -- "$__work_env" |
    jq -e --arg expected "$__fixture_xdg_config/gh/work" '.GH_CONFIG_DIR == $expected' >/dev/null ||
    fail "work GH_CONFIG_DIR did not follow XDG_CONFIG_HOME"
print -r -- "$__personal_env" |
    jq -e --arg expected "$__fixture_xdg_config/gh/personal" '.GH_CONFIG_DIR == $expected' >/dev/null ||
    fail "personal GH_CONFIG_DIR did not follow XDG_CONFIG_HOME"
rm -rf -- "$__fixture_dir"

for __target in "$HOME/dev/personal/mise.toml" "$HOME/dev/work/mise.toml"; do
    [[ -f "$__target" && ! -L "$__target" ]] || fail "workspace mise target is not a regular file: $__target"
done
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/personal\"" "$HOME/dev/personal/mise.toml" ||
    fail "personal workspace GH_CONFIG_DIR is incorrect"
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/work\"" "$HOME/dev/work/mise.toml" ||
    fail "work workspace GH_CONFIG_DIR is incorrect"
[[ "$(stat -c '%a' "$HOME/.config/gh/personal")" == "755" ]] || fail "GitHub directory mode is not 0755"
[[ -d "$HOME/.config/gh/personal" && ! -L "$HOME/.config/gh/personal" ]] ||
    fail "GitHub target directory must remain physical"
[[ -L "$HOME/.config/gh/personal/hosts.yml" ]] ||
    fail "GitHub hosts target must be a symlink"
case "$(readlink "$HOME/.config/gh/personal/hosts.yml")" in
    /*) fail "GitHub hosts link must be relative" ;;
esac
cmp -s home/.config/gh/personal/hosts.yml "$HOME/.config/gh/personal/hosts.yml" ||
    fail "GitHub hosts target does not match the tracked source"

echo "GitHub bootstrap configuration passed."
