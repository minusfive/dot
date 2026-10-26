#!/usr/bin/env zsh
# Test global mise configuration and initialization wiring.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing global mise configuration..."

export MISE_AUTO_INSTALL=false
export MISE_EXEC_AUTO_INSTALL=false
export MISE_NOT_FOUND_AUTO_INSTALL=false

[[ -f ".mise/config.toml" ]] || fail "missing .mise/config.toml"
[[ -f ".mise/conf.d/tasks.toml" ]] || fail "missing .mise/conf.d/tasks.toml"
[[ -f ".mise/conf.d/tools.toml" ]] || fail "missing .mise/conf.d/tools.toml"
[[ -f ".mise/mise.lock" ]] || fail "missing .mise/mise.lock"
[[ ! -f "mise.toml" ]] || fail "root mise.toml should be removed"
[[ ! -f "mise.lock" ]] || fail "root mise.lock should be removed"

[[ -f "home/.config/mise/config.toml" ]] || fail "missing home/.config/mise/config.toml"
[[ -f "home/.config/mise/miserc.toml" ]] || fail "missing home/.config/mise/miserc.toml"
[[ -f "home/.config/mise/mise.lock" ]] || fail "missing home/.config/mise/mise.lock"
[[ -f "home/.config/mise/conf.d/mise.toml" ]] || fail "missing mise module declaration"
[[ ! -e "home/.config/mise/conf.d/bootstrap-ai.toml" ]] ||
    fail "empty legacy AI declaration should be removed"
if grep -qF '"~/.config/mise/conf.d/bootstrap-ai.toml"' home/.config/mise/conf.d/mise.toml; then
    fail "mise control-plane module still deploys the removed AI declaration"
fi
[[ ! -e ".config/mise" ]] || fail "legacy mise source should be removed"
[[ ! -e "home/.config/mise/mise.personal.toml" ]] || fail "obsolete personal config should be removed"
[[ ! -e "home/.config/mise/files" ]] || fail "obsolete mise files directory should be removed"

[[ ! -e scripts/mise.zsh ]] || fail "duplicate mise lifecycle script remains"
[[ ! -e scripts/functions.zsh ]] || fail "duplicate bootstrap utility script remains"
grep -qF 'export MISE_CONFIG_DIR=' scripts/mise-env.zsh ||
    fail "mise environment script does not select repository-scoped mise config"
grep -qF 'export MISE_ENV_CONF_D=true' scripts/mise-env.zsh ||
    fail "mise environment script does not enable mise conf.d modules"
grep -qE 'unset .* MISE_AUTO_ENV([[:space:]]|$)' scripts/mise-env.zsh ||
    fail "mise environment script does not clear inherited MISE_AUTO_ENV"
[[ ! -e scripts/tasks/system/bootstrap.zsh ]] || fail "retired bootstrap task remains"

grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml || fail "task include path is missing"
env -u MISE_ENV -u MISE_AUTO_ENV \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    mise -C "$__root_dir" tasks validate --errors-only >/dev/null ||
    fail "mise task definitions failed native validation"
mise run lint-skill-index >/dev/null || fail "root skill index validation failed"
mise run lint-skill-index --base-path home >/dev/null || fail "home skill index validation failed"
grep -qF '["lint_skill_index"]' hk.pkl || fail "root skill index hook is missing"
grep -qF '["lint_home_skill_index"]' hk.pkl || fail "home skill index hook is missing"
grep -qF '["validate_skill_evals"]' hk.pkl || fail "skill evaluation validation hook is missing"
grep -qF '["validate_skill_name_conflicts"]' hk.pkl || fail "skill name conflict hook is missing"
grep -qF '["validate_task_name_conflicts"]' hk.pkl || fail "task name conflict hook is missing"

grep -qF '"~/.config/mise/tasks/gh/auth/login.zsh"' home/.config/mise/conf.d/mise.toml ||
    fail "GitHub auth task is not owned by the mise control plane"
[[ -f "home/.config/mise/miserc.local.toml.tmpl" ]] ||
    fail "persisted profile selector template is missing"
[[ -f "home/.config/mise/profile.tmpl" ]] ||
    fail "resolved profile template is missing"
grep -qF '"~/.config/mise/miserc.local.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "control plane does not deploy the persisted profile selector"
grep -qF 'miserc.local.toml.tmpl", mode = "template", template = "tera"' home/.config/mise/conf.d/mise.toml ||
    fail "persisted profile selector is not rendered with Tera"
grep -qF '"~/.local/state/minusfive/profile"' home/.config/mise/conf.d/mise.toml ||
    fail "control plane does not deploy the resolved profile state"
