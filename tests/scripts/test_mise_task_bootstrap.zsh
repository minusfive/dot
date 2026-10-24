#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bootstrap lifecycle tasks..."

local __pre_packages="home/.config/mise/tasks/bootstrap/pre-packages.zsh"
local __pre_dotfiles="home/.config/mise/tasks/bootstrap/pre-dotfiles.zsh"
local __post_tools="home/.config/mise/tasks/bootstrap/post-tools.zsh"
[[ -x "$__pre_packages" ]] || fail "pre-packages task is missing or not executable"
[[ -x "$__pre_dotfiles" ]] || fail "pre-dotfiles task is missing or not executable"
[[ -x "$__post_tools" ]] || fail "post-tools task is missing or not executable"
zsh -n "$__pre_packages" || fail "pre-packages task has syntax errors"
zsh -n "$__pre_dotfiles" || fail "pre-dotfiles task has syntax errors"
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
grep -qF '#MISE description="Validate the selected profile before dotfile bootstrap"' \
    "$__pre_dotfiles" ||
    fail "pre-dotfiles profile validation description is missing"
grep -qF '#MISE confirm={message="Continue bootstrap with the `{{ usage.profile }}` profile?", default="no"}' \
    "$__pre_dotfiles" ||
    fail "pre-dotfiles task confirmation is missing"
grep -qF '#USAGE flag "-p --profile <profile>" env="MISE_ENV" default="work" {' \
    "$__pre_dotfiles" ||
    fail "pre-dotfiles profile flag is missing"
grep -qF '#USAGE   env_fallback "DOT_PROFILE"' "$__pre_dotfiles" ||
    fail "pre-dotfiles profile fallback is missing"
grep -qF '#USAGE      choice "work" help="Safest profile, default"' "$__pre_dotfiles" ||
    fail "pre-dotfiles work choice is missing"
grep -qF '#USAGE      choice "personal" help="adds personal resources and configurations"' \
    "$__pre_dotfiles" ||
    fail "pre-dotfiles personal choice is missing"
grep -qF 'mise upgrade --prune' "$__post_tools" ||
    fail "post-tools task does not upgrade mise tools"
grep -qF 'mise reshim -f' "$__post_tools" ||
    fail "post-tools task does not reshim mise tools"

if grep -qE '__profile_file|miserc\.local\.toml|dot apply|previous_' "$__pre_packages" "$__pre_dotfiles"; then
    fail "pre-packages task still owns profile persistence or selector rendering"
fi

local __invalid_profile_log="$(mktemp)"
trap 'rm -f -- "$__invalid_profile_log"' EXIT
for __hook in pre-packages pre-dotfiles; do
    if env MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -E invalid -C "$__root_dir" run "bootstrap:$__hook" >| "$__invalid_profile_log" 2>&1; then
        fail "$__hook accepted an invalid environment profile"
    fi
    grep -qF "expected one of work, personal" "$__invalid_profile_log" ||
        fail "$__hook did not report its allowed profiles"
done

echo "Bootstrap lifecycle tasks passed."
