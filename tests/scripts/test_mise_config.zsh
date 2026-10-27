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
if grep -qF '"mise/config/mise/conf.d/bootstrap-ai.toml"' home/.config/mise/conf.d/mise.toml; then
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

grep -qF '"mise/config/mise/tasks/gh/auth/login.zsh"' home/.config/mise/conf.d/mise.toml ||
    fail "GitHub auth task is not owned by the mise control plane"
[[ -f "home/.config/mise/miserc.local.toml.tmpl" ]] ||
    fail "persisted profile selector template is missing"
[[ -f "home/.config/mise/profile.tmpl" ]] ||
    fail "resolved profile template is missing"
grep -qF '"mise/config/mise/miserc.local.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "control plane does not deploy the persisted profile selector"
grep -qF 'miserc.local.toml.tmpl", mode = "template", template = "tera"' home/.config/mise/conf.d/mise.toml ||
    fail "persisted profile selector is not rendered with Tera"
grep -qF '"mise/state/minusfive/profile"' home/.config/mise/conf.d/mise.toml ||
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
local __trust_data="$(test_fixture_dir mise-config-trust)"
trap 'rm -rf -- "$__trust_data"' EXIT
local __trust_home="$__trust_data/home"
local __trust_config="$__trust_home/.config/mise"
local __personal_workspace="$__trust_home/dev/personal"
local __work_workspace="$__trust_home/dev/work"
local __dot_workspace="$__personal_workspace/dot"
mkdir -p "$__trust_config" "$__personal_workspace" "$__work_workspace" "$__dot_workspace"
ln -s "$__root_dir/home/.config/mise/config.toml" "$__trust_config/config.toml"
ln -s "$__root_dir/home/.config/mise/conf.d" "$__trust_config/conf.d"
ln -s "$__root_dir/home/.config/mise/miserc.toml" "$__trust_config/miserc.toml"
for __workspace in "$__personal_workspace" "$__work_workspace" "$__dot_workspace"; do
    print -r -- "[vars]" > "$__workspace/mise.toml"
    print -r -- "trust_probe = \"${__workspace:t}\"" >> "$__workspace/mise.toml"
    local __trust_value="$(
        env -u MISE_ENV -u MISE_AUTO_ENV \
            HOME="$__trust_home" \
            MISE_CONFIG_DIR="$__trust_config" \
            MISE_GLOBAL_CONFIG_FILE="$__trust_config/config.toml" \
            MISE_GLOBAL_CONFIG_ROOT="$__trust_config" \
            MISE_DATA_DIR="$__trust_data/data" \
            MISE_STATE_DIR="$__trust_data/state" \
            MISE_CACHE_DIR="$__trust_data/cache" \
            MISE_CEILING_PATHS="$__trust_home" \
            MISE_ENV_CONF_D=true MISE_NO_HOOKS=1 \
            mise -C "$__workspace" config get vars.trust_probe
    )" || fail "trusted config path did not load for ${__workspace:t}"
    [[ "$__trust_value" == "${__workspace:t}" ]] ||
        fail "trusted config path returned the wrong workspace value: ${__workspace:t}"
