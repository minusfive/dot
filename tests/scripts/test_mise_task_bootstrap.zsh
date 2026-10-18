#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bootstrap task behavior..."

local __fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
local __stub_dir="$__fixture_dir/bin"
local __state_dir="$__fixture_dir/state"
local __log_file="$__fixture_dir/mise.log"
mkdir -p "$__stub_dir" "$__state_dir"
cat > "$__stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
    printf '%s\n' '2026.10.7 macos-arm64'
    exit 0
fi
printf '%s|DOT_PROFILE=%s|MISE_ENV=%s|MISE_AUTO_ENV=%s\n' \
    "$*" "${DOT_PROFILE:-}" "${MISE_ENV:-}" "${MISE_AUTO_ENV:-}" >> "$MISE_CALL_LOG"
if [[ "$*" == *"bootstrap"* && "$*" != *"--dry-run"* && "$*" != *"--skip task"* ]]; then
    printf '%s\n' "recursive bootstrap task invocation" >> "$MISE_CALL_LOG"
    exit 97
fi
EOF
chmod +x "$__stub_dir/mise"

local __state_file="$__state_dir/minusfive/profile"
local __status
local __real_mise="$(command -v mise)"
if (
    env HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" XDG_STATE_HOME="$__state_dir" \
        PATH="$__stub_dir:/usr/bin:/bin" MISE_PROJECT_ROOT="$__root_dir" \
        MISE_CALL_LOG="$__log_file" MISE_BOOTSTRAP_CONFIRM=yes \
        usage_profile=personal zsh "$__root_dir/scripts/tasks/bootstrap.zsh"
); then
    __status=0
else
    __status=$?
fi
[[ "$__status" -eq 0 ]] || fail "explicit personal bootstrap failed"
[[ -f "$__state_file" && "$(<"$__state_file")" == personal ]] ||
    fail "explicit profile was not persisted"
grep -qF 'self-update --yes|DOT_PROFILE=personal|MISE_ENV=|MISE_AUTO_ENV=' "$__log_file" ||
    fail "self-update did not receive the selected profile and cleaned environment"
grep -qF 'bootstrap --yes --skip task|DOT_PROFILE=personal|MISE_ENV=|MISE_AUTO_ENV=' "$__log_file" ||
    fail "bootstrap did not skip the recursive task phase or receive the selected profile"
if grep -qF 'recursive bootstrap task invocation' "$__log_file"; then
    fail "bootstrap task was invoked recursively"
fi

local __mtime_before
__mtime_before="$(stat -c '%Y' "$__state_file")"
local __dry_log="$__fixture_dir/dry.log"
if (
    env HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" XDG_STATE_HOME="$__state_dir" \
        PATH="$__stub_dir:/usr/bin:/bin" MISE_PROJECT_ROOT="$__root_dir" \
        MISE_CALL_LOG="$__dry_log" usage_profile=work usage_dry_run=true \
        zsh "$__root_dir/scripts/tasks/bootstrap.zsh"
); then
    __status=0
else
    __status=$?
fi
[[ "$__status" -eq 0 ]] || fail "dry run failed"
[[ "$(<"$__state_file")" == personal ]] || fail "dry run changed profile state"
[[ "$(stat -c '%Y' "$__state_file")" == "$__mtime_before" ]] ||
    fail "dry run changed profile state mtime"
grep -qF 'bootstrap --dry-run|DOT_PROFILE=work' "$__dry_log" ||
    fail "dry run did not hand off the selected profile"
if grep -qF 'self-update' "$__dry_log"; then
    fail "dry run performed self-update"
fi

if (
    env HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" XDG_STATE_HOME="$__state_dir" \
        PATH="$__stub_dir:/usr/bin:/bin" MISE_PROJECT_ROOT="$__root_dir" \
        MISE_CALL_LOG="$__fixture_dir/invalid.log" usage_profile=invalid \
        zsh "$__root_dir/scripts/tasks/bootstrap.zsh"
); then
    fail "invalid profile was accepted"
fi
[[ "$(<"$__state_file")" == personal ]] || fail "invalid profile changed state"

local __decline_log="$__fixture_dir/decline.log"
if (
    env HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" XDG_STATE_HOME="$__state_dir" \
        PATH="$__stub_dir:/usr/bin:/bin" MISE_PROJECT_ROOT="$__root_dir" \
        MISE_CALL_LOG="$__decline_log" MISE_BOOTSTRAP_CONFIRM=no \
        usage_profile=work zsh "$__root_dir/scripts/tasks/bootstrap.zsh"
); then
    __status=0
else
    __status=$?
fi
[[ "$__status" -eq 0 ]] || fail "declined confirmation failed"
[[ "$(<"$__state_file")" == personal ]] || fail "declined confirmation changed profile state"
[[ ! -s "$__decline_log" ]] || fail "declined confirmation ran mise commands"

for __profile in work personal; do
    local __cli_dry_log="$__fixture_dir/cli-$__profile.log"
    env HOME="$__fixture_dir/home" ZDOTDIR="$__fixture_dir/zsh" \
        XDG_STATE_HOME="$__state_dir" PATH="$__stub_dir:/usr/bin:/bin" \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        MISE_CALL_LOG="$__cli_dry_log" \
        "$__real_mise" -C "$__root_dir" run bootstrap \
        --profile "$__profile" --dry-run >/dev/null
    grep -qF "bootstrap --dry-run|DOT_PROFILE=$__profile" "$__cli_dry_log" ||
        fail "CLI dry run did not hand off the $__profile profile"
done

echo "Bootstrap task behavior passed."
