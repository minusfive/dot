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

zsh -n scripts/install-mise.zsh || fail "scripts/install-mise.zsh has syntax errors"
[[ ! -e scripts/mise.zsh ]] || fail "duplicate mise lifecycle script remains"
[[ ! -e scripts/functions.zsh ]] || fail "duplicate bootstrap utility script remains"
grep -qF 'curl -fsSL https://mise.run | sh' scripts/install-mise.zsh || fail "mise installer bridge missing"
grep -qF 'local __code_color=$' scripts/install-mise.zsh ||
    fail "mise installer does not define terminal code formatting"
grep -qF 'mise run system:bootstrap --help${__reset_color}' scripts/install-mise.zsh ||
    fail "mise installer does not print canonical task instructions"
if grep -qF 'DOT_MISE_INSTALLED_DURING_RUN' scripts/install-mise.zsh; then
    fail "mise installer retains obsolete installer state forwarding"
fi
grep -qF 'export MISE_CONFIG_DIR=' scripts/tasks/system/bootstrap.zsh ||
    fail "bootstrap task does not select repository-scoped mise config"
grep -qF 'export MISE_ENV_CONF_D=true' scripts/tasks/system/bootstrap.zsh ||
    fail "bootstrap task does not enable mise conf.d modules"
grep -qF 'unset MISE_ENV' scripts/tasks/system/bootstrap.zsh ||
    fail "bootstrap task does not clear inherited MISE_ENV"
grep -qF 'unset MISE_AUTO_ENV' scripts/tasks/system/bootstrap.zsh ||
    fail "bootstrap task does not clear inherited MISE_AUTO_ENV"

grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml || fail "task include path is missing"
local __task_listing
__task_listing="$(XDG_CONFIG_HOME="$__root_dir/.config" DOT_PROFILE=work mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^setup[[:space:]]' || fail "setup task is not discoverable"
print -r -- "$__task_listing" | grep -q '^check[[:space:]]' || fail "check task is not discoverable"
print -r -- "$__task_listing" | grep -q '^system:bootstrap[[:space:]]' || fail "system bootstrap task is not discoverable"
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

grep -qF '"~/.config/mise/tasks/gh/auth/login.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "GitHub auth task is not owned by the mise control plane"
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
grep -qF 'min_version = "2026.10.7"' home/.config/mise/config.toml || fail "mise minimum version is missing"
grep -qF 'minimum_release_age = "7d"' home/.config/mise/config.toml || fail "minimum release age is missing"
grep -qF 'trusted_config_paths = ["~/dev/personal", "~/dev/personal/dot", "~/dev/work"]' home/.config/mise/config.toml ||
    fail "workspace trust paths are missing"
local __trust_data="$(mktemp -d)"
trap 'rm -rf -- "$__trust_data"' EXIT
for __workspace in personal work; do
    local __trust_status="$(
        env -u MISE_ENV MISE_DATA_DIR="$__trust_data" \
            mise -C "$HOME/dev/$__workspace" trust --show 2>&1
    )"
    print -r -- "$__trust_status" | grep -qF "~/dev/$__workspace: trusted" ||
        fail "workspace trust path is not active: $__workspace"
done
local __dot_trust_status="$(
    env -u MISE_ENV MISE_DATA_DIR="$__trust_data" \
        mise -C "$__root_dir" trust --show 2>&1
)"
local __expected_dot_trust="${__root_dir/#$HOME/~}: trusted"
print -r -- "$__dot_trust_status" | grep -qF "$__expected_dot_trust" ||
    fail "repository trust path is not active"
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
if grep -qE -- '--brew|--vm|brew\.zsh|vm\.zsh' scripts/install-mise.zsh; then
    fail "removed Homebrew and VM options remain in the mise installer"
fi
[[ ! -e scripts/os.zsh ]] || fail "OS operations must use mise macos tasks"

local __mise_source="home/.config/mise/conf.d/module.mise.toml"
local __mise_fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__trust_data" "$__mise_fixture_dir"' EXIT
local __mise_fixture_home="$__mise_fixture_dir/home"
local __mise_fixture_config="$__mise_fixture_dir/config"
mkdir -p \
    "$__mise_fixture_home/dev/personal" \
    "$__mise_fixture_config" \
    "$__mise_fixture_dir/data" \
    "$__mise_fixture_dir/cache" \
    "$__mise_fixture_dir/state"
