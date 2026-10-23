#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

local __task="scripts/tasks/system/bootstrap.zsh"
[[ -x "$__task" ]] || fail "system bootstrap task is missing or not executable"
zsh -n "$__task" || fail "system bootstrap task has syntax errors"
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
if grep -qF 'final = [' home/.config/mise/conf.d/module-mise.toml; then
    fail "final bootstrap hook must not duplicate the bootstrap follow-up task"
fi
grep -qF '#MISE env={MISE_TASK_RUN_AUTO_INSTALL="false"}' "$__task" ||
    fail "bootstrap-only task auto-install suppression is missing"
grep -qF '#MISE confirm={message="Apply the `{{ usage.profile }}` system profile?", default="no"}' "$__task" ||
    fail "native profile confirmation template is missing"
grep -qF '#USAGE flag "-p --profile <profile>" env="MISE_ENV"' "$__task" ||
    fail "native profile Usage is missing"
grep -qF '#MISE description="Install tools, applications, and configure this system according to the selected profile.' "$__task" ||
    fail "bootstrap task description is missing"
grep -qF '**Currently selected profile: `{{ env.MISE_ENV | default(value=' "$__task" ||
    fail "task description does not use the selected environment template"
grep -qF '#USAGE   help "Select the profile to apply"' "$__task" ||
    fail "profile flag help does not describe only its purpose"
if grep -qE '^#USAGE.*\{\{ env\.DOT_PROFILE' "$__task"; then
    fail "profile flag help contains a Tera template"
fi
grep -qF '#USAGE   choices {' "$__task" ||
    fail "native profile choices are missing"
grep -qF '#USAGE      choice "work" help="Safest profile, default"' "$__task" ||
    fail "work profile description is missing"
grep -qF '#USAGE      choice "personal" help="adds personal resources and configurations"' "$__task" ||
    fail "personal profile description is missing"
grep -qF '#USAGE flag "--dry-run" help="Preview the selected `profile` actions without applying them or changing state."' "$__task" ||
    fail "dry-run help does not describe its behavior"
if grep -qF 'self-update' "$__task"; then
    fail "system bootstrap must use mise self-update settings"
fi
grep -qF 'mise -C "$__root_dir" -E "$__profile" bootstrap --yes' "$__task" ||
    fail "direct mise bootstrap is missing"
grep -qF 'mise -C "$__root_dir" -E "$__profile" bootstrap --dry-run' "$__task" ||
    fail "dry-run mise bootstrap is missing"
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
__help="$(env MISE_ENV=work "$__mise_bin" -C "$__root_dir" run system:bootstrap --help)"
print -r -- "$__help" | grep -qF '[possible values: work, personal]' ||
    fail "bootstrap help does not expose native profile choices"
print -r -- "$__help" | grep -qF 'Install tools, applications, and configure this system' ||
    fail "bootstrap help does not show the task description"
print -r -- "$__help" | grep -qF '**Currently selected profile: `work`**.' ||
    fail "bootstrap help does not show the selected profile"
print -r -- "$__help" | grep -qF '**`work`**: safest, default.' ||
    fail "bootstrap help does not explain the work profile"
print -r -- "$__help" | grep -qF '**`personal`**: adds personal resources' ||
    fail "bootstrap help does not explain the personal profile"
print -r -- "$__help" | grep -qF '[env: MISE_ENV]' ||
    fail "bootstrap help does not expose the profile environment default"
__help="$(env -u MISE_ENV -u DOT_PROFILE "$__mise_bin" -C "$__root_dir" run system:bootstrap --help)"
print -r -- "$__help" | grep -qF '**Currently selected profile: `work`**.' ||
    fail "task description does not show the work fallback when MISE_ENV is absent"

cat > "$__bin_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$BOOTSTRAP_LOG"
printf 'MISE_ENV=%s\n' "${MISE_ENV:-}" >> "$BOOTSTRAP_ENV"
printf 'DOT_PROFILE=%s\n' "${DOT_PROFILE:-}" >> "$BOOTSTRAP_ENV"
printf 'MISE_TASK_RUN_AUTO_INSTALL=%s\n' "${MISE_TASK_RUN_AUTO_INSTALL:-}" >> "$BOOTSTRAP_ENV"
if [[ "$*" == *"bootstrap --yes"* ]]; then
    mkdir -p "$(dirname "$BOOTSTRAP_PROFILE")"
    printf '%s\n' "${DOT_PROFILE:-work}" >| "$BOOTSTRAP_PROFILE"
fi
if [[ "$*" == *"bootstrap --yes"* && "${BOOTSTRAP_STATUS:-0}" != 0 ]]; then
    exit "$BOOTSTRAP_STATUS"
fi
EOF
chmod +x "$__bin_dir/mise"

