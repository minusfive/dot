#!/usr/bin/env zsh
# Test the Oh My Zsh bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Oh My Zsh bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.oh-my-zsh.toml"
local __target="$HOME/.config/oh-my-zsh"

[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '[bootstrap.repos]' "$__config" || fail "repository bootstrap section is missing"
grep -qF '"~/.config/oh-my-zsh" = { url = "https://github.com/ohmyzsh/ohmyzsh.git" }' "$__config" ||
    fail "Oh My Zsh repository declaration is missing"
grep -qF '[bootstrap.hooks]' "$__config" || fail "Oh My Zsh bootstrap hooks are missing"
grep -qF 'post-dotfiles = "mise run omz:update"' "$__config" ||
    fail "Oh My Zsh update hook is missing"
grep -qF '"~/.config/mise/conf.d/module.oh-my-zsh.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.oh-my-zsh.toml"
grep -qF '"~/.config/mise/tasks/omz/update.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy the Oh My Zsh update task"
local __profile_count="$(grep -o '"oh-my-zsh"' home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
[[ "$__profile_count" -eq 2 ]] ||
    fail "oh-my-zsh must be selected by both profiles"
[[ -f "home/.config/mise/tasks/omz/update.zsh" ]] ||
    fail "missing Oh My Zsh update task"
zsh -n home/.config/mise/tasks/omz/update.zsh ||
    fail "Oh My Zsh update task has syntax errors"
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" tasks info omz:update
)"
print -r -- "$__task_info" | grep -qF 'Task: omz:update' ||
    fail "Oh My Zsh update task is not discoverable"
[[ -d "$__target" && ! -L "$__target" ]] ||
    fail "Oh My Zsh target is not a physical directory"
[[ "$(git -C "$__target" config --get remote.origin.url)" == "https://github.com/ohmyzsh/ohmyzsh.git" ]] ||
    fail "Oh My Zsh target origin is incorrect"

echo "Oh My Zsh bootstrap configuration passed."
