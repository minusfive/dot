#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

local __task="scripts/tasks/bootstrap.zsh"
[[ -f "$__task" ]] || fail "bootstrap task is missing"
[[ ! -e scripts/mise.zsh ]] || fail "retired mise lifecycle script remains"
zsh -n "$__task" || fail "bootstrap task has syntax errors"
grep -qF 'export MISE_CONFIG_DIR="$__project_root/home/.config/mise"' "$__task" ||
    fail "repository-scoped mise configuration is not selected"
grep -qF 'export MISE_ENV_CONF_D=true' "$__task" ||
    fail "MISE_ENV_CONF_D is not enabled"
grep -qF 'unset MISE_ENV' "$__task" || fail "inherited MISE_ENV is not cleared"
grep -qF 'unset MISE_AUTO_ENV' "$__task" || fail "inherited MISE_AUTO_ENV is not cleared"
grep -qF 'mise -C "$__project_root" self-update --yes' "$__task" ||
    fail "mise self-update is missing"
grep -qF 'mise -C "$__project_root" bootstrap --yes --skip task' "$__task" ||
    fail "full mise bootstrap without the recursive task phase is missing"
grep -qF 'gh auth status --hostname github.com' "$__task" ||
    fail "GitHub CLI authentication prerequisite is missing"
grep -qF 'curl -fsSL https://mise.run | sh' "$__task" ||
    fail "mise acquisition is missing"
[[ "$(grep -cF 'vared -p' "$__task")" -eq 1 ]] ||
    fail "bootstrap task must have one confirmation boundary"
for __obsolete_step in \
    'mise bootstrap packages apply --yes' \
    'mise bootstrap dotfiles apply --yes' \
    'mise bootstrap repos apply --yes' \
    'mise completion'; do
    if grep -qF "$__obsolete_step" "$__task"; then
        fail "lifecycle-owned step remains procedural: $__obsolete_step"
    fi
done
if grep -qE 'mise install([[:space:]]|$)' "$__task"; then
    fail "lifecycle-owned mise install remains procedural"
fi

local __fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
local __source_home="$__fixture_dir/source-home"
mkdir -p "$__source_home/dev/personal"
ln -s "$__root_dir" "$__source_home/dev/personal/dot"

local __work_dry_run
__work_dry_run="$(
    env -u MISE_ENV -u MISE_AUTO_ENV HOME="$__source_home" DOT_PROFILE=work \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" bootstrap --dry-run 2>&1
)"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: system packages' ||
    fail "work dry run is missing package bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: repos' ||
    fail "work dry run is missing repository bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: dotfiles' ||
    fail "work dry run is missing dotfile bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: tools' ||
    fail "work dry run is missing tool bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: final hooks' ||
    fail "work dry run is missing final hooks"

local __personal_dry_run
__personal_dry_run="$(
    env -u MISE_ENV -u MISE_AUTO_ENV HOME="$__source_home" DOT_PROFILE=personal \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" bootstrap --dry-run 2>&1
)"
print -r -- "$__personal_dry_run" | grep -qF 'brew-cask' ||
    fail "personal dry run is missing package bootstrap"

local __stub_dir="$__fixture_dir/bin"
local __log_file="$__fixture_dir/mise.log"
mkdir -p "$__stub_dir"
cat > "$__stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
    printf '%s\n' '2026.10.7 macos-arm64'
    exit 0
fi
printf '%s\n' "$*" >> "$MISE_CALL_LOG"
if [[ "$*" == *"bootstrap"* && "$*" != *"--dry-run"* && "$*" != *"--skip task"* ]]; then
    if (( ${MISE_STUB_DEPTH:-0} >= 1 )); then
        printf '%s\n' "recursive bootstrap task invocation" >> "$MISE_CALL_LOG"
        exit 97
    fi
    MISE_STUB_DEPTH=1 zsh "$MISE_TASK_SCRIPT"
fi
if [[ "$*" == *"bootstrap"* && "$*" != *"--dry-run"* ]]; then
    [[ "${MISE_STUB_BOOTSTRAP_STATUS:-ok}" == ok ]]
fi
EOF
chmod +x "$__stub_dir/mise"

local __run_status
if (
    env -u MISE_ENV -u MISE_AUTO_ENV HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" \
        XDG_STATE_HOME="$__fixture_dir/state" PATH="$__stub_dir:/usr/bin:/bin" \
        MISE_PROJECT_ROOT="$__root_dir" MISE_CALL_LOG="$__log_file" \
        MISE_TASK_SCRIPT="$__root_dir/$__task" \
        MISE_BOOTSTRAP_CONFIRM=yes zsh "$__root_dir/$__task"
); then
    __run_status=0
else
    __run_status=$?
fi
[[ "$__run_status" -eq 0 ]] || fail "successful lifecycle fixture failed"
grep -qF 'self-update --yes' "$__log_file" || fail "self-update did not run"
grep -qF 'bootstrap --yes --skip task' "$__log_file" ||
    fail "bootstrap did not skip the recursive task phase"
if grep -qF 'recursive bootstrap task invocation' "$__log_file"; then
    fail "bootstrap task was invoked recursively"
fi
[[ "$(sed -n '1p' "$__log_file")" == *"self-update --yes" ]] ||
    fail "self-update did not precede bootstrap"

MISE_STUB_BOOTSTRAP_STATUS=fail
if (
    env -u MISE_ENV -u MISE_AUTO_ENV HOME="$__fixture_dir/home-fail" ZDOTDIR="$__fixture_dir/zsh-fail" \
        XDG_STATE_HOME="$__fixture_dir/state-fail" PATH="$__stub_dir:/usr/bin:/bin" \
        MISE_PROJECT_ROOT="$__root_dir" MISE_CALL_LOG="$__fixture_dir/fail.log" \
        MISE_TASK_SCRIPT="$__root_dir/$__task" \
        MISE_BOOTSTRAP_CONFIRM=yes MISE_STUB_BOOTSTRAP_STATUS=fail \
        zsh "$__root_dir/$__task"
); then
    fail "bootstrap failure was ignored"
fi

echo "Mise bootstrap lifecycle passed."
