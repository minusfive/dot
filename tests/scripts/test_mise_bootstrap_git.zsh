#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Git bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.git.toml"
local __source_config="home/.config/git/config"
local __source_ignore="home/.config/git/ignore"
local __target="$HOME/.config/git"
[[ -f "$__config" && -f "$__source_config" && -f "$__source_ignore" ]] ||
    fail "Git source or declaration is missing"
grep -qF '"~/.config/git" = { source = "~/dev/personal/dot/home/.config/git", mode = "symlink-each" }' "$__config" ||
    fail "Git symlink-each declaration is missing"
[[ -d "$__target" && ! -L "$__target" ]] || fail "Git target must be a physical directory"
for __path in "$__target/config" "$__target/ignore"; do
    [[ -L "$__path" ]] || fail "Git target is not a symlink: $__path"
    case "$(readlink "$__path")" in
        /*) fail "Git target link is absolute: $__path" ;;
    esac
done
[[ "$(realpath "$__target/config")" == "$(realpath "$__source_config")" ]] ||
    fail "Git config target does not resolve to the tracked source"
[[ "$(realpath "$__target/ignore")" == "$(realpath "$__source_ignore")" ]] ||
    fail "Git ignore target does not resolve to the tracked source"
git config --global --get gpg.format | grep -Fx ssh >/dev/null || fail "Git SSH signing format changed"
git config --global --get commit.gpgsign | grep -Fx true >/dev/null || fail "Git commit signing changed"
git config --global --get tag.gpgsign | grep -Fx true >/dev/null || fail "Git tag signing changed"
local __signer="$(git config --global --get gpg.ssh.program)"
[[ -x "$__signer" ]] || fail "Git SSH signing program is unavailable"
git check-ignore -q --no-index mise.local.toml || fail "Git global ignore does not cover mise.local.toml"
git check-ignore -q --no-index config.personal.local.toml || fail "Git global ignore does not cover config.personal.local.toml"
if rg -n -i '(api[_-]?key|token|secret|credential|private[[:space:]_-]?key|auth[.]db)' "$__source_config" "$__source_ignore"; then
    fail "credential-like content found in Git sources"
fi

echo "Git bootstrap configuration passed."