grep -qF 'profile.tmpl", mode = "template", template = "tera"' home/.config/mise/conf.d/mise.toml ||
    fail "resolved profile state is not rendered with Tera"
if grep -qE 'shared_modules|work_profile_modules|personal_profile_modules|^env = ' home/.config/mise/miserc.toml; then
    fail "profile module arrays or rendered environment remain in miserc.toml"
fi
local __profile_config
for __profile in work personal; do
    __profile_config="$(
        env MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "dockutil.toml" ||
        fail "dockutil module is missing from the $__profile profile"
    print -r -- "$__profile_config" | grep -qF "hammerspoon.toml" ||
        fail "Hammerspoon module is missing from the $__profile profile"
done
if grep -qF '"profiles"' home/.config/mise/miserc.toml; then
    fail "retired profiles environment remains selected"
fi
grep -qF "env_conf_d = true" home/.config/mise/miserc.toml || fail "env_conf_d is not enabled"
grep -qF 'min_version = "2026.10.19"' home/.config/mise/config.toml || fail "mise minimum version is missing"
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
grep -qF '"~/.config/mise/conf.d/mise.toml"' home/.config/mise/conf.d/mise.toml || fail "mise module must manage itself"
if grep -R -qF '../../../home' home/.config/mise; then
    fail "legacy relative mise source path remains"
fi
grep -qF 'source = "~/dev/personal/dot/home/AGENTS.md"' home/.config/mise/conf.d/copilot.toml ||
    fail "Copilot source path is not canonical"
[[ ! -e "home/.config/mise/conf.d/profiles.toml" ]] || fail "retired profile module remains"

[[ ! -L "$HOME/.config/mise" ]] || fail "mise target must be a physical directory"
grep -qF 'auto_env = true' home/.config/mise/miserc.toml ||
    fail "auto_env must load platform-specific conf.d modules"
if grep -qE -- '--brew|--vm|brew\.zsh|vm\.zsh' scripts/install-mise.zsh; then
    fail "removed Homebrew and VM options remain in the mise installer"
fi
[[ ! -e scripts/os.zsh ]] || fail "OS operations must use mise macos tasks"

local __mise_source="home/.config/mise/conf.d/mise.toml"
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
mkdir -p "$__mise_fixture_config/tasks/bootstrap"
ln -s "$__root_dir/home/.config/mise/tasks/bootstrap/pre-dotfiles.zsh" \
    "$__mise_fixture_config/tasks/bootstrap/pre-dotfiles.zsh"
env -u MISE_ENV -u MISE_AUTO_ENV \
    HOME="$__mise_fixture_home" \
    XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
    XDG_STATE_HOME="$__mise_fixture_dir/state" \
    MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
    MISE_CONFIG_DIR="$__mise_fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__mise_fixture_home" \
    MISE_DATA_DIR="$__mise_fixture_dir/data" \
    MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
    MISE_STATE_DIR="$__mise_fixture_dir/state" \
    MISE_ENV_CONF_D=true \
    MISE_YES=1 \
    mise -C "$__mise_fixture_home" dot apply --yes >/dev/null ||
    fail "isolated mise dotfile deployment failed"
grep -qxF 'env = ["work"]' "$__mise_fixture_home/.config/mise/miserc.local.toml" ||
    fail "missing profile state did not render the work selector"
mkdir -p "$__mise_fixture_dir/state/minusfive"
print -r -- personal >| "$__mise_fixture_dir/state/minusfive/profile"
env \
    HOME="$__mise_fixture_home" \
    XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
    XDG_STATE_HOME="$__mise_fixture_dir/state" \
    MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
    MISE_CONFIG_DIR="$__mise_fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__mise_fixture_home" \
    MISE_DATA_DIR="$__mise_fixture_dir/data" \
    MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
    MISE_STATE_DIR="$__mise_fixture_dir/state/mise" \
    MISE_ENV=personal \
    MISE_ENV_CONF_D=true \
    MISE_YES=1 \
    mise -C "$__mise_fixture_home" dot apply --yes >/dev/null ||
    fail "explicit personal profile selector render failed"
grep -qxF 'env = ["personal"]' "$__mise_fixture_home/.config/mise/miserc.local.toml" ||
    fail "personal profile state did not render the personal selector"
