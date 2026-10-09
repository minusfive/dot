#!/usr/bin/env zsh
# Test global mise configuration and initialization wiring.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing global mise configuration..."

[[ -f ".mise/config.toml" ]] || fail "missing .mise/config.toml"
[[ -f ".mise/conf.d/tasks.toml" ]] || fail "missing .mise/conf.d/tasks.toml"
[[ -f ".mise/conf.d/tools.toml" ]] || fail "missing .mise/conf.d/tools.toml"
[[ -f ".mise/mise.lock" ]] || fail "missing .mise/mise.lock"
[[ ! -f "mise.toml" ]] || fail "root mise.toml should be removed"
[[ ! -f "mise.lock" ]] || fail "root mise.lock should be removed"

[[ -f ".config/mise/config.toml" ]] || fail "missing .config/mise/config.toml"
[[ -f ".config/mise/miserc.toml" ]] || fail "missing .config/mise/miserc.toml"
[[ -f ".config/mise/mise.lock" ]] || fail "missing .config/mise/mise.lock"
[[ ! -f ".config/mise/mise.personal.toml" ]] || fail "obsolete personal config should be removed"
[[ ! -e ".config/mise/files" ]] || fail "obsolete mise files directory should be removed"

zsh -n scripts/mise.zsh || fail "scripts/mise.zsh has syntax errors"
grep -qF 'curl -fsSL https://mise.run | sh' scripts/mise.zsh || fail "mise installer bridge missing"
grep -qF 'if [[ -x "$HOME/.local/bin/mise" ]]; then' scripts/mise.zsh || fail "PATH refresh bridge missing"
grep -qF 'if [[ $(command -v mise) == "" ]]; then' scripts/mise.zsh || fail "mise availability check missing"

local __packages_line="$(line_of "mise bootstrap packages apply --yes")"
local __files_line="$(line_of "mise bootstrap files apply --yes")"
local __personal_trust_line="$(line_of 'mise trust --yes "$HOME/dev/personal/mise.toml"')"
local __work_trust_line="$(line_of 'mise trust --yes "$HOME/dev/work/mise.toml"')"
local __self_update_line="$(line_of "mise self-update --yes")"
local __prune_line="$(line_of "mise prune")"
local __install_line="$(line_of "mise install")"
local __upgrade_line="$(line_of "mise upgrade")"
local __reshim_line="$(line_of "mise reshim -f")"
local __repos_line="$(line_of "mise bootstrap repos apply --yes")"
local __dotfiles_line="$(line_of "mise bootstrap dotfiles apply --yes")"

for __line in \
    "$__self_update_line" \
    "$__packages_line" \
    "$__files_line" \
    "$__personal_trust_line" \
    "$__work_trust_line" \
    "$__prune_line" \
    "$__install_line" \
    "$__upgrade_line" \
    "$__reshim_line" \
    "$__repos_line" \
    "$__dotfiles_line"; do
    [[ -n "$__line" ]] || fail "missing mise initialization step"
done

if ! (( __self_update_line < __packages_line &&
    __packages_line < __files_line &&
    __files_line < __personal_trust_line &&
    __personal_trust_line < __work_trust_line &&
    __work_trust_line < __prune_line &&
    __prune_line < __install_line &&
    __install_line < __upgrade_line &&
    __upgrade_line < __reshim_line &&
    __reshim_line < __repos_line &&
    __repos_line < __dotfiles_line )); then
    fail "mise initialization phase order is incorrect"
fi

grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml || fail "task include path is missing"
local __task_listing
__task_listing="$(XDG_CONFIG_HOME="$__root_dir/.config" DOT_PROFILE=work mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^setup[[:space:]]' || fail "setup task is not discoverable"
print -r -- "$__task_listing" | grep -q '^check[[:space:]]' || fail "check task is not discoverable"
print -r -- "$__task_listing" | grep -q '^lint-skill-index[[:space:]]' || fail "lint-skill-index task is not discoverable"
mise run lint-skill-index >/dev/null || fail "root skill index validation failed"
mise run lint-skill-index --base-path home >/dev/null || fail "home skill index validation failed"
grep -qF '["lint_skill_index"]' hk.pkl || fail "root skill index hook is missing"
grep -qF '["lint_home_skill_index"]' hk.pkl || fail "home skill index hook is missing"

