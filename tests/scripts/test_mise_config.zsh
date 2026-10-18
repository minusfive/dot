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

[[ -f "home/.config/mise/config.toml" ]] || fail "missing home/.config/mise/config.toml"
[[ -f "home/.config/mise/miserc.toml" ]] || fail "missing home/.config/mise/miserc.toml"
[[ -f "home/.config/mise/mise.lock" ]] || fail "missing home/.config/mise/mise.lock"
[[ -f "home/.config/mise/conf.d/module.mise.toml" ]] || fail "missing mise module declaration"
[[ ! -e "home/.config/mise/conf.d/bootstrap-ai.toml" ]] ||
    fail "empty legacy AI declaration should be removed"
if grep -qF '"~/.config/mise/conf.d/bootstrap-ai.toml"' home/.config/mise/conf.d/module.mise.toml; then
    fail "mise control-plane module still deploys the removed AI declaration"
fi
[[ ! -e ".config/mise" ]] || fail "legacy mise source should be removed"
[[ ! -e "home/.config/mise/mise.personal.toml" ]] || fail "obsolete personal config should be removed"
[[ ! -e "home/.config/mise/files" ]] || fail "obsolete mise files directory should be removed"

zsh -n scripts/mise.zsh || fail "scripts/mise.zsh has syntax errors"
grep -qF 'curl -fsSL https://mise.run | sh' scripts/mise.zsh || fail "mise installer bridge missing"
grep -qF 'if [[ -x "$HOME/.local/bin/mise" ]]; then' scripts/mise.zsh || fail "PATH refresh bridge missing"
grep -qF 'local __mise_path="$(command -v mise || true)"' scripts/mise.zsh ||
    fail "mise availability lookup missing"
grep -qF 'if [[ -z "$__mise_path" ]]; then' scripts/mise.zsh ||
    fail "mise availability check missing"
grep -qF '_v_mise_ensure_stable_path "$__mise_path"' scripts/mise.zsh ||
    fail "stable mise path setup is missing"
grep -qF 'export MISE_CONFIG_DIR="$__mise_config_dir"' scripts/mise.zsh ||
    fail "repository-scoped mise config is not selected"
grep -qF 'export MISE_ENV_CONF_D=true' scripts/mise.zsh ||
    fail "MISE_ENV_CONF_D is not enabled"
grep -qF 'unset MISE_ENV' scripts/mise.zsh || fail "inherited MISE_ENV is not cleared"
grep -qF 'unset MISE_AUTO_ENV' scripts/mise.zsh || fail "inherited MISE_AUTO_ENV is not cleared"
grep -qF 'mise -C "$__dotfiles_dir" bootstrap --yes' scripts/mise.zsh ||
    fail "full bootstrap lifecycle command is missing"
if grep -qF 'tasks info bootstrap' scripts/mise.zsh; then
    fail "bootstrap task preflight should be replaced by a package hook"
fi

local __self_update_line="$(line_of 'mise -C "$__dotfiles_dir" self-update --yes')"
local __bootstrap_line="$(line_of 'mise -C "$__dotfiles_dir" bootstrap --yes')"
local __confirm_count="$(grep -cF '_v_confirm_proceed' scripts/mise.zsh)"

for __line in \
    "$__self_update_line" \
    "$__bootstrap_line"; do
    [[ -n "$__line" ]] || fail "missing mise initialization step"
done

if ! (( __self_update_line < __bootstrap_line &&
    __confirm_count == 1 )); then
    fail "mise initialization phase order is incorrect"
fi
for __hook_command in \
    'mise bootstrap packages upgrade --yes' \
    'mise bootstrap packages prune --yes' \
    'mise upgrade --prune' \
    'mise reshim -f'; do
    if grep -qF "$__hook_command" scripts/mise.zsh; then
        fail "maintenance command remains procedural: $__hook_command"
    fi
done
for __obsolete_step in \
    'mise bootstrap packages apply --yes' \
    'mise bootstrap dotfiles apply --yes' \
    'mise bootstrap files apply --yes' \
    'mise bootstrap repos apply --yes' \
    'mise install'; do
    if grep -qF "$__obsolete_step" scripts/mise.zsh; then
        fail "lifecycle-owned step remains procedural: $__obsolete_step"
    fi
done

grep -qF 'module.betterdisplay.toml' home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay module is not owned by the mise control plane"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/export.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay export task is not owned by the mise control plane"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/import.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay import task is not owned by the mise control plane"
grep -qF '[bootstrap.macos.launchd.agents.betterdisplay-settings-export]' home/.config/mise/conf.d/module.betterdisplay.toml ||
    fail "BetterDisplay export bootstrap is not owned by its mise module"
