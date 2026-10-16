#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Powerlevel10k bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.p10k.toml"
local __source="home/.config/zsh/.p10k.zsh"
local __target="$HOME/.config/zsh/.p10k.zsh"
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
grep -qF '"~/.config/mise/conf.d/module.p10k.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.p10k.toml"
[[ -L "$__target" ]] || fail "Powerlevel10k target is not a symlink"
case "$(readlink "$__target")" in
    /*) fail "Powerlevel10k target link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "Powerlevel10k target does not resolve to the tracked source"
for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.p10k.toml" ||
        fail "Powerlevel10k module must be selected by the $__profile profile"
done

echo "Powerlevel10k bootstrap configuration passed."
