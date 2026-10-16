#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing 1Password bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.1password.toml"
assert_module_package 1password brew-cask:1password
assert_module_package 1password brew-cask:1password-cli
assert_module_package 1password mas:1569813296
local __source="home/.config/1Password/ssh/agent.toml"
local __target="$HOME/.config/1Password/ssh/agent.toml"
local __ssh_config="home/.ssh/config"
local __ssh_target="$HOME/.ssh/config"
[[ -f "$__config" && -f "$__source" ]] || fail "1Password source or declaration is missing"
grep -qF '"~/.config/1Password/ssh/agent.toml" = { source = "~/dev/personal/dot/home/.config/1Password/ssh/agent.toml", mode = "symlink" }' "$__config" ||
    fail "1Password agent symlink declaration is missing"
grep -qF '"~/.ssh/config" = { source = "~/dev/personal/dot/home/.ssh/config", mode = "symlink" }' "$__config" ||
    fail "SSH config symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/onepassword"' "$__config" ||
    fail "1Password zshrc edit is missing"
[[ -d "$HOME/.config/1Password" && ! -L "$HOME/.config/1Password" ]] ||
    fail "1Password target must be a physical directory"
[[ -L "$__target" ]] || fail "1Password agent target must be a symlink"
case "$(readlink "$__target")" in
    /*) fail "1Password agent link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__source")" ]] ||
    fail "1Password agent target does not resolve to the tracked source"
[[ -f "$__ssh_config" && -L "$__ssh_target" ]] || fail "SSH config source or target is missing"
case "$(readlink "$__ssh_target")" in
    /*) fail "SSH config target link is absolute" ;;
esac
[[ "$(realpath "$__ssh_target")" == "$(realpath "$__ssh_config")" ]] ||
    fail "SSH config target does not resolve to the tracked source"
[[ ! -e home/.config/1Password/id_rsa && ! -e home/.config/1Password/id_ed25519 ]] ||
    fail "private key entered the tracked 1Password source"
test -S "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" ||
    fail "1Password SSH agent socket is unavailable"
ssh -G github.com >/dev/null || fail "SSH configuration smoke test failed"
if grep -Eq 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY' "$__source"; then
    fail "private key material found in 1Password source"
fi

echo "1Password bootstrap configuration passed."
