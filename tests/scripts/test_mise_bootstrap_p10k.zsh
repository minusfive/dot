#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Powerlevel10k bootstrap configuration..."

local __config="home/.config/mise/conf.d/p10k.toml"
local __source="home/.config/zsh/.p10k.zsh"
[[ -f "$__config" && -f "$__source" ]] || fail "Powerlevel10k source or declaration is missing"
grep -qF '"~/.config/oh-my-zsh/custom/themes/powerlevel10k" = { url = "https://github.com/romkatv/powerlevel10k.git" }' "$__config" ||
    fail "Powerlevel10k repository declaration is missing"
grep -qF '"~/.config/zsh/.p10k.zsh" = { source = "~/dev/personal/dot/home/.config/zsh/.p10k.zsh", mode = "symlink" }' "$__config" ||
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
grep -qF '"~/.config/mise/conf.d/p10k.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "mise control-plane module does not deploy p10k.toml"
for __other_config in home/.config/mise/conf.d/*.toml; do
    [[ "$__other_config" == "$__config" ]] && continue
    if grep -qF '"~/.config/oh-my-zsh/custom/themes/powerlevel10k"' "$__other_config" ||
        grep -qF '"~/.config/zsh/.p10k.zsh"' "$__other_config" ||
        grep -qF '"~/.config/zsh/.zshrc/p10k"' "$__other_config" ||
        grep -qF '"~/.config/zsh/.zshrc-zone-2.zsh/p10k"' "$__other_config"; then
        fail "Powerlevel10k ownership is duplicated in $__other_config"
    fi
done

local __fixture_root
__fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/p10k.XXXXXX")" ||
    fail "could not create Powerlevel10k fixture"
__fixture_root="$(realpath "$__fixture_root")"
trap 'rm -rf -- "$__fixture_root"' EXIT
mkdir -p \
    "$__fixture_root/.config/zsh" \
    "$__fixture_root/.config/oh-my-zsh/custom/themes/powerlevel10k" \
    "$__fixture_root/dev/personal" \
    "$__fixture_root/mise-data" \
    "$__fixture_root/mise-cache"
ln -s "$__root_dir" "$__fixture_root/dev/personal/dot"
ln -s "$__root_dir/home/.config/zsh/.p10k.zsh" "$__fixture_root/.config/zsh/.p10k.zsh"
local __dry_run_output
if ! __dry_run_output="$(
    env MISE_ENV=work HOME="$__fixture_root" XDG_CONFIG_HOME="$__fixture_root/.config" \
        MISE_DATA_DIR="$__fixture_root/mise-data" MISE_CACHE_DIR="$__fixture_root/mise-cache" \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" bootstrap dotfiles apply --dry-run 2>&1
)"; then
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
        env MISE_ENV=work HOME="$__fixture_root" XDG_CONFIG_HOME="$__fixture_root/.config" \
            MISE_DATA_DIR="$__fixture_root/mise-data" MISE_CACHE_DIR="$__fixture_root/mise-cache" \
            MISE_ENV="$__profile" MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "p10k.toml" ||
        fail "Powerlevel10k module must be selected by the $__profile profile"
done

echo "Powerlevel10k bootstrap configuration passed."