print -r -- work >| "$__mise_fixture_dir/state/minusfive/profile"
env \
    HOME="$__mise_fixture_home" \
    XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
    XDG_STATE_HOME="$__mise_fixture_dir/state" \
    MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
    MISE_CONFIG_DIR="$__mise_fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__mise_fixture_home" \
    MISE_DATA_DIR="$__mise_fixture_dir/data" \
    MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
    MISE_STATE_DIR="$__mise_fixture_dir/state/mise" \
    MISE_ENV_CONF_D=true \
    MISE_YES=1 \
    mise -C "$__mise_fixture_home" -E personal dot apply --yes >/dev/null ||
    fail "explicit profile selector render failed"
grep -qxF 'env = ["personal"]' "$__mise_fixture_home/.config/mise/miserc.local.toml" ||
    fail "explicit environment did not override the persisted profile selector"
print -r -- invalid >| "$__mise_fixture_dir/state/minusfive/profile"
env \
    HOME="$__mise_fixture_home" \
    XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
    XDG_STATE_HOME="$__mise_fixture_dir/state" \
    MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
    MISE_CONFIG_DIR="$__mise_fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__mise_fixture_home" \
    MISE_DATA_DIR="$__mise_fixture_dir/data" \
    MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
    MISE_STATE_DIR="$__mise_fixture_dir/state/mise" \
    MISE_ENV_CONF_D=true \
    MISE_YES=1 \
    mise -C "$__mise_fixture_home" dot apply --yes >/dev/null ||
    fail "invalid profile selector render failed"
grep -qxF 'env = ["work"]' "$__mise_fixture_home/.config/mise/miserc.local.toml" ||
    fail "invalid profile state did not render the work selector"
local __mise_link_count
__mise_link_count="$(find "$__mise_fixture_home/.config/mise" -type l | wc -l | tr -d ' ')"
local __mise_status
__mise_status="$(
    env -u MISE_ENV -u MISE_AUTO_ENV \
        HOME="$__mise_fixture_home" \
        XDG_CONFIG_HOME="$__mise_fixture_home/.config" \
        XDG_STATE_HOME="$__mise_fixture_dir/state" \
        MISE_GLOBAL_CONFIG_FILE="$__mise_fixture_config/config.toml" \
        MISE_GLOBAL_CONFIG_ROOT="$__mise_fixture_config" \
        MISE_CONFIG_DIR="$__mise_fixture_config" \
        MISE_IGNORED_CONFIG_PATHS="$__mise_fixture_home/.config/mise" \
        MISE_CEILING_PATHS="$__mise_fixture_home" \
        MISE_DATA_DIR="$__mise_fixture_dir/data" \
        MISE_CACHE_DIR="$__mise_fixture_dir/cache" \
        MISE_STATE_DIR="$__mise_fixture_dir/state" \
        MISE_ENV_CONF_D=true \
        mise -C "$__mise_fixture_home" dot status --json
)" || fail "isolated mise dotfile status failed"
print -r -- "$__mise_status" |
    jq -e '(.files | length > 0) and all(.files[]; .state == "applied")' >/dev/null ||
    fail "isolated mise dotfile status reported unapplied declarations"
