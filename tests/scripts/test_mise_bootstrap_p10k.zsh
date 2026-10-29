#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Powerlevel10k bootstrap configuration..."

local __config="home/.config/mise/conf.d/p10k.toml"
local __source="home/.config/zsh/.p10k.zsh"
[[ -f "$__config" && -f "$__source" ]] || fail "Powerlevel10k source or declaration is missing"
grep -qF '"~/.config/oh-my-zsh/custom/themes/powerlevel10k" = { url = "https://github.com/romkatv/powerlevel10k.git" }' "$__config" ||
    fail "Powerlevel10k repository declaration is missing"
grep -qF '"p10k/config/zsh/.p10k.zsh" = { source = "~/dev/personal/dot/home/.config/zsh/.p10k.zsh", mode = "symlink", variants = [{ default = true, target = "{{ xdg_config_home }}/zsh/.p10k.zsh" }] }' "$__config" ||
    fail "Powerlevel10k configuration link is missing"
for __entry in \
    '~/.config/zsh/.zshrc/p10k' \
    '~/.config/zsh/.zshrc-zone-2.zsh/p10k'; do
    grep -qF "\"$__entry\"" "$__config" ||
        fail "Powerlevel10k Zsh edit is missing: $__entry"
done
for __source_path in home/.config/p10k/zshrc.zsh home/.config/p10k/zshrc-zone-2.zsh; do
    [[ -f "$__source_path" ]] || fail "missing Powerlevel10k Zsh source: $__source_path"
    zsh -n "$__source_path" || fail "Powerlevel10k Zsh source has syntax errors: $__source_path"
done
grep -qF 'ZSH_THEME="powerlevel10k/powerlevel10k"' home/.config/p10k/zshrc.zsh ||
    fail "Powerlevel10k module does not own ZSH_THEME"