done
grep -qF '[settings.dotfiles]' home/.config/mise/config.toml || fail "dotfiles settings are missing"
grep -qF 'relative_symlinks = true' home/.config/mise/config.toml || fail "relative symlinks are not enabled"
grep -qF '"mise/config/mise/conf.d/mise.toml"' home/.config/mise/conf.d/mise.toml || fail "mise module must manage itself"
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
local __mise_fixture_dir="$(test_fixture_dir mise-config)"
trap 'rm -rf -- "$__trust_data" "$__mise_fixture_dir"' EXIT
local __mise_fixture_home="$__mise_fixture_dir/home"
local __mise_fixture_repository="$__mise_fixture_home/dev/personal/dot"
local __host_mise_config="$HOME/.config/mise"
local __mise_default_xdg_config="$__mise_fixture_home/.config"
local __mise_default_xdg_data="$__mise_fixture_dir/default-xdg/data"
local __mise_default_xdg_state="$__mise_fixture_dir/default-xdg/state"
local __mise_default_xdg_cache="$__mise_fixture_dir/default-xdg/cache"
local __mise_default_config_dir="$__mise_default_xdg_config/mise"
local __mise_custom_xdg_config="$__mise_fixture_dir/custom-xdg/config"
local __mise_custom_xdg_data="$__mise_fixture_dir/custom-xdg/data"
local __mise_custom_xdg_state="$__mise_fixture_dir/custom-xdg/state"
local __mise_custom_xdg_cache="$__mise_fixture_dir/custom-xdg/cache"
local __mise_custom_config_dir="$__mise_fixture_dir/custom-mise"
local __mise_fixture_global_config="$__mise_fixture_dir/global-mise.toml"
mkdir -p \
    "$__mise_fixture_repository" \
    "$__mise_default_config_dir" \
    "$__mise_default_xdg_data" \
    "$__mise_default_xdg_state" \
    "$__mise_default_xdg_cache" \
    "$__mise_custom_xdg_config" \
    "$__mise_custom_xdg_data" \
    "$__mise_custom_xdg_state" \
    "$__mise_custom_xdg_cache" \
    "$__mise_fixture_dir/mise-data" \
    "$__mise_fixture_dir/mise-state" \
    "$__mise_fixture_dir/mise-cache" \
    "$__mise_fixture_dir/mise-tmp" \
    "$__mise_fixture_dir/system-config" \
    "$__mise_custom_config_dir"
ln -s "$__root_dir/home" "$__mise_fixture_repository/home"
cp "$__root_dir/home/.config/mise/conf.d/opencode.personal.toml" \
    "$__mise_fixture_repository/mise.personal.toml"

python3 - "$__root_dir/home/.config/mise/conf.d" "$__mise_fixture_global_config" <<'PY'
import json
import pathlib
import sys
import tomllib

module_dir = pathlib.Path(sys.argv[1])
output = pathlib.Path(sys.argv[2])


def toml_value(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, list):
        return "[ " + ", ".join(toml_value(item) for item in value) + " ]"
    if isinstance(value, dict):
        return "{ " + ", ".join(
            f"{key} = {toml_value(item)}" for key, item in value.items()
        ) + " }"
    return str(value)


lines = [
    "[settings.dotfiles]",
    "relative_symlinks = true",
    "",
    "[vars]",
    'resolved_profile = "{% if mise_env is defined and mise_env | length > 0 %}{{ mise_env[0] }}{% else %}work{% endif %}"',
    "",
    "[dotfiles]",
]
seen = set()
native_order = [
    module.name
    for module in sorted(module_dir.glob("*.toml"), key=lambda module: module.name)
    if not module.name.endswith(".personal.toml")
]
if native_order.index("p10k.toml") >= native_order.index("zsh.toml"):
    raise SystemExit("generated native-order module sequence must place p10k.toml before zsh.toml")
for module_name in native_order:
    module = module_dir / module_name
    if module.name.endswith(".personal.toml"):
        continue
    with module.open("rb") as stream:
        dotfiles = tomllib.load(stream).get("dotfiles", {})
    for target, spec in dotfiles.items():
        if not isinstance(spec, dict) or "mode" not in spec:
            continue
        if target in seen:
            raise SystemExit(f"duplicate whole-file target: {target}")
        seen.add(target)
        values = ", ".join(
            f"{key} = {toml_value(value)}" for key, value in spec.items()
        )
        lines.append(f"{toml_value(target)} = {{ {values} }}")
output.write_text("\n".join(lines) + "\n")
PY

