#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

local __task="scripts/tasks/system/bootstrap.zsh"
[[ -x "$__task" ]] || fail "system bootstrap task is missing or not executable"
zsh -n "$__task" || fail "system bootstrap task has syntax errors"
grep -qF '#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}' "$__task" ||
    fail "bootstrap-only task auto-install suppression is missing"
grep -qF '#MISE confirm={message="Apply the `{{ usage.profile }}` system profile?", default="no"}' "$__task" ||
    fail "native profile confirmation template is missing"
grep -qF '#USAGE flag "-p --profile <profile>" env="DOT_PROFILE"' "$__task" ||
    fail "native profile Usage is missing"
grep -qF '#MISE description="Install tools, applications, and configure this system according to the selected profile.' "$__task" ||
    fail "bootstrap task description is missing"
grep -qF '**Currently applied / persisted profile: `{{ env.DOT_PROFILE }}`**' "$__task" ||
    fail "task description does not use the profile template"
grep -qF '#USAGE   help "Select the profile to apply"' "$__task" ||
    fail "profile flag help does not describe only its purpose"
if grep -qE '^#USAGE.*\{\{ env\.DOT_PROFILE' "$__task"; then
    fail "profile flag help contains a Tera template"
fi
grep -qF '#USAGE   choices "work" "personal"' "$__task" ||
    fail "native profile choices are missing"
grep -qF '#USAGE   **`work`**: safest, default. Intended for work machines.' "$__task" ||
    fail "work profile description is missing"
grep -qF '#USAGE   **`personal`**: adds personal tools, applications, and configurations.' "$__task" ||
    fail "personal profile description is missing"
grep -qF '#USAGE flag "--dry-run" help="Preview the selected `profile` actions without applying them or changing state."' "$__task" ||
    fail "dry-run help does not describe its behavior"
grep -qF 'mise -C "$__root_dir" self-update --yes' "$__task" ||
    fail "existing-mise self-update is missing"
grep -qF 'mise -C "$__root_dir" bootstrap --yes' "$__task" ||
    fail "direct mise bootstrap is missing"
if grep -qE -- '--skip|--only|mise exec gh|setup-git' "$__task"; then
    fail "bootstrap task contains an obsolete lifecycle or authentication step"
fi

local __fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
local __bin_dir="$__fixture_dir/bin"
local __log_file="$__fixture_dir/mise.log"
local __env_file="$__fixture_dir/mise.env"
mkdir -p "$__bin_dir"

local __mise_bin="$(command -v mise)"
local __help
__help="$(env -u MISE_ENV DOT_PROFILE=work "$__mise_bin" -C "$__root_dir" run system:bootstrap --help)"
print -r -- "$__help" | grep -qF '[possible values: work, personal]' ||
    fail "bootstrap help does not expose native profile choices"
print -r -- "$__help" | grep -qF 'Install tools, applications, and configure this system' ||
    fail "bootstrap help does not show the task description"
print -r -- "$__help" | grep -qF '**Currently applied / persisted profile: `work`**.' ||
    fail "bootstrap help does not show the persisted profile override"
print -r -- "$__help" | grep -qF '**`work`**: safest, default.' ||
    fail "bootstrap help does not explain the work profile"
print -r -- "$__help" | grep -qF '**`personal`**: adds personal tools' ||
    fail "bootstrap help does not explain the personal profile"
print -r -- "$__help" | grep -qF '[env: DOT_PROFILE]' ||
    fail "bootstrap help does not expose the profile environment default"
__help="$(env -u MISE_ENV -u DOT_PROFILE "$__mise_bin" -C "$__root_dir" run system:bootstrap --help)"
print -r -- "$__help" | grep -qF '**Currently applied / persisted profile:' ||
    fail "task description does not show the persisted profile when DOT_PROFILE is absent"
unset DOT_PROFILE

cat > "$__bin_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$BOOTSTRAP_LOG"
printf '%s\n' "${MISE_TASK_RUN_AUTO_INSTALL:-}" >> "$BOOTSTRAP_ENV"
if [[ "$*" == *"bootstrap --yes"* && "${BOOTSTRAP_STATUS:-0}" != 0 ]]; then
    exit "$BOOTSTRAP_STATUS"
