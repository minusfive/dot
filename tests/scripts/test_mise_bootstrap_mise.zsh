#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise control-plane module..."

local __config="home/.config/mise/conf.d/module-mise.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF '"~/.config/mise/conf.d/module-mise.toml"' "$__config" ||
    fail "mise control-plane module does not manage itself"
grep -qF '"~/.config/mise/tasks/global-install-packages-all.sh"' "$__config" ||
    fail "aggregate package task is missing"
grep -qF '"~/.config/mise/tasks/mise/cleanup.zsh"' "$__config" ||
    fail "stale-link cleanup task is missing"
grep -qF '"~/.config/mise/tasks/mise/cleanup/inventory.zsh"' "$__config" ||
    fail "cleanup inventory task is missing"
grep -qF '"~/.config/mise/tasks/bootstrap/pre-packages.zsh"' "$__config" ||
    fail "pre-packages profile task is missing"
grep -qF '"~/.config/mise/tasks/bootstrap/post-tools.zsh"' "$__config" ||
    fail "post-tools maintenance task is missing"
grep -qF '[settings.self_update]' "$__config" ||
    fail "self-update settings are missing"
grep -qF 'auto = true' "$__config" ||
    fail "automatic self-update is disabled"
grep -qF 'minimum_release_age = "2d"' "$__config" ||
    fail "self-update release age is missing"
grep -qF '"~/.config/mise/tasks/git/auth/setup.zsh"' "$__config" ||
    fail "Git auth setup task is missing"
grep -qF '"~/.config/mise/utils/git-domains.zsh"' "$__config" ||
    fail "Git domain helper is missing"
if grep -qF '"mise upgrade --prune"' "$__config" ||
    grep -qF '"mise reshim -f"' "$__config"; then
    fail "legacy inline tool maintenance hook remains"
fi
grep -qF 'post-tools = "mise run bootstrap:post-tools"' "$__config" ||
    fail "post-tools maintenance hook is missing"
grep -qF 'pre-packages = "mise run bootstrap:pre-packages"' "$__config" ||
    fail "pre-packages profile hook is missing"
[[ ! -e "home/.config/mise/conf.d/module-tools.toml" ]] ||
    fail "combined tools module remains"
[[ ! -e "home/.config/mise/conf.d/module-uv.toml" ]] ||
    fail "standalone uv module remains"
if grep -qF '[[tools.opencode]]' home/.config/mise/mise.lock; then
    fail "OpenCode tool lock entry must be removed"
fi
if grep -qF '[[tools."npm:mcp-hub"]]' home/.config/mise/mise.lock; then
    fail "mcp-hub tool lock entry must be removed"
fi

local __migration_fixture="$__root_dir/.agents/projects.local/issue-74-native-mise-env/runtime/mise-migration.$$"
trap 'rm -rf -- "$__migration_fixture"' EXIT
local __fixture_home="$__migration_fixture/home"
local __fixture_config="$__migration_fixture/config"
mkdir -p \
    "$__fixture_home/.config/mise/conf.d" \
    "$__fixture_home/dev/personal" \
    "$__fixture_home/.local/share/legacy-package" \
    "$__fixture_home/dev/personal/legacy-repository" \
    "$__fixture_config" \
    "$__migration_fixture/data" \
    "$__migration_fixture/cache" \
    "$__migration_fixture/state"
ln -s "$__root_dir" "$__fixture_home/dev/personal/dot"
{
    print -r -- "[settings.dotfiles]"
    print -r -- "relative_symlinks = true"
    print -r -- ""
    cat "$__config"
} >| "$__fixture_config/config.toml"
ln -s "$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/module.mise.toml" \
    "$__fixture_home/.config/mise/conf.d/module.mise.toml"
ln -s "$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/module.discord.toml" \
    "$__fixture_home/.config/mise/conf.d/module.discord.toml"

env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_STATE_HOME="$__migration_fixture/state" \
    MISE_GLOBAL_CONFIG_FILE="$__fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__fixture_config" \
    MISE_CONFIG_DIR="$__fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__fixture_home/.config/mise" \
    MISE_CEILING_PATHS="$__fixture_home" \
    MISE_DATA_DIR="$__migration_fixture/data" \
    MISE_CACHE_DIR="$__migration_fixture/cache" \
    MISE_STATE_DIR="$__migration_fixture/state/mise" \
    MISE_ENV=personal MISE_ENV_CONF_D=true \
    mise -C "$__fixture_home" dot apply --yes >/dev/null ||
    fail "migration fixture dotfile deployment failed"
[[ -L "$__fixture_home/.config/mise/conf.d/module-mise.toml" ]] ||
    fail "new control-plane link did not replace the old deployment"
[[ -L "$__fixture_home/.config/mise/conf.d/module-discord.personal.toml" ]] ||
    fail "new personal fragment link did not replace the old deployment"
[[ -L "$__fixture_home/.config/mise/conf.d/module.mise.toml" ]] ||
    fail "stale control-plane link was removed before cleanup"
[[ -L "$__fixture_home/.config/mise/conf.d/module.discord.toml" ]] ||
    fail "stale personal fragment link was removed before cleanup"

env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    MISE_ENV_CONF_D=true \
    MISE_PROJECT_ROOT="$__root_dir" \
    zsh "$__root_dir/home/.config/mise/tasks/mise/cleanup.zsh" >| "$__migration_fixture/cleanup.log" 2>&1 ||
    {
        cat "$__migration_fixture/cleanup.log"
        fail "migration fixture cleanup failed"
    }
[[ ! -e "$__fixture_home/.config/mise/conf.d/module.mise.toml" ]] ||
    fail "stale control-plane link survived cleanup"
[[ ! -e "$__fixture_home/.config/mise/conf.d/module.discord.toml" ]] ||
    fail "stale personal fragment link survived cleanup"
[[ -d "$__fixture_home/.local/share/legacy-package" ]] ||
    fail "cleanup removed a package-owned directory"
[[ -d "$__fixture_home/dev/personal/legacy-repository" ]] ||
    fail "cleanup removed a repository-owned directory"

echo "mise control-plane module passed."