trust_mise_fixture_config() {
    local __config_dir="$1"
    local -a __mise_env=(
        "HOME=$__mise_fixture_home"
        "XDG_CONFIG_HOME=$__mise_default_xdg_config"
        "XDG_DATA_HOME=$__mise_default_xdg_data"
        "XDG_STATE_HOME=$__mise_default_xdg_state"
        "XDG_CACHE_HOME=$__mise_default_xdg_cache"
        "MISE_CONFIG_DIR=$__config_dir"
        "MISE_GLOBAL_CONFIG_FILE=$__mise_fixture_global_config"
        "MISE_GLOBAL_CONFIG_ROOT=$__mise_fixture_dir"
        "MISE_DATA_DIR=$__mise_fixture_dir/mise-data"
        "MISE_STATE_DIR=$__mise_fixture_dir/mise-state"
        "MISE_CACHE_DIR=$__mise_fixture_dir/mise-cache"
        "MISE_TMP_DIR=$__mise_fixture_dir/mise-tmp"
        "MISE_SYSTEM_CONFIG_DIR=$__mise_fixture_dir/system-config"
        "MISE_INSTALLS_DIR=$__mise_fixture_dir/mise-installs"
        "MISE_INSTALL_STORE_DIR=$__mise_fixture_dir/mise-install-store"
        "MISE_PLUGINS_DIR=$__mise_fixture_dir/mise-plugins"
        "MISE_DOWNLOADS_DIR=$__mise_fixture_dir/mise-downloads"
        "MISE_SHIMS_DIR=$__mise_fixture_dir/mise-shims"
        "MISE_SYSTEM_DATA_DIR=$__mise_fixture_dir/system-data"
        "MISE_SYSTEM_INSTALLS_DIR=$__mise_fixture_dir/system-installs"
        "MISE_SYSTEM_SHIMS_DIR=$__mise_fixture_dir/system-shims"
        "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
        "MISE_CEILING_PATHS=$__mise_fixture_home"
    )

    env -u MISE_ENV -u MISE_SAFE "${__mise_env[@]}" \
        mise -C "$__mise_fixture_repository" trust "$__mise_fixture_global_config" >/dev/null ||
        fail "could not trust the fixture global config"
    env -u MISE_ENV -u MISE_SAFE "${__mise_env[@]}" \
        mise -C "$__mise_fixture_repository" trust "$__mise_fixture_repository/mise.personal.toml" >/dev/null ||
        fail "could not trust the fixture personal config"
}

local -a __mise_default_env=(
    "HOME=$__mise_fixture_home"
    "XDG_CONFIG_HOME=$__mise_default_xdg_config"
    "XDG_DATA_HOME=$__mise_default_xdg_data"
    "XDG_STATE_HOME=$__mise_default_xdg_state"
    "XDG_CACHE_HOME=$__mise_default_xdg_cache"
    "MISE_CONFIG_DIR=$__mise_default_config_dir"
    "MISE_GLOBAL_CONFIG_FILE=$__mise_fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__mise_fixture_dir"
    "MISE_CEILING_PATHS=$__mise_fixture_home"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_DATA_DIR=$__mise_fixture_dir/mise-data"
    "MISE_STATE_DIR=$__mise_fixture_dir/mise-state"
    "MISE_CACHE_DIR=$__mise_fixture_dir/mise-cache"
    "MISE_TMP_DIR=$__mise_fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__mise_fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__mise_fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__mise_fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__mise_fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__mise_fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__mise_fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__mise_fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__mise_fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__mise_fixture_dir/system-shims"
    "MISE_ENV_CONF_D=true"
    "MISE_NO_HOOKS=1"
)
trust_mise_fixture_config "$__mise_default_config_dir"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__mise_default_env[@]}" \
    mise -C "$__mise_fixture_repository" -E work bootstrap --only dotfiles --yes >/dev/null ||
    fail "default-path mise dotfile bootstrap failed"
[[ ! -e "$__mise_default_xdg_config/opencode" ]] ||
    fail "work profile deployed the personal OpenCode target"