grep -qF "env = [\"{{ env.DOT_PROFILE | default(value='work') }}\"]" .config/mise/miserc.toml || fail "profile bridge is missing"
grep -qF "env_conf_d = true" .config/mise/miserc.toml || fail "env_conf_d is not enabled"
grep -qF 'minimum_release_age = "7d"' .config/mise/config.toml || fail "minimum release age is missing"
grep -qF '[settings.dotfiles]' .config/mise/config.toml || fail "dotfiles settings are missing"
grep -qF 'relative_symlinks = true' .config/mise/config.toml || fail "relative symlinks are not enabled"
for __local_pattern in \
    'mise.local.toml' \
    'mise.*.local.toml' \
    'miserc.local.toml' \
    'miserc.*.local.toml' \
    'config.local.toml' \
    'config.*.local.toml'; do
    grep -qF "$__local_pattern" .config/git/ignore || fail "missing global Git ignore pattern: $__local_pattern"
done

# Stow installs this source file as Git's global excludes file.
local __tmp_stow_home
__tmp_stow_home="$(mktemp -d)"
trap 'rm -rf "$__tmp_stow_home"' EXIT
mkdir -p "$__tmp_stow_home/.config"
stow -R . --dir="$__root_dir" --target="$__tmp_stow_home" >/dev/null || fail "Stow bootstrap failed"
local __global_ignore="$__tmp_stow_home/.config/git/ignore"
[[ -f "$__global_ignore" ]] || fail "Stow did not install the global Git ignore file"
[[ "$(realpath "$__global_ignore")" == "$(realpath ".config/git/ignore")" ]] || fail "global Git ignore source is incorrect"

for __local_file in \
    'mise.local.toml' \
    'mise.personal.local.toml' \
    'miserc.local.toml' \
    'miserc.personal.local.toml' \
    'config.local.toml' \
    'config.personal.local.toml'; do
    HOME="$__tmp_stow_home" XDG_CONFIG_HOME="$__tmp_stow_home/.config" \
        git check-ignore -q --no-index "$__local_file" ||
        fail "bootstrapped global Git ignore does not ignore local config: $__local_file"
done
grep -qF '^/\.mise' .stow-local-ignore || fail "Stow should ignore .mise"
grep -qF '^/home' .stow-local-ignore || fail "Stow should ignore home sources"

local __tmp_config_home
__tmp_config_home="$(mktemp -d)"
trap 'rm -rf "$__tmp_stow_home" "$__tmp_config_home"' EXIT
mkdir -p "$__tmp_config_home/mise/conf.d"
cp .config/mise/config.toml "$__tmp_config_home/mise/config.toml"
cp .config/mise/miserc.toml "$__tmp_config_home/mise/miserc.toml"
cp .config/mise/conf.d/bootstrap-packages.personal.toml "$__tmp_config_home/mise/conf.d/bootstrap-packages.personal.toml"
printf '[env]\nMISE_PROFILE_SMOKE_WORK = "1"\n' > "$__tmp_config_home/mise/config.work.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_BASE = "1"\n' >> "$__tmp_config_home/mise/config.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' >> "$__tmp_config_home/mise/conf.d/bootstrap-packages.personal.toml"

local __work_env
__work_env="$(env -u MISE_ENV XDG_CONFIG_HOME="$__tmp_config_home" DOT_PROFILE=work mise -C "$__tmp_config_home" env --json)"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "work profile should load base config"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_WORK": "1"' || fail "work profile should load work config"
if print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "work profile should not load personal config"
fi

local __personal_env
__personal_env="$(env -u MISE_ENV XDG_CONFIG_HOME="$__tmp_config_home" DOT_PROFILE=personal mise -C "$__tmp_config_home" env --json)"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "personal profile should load base config"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"' || fail "personal profile should load personal config"
if print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_WORK": "1"'; then
    fail "personal profile should not load work config"
fi

echo "Global mise configuration passed."