fi
EOF
chmod +x "$__bin_dir/mise"

run_task() {
    env -u MISE_ENV -u MISE_AUTO_ENV \
        HOME="$__fixture_dir/home" \
        XDG_STATE_HOME="$__fixture_dir/home/.local/state" \
        PATH="$__bin_dir:$PATH" \
        BOOTSTRAP_LOG="$__log_file" \
        BOOTSTRAP_ENV="$__env_file" \
        "$__mise_bin" -C "$__root_dir" "$@"
}

mkdir -p "$__fixture_dir/home"
: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap --profile personal
grep -qF -- "-C $__root_dir self-update --yes" "$__log_file" ||
    fail "existing mise did not self-update"
grep -qF -- "-C $__root_dir bootstrap --yes" "$__log_file" ||
    fail "bootstrap lifecycle did not run"
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "confirmed profile was not persisted"
grep -q '^false$' "$__env_file" || fail "bootstrap task did not suppress outer task auto-install"

: > "$__log_file"
: > "$__env_file"
(unset DOT_PROFILE; run_task run --yes system:bootstrap)
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "profile-free bootstrap did not reuse the persisted profile"

rm -f "$__fixture_dir/home/.local/state/minusfive/profile"
: > "$__log_file"
: > "$__env_file"
(unset DOT_PROFILE; run_task run --yes system:bootstrap)
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "profile-free bootstrap did not use the work fallback"

print -r -- invalid >| "$__fixture_dir/home/.local/state/minusfive/profile"
if (unset DOT_PROFILE; run_task run --yes system:bootstrap --dry-run > "$__fixture_dir/invalid-profile.txt" 2>&1); then
    fail "invalid persisted profile was accepted"
fi
grep -qF "expected one of work, personal" "$__fixture_dir/invalid-profile.txt" ||
    fail "invalid persisted profile did not report the allowed choices"

: > "$__log_file"
: > "$__env_file"
DOT_PROFILE=personal run_task run --yes system:bootstrap
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "profile environment default was not persisted"

: > "$__log_file"
: > "$__env_file"
DOT_PROFILE=personal run_task run --yes system:bootstrap --dry-run > "$__fixture_dir/profile-env-dry-run.txt"
grep -qF "Would apply the personal mise bootstrap profile." "$__fixture_dir/profile-env-dry-run.txt" ||
    fail "profile environment default was not applied"
[[ ! -s "$__log_file" ]] || fail "profile environment dry run invoked lifecycle commands"

: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap --profile work
grep -qF -- "-C $__root_dir self-update --yes" "$__log_file" ||
    fail "existing-mise self-update did not run on a later invocation"
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "work profile was not persisted"

: > "$__log_file"
if run_task run --yes system:bootstrap --profile invalid >/dev/null 2>&1; then
    fail "invalid profile was accepted"
fi
[[ ! -s "$__log_file" ]] || fail "invalid profile ran the task body"

local __decline_status=0
: > "$__log_file"
print -r -- "n" | run_task run system:bootstrap --profile personal >/dev/null 2>&1 ||
    __decline_status=${pipestatus[2]}
[[ "$__decline_status" -ne 0 ]] || fail "declined confirmation unexpectedly succeeded"
[[ ! -s "$__log_file" ]] || fail "declined confirmation ran mise"
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "declined confirmation changed profile state"

: > "$__log_file"
run_task run --yes system:bootstrap --profile personal --dry-run >/dev/null
[[ ! -s "$__log_file" ]] || fail "dry run invoked lifecycle commands"
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "dry run changed profile state"

: > "$__log_file"
BOOTSTRAP_STATUS=17 run_task run --yes system:bootstrap --profile personal >/dev/null 2>&1 && fail "bootstrap failure was ignored"
grep -qF -- "-C $__root_dir bootstrap --yes" "$__log_file" ||
    fail "failed bootstrap was not attempted"

: > "$__log_file"
run_task run --yes system:bootstrap --profile personal
grep -qF -- "-C $__root_dir self-update --yes" "$__log_file" ||
    fail "bootstrap did not self-update"
grep -qF -- "-C $__root_dir bootstrap --yes" "$__log_file" ||
    fail "bootstrap did not run after self-update"

echo "Mise bootstrap lifecycle passed."
