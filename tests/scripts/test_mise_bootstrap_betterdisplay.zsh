#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing BetterDisplay module ownership and local tasks..."
assert_module_package betterdisplay brew-cask:betterdisplay

local __module="home/.config/mise/conf.d/module.betterdisplay.toml"
local __control_plane="home/.config/mise/conf.d/module.mise.toml"
local __config_home="$(mktemp -d)"
trap 'rm -rf -- "$__config_home"' EXIT
grep -qF '"~/.config/BetterDisplay" = { source = "~/dev/personal/dot/home/.config/BetterDisplay", mode = "symlink-each", exclude = ["README.md"] }' "$__module" ||
    fail "BetterDisplay dotfile ownership is missing"
grep -qF '"~/.config/mise/conf.d/module.betterdisplay.toml"' "$__control_plane" ||
    fail "control-plane module does not deploy BetterDisplay ownership"

[[ -x scripts/tasks/betterdisplay/sync.zsh ]] ||
    fail "BetterDisplay sync task is not executable"
[[ ! -e scripts/tasks/betterdisplay/settings ]] ||
    fail "legacy BetterDisplay task directory remains"
[[ ! -e "home/.config/mise/tasks/betterdisplay" ]] ||
    fail "BetterDisplay tasks remain in the global task directory"
if grep -qF '~/.config/mise/tasks/betterdisplay' "$__control_plane"; then
    fail "global BetterDisplay task links remain"
fi
if grep -Eiq 'launchagent|timer|start_interval|run_at_load' \
    home/.config/mise/conf.d/module.betterdisplay.toml \
    "$__control_plane" \
    scripts/mise.zsh; then
    fail "BetterDisplay launch-agent or timer declarations remain"
fi

local __task_listing
__task_listing="$(env -u MISE_ENV MISE_PROJECT_ROOT="$__root_dir" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    XDG_CONFIG_HOME="$__config_home" mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^betterdisplay:sync[[:space:]]' ||
    fail "BetterDisplay sync task is not discoverable"
if print -r -- "$__task_listing" |
    grep -E '^betterdisplay:' |
    grep -v '^betterdisplay:sync[[:space:]]'; then
    fail "legacy BetterDisplay tasks remain discoverable"
fi

echo "BetterDisplay module ownership and local tasks passed."