local __mise_declaration_count
__mise_declaration_count="$(
    awk '
        /^\[dotfiles\]$/ { in_dotfiles = 1; next }
        /^\[/ { in_dotfiles = 0 }
        in_dotfiles && /^"~\// { count++ }
        END { print count }
    ' "$__mise_source"
)"
local __symlink_each_declaration_count
__symlink_each_declaration_count="$(grep -c 'mode = "symlink-each"' "$__mise_source")"
local __template_declaration_count
__template_declaration_count="$(grep -c 'template = "tera"' "$__mise_source")"
local __symlink_each_source_count
__symlink_each_source_count="$(find home/.config/mise/conf.d/macos -type f | wc -l | tr -d ' ')"
local __nested_mise_declaration_count=0
local __module
for __module in home/.config/mise/conf.d/*.toml; do
    [[ "$__module" == *mise.toml || "$__module" == *.personal.toml ]] && continue
    (( __nested_mise_declaration_count += $(
        awk '/^"~\/.config\/mise/{ count++ } END { print count + 0 }' "$__module"
    ) )) || :
done
local __expected_mise_link_count=$((__mise_declaration_count -
    __symlink_each_declaration_count - __template_declaration_count +
    __symlink_each_source_count + __nested_mise_declaration_count))
[[ "$__mise_link_count" -eq "$__expected_mise_link_count" ]] ||
    fail "expected $__expected_mise_link_count managed mise links from the control-plane declarations, found $__mise_link_count"
[[ -L "$__mise_fixture_home/.config/mise/conf.d/betterdisplay.toml" ]] ||
    fail "isolated deployment omitted the BetterDisplay module link"
[[ -f "$__mise_fixture_home/.config/mise/miserc.local.toml" ]] ||
    fail "isolated deployment omitted the generated profile selector"
if grep -qE '^"~/.config/mise/tasks/betterdisplay' "$__mise_source"; then
    fail "mise control-plane module still declares BetterDisplay task links"
fi
[[ ! -e "$__mise_fixture_home/.config/mise/tasks/betterdisplay" ]] ||
    fail "isolated deployment created BetterDisplay task links"
grep -qF '*.local.*' home/.config/git/ignore ||
    fail "global Git ignore does not cover local-suffix paths"

# Mise deploys this source file as Git's global excludes file.
[[ -f "home/.config/git/ignore" ]] || fail "mise global Git ignore source is missing"
[[ -L "$HOME/.config/git/ignore" ]] || fail "mise did not install the global Git ignore file"

for __local_file in \
    'mise.local.toml' \
    'mise.personal.local.toml' \
    'miserc.local.toml' \
    'miserc.personal.local.toml' \
    'config.local.toml' \
    'config.personal.local.toml' \
    'config.pip.local.conf' \
    'example.local.yaml' \
    '.env.local.sample' \
    '.claude/settings.local.json'; do
    git check-ignore -q --no-index "$__local_file" ||
        fail "bootstrapped global Git ignore does not ignore local config: $__local_file"
done

local __fallback_home
__fallback_home="$(mktemp -d)"
mkdir -p "$__fallback_home/.config/mise/conf.d" "$__fallback_home/.local/state/minusfive"
cp home/.config/mise/config.toml "$__fallback_home/.config/mise/config.toml"
cp home/.config/mise/miserc.toml "$__fallback_home/.config/mise/miserc.toml"
cp home/.config/mise/conf.d/discord.personal.toml \
    "$__fallback_home/.config/mise/conf.d/discord.personal.toml"
print -r -- personal >| "$__fallback_home/.local/state/minusfive/profile"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' \
    >> "$__fallback_home/.config/mise/conf.d/discord.personal.toml"

local __fallback_env
__fallback_env="$(
    env -u MISE_ENV \
        HOME="$__fallback_home" \
        XDG_CONFIG_HOME="$__fallback_home/.config" \
        XDG_STATE_HOME="$__fallback_home/.local/state" \
        mise -C "$__fallback_home" env --json
)"
print -r -- "$__fallback_env" | grep -q '"MISE_ENV": "personal"' ||
    fail "persisted personal state did not provide the native task fallback"
if print -r -- "$__fallback_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "config fallback selected personal fragments before explicit environment selection"
fi

local __tmp_home
__tmp_home="$(mktemp -d)"
trap 'rm -rf -- "$__trust_data" "$__mise_fixture_dir" "$__fallback_home" "$__tmp_home"' EXIT
mkdir -p "$__tmp_home/.config/mise/conf.d"
cp home/.config/mise/config.toml "$__tmp_home/.config/mise/config.toml"
cp home/.config/mise/miserc.toml "$__tmp_home/.config/mise/miserc.toml"
cp home/.config/mise/conf.d/discord.personal.toml "$__tmp_home/.config/mise/conf.d/discord.personal.toml"
print -r -- 'env = ["personal"]' >| "$__tmp_home/.config/mise/miserc.local.toml"
mkdir -p "$__tmp_home/.local/state/minusfive"
print -r -- personal >| "$__tmp_home/.local/state/minusfive/profile"
printf '\nMISE_PROFILE_SMOKE_BASE = "1"\n' >> "$__tmp_home/.config/mise/config.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' >> "$__tmp_home/.config/mise/conf.d/discord.personal.toml"

local __work_env
__work_env="$(env MISE_ENV=work HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" mise -C "$__tmp_home" env --json)"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "work profile should load base config"
if print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "work profile should not load personal config"
fi

local __work_profile
__work_profile="$(env MISE_ENV=work HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" mise -C "$__tmp_home" exec -- sh -c 'printf "%s" "$MISE_ENV"')"
[[ "$__work_profile" == work ]] || fail "explicit work environment should override persisted state"
local __cli_work_profile
__cli_work_profile="$(env HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" mise -C "$__tmp_home" -E work exec -- sh -c 'printf "%s" "$MISE_ENV"')"
[[ "$__cli_work_profile" == work ]] || fail "explicit -E work environment was not exported"

local __personal_env
__personal_env="$(env MISE_ENV=personal HOME="$__tmp_home" XDG_CONFIG_HOME="$__tmp_home/.config" mise -C "$__tmp_home" env --json)"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "personal profile should load base config"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"' || fail "personal profile should load personal config"

echo "Global mise configuration passed."
