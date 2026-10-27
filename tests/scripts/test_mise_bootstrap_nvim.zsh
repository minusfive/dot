#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Neovim bootstrap configuration..."

local __config="home/.config/mise/conf.d/nvim.toml"
assert_module_package nvim brew:neovim
assert_module_repo nvim \
    git@github.com:minusfive/LazyVim.git \
    "$HOME/dev/personal/nvim-plugins/LazyVim" \
    minusfive
local __source="home/.config/nvim"
local __target="$HOME/.config/nvim"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"nvim/config/nvim" = { source = "~/dev/personal/dot/home/.config/nvim", mode = "symlink-each", exclude = ["zshrc.zsh"], variants = [{ default = true, target = "{{ xdg_config_home }}/nvim" }] }' "$__config" ||
    fail "Neovim symlink-each declaration is missing"
[[ -f "$__source/zshrc.zsh" ]] || fail "missing Neovim Zsh source"
zsh -n "$__source/zshrc.zsh" || fail "Neovim Zsh source has syntax errors"
grep -qF '"~/.config/zsh/.zshrc-zone-2.zsh/nvim"' "$__config" ||
    fail "Neovim Zsh edit is missing"
[[ -d "$__target" && ! -L "$__target" ]] || fail "Neovim target must be a physical directory"
local __source_count="$(find "$__source" -type f | wc -l | tr -d ' ')"
local __link_count="$(find "$__target" -type l | wc -l | tr -d ' ')"
[[ "$__source_count" == "55" ]] || fail "expected 55 Neovim source files, found $__source_count"
[[ "$__link_count" == "54" ]] || fail "expected 54 Neovim links, found $__link_count"
[[ ! -e "$__target/zshrc.zsh" ]] || fail "Neovim Zsh source leaked into the runtime target"
find "$__target" -type l -exec sh -c 'for path do case "$(readlink "$path")" in /*) exit 1;; esac; done' sh {} + ||
    fail "Neovim deployed link is absolute"
[[ -f "$__target/.gitignore" ]] || fail "Neovim runtime boundary .gitignore is missing"
local __smoke_fixture="$(test_fixture_dir nvim-smoke)"
trap 'rm -rf -- "$__smoke_fixture"' EXIT
mkdir -p "$__smoke_fixture/.config" "$__smoke_fixture/data" \
    "$__smoke_fixture/state" "$__smoke_fixture/cache"
cp -RL "$__target" "$__smoke_fixture/.config/nvim" ||
    fail "could not copy the Neovim target into the smoke fixture"
local __smoke_output
if ! __smoke_output="$(
    env HOME="$__smoke_fixture" \
        XDG_CONFIG_HOME="$__smoke_fixture/.config" \
        XDG_DATA_HOME="$__smoke_fixture/data" \
        XDG_STATE_HOME="$__smoke_fixture/state" \
        XDG_CACHE_HOME="$__smoke_fixture/cache" \
        nvim --headless '+qa' 2>&1
)"; then
    print -r -- "$__smoke_output" >&2
    fail "Neovim headless smoke test failed"
fi

echo "Neovim bootstrap configuration passed."