grep -qxF 'env = ["work"]' "$__mise_default_config_dir/miserc.local.toml" ||
    fail "missing profile state did not render the work selector"
grep -qxF 'work' "$__mise_default_xdg_state/minusfive/profile" ||
    fail "work profile state was not written to the default XDG state directory"

local __default_mise_status="$(
    env "${__mise_default_env[@]}" MISE_SAFE=1 \
        mise -C "$__mise_fixture_repository" -E work dot status --json
)" || fail "default-path mise dotfile status failed"
print -r -- "$__default_mise_status" |
    jq -e --arg config "$__mise_default_config_dir/config.toml" \
        --arg lock "$__mise_default_config_dir/mise.lock" \
        --arg profile "$__mise_default_xdg_state/minusfive/profile" \
        --arg nvim "$__mise_default_xdg_config/nvim" \
        '(.files | length > 0) and
        any(.files[]; .target == $config and .mode == "symlink") and
        any(.files[]; .target == $lock and .mode == "symlink") and
        any(.files[]; .target == $profile and .mode == "template") and
        any(.files[]; .target == $nvim and .mode == "symlink-each")' >/dev/null ||
    {
        fail "default-path mise targets did not resolve to the fixture directories"
    }
[[ ! -e "$__mise_default_xdg_config/zsh/.p10k.zsh" ]] ||
    fail "native work-profile module order unexpectedly deployed the p10k file"

local -a __mise_custom_env=(
    "HOME=$__mise_fixture_home"
    "XDG_CONFIG_HOME=$__mise_custom_xdg_config"
    "XDG_DATA_HOME=$__mise_custom_xdg_data"
    "XDG_STATE_HOME=$__mise_custom_xdg_state"
    "XDG_CACHE_HOME=$__mise_custom_xdg_cache"
    "MISE_CONFIG_DIR=$__mise_custom_config_dir"
    "MISE_GLOBAL_CONFIG_FILE=$__mise_fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__mise_fixture_dir"
    "MISE_CEILING_PATHS=$__mise_fixture_home"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_DATA_DIR=$__mise_fixture_dir/mise-data"
    "MISE_STATE_DIR=$__mise_fixture_dir/mise-state"
    "MISE_CACHE_DIR=$__mise_fixture_dir/mise-cache"
    "MISE_TMP_DIR=$__mise_fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__mise_fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__mise_fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__mise_fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__mise_fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__mise_fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__mise_fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__mise_fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__mise_fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__mise_fixture_dir/system-shims"
    "MISE_ENV_CONF_D=true"
    "MISE_NO_HOOKS=1"
)
trust_mise_fixture_config "$__mise_custom_config_dir"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__mise_custom_env[@]}" \
    mise -C "$__mise_fixture_repository" -E work bootstrap --only dotfiles --yes >/dev/null ||
    fail "custom-path work mise dotfile bootstrap failed"
[[ ! -e "$__mise_custom_xdg_config/opencode" ]] ||
    fail "custom work profile deployed the personal OpenCode target"
grep -qxF 'env = ["work"]' "$__mise_custom_config_dir/miserc.local.toml" ||
    fail "custom-path work profile selector was not rendered"
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__mise_custom_env[@]}" \
    mise -C "$__mise_fixture_repository" -E personal bootstrap --only dotfiles --yes >/dev/null ||
    fail "custom-path personal mise dotfile bootstrap failed"
[[ -d "$__mise_custom_xdg_config/opencode" && ! -L "$__mise_custom_xdg_config/opencode" ]] ||
    fail "personal profile did not deploy OpenCode under XDG_CONFIG_HOME"
[[ -L "$__mise_custom_xdg_config/opencode/opencode.jsonc" ]] ||
    fail "personal profile did not link the OpenCode source file"
grep -qxF 'env = ["personal"]' "$__mise_custom_config_dir/miserc.local.toml" ||
    fail "personal profile state did not render the personal selector"

