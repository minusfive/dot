#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise control-plane module..."

local __config="home/.config/mise/conf.d/mise.toml"
[[ -f "$__config" ]] || fail "missing $__config"
if grep -qF '"mise/config/mise/' "$__config"; then
    fail "mise control-plane module still declares per-file mise config ownership"
fi
grep -qF '"mise/state/minusfive/profile"' "$__config" ||
    fail "resolved profile state is missing"
grep -qF 'profile.tmpl", mode = "template", template = "tera"' "$__config" ||
    fail "resolved profile state is not rendered with Tera"
grep -qF '[settings.self_update]' "$__config" ||
    fail "self-update settings are missing"
grep -qF 'auto = true' "$__config" ||
    fail "automatic self-update is disabled"
grep -qF 'minimum_release_age = "2d"' "$__config" ||
    fail "self-update release age is missing"
if grep -qF '"mise upgrade --prune"' "$__config" ||
    grep -qF '"mise reshim -f"' "$__config"; then
    fail "legacy inline tool maintenance hook remains"
fi
grep -qF 'post-tools = "mise run bootstrap:post-tools"' "$__config" ||
    fail "post-tools maintenance hook is missing"
grep -qF 'final = "mise run bootstrap:final"' "$__config" ||
    fail "final bootstrap hook is missing"
grep -qF 'pre-packages = "mise run bootstrap:pre-packages"' "$__config" ||
    fail "pre-packages profile hook is missing"
grep -qF 'pre-dotfiles = "mise run bootstrap:pre-dotfiles"' "$__config" ||
    fail "pre-dotfiles profile hook is missing"
[[ ! -e "home/.config/mise/conf.d/tools.toml" ]] ||
    fail "combined tools module remains"
[[ ! -e "home/.config/mise/conf.d/uv.toml" ]] ||
    fail "standalone uv module remains"
if grep -qF '[[tools.opencode]]' home/.config/mise/mise.lock; then
    fail "OpenCode tool lock entry must be removed"
fi
if grep -qF '[[tools."npm:mcp-hub"]]' home/.config/mise/mise.lock; then
    fail "mcp-hub tool lock entry must be removed"
fi

local __migration_fixture
__migration_fixture="$(test_fixture_dir mise-migration)" || exit 1
trap 'rm -rf -- "$__migration_fixture"' EXIT
local __fixture_home="$__migration_fixture/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_config="$__migration_fixture/config"
mkdir -p \
    "$__fixture_home/.config/mise/conf.d" \
    "$__fixture_repository" \
    "$__fixture_home/.local/share/legacy-package" \
    "$__fixture_home/dev/personal/legacy-repository" \
    "$__fixture_config" \
    "$__migration_fixture/data" \
    "$__migration_fixture/cache" \
    "$__migration_fixture/state" \
    "$__migration_fixture/tmp" \
    "$__migration_fixture/system-config"
cp -R "$__root_dir/home" "$__fixture_repository/home"
{
    print -r -- "[vars]"
    print -r -- "resolved_profile = \"personal\""
    print -r -- ""
    print -r -- "[settings.dotfiles]"
    print -r -- "relative_symlinks = true"
    print -r -- ""
    print -r -- "[dotfiles]"
    print -r -- "# Legacy absolute target keys model links from the previous deployment."
    print -r -- "\"~/.config/mise/conf.d/mise.toml\" = { source = \"$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/mise.toml\", mode = \"symlink\" }"
    print -r -- "\"~/.config/mise/conf.d/discord.personal.toml\" = { source = \"$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/discord.personal.toml\", mode = \"symlink\" }"
    print -r -- "\"~/.config/mise/tasks/bootstrap/pre-dotfiles.zsh\" = { source = \"$__fixture_home/dev/personal/dot/home/.config/mise/tasks/bootstrap/pre-dotfiles.zsh\", mode = \"symlink\" }"
} >| "$__fixture_config/config.toml"
ln -s "$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/module.mise.toml" \
    "$__fixture_home/.config/mise/conf.d/module.mise.toml"
ln -s "$__fixture_home/dev/personal/dot/home/.config/mise/conf.d/module.discord.toml" \
    "$__fixture_home/.config/mise/conf.d/module.discord.toml"

env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_DATA_HOME="$__migration_fixture/data" \
    XDG_STATE_HOME="$__migration_fixture/state" \
    XDG_CACHE_HOME="$__migration_fixture/cache" \
    MISE_CONFIG_DIR="$__fixture_config" \
    MISE_GLOBAL_CONFIG_FILE="$__fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$HOME/.config/mise" \
    MISE_CEILING_PATHS="$__fixture_home" \
    MISE_DATA_DIR="$__migration_fixture/data" \
    MISE_STATE_DIR="$__migration_fixture/state/mise" \
    MISE_CACHE_DIR="$__migration_fixture/cache" \
    MISE_TMP_DIR="$__migration_fixture/tmp" \
    MISE_SYSTEM_CONFIG_DIR="$__migration_fixture/system-config" \
    mise -C "$__fixture_repository" trust "$__fixture_config/config.toml" >/dev/null ||
    fail "could not trust migration fixture config"

