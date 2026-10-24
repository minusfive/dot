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
grep -qF '#MISE description="Confirm the selected profile before package bootstrap"' \
    "$__pre_packages" ||
    fail "pre-packages task description is missing"
grep -qF '#MISE confirm={message="Continue bootstrap with the `{{ usage.profile }}` profile?", default="no"}' \
    "$__pre_packages" ||
    fail "pre-packages task confirmation is missing"
grep -qF '#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {' \
    "$__pre_packages" ||
    fail "pre-packages profile flag is missing"
grep -qF '#USAGE   env_fallback "DOT_PROFILE"' "$__pre_packages" ||
    fail "pre-packages profile fallback is missing"
grep -qF '#USAGE      choice "work" help="Safest profile, default"' "$__pre_packages" ||
    fail "pre-packages work choice is missing"
grep -qF '#USAGE      choice "personal" help="adds personal resources and configurations"' \
    "$__pre_packages" ||
    fail "pre-packages personal choice is missing"
grep -qF 'mise upgrade --prune' "$__post_tools" ||
    fail "post-tools task does not upgrade mise tools"
grep -qF 'mise reshim -f' "$__post_tools" ||
    fail "post-tools task does not reshim mise tools"

if grep -qE '__profile_file|miserc\.local\.toml|dot apply|previous_' "$__pre_packages"; then
    fail "pre-packages task still owns profile persistence or selector rendering"
fi

echo "Bootstrap lifecycle tasks passed."