local __custom_mise_status="$(
    env "${__mise_custom_env[@]}" MISE_SAFE=1 \
        mise -C "$__mise_fixture_repository" -E personal dot status --json
)" || fail "custom-path mise dotfile status failed"
print -r -- "$__custom_mise_status" |
    jq -e --arg config "$__mise_custom_config_dir/config.toml" \
        --arg lock "$__mise_custom_config_dir/mise.lock" \
        --arg profile "$__mise_custom_xdg_state/minusfive/profile" \
        --arg nvim "$__mise_custom_xdg_config/nvim" \
        '(.files | length > 0) and
        any(.files[]; .target == $config and .mode == "symlink") and
        any(.files[]; .target == $lock and .mode == "symlink") and
        any(.files[]; .target == $profile and .mode == "template") and
        any(.files[]; .target == $nvim and .mode == "symlink-each")' >/dev/null ||
    fail "custom-path mise targets did not resolve to the fixture directories"

grep -qxF 'personal' "$__mise_custom_xdg_state/minusfive/profile" ||
    fail "personal profile state was not written to the custom XDG state directory"
[[ -d "$__mise_custom_xdg_config/gh/personal" ]] ||
    fail "custom XDG GitHub host target parent was not created"
[[ -L "$__mise_custom_xdg_config/gh/personal/hosts.yml" ]] ||
    fail "GitHub hosts target did not follow the custom XDG configuration directory"
[[ -L "$__mise_custom_xdg_config/zsh/.p10k.zsh" ]] ||
    fail "native module order did not deploy the p10k file"

local __custom_cleanup_env=(
    "${__mise_custom_env[@]}"
    "MISE_PROJECT_ROOT=$__mise_fixture_repository"
)
env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE \
    "${__custom_cleanup_env[@]}" \
    mise -C "$__mise_fixture_repository" -E personal run mise:cleanup >/dev/null ||
    fail "custom-root cleanup failed after migration"
[[ ! -L "$__mise_default_config_dir/config.toml" ]] ||
    fail "custom-root cleanup left the old default mise config link"
[[ ! -L "$__mise_default_config_dir/mise.lock" ]] ||
    fail "custom-root cleanup left the old default mise lock link"
[[ -L "$__mise_custom_config_dir/config.toml" ]] ||
    fail "custom-root cleanup removed the active custom mise config link"

local __mise_link_count
__mise_link_count="$(find "$__mise_custom_config_dir" -type l | wc -l | tr -d ' ')"
local __mise_declaration_count
__mise_declaration_count="$(
    awk '
        /^\[dotfiles\]$/ { in_dotfiles = 1; next }
        /^\[/ { in_dotfiles = 0 }
        in_dotfiles && /^"mise\// { count++ }
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
        awk '/^"[^"]+\/config\/mise\// { count++ } END { print count + 0 }' "$__module"
    ) )) || :
done
local __expected_mise_link_count=$((__mise_declaration_count -
    __symlink_each_declaration_count - __template_declaration_count +
    __symlink_each_source_count + __nested_mise_declaration_count))
[[ "$__mise_link_count" -eq "$__expected_mise_link_count" ]] ||
    fail "expected $__expected_mise_link_count managed mise links in the custom config directory, found $__mise_link_count"
[[ -L "$__mise_custom_config_dir/conf.d/betterdisplay.toml" ]] ||
    fail "isolated deployment omitted the BetterDisplay module link"
[[ -f "$__mise_custom_config_dir/miserc.local.toml" ]] ||
    fail "isolated deployment omitted the generated profile selector"
if grep -qE '^"mise/config/mise/tasks/betterdisplay' "$__mise_source"; then
    fail "mise control-plane module still declares BetterDisplay task links"
fi
[[ ! -e "$__mise_custom_config_dir/tasks/betterdisplay" ]] ||
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
__fallback_home="$(test_fixture_dir fallback-home)"
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
__tmp_home="$(test_fixture_dir tmp-home)"
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