for __other_config in home/.config/mise/conf.d/*.toml; do
    [[ "$__other_config" == "$__config" ]] && continue
    if grep -qF '"~/.config/oh-my-zsh/custom/themes/powerlevel10k"' "$__other_config" ||
        grep -qF '"p10k/config/zsh/.p10k.zsh"' "$__other_config" ||
        grep -qF '"~/.config/zsh/.zshrc/p10k"' "$__other_config" ||
        grep -qF '"~/.config/zsh/.zshrc-zone-2.zsh/p10k"' "$__other_config"; then
        fail "Powerlevel10k ownership is duplicated in $__other_config"
    fi
done

local __fixture_root
__fixture_root="$(test_fixture_dir p10k)" ||
    fail "could not create Powerlevel10k fixture"
__fixture_root="$(realpath "$__fixture_root")"
local __fixture_repository="$__fixture_root/dev/personal/dot"
local __fixture_mise_config="$__fixture_root/mise-config"
local __fixture_mise_data="$__fixture_root/mise-data"
local __fixture_mise_state="$__fixture_root/mise-state"
local __fixture_mise_cache="$__fixture_root/mise-cache"
local __fixture_mise_tmp="$__fixture_root/mise-tmp"
trap 'rm -rf -- "$__fixture_root"' EXIT
mkdir -p \
    "$__fixture_root/.config/zsh" \
    "$__fixture_root/.config/oh-my-zsh/custom/themes/powerlevel10k" \
    "$__fixture_repository" \
    "$__fixture_mise_config" \
    "$__fixture_mise_data" \
    "$__fixture_mise_state" \
    "$__fixture_mise_cache" \
    "$__fixture_mise_tmp" \
    "$__fixture_root/system-config" \
    "$__fixture_root/mise-installs" \
    "$__fixture_root/mise-install-store" \
    "$__fixture_root/mise-plugins" \
    "$__fixture_root/mise-downloads" \
    "$__fixture_root/mise-shims" \
    "$__fixture_root/system-data" \
    "$__fixture_root/system-installs" \
    "$__fixture_root/system-shims" \
    "$__fixture_root/xdg/data" \
    "$__fixture_root/xdg/state" \
    "$__fixture_root/xdg/cache"
ln -s "$__root_dir/home" "$__fixture_repository/home"
local __relative_source="$(
    python3 -c 'import os,sys; print(os.path.relpath(os.path.abspath(sys.argv[1]), os.path.dirname(os.path.abspath(sys.argv[2]))))' \
        "$__source" "$__fixture_root/.config/zsh/.p10k.zsh"
)"
ln -s "$__relative_source" "$__fixture_root/.config/zsh/.p10k.zsh"
{
    print -r -- "[settings.dotfiles]"
    print -r -- "relative_symlinks = true"
    print -r -- ""
    print -r -- "[vars]"
    print -r -- "resolved_profile = \"work\""
    print -r -- ""
    print -r -- "[dotfiles]"
    grep -qF '"zsh/config/zsh"' home/.config/mise/conf.d/zsh.toml ||
        fail "Zsh directory declaration is missing"
    grep -F '"zsh/config/zsh"' home/.config/mise/conf.d/zsh.toml
    grep -F '"p10k/config/zsh/.p10k.zsh"' "$__config"
    grep -F '"~/.config/zsh/.zshrc/p10k"' "$__config"
    grep -F '"~/.config/zsh/.zshrc-zone-2.zsh/p10k"' "$__config"
    grep -F '"~/.config/zsh/.zshrc/zones"' home/.config/mise/conf.d/zsh.toml
} > "$__fixture_repository/mise.toml"

local -a __fixture_env=(
    "HOME=$__fixture_root"
    "XDG_CONFIG_HOME=$__fixture_root/.config"
    "XDG_DATA_HOME=$__fixture_root/xdg/data"
    "XDG_STATE_HOME=$__fixture_root/xdg/state"
    "XDG_CACHE_HOME=$__fixture_root/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_mise_config"
    "MISE_DATA_DIR=$__fixture_mise_data"
    "MISE_STATE_DIR=$__fixture_mise_state"
    "MISE_CACHE_DIR=$__fixture_mise_cache"
    "MISE_TMP_DIR=$__fixture_mise_tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_root/system-config"
    "MISE_INSTALLS_DIR=$__fixture_root/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_root/mise-install-store"
    "MISE_PLUGINS_DIR=$__fixture_root/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_root/mise-downloads"
    "MISE_SHIMS_DIR=$__fixture_root/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_root/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_root/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_root/system-shims"
    "MISE_ENV_CONF_D=true"
    "MISE_NO_HOOKS=1"
    "MISE_CEILING_PATHS=$__fixture_root"
)
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_repository/mise.toml" >/dev/null ||
    fail "could not trust Powerlevel10k fixture config"
local __dry_run_output
if ! __dry_run_output="$(
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
        mise -C "$__fixture_repository" -E work bootstrap --only dotfiles --dry-run 2>&1
)"; then
    print -r -- "$__dry_run_output" >&2
    fail "Powerlevel10k dotfile dry run failed"
fi
local __p10k_block_line="$(print -r -- "$__dry_run_output" | grep -nF 'edit ~/.config/zsh/.zshrc (block:p10k)' | cut -d: -f1)"
local __zones_block_line="$(print -r -- "$__dry_run_output" | grep -nF 'edit ~/.config/zsh/.zshrc (block:zones)' | cut -d: -f1)"
[[ -n "$__p10k_block_line" && -n "$__zones_block_line" && $__p10k_block_line -lt $__zones_block_line ]] ||
    fail "Powerlevel10k block must render before the Zsh zones block"
[[ -d "$__fixture_root/.config/oh-my-zsh/custom/themes/powerlevel10k" ]] ||
    fail "Powerlevel10k runtime repository is not physical"
[[ -L "$__fixture_root/.config/zsh/.p10k.zsh" ]] ||
    fail "Powerlevel10k target is not a symlink"
[[ "$(realpath "$__fixture_root/.config/zsh/.p10k.zsh")" == "$(realpath "$__source")" ]] ||
    fail "Powerlevel10k target does not resolve to the tracked source"

for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
            MISE_CEILING_PATHS="$__test_mise_repository" \
            mise -C "$__test_mise_repository" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "p10k.toml" ||
        fail "Powerlevel10k module must be selected by the $__profile profile"
done

echo "Powerlevel10k bootstrap configuration passed."
