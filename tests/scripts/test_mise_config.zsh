#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing global mise configuration..."

[[ -f ".mise/config.toml" ]] || fail "missing .mise/config.toml"
[[ -f ".mise/conf.d/tasks.toml" ]] || fail "missing .mise/conf.d/tasks.toml"
[[ -f ".mise/conf.d/tools.toml" ]] || fail "missing .mise/conf.d/tools.toml"
[[ -f ".mise/mise.lock" ]] || fail "missing .mise/mise.lock"
[[ ! -f "mise.toml" ]] || fail "root mise.toml should be removed"
[[ ! -f "mise.lock" ]] || fail "root mise.lock should be removed"
[[ -f "home/.config/mise/config.toml" ]] || fail "missing home mise configuration"
[[ -f "home/.config/mise/miserc.toml" ]] || fail "missing home mise profile configuration"
[[ -f "home/.config/mise/mise.lock" ]] || fail "missing home mise lockfile"
[[ -f "home/.config/mise/conf.d/module.mise.toml" ]] || fail "missing mise control plane"
[[ ! -e scripts/mise.zsh ]] || fail "retired mise lifecycle script remains"
[[ -x scripts/tasks/bootstrap.zsh ]] || fail "bootstrap task is not executable"
[[ -x scripts/tasks/setup.zsh ]] || fail "setup task is not executable"
[[ -x tests/scripts/test_mise_task_setup.zsh ]] || fail "setup task test is not executable"
[[ -f scripts/utils/profile.zsh ]] || fail "profile helper is missing"
[[ -f scripts/utils/mise.zsh ]] || fail "mise helper is missing"
zsh -n scripts/init.zsh scripts/tasks/bootstrap.zsh scripts/utils/profile.zsh scripts/utils/mise.zsh ||
    fail "bootstrap scripts have syntax errors"

grep -qF '#USAGE flag "--profile <profile>"' scripts/tasks/bootstrap.zsh ||
    fail "profile Usage metadata is missing"
grep -qF '#USAGE   choices "work" "personal"' scripts/tasks/bootstrap.zsh ||
    fail "profile Usage choices are missing"
grep -qF '#USAGE flag "--dry-run"' scripts/tasks/bootstrap.zsh ||
    fail "dry-run Usage metadata is missing"
grep -qF '#MISE raw=true' scripts/tasks/bootstrap.zsh ||
    fail "bootstrap task raw mode is missing"
grep -qF '[settings.task]' .mise/config.toml ||
    fail "task settings are missing"
grep -qF 'run_auto_install = false' .mise/config.toml ||
    fail "outer task auto-installation is not disabled"
grep -qF 'export MISE_TASK_RUN_AUTO_INSTALL=0' scripts/init.zsh ||
    fail "compatibility entrypoint does not disable outer task auto-installation"
grep -qxF 'mise install' scripts/tasks/setup.zsh ||
    fail "setup task does not provision development tools explicitly"
grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml ||
    fail "task include path is missing"
local __task_listing
__task_listing="$(MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^bootstrap[[:space:]]' ||
    fail "bootstrap task is not discoverable"
local __task_info
__task_info="$(MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true mise -C "$__root_dir" tasks info bootstrap)"
print -r -- "$__task_info" | grep -qF 'Task: bootstrap' ||
    fail "bootstrap task metadata is missing"
print -r -- "$__task_info" | grep -qF 'Properties: raw' ||
    fail "bootstrap task raw mode is not active"
local __task_help
__task_help="$(MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true mise -C "$__root_dir" run bootstrap --help)"
print -r -- "$__task_help" | grep -qF -- '--profile <profile>' ||
    fail "bootstrap profile help is missing"
print -r -- "$__task_help" | grep -qF -- '[possible values: work, personal]' ||
    fail "bootstrap profile choices are missing"
print -r -- "$__task_help" | grep -qF -- '--dry-run' ||
    fail "bootstrap dry-run help is missing"
MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    mise -C "$__root_dir" run --dry-run bootstrap >/dev/null ||
    fail "native task graph preview failed"

for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.hammerspoon.toml" ||
        fail "Hammerspoon is missing from $__profile"
    print -r -- "$__profile_config" | grep -qF "module.betterdisplay.toml" ||
        fail "BetterDisplay is missing from $__profile"
done
local __work_config
__work_config="$(
    env -u MISE_ENV DOT_PROFILE=work \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" config ls --no-truncate
)"
for __personal_module in discord opencode softraid whatsapp; do
    if print -r -- "$__work_config" | grep -qF "module.$__personal_module.toml"; then
        fail "$__personal_module leaked into work profile"
    fi
done

for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV DOT_PROFILE="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.dockutil.toml" ||
        fail "dockutil is missing from $__profile"
done

grep -qF 'shared_modules' home/.config/mise/miserc.toml ||
    fail "shared profile module list is missing"
grep -qF 'personal_profile_modules' home/.config/mise/miserc.toml ||
    fail "personal profile module list is missing"
grep -qF 'env_conf_d = true' home/.config/mise/miserc.toml ||
    fail "env_conf_d is not enabled"
grep -qF 'relative_symlinks = true' home/.config/mise/config.toml ||
    fail "relative symlinks are not enabled"
grep -qF '"~/.config/mise/conf.d/module.mise.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise module must manage itself"
grep -qF 'module.betterdisplay.toml' home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay module is not owned by the mise control plane"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/export.zsh"' \
    home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay export task is not owned by the mise control plane"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/import.zsh"' \
    home/.config/mise/conf.d/module.mise.toml ||
    fail "BetterDisplay import task is not owned by the mise control plane"
if grep -qiE 'launchd|start_interval|run_at_load' home/.config/mise/conf.d/module.betterdisplay.toml; then
    fail "BetterDisplay automatic LaunchAgent declarations remain"
fi
if grep -qF 'betterdisplay.zsh' scripts/init.zsh; then
    fail "deleted BetterDisplay initializer remains wired into scripts/init.zsh"
fi
grep -qF 'minimum_release_age = "7d"' home/.config/mise/config.toml ||
    fail "minimum release age is missing"
grep -qF 'trusted_config_paths = ["~/dev/personal", "~/dev/personal/dot", "~/dev/work"]' \
    home/.config/mise/config.toml ||
    fail "workspace trust paths are missing"
grep -qF '[settings.dotfiles]' home/.config/mise/config.toml ||
    fail "dotfiles settings are missing"
[[ ! -e scripts/os.zsh ]] || fail "OS operations must use mise macOS tasks"
if grep -qE -- '--brew|--vm|brew\.zsh|vm\.zsh' scripts/init.zsh scripts/functions.zsh; then
    fail "removed Homebrew and VM options remain in the initializer"
fi

echo "Global mise configuration passed."