if grep -qF 'betterdisplay.zsh' scripts/init.zsh; then
    fail "deleted BetterDisplay initializer remains wired into scripts/init.zsh"
fi

grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml || fail "task include path is missing"
local __task_listing
__task_listing="$(XDG_CONFIG_HOME="$__root_dir/.config" DOT_PROFILE=work mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^setup[[:space:]]' || fail "setup task is not discoverable"
print -r -- "$__task_listing" | grep -q '^check[[:space:]]' || fail "check task is not discoverable"
print -r -- "$__task_listing" | grep -q '^lint-skill-index[[:space:]]' || fail "lint-skill-index task is not discoverable"
print -r -- "$__task_listing" | grep -q '^ai:skills:evals:init[[:space:]]' || fail "ai:skills:evals:init task is not discoverable"
print -r -- "$__task_listing" | grep -q '^ai:skills:evals:prepare[[:space:]]' || fail "ai:skills:evals:prepare task is not discoverable"
print -r -- "$__task_listing" | grep -q '^ai:skills:validate-conflicts[[:space:]]' || fail "ai:skills:validate-conflicts task is not discoverable"
local __task_json
__task_json="$(XDG_CONFIG_HOME="$__root_dir/.config" DOT_PROFILE=work mise -C "$__root_dir" tasks ls --json)"
print -r -- "$__task_json" | jq -e 'any(.[]; (.aliases // []) | index("mise:tasks:validate-conflicts"))' >/dev/null ||
    fail "mise:tasks:validate-conflicts task alias is not discoverable"
print -r -- "$__task_listing" | grep -q '^ai:skills:evals:validate[[:space:]]' || fail "ai:skills:evals:validate task is not discoverable"
mise run lint-skill-index >/dev/null || fail "root skill index validation failed"
mise run lint-skill-index --base-path home >/dev/null || fail "home skill index validation failed"
grep -qF '["lint_skill_index"]' hk.pkl || fail "root skill index hook is missing"
grep -qF '["lint_home_skill_index"]' hk.pkl || fail "home skill index hook is missing"
grep -qF '["validate_skill_evals"]' hk.pkl || fail "skill evaluation validation hook is missing"
grep -qF '["validate_skill_name_conflicts"]' hk.pkl || fail "skill name conflict hook is missing"
grep -qF '["validate_task_name_conflicts"]' hk.pkl || fail "task name conflict hook is missing"

if grep -qF 'export MISE_ENV=' scripts/mise.zsh; then
    fail "scripts/mise.zsh must not export MISE_ENV"
fi
grep -qF "shared_modules" home/.config/mise/miserc.toml ||
    fail "shared profile module list is missing"
grep -qF "work_profile_modules" home/.config/mise/miserc.toml ||
    fail "work profile module list is missing"
grep -qF "personal_profile_modules" home/.config/mise/miserc.toml ||
    fail "personal profile module list is missing"
grep -qF "{% if env.DOT_PROFILE" home/.config/mise/miserc.toml ||
    fail "profile selection template is missing"
local __profile_config
for __profile in work personal; do
    __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.dockutil.toml" ||
        fail "dockutil module is missing from the $__profile profile"
    print -r -- "$__profile_config" | grep -qF "module.hammerspoon.toml" ||
        fail "Hammerspoon module is missing from the $__profile profile"
done
if grep -qF '"profiles"' home/.config/mise/miserc.toml; then
    fail "retired profiles environment remains selected"
fi
grep -qF "env_conf_d = true" home/.config/mise/miserc.toml || fail "env_conf_d is not enabled"
grep -qF 'minimum_release_age = "7d"' home/.config/mise/config.toml || fail "minimum release age is missing"
grep -qF 'trusted_config_paths = ["~/dev/personal", "~/dev/personal/dot", "~/dev/work"]' home/.config/mise/config.toml ||
    fail "workspace trust paths are missing"
local __trust_data="$(mktemp -d)"
for __workspace in personal work; do
    local __trust_status="$(
        env -u MISE_ENV MISE_DATA_DIR="$__trust_data" \
            mise -C "$HOME/dev/$__workspace" trust --show 2>&1
    )"
    print -r -- "$__trust_status" | grep -qF "~/dev/$__workspace: trusted" ||
        fail "workspace trust path is not active: $__workspace"