ln -s "$__root_dir" "$__mise_fixture_home/dev/personal/dot"
{
    print -r -- "[settings.dotfiles]"
    print -r -- "relative_symlinks = true"
    print -r -- ""
    cat "$__mise_source"
} >| "$__mise_fixture_config/config.toml"
env -u MISE_ENV -u MISE_AUTO_ENV \
    HOME="$__mise_fixture_home" \
    XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
    MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
    MISE_CONFIG_DIR="$__mise_fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__mise_fixture_home" \
    MISE_DATA_DIR="$__mise_fixture_dir/data" \
    MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
    MISE_STATE_DIR="$__mise_fixture_dir/state" \
    MISE_ENV_CONF_D=true \
    mise -C "$__mise_fixture_home" dot apply --yes >/dev/null ||
    fail "isolated mise dotfile deployment failed"
local __mise_link_count
__mise_link_count="$(find "$__mise_fixture_home/.config/mise" -type l | wc -l | tr -d ' ')"
[[ "$__mise_link_count" -eq 114 ]] ||
    fail "expected 114 managed mise links from the control-plane declarations, found $__mise_link_count"
[[ -L "$__mise_fixture_home/.config/mise/conf.d/module.betterdisplay.toml" ]] ||
    fail "isolated deployment omitted the BetterDisplay module link"
if grep -qE '^"~/.config/mise/tasks/betterdisplay' "$__mise_source"; then
    fail "mise control-plane module still declares BetterDisplay task links"
fi
[[ ! -e "$__mise_fixture_home/.config/mise/tasks/betterdisplay" ]] ||
    fail "isolated deployment created BetterDisplay task links"
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
trap 'rm -rf -- "$__trust_data" "$__mise_fixture_dir" "$__tmp_home"' EXIT
mkdir -p "$__tmp_home/.config/mise/conf.d"
cp home/.config/mise/config.toml "$__tmp_home/.config/mise/config.toml"
cp home/.config/mise/miserc.toml "$__tmp_home/.config/mise/miserc.toml"
cp home/.config/mise/conf.d/module.discord.toml "$__tmp_home/.config/mise/conf.d/module.discord.toml"
mkdir -p "$__tmp_home/.local/state/minusfive"
print -r -- personal >| "$__tmp_home/.local/state/minusfive/profile"
printf '\nMISE_PROFILE_SMOKE_BASE = "1"\n' >> "$__tmp_home/.config/mise/config.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' >> "$__tmp_home/.config/mise/conf.d/module.discord.toml"

local __work_env
__work_env="$(env -u MISE_ENV HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" DOT_PROFILE=work mise -C "$__tmp_home" env --json)"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "work profile should load base config"
if print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "work profile should not load personal config"
fi

local __work_profile
__work_profile="$(env -u MISE_ENV HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" DOT_PROFILE=work mise -C "$__tmp_home" exec -- sh -c 'printf "%s" "$DOT_PROFILE"')"
[[ "$__work_profile" == work ]] || fail "explicit work profile should override persisted state"

local __persisted_env
__persisted_env="$(env -u MISE_ENV -u DOT_PROFILE HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" XDG_STATE_HOME="$__tmp_home/.local/state" mise -C "$__tmp_home" env --json)"
print -r -- "$__persisted_env" | grep -q '"DOT_PROFILE": "personal"' ||
    fail "mise should load the persisted profile when DOT_PROFILE is unset"

local __persisted_profile
__persisted_profile="$(env -u MISE_ENV -u DOT_PROFILE HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" XDG_STATE_HOME="$__tmp_home/.local/state" mise -C "$__tmp_home" exec -- sh -c 'printf "%s" "$DOT_PROFILE"')"
[[ "$__persisted_profile" == personal ]] || fail "mise should export the persisted profile"

local __personal_env
__personal_env="$(env -u MISE_ENV HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" DOT_PROFILE=personal mise -C "$__tmp_home" env --json)"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "personal profile should load base config"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"' || fail "personal profile should load personal config"

echo "Global mise configuration passed."
