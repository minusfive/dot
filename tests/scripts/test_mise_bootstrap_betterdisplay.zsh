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

for __task in \
    scripts/tasks/betterdisplay/settings/export.zsh \
    scripts/tasks/betterdisplay/settings/import.zsh; do
    [[ -x "$__task" ]] || fail "BetterDisplay task is not executable: $__task"
done
[[ ! -e "home/.config/mise/tasks/betterdisplay" ]] ||
    fail "BetterDisplay tasks remain in the global task directory"
if grep -qF '~/.config/mise/tasks/betterdisplay' "$__control_plane"; then
    fail "global BetterDisplay task links remain"
fi
if grep -Eiq 'launchagent|timer' home/.config/mise/conf.d/module.betterdisplay.toml "$__control_plane" scripts/mise.zsh; then
    fail "BetterDisplay launch-agent or timer declarations remain"
fi

local __task_listing
__task_listing="$(env -u MISE_ENV MISE_PROJECT_ROOT="$__root_dir" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    XDG_CONFIG_HOME="$__config_home" mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^betterdisplay:settings:export[[:space:]]' ||
    fail "BetterDisplay export task is not discoverable"
print -r -- "$__task_listing" | grep -q '^betterdisplay:settings:import[[:space:]]' ||
    fail "BetterDisplay import task is not discoverable"

echo "BetterDisplay module ownership and local tasks passed."
