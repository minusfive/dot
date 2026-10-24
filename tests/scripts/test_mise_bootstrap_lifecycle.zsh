#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

[[ ! -e "scripts/tasks/system/bootstrap.zsh" ]] ||
    fail "retired system bootstrap task remains"
zsh -n scripts/mise-env.zsh || fail "mise environment script has syntax errors"
local __follow_up_task="scripts/tasks/bootstrap.zsh"
[[ -x "$__follow_up_task" ]] || fail "bootstrap follow-up task is missing or not executable"
zsh -n "$__follow_up_task" || fail "bootstrap follow-up task has syntax errors"
for __command in \
    "mise run mise:cleanup:inventory" \
    "mise run mise:cleanup" \
    "mise fix"; do
    grep -qF "$__command" "$__follow_up_task" ||
        fail "bootstrap follow-up task is missing: $__command"
done
if grep -qF 'final = [' home/.config/mise/conf.d/mise.toml; then
    fail "final bootstrap hook must not duplicate the bootstrap follow-up task"
fi

local __mise_bin="$(command -v mise)"
local __help="$("$__mise_bin" -C "$__root_dir" bootstrap --help)"
print -r -- "$__help" | grep -qF 'Set up this machine from your mise config' ||
    fail "native bootstrap help is unavailable"
for __profile in work personal; do
    env MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        "$__mise_bin" -E "$__profile" -C "$__root_dir" bootstrap --dry-run >/dev/null ||
        fail "native $__profile bootstrap preview failed"
done

echo "Mise bootstrap lifecycle passed."