env -u MISE_SAFE -u MISE_ENV -u MISE_AUTO_ENV \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_DATA_HOME="$__migration_fixture/data" \
    XDG_STATE_HOME="$__migration_fixture/state" \
    XDG_CACHE_HOME="$__migration_fixture/cache" \
    MISE_GLOBAL_CONFIG_FILE="$__fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__fixture_config" \
    MISE_CONFIG_DIR="$__fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$HOME/.config/mise" \
    MISE_CEILING_PATHS="$__fixture_home" \
    MISE_DATA_DIR="$__migration_fixture/data" \
    MISE_CACHE_DIR="$__migration_fixture/cache" \
    MISE_STATE_DIR="$__migration_fixture/state/mise" \
    MISE_TMP_DIR="$__migration_fixture/tmp" \
    MISE_SYSTEM_CONFIG_DIR="$__migration_fixture/system-config" \
    MISE_INSTALLS_DIR="$__migration_fixture/mise-installs" \
    MISE_INSTALL_STORE_DIR="$__migration_fixture/mise-install-store" \
    MISE_PLUGINS_DIR="$__migration_fixture/mise-plugins" \
    MISE_DOWNLOADS_DIR="$__migration_fixture/mise-downloads" \
    MISE_SHIMS_DIR="$__migration_fixture/mise-shims" \
    MISE_SYSTEM_DATA_DIR="$__migration_fixture/system-data" \
    MISE_SYSTEM_INSTALLS_DIR="$__migration_fixture/system-installs" \
    MISE_SYSTEM_SHIMS_DIR="$__migration_fixture/system-shims" \
    MISE_NO_HOOKS=1 \
    MISE_AUTO_INSTALL=false \
    MISE_EXEC_AUTO_INSTALL=false \
    MISE_NOT_FOUND_AUTO_INSTALL=false \
    MISE_ENV_CONF_D=true \
    mise -C "$__fixture_repository" -E personal bootstrap --only dotfiles --yes >/dev/null ||
    fail "migration fixture dotfile deployment failed"
[[ -L "$__fixture_home/.config/mise/conf.d/mise.toml" ]] ||
    fail "new control-plane link did not replace the old deployment"
[[ -L "$__fixture_home/.config/mise/conf.d/discord.personal.toml" ]] ||
    fail "new personal fragment link did not replace the old deployment"
[[ -L "$__fixture_home/.config/mise/conf.d/module.mise.toml" ]] ||
    fail "stale control-plane link was removed before cleanup"
[[ -L "$__fixture_home/.config/mise/conf.d/module.discord.toml" ]] ||
    fail "stale personal fragment link was removed before cleanup"

env -u MISE_SAFE -u MISE_ENV -u MISE_AUTO_ENV \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    XDG_DATA_HOME="$__migration_fixture/data" \
    XDG_STATE_HOME="$__migration_fixture/state" \
    XDG_CACHE_HOME="$__migration_fixture/cache" \
    MISE_CONFIG_DIR="$__fixture_config" \
    MISE_GLOBAL_CONFIG_FILE="$__fixture_config/config.toml" \
    MISE_GLOBAL_CONFIG_ROOT="$__fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$HOME/.config/mise" \
    MISE_CEILING_PATHS="$__fixture_home" \
    MISE_STATE_DIR="$__migration_fixture/state/mise" \
    MISE_DATA_DIR="$__migration_fixture/data" \
    MISE_CACHE_DIR="$__migration_fixture/cache" \
    MISE_TMP_DIR="$__migration_fixture/tmp" \
    MISE_SYSTEM_CONFIG_DIR="$__migration_fixture/system-config" \
    MISE_INSTALLS_DIR="$__migration_fixture/mise-installs" \
    MISE_INSTALL_STORE_DIR="$__migration_fixture/mise-install-store" \
    MISE_PLUGINS_DIR="$__migration_fixture/mise-plugins" \
    MISE_DOWNLOADS_DIR="$__migration_fixture/mise-downloads" \
    MISE_SHIMS_DIR="$__migration_fixture/mise-shims" \
    MISE_SYSTEM_DATA_DIR="$__migration_fixture/system-data" \
    MISE_SYSTEM_INSTALLS_DIR="$__migration_fixture/system-installs" \
    MISE_SYSTEM_SHIMS_DIR="$__migration_fixture/system-shims" \
    MISE_ENV_CONF_D=true \
    MISE_NO_HOOKS=1 \
    MISE_PROJECT_ROOT="$__fixture_repository" \
    zsh "$__root_dir/home/.config/mise/tasks/bootstrap/post-dotfiles/cleanup.zsh" >| "$__migration_fixture/cleanup.log" 2>&1 ||
    {
        cat "$__migration_fixture/cleanup.log"
        fail "migration fixture cleanup failed"
    }
[[ ! -L "$__fixture_home/.config/mise/conf.d/module.mise.toml" ]] ||
   fail "stale control-plane link survived cleanup"
[[ ! -L "$__fixture_home/.config/mise/conf.d/module.discord.toml" ]] ||
    fail "stale personal fragment link survived cleanup"
[[ -d "$__fixture_home/.local/share/legacy-package" ]] ||
    fail "cleanup removed a package-owned directory"
[[ -d "$__fixture_home/dev/personal/legacy-repository" ]] ||
    fail "cleanup removed a repository-owned directory"

echo "mise control-plane module passed."
