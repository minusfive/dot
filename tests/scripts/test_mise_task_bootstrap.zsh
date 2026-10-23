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
grep -qF '#USAGE flag "-p --profile <profile>" env="DOT_PROFILE" default="work" {' \
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
mkdir -p "$__fixture_home/.config" "$__fixture_home/.local/state"

env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_STATE_HOME="$__fixture_home/.local/state" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true \
    DOT_PROFILE=personal \
    mise --yes -C "$__root_dir" run bootstrap:pre-packages >/dev/null ||
    fail "pre-packages task did not persist the selected profile"
[[ "$(cat "$__fixture_home/.local/state/minusfive/profile")" == personal ]] ||
    fail "pre-packages task persisted the wrong profile"

if env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_STATE_HOME="$__fixture_home/.local/state" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true \
    DOT_PROFILE=invalid \
    mise --yes -C "$__root_dir" run bootstrap:pre-packages >/dev/null 2>&1; then
    fail "pre-packages task accepted an invalid profile"
fi

echo "Bootstrap lifecycle tasks passed."
