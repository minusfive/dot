#!/usr/bin/env zsh
# Test the GitHub bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GitHub bootstrap configuration..."

local __config="home/.config/mise/conf.d/module-gh.toml"
[[ -f "$__config" ]] || fail "missing $__config"
assert_module_package gh brew:gh
grep -qF '[bootstrap.hooks]' "$__config" || fail "GitHub post-packages hook is missing"
grep -qF "post-packages = 'gh extension install --force" "$__config" ||
    fail "GitHub post-packages hook phase is missing"
grep -qF 'gh extension install --force "yusukebe/gh-markdown-preview"' "$__config" ||
    fail "GitHub extension install is missing from the post-packages hook"
[[ -f "home/.config/gh/gh-personal.mise.toml" ]] || fail "missing personal GH environment source"
[[ -f "home/.config/gh/gh-work.mise.toml" ]] || fail "missing work GH environment source"
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
grep -qF '"~/.config/mise/conf.d/module-gh.toml"' home/.config/mise/conf.d/module-mise.toml ||
    fail "mise control-plane module does not deploy module-gh.toml"
grep -qF 'source = "~/dev/personal/dot/home/.config/gh/personal/hosts.yml"' "$__config" || fail "GitHub hosts source is missing"
grep -qF '"~/dev/personal/mise.toml/gh-config" = { source = "~/dev/personal/dot/home/.config/gh/gh-personal.mise.toml", template = "tera", merge = true }' "$__config" ||
    fail "personal GH_CONFIG_DIR merge entry is missing"
grep -qF '"~/dev/work/mise.toml/gh-config" = { source = "~/dev/personal/dot/home/.config/gh/gh-work.mise.toml", template = "tera", merge = true }' "$__config" ||
    fail "work GH_CONFIG_DIR merge entry is missing"
grep -qF 'GH_CONFIG_DIR = "{{ env.HOME }}/.config/gh/personal"' home/.config/gh/gh-personal.mise.toml ||
    fail "personal GH_CONFIG_DIR source is missing"
grep -qF 'GH_CONFIG_DIR = "{{ env.HOME }}/.config/gh/work"' home/.config/gh/gh-work.mise.toml ||
    fail "work GH_CONFIG_DIR source is missing"
if grep -qF 'bootstrap-gh.toml' home/.config/mise/conf.d/module-mise.toml; then
    fail "legacy GitHub declaration is still deployed"
fi
[[ ! -e "home/.config/mise/conf.d/module-profiles.toml" ]] ||
    fail "retired profile module remains"
local __merge_dry_run="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" bootstrap dotfiles apply --dry-run 2>&1
)"
print -r -- "$__merge_dry_run" | grep -qF 'edit ~/dev/personal/mise.toml (merge:gh-config)' ||
    fail "personal GH_CONFIG_DIR merge is not active"
print -r -- "$__merge_dry_run" | grep -qF 'edit ~/dev/work/mise.toml (merge:gh-config)' ||
    fail "work GH_CONFIG_DIR merge is not active"
for __target in "$HOME/dev/personal/mise.toml" "$HOME/dev/work/mise.toml"; do
    [[ -f "$__target" && ! -L "$__target" ]] || fail "workspace mise target is not a regular file: $__target"
done
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/personal\"" "$HOME/dev/personal/mise.toml" ||
    fail "personal workspace GH_CONFIG_DIR is incorrect"
grep -Fxq "GH_CONFIG_DIR = \"$HOME/.config/gh/work\"" "$HOME/dev/work/mise.toml" ||
    fail "work workspace GH_CONFIG_DIR is incorrect"
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
