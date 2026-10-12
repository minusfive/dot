#!/usr/bin/env zsh
# Test the repository bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing repository bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.repos.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ ! -e "home/.config/mise/conf.d/bootstrap-repos.toml" ]] ||
    fail "legacy repository declaration must be retired"
grep -qF '"~/.config/mise/conf.d/module.repos.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.repos.toml"
grep -qF "[bootstrap.repos]" "$__config" || fail "repository bootstrap section is missing"

local -a __repos=(
    "powerlevel10k|https://github.com/romkatv/powerlevel10k.git|$HOME/.config/oh-my-zsh/custom/themes/powerlevel10k"
    "fast-syntax-highlighting|https://github.com/zdharma-continuum/fast-syntax-highlighting.git|$HOME/.config/oh-my-zsh/custom/plugins/fast-syntax-highlighting"
    "zsh-autosuggestions|https://github.com/zsh-users/zsh-autosuggestions.git|$HOME/.config/oh-my-zsh/custom/plugins/zsh-autosuggestions"
    "fzf-tab|https://github.com/Aloxaf/fzf-tab.git|$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab"
    "fzf-tab-source|https://github.com/Freed-Wu/fzf-tab-source.git|$HOME/.config/oh-my-zsh/custom/plugins/fzf-tab-source"
    "zsh-vi-mode|https://github.com/jeffreytse/zsh-vi-mode.git|$HOME/.config/oh-my-zsh/custom/plugins/zsh-vi-mode"
    "ohmyzsh-full-autoupdate|https://github.com/Pilaton/OhMyZsh-full-autoupdate.git|$HOME/.config/oh-my-zsh/custom/plugins/ohmyzsh-full-autoupdate"
    "LazyVim|git@github.com:minusfive/LazyVim.git|$HOME/dev/personal/nvim-plugins/LazyVim"
)
for __record in "${__repos[@]}"; do
    local __name="${__record%%|*}"
    local __rest="${__record#*|}"
    local __url="${__rest%%|*}"
    local __target="${__rest#*|}"
    grep -qF "$__url" "$__config" || fail "repository $__name URL is missing"
    [[ -d "$__target" && ! -L "$__target" ]] || fail "repository target is not a physical directory: $__target"
    [[ -z "$(git -C "$__target" status --porcelain)" ]] || fail "repository checkout is dirty: $__target"
done
grep -qF 'ref = "minusfive"' "$__config" || fail "LazyVim ref is missing"
[[ "$(git -C "$HOME/dev/personal/nvim-plugins/LazyVim" symbolic-ref --short HEAD)" == "minusfive" ]] ||
    fail "LazyVim checkout is not on the minusfive ref"

echo "Repository bootstrap configuration passed."