done
local __dot_trust_root="$HOME/dev/personal/dot"
local __dot_trust_status="$(
    env -u MISE_ENV MISE_DATA_DIR="$__trust_data" \
        mise -C "$__dot_trust_root" trust --show 2>&1
)"
print -r -- "$__dot_trust_status" | grep -qF "~/dev/personal/dot: trusted" ||
    fail "repository trust path is not active"
rm -rf "$__trust_data"
grep -qF '[settings.dotfiles]' home/.config/mise/config.toml || fail "dotfiles settings are missing"
grep -qF 'relative_symlinks = true' home/.config/mise/config.toml || fail "relative symlinks are not enabled"
grep -qF '"~/.config/mise/conf.d/module.mise.toml"' home/.config/mise/conf.d/module.mise.toml || fail "mise module must manage itself"
if grep -R -qF '../../../home' home/.config/mise; then
    fail "legacy relative mise source path remains"
fi
grep -qF 'source = "~/dev/personal/dot/home/AGENTS.md"' home/.config/mise/conf.d/module.copilot.toml ||
    fail "Copilot source path is not canonical"
[[ ! -e "home/.config/mise/conf.d/module.profiles.toml" ]] || fail "retired profile module remains"

[[ ! -L "$HOME/.config/mise" ]] || fail "mise target must be a physical directory"
grep -qF 'auto_env = true' home/.config/mise/miserc.toml ||
    fail "auto_env must load platform-specific conf.d modules"
if grep -qE -- '--brew|--vm|brew\.zsh|vm\.zsh' scripts/init.zsh scripts/functions.zsh; then
    fail "removed Homebrew and VM options remain in the initializer"
fi
[[ ! -e scripts/os.zsh ]] || fail "OS operations must use mise macos tasks"

local __mise_link_count
__mise_link_count="$(find "$HOME/.config/mise" -type l | wc -l | tr -d ' ')"
[[ -L "$HOME/.config/mise/tasks/betterdisplay/settings/export.zsh" ]] ||
    fail "BetterDisplay export task was not deployed as a symlink"
[[ -L "$HOME/.config/mise/tasks/betterdisplay/settings/import.zsh" ]] ||
    fail "BetterDisplay import task was not deployed as a symlink"
[[ "$__mise_link_count" -eq 112 ]] || fail "expected 112 managed mise links, found $__mise_link_count"
local __unset_mise_env_line="$(line_of "unset MISE_ENV")"
(( __unset_mise_env_line < __self_update_line )) || fail "MISE_ENV must be cleared before mise commands run"
for __local_pattern in \
    'mise.local.toml' \
    'mise.*.local.toml' \
    'miserc.local.toml' \
    'miserc.*.local.toml' \
    'config.local.toml' \
    'config.*.local.toml'; do
    grep -qF "$__local_pattern" home/.config/git/ignore || fail "missing global Git ignore pattern: $__local_pattern"
done

# Mise deploys this source file as Git's global excludes file.
[[ -f "home/.config/git/ignore" ]] || fail "mise global Git ignore source is missing"
[[ -L "$HOME/.config/git/ignore" ]] || fail "mise did not install the global Git ignore file"

for __local_file in \
    'mise.local.toml' \
    'mise.personal.local.toml' \
    'miserc.local.toml' \
    'miserc.personal.local.toml' \
    'config.local.toml' \
    'config.personal.local.toml'; do
    git check-ignore -q --no-index "$__local_file" ||
        fail "bootstrapped global Git ignore does not ignore local config: $__local_file"
done

local __tmp_home
__tmp_home="$(mktemp -d)"
trap 'rm -rf "$__tmp_home"' EXIT
mkdir -p "$__tmp_home/.config/mise/conf.d"
cp home/.config/mise/config.toml "$__tmp_home/.config/mise/config.toml"
cp home/.config/mise/miserc.toml "$__tmp_home/.config/mise/miserc.toml"
cp home/.config/mise/conf.d/module.discord.toml "$__tmp_home/.config/mise/conf.d/module.discord.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_BASE = "1"\n' >> "$__tmp_home/.config/mise/config.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' >> "$__tmp_home/.config/mise/conf.d/module.discord.toml"

local __work_env
__work_env="$(env -u MISE_ENV HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" DOT_PROFILE=work mise -C "$__tmp_home" env --json)"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "work profile should load base config"
if print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "work profile should not load personal config"
fi

local __personal_env
__personal_env="$(env -u MISE_ENV HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" DOT_PROFILE=personal mise -C "$__tmp_home" env --json)"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "personal profile should load base config"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"' || fail "personal profile should load personal config"

echo "Global mise configuration passed."
