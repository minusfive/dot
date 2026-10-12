#!/usr/bin/env zsh
# Test the GitHub bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GitHub bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.gh.toml"
[[ -f "$__config" ]] || fail "missing $__config"
assert_module_package gh brew:gh
[[ -f "home/dev/profile.mise.toml" ]] || fail "missing profile source"
[[ -f "home/.config/gh/personal/hosts.yml" ]] || fail "missing GitHub hosts source"
if grep -qF "oauth_token:" "home/.config/gh/personal/hosts.yml"; then
    fail "GitHub hosts source must not contain an OAuth token"
fi

grep -qF '[bootstrap.directories."~/.config/gh/personal"]' "$__config" || fail "GitHub directory resource is missing"
grep -qF '"~/.config/gh/personal/hosts.yml" = { source = "~/dev/personal/dot/home/.config/gh/personal/hosts.yml", mode = "symlink" }' "$__config" ||
    fail "GitHub hosts dotfile resource is missing"
if grep -qF '[bootstrap.files."~/.config/gh/personal/hosts.yml"]' "$__config"; then
    fail "GitHub hosts resource must not remain a bootstrap file"
fi
grep -qF '"~/.config/mise/conf.d/module.gh.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.gh.toml"
grep -qF 'source = "~/dev/personal/dot/home/.config/gh/personal/hosts.yml"' "$__config" || fail "GitHub hosts source is missing"
if grep -qF 'bootstrap-gh.toml' home/.config/mise/conf.d/module.mise.toml; then
    fail "legacy GitHub declaration is still deployed"
fi
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
