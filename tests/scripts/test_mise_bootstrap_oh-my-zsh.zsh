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
for __repo in \
    'https://github.com/ohmyzsh/ohmyzsh.git|'"$HOME/.config/oh-my-zsh" \
    'https://github.com/zdharma-continuum/fast-syntax-highlighting.git|'"$HOME/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting" \
    'https://github.com/Aloxaf/fzf-tab.git|'"$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab" \
    'https://github.com/Freed-Wu/fzf-tab-source.git|'"$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab-source" \
    'https://github.com/Pilaton/OhMyZsh-full-autoupdate.git|'"$HOME/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate" \
    'https://github.com/zsh-users/zsh-autosuggestions.git|'"$HOME/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions" \
    'https://github.com/jeffreytse/zsh-vi-mode.git|'"$HOME/.config/oh-my-zsh/custom/plugins/zsh-vi-mode"; do
    local __url="${__repo%%|*}"
    local __repo_target="${__repo#*|}"
    grep -qF "$__url" "$__config" || fail "Oh My Zsh repository URL is missing: $__url"
    [[ -d "$__repo_target" && ! -L "$__repo_target" ]] ||
        fail "Oh My Zsh repository target is invalid: $__repo_target"
done
grep -qF '"~/.config/zsh/.zshrc-zone-1.zsh/oh-my-zsh"' "$__config" ||
    fail "Oh My Zsh zshrc edit is missing"
grep -qF '[bootstrap.hooks]' "$__config" || fail "Oh My Zsh bootstrap hooks are missing"
grep -qF 'post-dotfiles = "mise run omz:update"' "$__config" ||
    fail "Oh My Zsh update hook is missing"
grep -qF '"~/.config/mise/conf.d/module.oh-my-zsh.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.oh-my-zsh.toml"
grep -qF '"~/.config/mise/tasks/omz/update.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy the Oh My Zsh update task"
grep -qF "'oh-my-zsh'," home/.config/mise/miserc.toml ||
    fail "oh-my-zsh must be present in the shared module list"
for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.oh-my-zsh.toml" ||
        fail "oh-my-zsh must be selected by the $__profile profile"
done
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
[[ "$(git -C "$__target" config --get remote.origin.url | sed 's/[.]git$//')" == "https://github.com/ohmyzsh/ohmyzsh" ]] ||
    fail "Oh My Zsh target origin is incorrect"

echo "Oh My Zsh bootstrap configuration passed."
