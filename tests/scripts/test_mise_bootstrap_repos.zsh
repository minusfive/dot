#!/usr/bin/env zsh
# Test the repository bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing repository bootstrap configuration..."

local __config=".config/mise/conf.d/bootstrap-repos.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF "[bootstrap.repos]" "$__config" || fail "repository bootstrap section is missing"

for __repo in \
    "powerlevel10k" \
    "fast-syntax-highlighting" \
    "zsh-autosuggestions" \
    "fzf-tab" \
    "zsh-vi-mode"; do
    grep -qF "$__repo" "$__config" || fail "repository $__repo is missing"
done

echo "Repository bootstrap configuration passed."
