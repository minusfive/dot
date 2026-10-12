#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing workspace profile bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.profiles.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/dev/profile.mise.toml" ]] || fail "missing profile template"
[[ ! -e "home/.config/mise/conf.d/bootstrap-gh.toml" ]] ||
    fail "legacy GitHub aggregate declaration must be retired after profile migration"
grep -qF '[dotfiles."~/dev/mise.toml"]' "$__config" ||
    fail "profile template group is missing"
grep -qF 'mode = "template"' "$__config" ||
    fail "profile entries must use template mode"
grep -qF '{ profile = "personal", target = "~/dev/personal/mise.toml" }' "$__config" ||
    fail "personal profile target variant is missing"
grep -qF '{ profile = "work", target = "~/dev/work/mise.toml" }' "$__config" ||
    fail "work profile target variant is missing"
grep -qF 'GH_CONFIG_DIR = "{{ env.HOME }}/.config/gh/{% if "personal" in mise_env %}personal{% else %}work{% endif %}"' home/dev/profile.mise.toml ||
    fail "profile template does not derive GH_CONFIG_DIR from the active profile"
grep -qF '"~/.config/mise/conf.d/module.profiles.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.profiles.toml"
local __dotfiles_line="$(line_of "mise bootstrap dotfiles apply --yes")"
local __personal_profile_line="$(line_of 'mise -E personal,mise,profiles bootstrap dotfiles apply --yes "$HOME/dev/personal/mise.toml"')"
local __work_profile_line="$(line_of 'mise -E work,mise,profiles bootstrap dotfiles apply --yes "$HOME/dev/work/mise.toml"')"
local __files_line="$(line_of "mise bootstrap files apply --yes")"
local __personal_trust_line="$(line_of 'mise trust --yes "$HOME/dev/personal/mise.toml"')"
local __work_trust_line="$(line_of 'mise trust --yes "$HOME/dev/work/mise.toml"')"
(( __dotfiles_line < __personal_profile_line &&
    __personal_profile_line < __work_profile_line &&
    __work_profile_line < __files_line &&
    __files_line < __personal_trust_line &&
    __personal_trust_line < __work_trust_line )) ||
    fail "workspace profile trust must follow dotfiles and file application"

for __target in "$HOME/dev/personal/mise.toml" "$HOME/dev/work/mise.toml"; do
    [[ -f "$__target" && ! -L "$__target" ]] || fail "workspace profile target is not a regular file: $__target"
    [[ "$(stat -c '%a' "$__target")" == "644" ]] || fail "workspace profile target mode is not 0644: $__target"
done
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/personal\"" "$HOME/dev/personal/mise.toml" ||
    fail "personal profile target has the wrong GH_CONFIG_DIR"
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/work\"" "$HOME/dev/work/mise.toml" ||
    fail "work profile target has the wrong GH_CONFIG_DIR"
if grep -Eiq '(oauth_token|token[[:space:]]*=|password[[:space:]]*=|secret[[:space:]]*=|private_key)' home/dev/profile.mise.toml; then
    fail "credential-like content found in profile template"
fi

echo "Workspace profile bootstrap configuration passed."