run_task() {
    local -a __task_env=(
        env
        -u MISE_AUTO_ENV
        -u MISE_GLOBAL_CONFIG_FILE
    )
    if [[ -n "${MISE_ENV:-}" ]]; then
        __task_env+=(MISE_ENV="$MISE_ENV")
    else
        __task_env+=(-u MISE_ENV)
    fi
    __task_env+=(
        HOME="$__fixture_dir/home"
        XDG_CONFIG_HOME="$__fixture_dir/home/.config"
        XDG_STATE_HOME="$__fixture_dir/home/.local/state"
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise"
        MISE_ENV_CONF_D=true
        PATH="$__bin_dir:$PATH"
        BOOTSTRAP_LOG="$__log_file"
        BOOTSTRAP_ENV="$__env_file"
        BOOTSTRAP_PROFILE="$__fixture_dir/home/.local/state/minusfive/profile"
    )
    __task_env+=("$__mise_bin" -C "$__root_dir")
    "${__task_env[@]}" "$@"
}

mkdir -p "$__fixture_dir/home/.config"
ln -s "$__root_dir/home/.config/mise" "$__fixture_dir/home/.config/mise"
: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap --profile personal
grep -qF -- "-C $__root_dir -E personal bootstrap --yes" "$__log_file" ||
    fail "bootstrap lifecycle did not run"
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "confirmed profile was not persisted"
grep -qF 'MISE_ENV=personal' "$__env_file" ||
    fail "bootstrap task did not pass the selected MISE_ENV"
grep -qF 'DOT_PROFILE=personal' "$__env_file" ||
    fail "bootstrap task did not preserve DOT_PROFILE for existing consumers"
grep -qF 'MISE_TASK_RUN_AUTO_INSTALL=false' "$__env_file" ||
    fail "bootstrap task did not suppress outer task auto-install"

rm -f "$__fixture_dir/home/.config/mise/miserc.local.toml"
print -r -- personal >| "$__fixture_dir/home/.local/state/minusfive/profile"
: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap
grep -qF -- "-C $__root_dir -E personal bootstrap --yes" "$__log_file" ||
    fail "persisted personal profile was not used without a generated selector"

: > "$__log_file"
: > "$__env_file"
MISE_ENV=personal run_task run --yes system:bootstrap
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "profile-free bootstrap did not reuse the persisted profile"

rm -f "$__fixture_dir/home/.local/state/minusfive/profile"
: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "profile-free bootstrap did not use the work fallback"

print -r -- invalid >| "$__fixture_dir/home/.local/state/minusfive/profile"
if (MISE_ENV=invalid run_task run --yes system:bootstrap --dry-run > "$__fixture_dir/invalid-profile.txt" 2>&1); then
    fail "invalid persisted profile was accepted"
fi
grep -qF "expected one of work, personal" "$__fixture_dir/invalid-profile.txt" ||
    fail "invalid persisted profile did not report the allowed choices"

: > "$__log_file"
: > "$__env_file"
MISE_ENV=personal run_task run --yes system:bootstrap
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "profile environment default was not persisted"

: > "$__log_file"
: > "$__env_file"
MISE_ENV=personal run_task run --yes system:bootstrap --dry-run >/dev/null
grep -qF -- "-C $__root_dir -E personal bootstrap --dry-run" "$__log_file" ||
    fail "profile environment dry run did not invoke mise bootstrap"
if grep -qF -- "self-update --yes" "$__log_file"; then
    fail "profile environment dry run invoked self-update"
fi
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == personal ]] ||
    fail "profile environment dry run changed profile state"

: > "$__log_file"
: > "$__env_file"
run_task run --yes system:bootstrap --profile work
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "work profile was not persisted"

: > "$__log_file"
if run_task run --yes system:bootstrap --profile invalid >/dev/null 2>&1; then
    fail "invalid profile was accepted"
fi
[[ ! -s "$__log_file" ]] || fail "invalid profile ran the task body"
print -r -- work >| "$__fixture_dir/home/.local/state/minusfive/profile"
if MISE_ENV=work,personal run_task run --yes system:bootstrap --dry-run >/dev/null 2>&1; then
    fail "comma-separated profile environments were accepted"
fi
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "invalid environment changed profile state"

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
grep -qF -- "-C $__root_dir -E personal bootstrap --dry-run" "$__log_file" ||
    fail "dry run did not invoke mise bootstrap"
if grep -qF -- "self-update --yes" "$__log_file"; then
    fail "dry run invoked self-update"
fi
[[ "$(cat "$__fixture_dir/home/.local/state/minusfive/profile")" == work ]] ||
    fail "dry run changed profile state"

: > "$__log_file"
BOOTSTRAP_STATUS=17 run_task run --yes system:bootstrap --profile personal >/dev/null 2>&1 && fail "bootstrap failure was ignored"
grep -qF -- "-C $__root_dir -E personal bootstrap --yes" "$__log_file" ||
    fail "failed bootstrap was not attempted"

: > "$__log_file"
run_task run --yes system:bootstrap --profile personal
grep -qF -- "-C $__root_dir -E personal bootstrap --yes" "$__log_file" ||
    fail "bootstrap did not run"

echo "Mise bootstrap lifecycle passed."
