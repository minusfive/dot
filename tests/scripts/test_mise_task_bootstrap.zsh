#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bootstrap lifecycle tasks..."

local __pre_packages="home/.config/mise/tasks/bootstrap/pre-packages.zsh"
local __post_tools="home/.config/mise/tasks/bootstrap/post-tools.zsh"
[[ -x "$__pre_packages" ]] || fail "pre-packages task is missing or not executable"
[[ -x "$__post_tools" ]] || fail "post-tools task is missing or not executable"
zsh -n "$__pre_packages" || fail "pre-packages task has syntax errors"
zsh -n "$__post_tools" || fail "post-tools task has syntax errors"
grep -qF '#MISE confirm=' "$__pre_packages" ||
    fail "pre-packages task confirmation is missing"
grep -qF '#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {' \
    "$__pre_packages" ||
    fail "pre-packages profile flag is missing"
grep -qF '#USAGE      choice "work" help="Safest profile, default"' "$__pre_packages" ||
    fail "pre-packages work choice is missing"
grep -qF '#USAGE      choice "personal" help="adds personal resources and configurations"' \
    "$__pre_packages" ||
    fail "pre-packages personal choice is missing"
grep -qF 'mise upgrade --prune' "$__post_tools" ||
    fail "post-tools task does not upgrade mise tools"
grep -qF 'mise reshim -f' "$__post_tools" ||
    fail "post-tools task does not reshim mise tools"

local __fixture_home="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_home"' EXIT
local __fixture_bin="$__fixture_home/bin"
local __mise_log="$__fixture_home/mise.log"
mkdir -p "$__fixture_bin" "$__fixture_home/.config" "$__fixture_home/.local/state"
cat > "$__fixture_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MISE_TEST_LOG"
if [[ "$*" == *"--no-hooks dot apply"* && "${MISE_REFRESH_STATUS:-0}" != 0 ]]; then
    exit "$MISE_REFRESH_STATUS"
fi
EOF
chmod +x "$__fixture_bin/mise"

env \
    HOME="$__fixture_home" \
    XDG_STATE_HOME="$__fixture_home/.local/state" \
    PATH="$__fixture_bin:$PATH" \
    MISE_TEST_LOG="$__mise_log" \
    MISE_ENV=personal \
    usage_profile=personal \
    zsh "$__pre_packages" ||
    fail "pre-packages task did not persist the selected profile"
[[ "$(cat "$__fixture_home/.local/state/minusfive/profile")" == personal ]] ||
    fail "pre-packages task persisted the wrong profile"
grep -qF -- '--no-hooks dot apply --yes ~/.config/mise/miserc.local.toml' "$__mise_log" ||
    fail "pre-packages task did not refresh the persisted profile selector"

local __real_fixture_home="$__fixture_home/real"
mkdir -p "$__real_fixture_home/dev/personal" \
    "$__real_fixture_home/.config/mise" \
    "$__real_fixture_home/.local/state/minusfive"
ln -s "$__root_dir" "$__real_fixture_home/dev/personal/dot"
print -r -- work >| "$__real_fixture_home/.local/state/minusfive/profile"
print -r -- 'env = ["work"]' >| "$__real_fixture_home/.config/mise/miserc.local.toml"
env \
    HOME="$__real_fixture_home" \
    XDG_CONFIG_HOME="$__real_fixture_home/.config" \
    XDG_STATE_HOME="$__real_fixture_home/.local/state" \
    MISE_PROJECT_ROOT="$__root_dir" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true \
    MISE_AUTO_INSTALL=false \
    MISE_NOT_FOUND_AUTO_INSTALL=false \
    MISE_TASK_RUN_AUTO_INSTALL=false \
    MISE_ENV=personal \
    usage_profile=personal \
    zsh "$__pre_packages" >/dev/null 2>&1 ||
    fail "real pre-packages selector refresh failed"
[[ "$(cat "$__real_fixture_home/.local/state/minusfive/profile")" == personal ]] ||
    fail "real pre-packages task persisted the wrong profile"
grep -qxF 'env = ["personal"]' "$__real_fixture_home/.config/mise/miserc.local.toml" ||
    fail "real pre-packages task did not render the personal selector"

local __failure_fixture_home="$__fixture_home/failure"
mkdir -p "$__failure_fixture_home/.config/mise" "$__failure_fixture_home/.local/state/minusfive"
print -r -- work >| "$__failure_fixture_home/.local/state/minusfive/profile"
print -r -- 'env = ["work"]' >| "$__failure_fixture_home/.config/mise/miserc.local.toml"
: > "$__mise_log"
if env \
    HOME="$__failure_fixture_home" \
    XDG_STATE_HOME="$__failure_fixture_home/.local/state" \
    PATH="$__fixture_bin:$PATH" \
    MISE_TEST_LOG="$__mise_log" \
    MISE_REFRESH_STATUS=17 \
    MISE_ENV=personal \
    usage_profile=personal \
    zsh "$__pre_packages" >/dev/null 2>&1; then
    fail "pre-packages task ignored selector refresh failure"
fi
[[ "$(cat "$__failure_fixture_home/.local/state/minusfive/profile")" == work ]] ||
    fail "selector refresh failure did not restore the previous profile"
grep -qxF 'env = ["work"]' "$__failure_fixture_home/.config/mise/miserc.local.toml" ||
    fail "selector refresh failure did not restore the previous selector"

echo "Bootstrap lifecycle tasks passed."
