#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing 1Password bootstrap configuration..."

local __config="home/.config/mise/conf.d/1password.toml"
grep -qF '"brew-cask:1password" = "latest"' "$__config" ||
    fail "1Password package declaration is missing"
grep -qF '"brew-cask:1password-cli" = "latest"' "$__config" ||
    fail "1Password CLI package declaration is missing"
grep -qF '"mas:1569813296" = "latest"' "$__config" ||
    fail "1Password Safari package declaration is missing"
local __source="home/.config/1Password/ssh/agent.toml"
local __ssh_config="home/.ssh/config"
[[ -f "$__config" && -f "$__source" ]] || fail "1Password source or declaration is missing"
grep -qF '"1password/config/1Password/ssh/agent.toml" = { source = "~/dev/personal/dot/home/.config/1Password/ssh/agent.toml", mode = "symlink", variants = [{ default = true, target = "{{ xdg_config_home }}/1Password/ssh/agent.toml" }] }' "$__config" ||
    fail "1Password agent symlink declaration is missing"
grep -qF '"~/.ssh/config" = { source = "~/dev/personal/dot/home/.ssh/config", mode = "symlink" }' "$__config" ||
    fail "SSH config symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-3.zsh/onepassword"' "$__config" ||
    fail "1Password zshrc edit is missing"
[[ ! -e home/.config/1Password/id_rsa && ! -e home/.config/1Password/id_ed25519 ]] ||
    fail "private key entered the tracked 1Password source"
if grep -Eq 'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY' "$__source"; then
    fail "private key material found in 1Password source"
fi

local __fixture_dir="$(test_fixture_dir 1password)"
local __fixture_home="$__fixture_dir/home"
local __fixture_repository="$__fixture_home/dev/personal/dot"
local __fixture_xdg_config="$__fixture_dir/xdg/config"
local __fixture_global_config="$__fixture_dir/global-mise.toml"
local __fixture_mise_config="$__fixture_dir/mise-config"
local __host_mise_config="$HOME/.config/mise"
mkdir -p "$__fixture_repository" "$__fixture_xdg_config" "$__fixture_mise_config"
trap 'rm -rf -- "$__fixture_dir"' EXIT
ln -s "$__root_dir/home" "$__fixture_repository/home"
git -C "$__fixture_repository" init -q
python3 - "$__config" "$__fixture_global_config" <<'PY'
import json
import pathlib
import sys
import tomllib

with pathlib.Path(sys.argv[1]).open("rb") as stream:
    dotfiles = tomllib.load(stream).get("dotfiles", {})


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
    "[dotfiles]",
]
for target, spec in dotfiles.items():
    values = ", ".join(
        f"{key} = {toml_value(value)}" for key, value in spec.items()
    )
    lines.append(f"{toml_value(target)} = {{ {values} }}")
pathlib.Path(sys.argv[2]).write_text("\n".join(lines) + "\n")
PY

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_xdg_config"
    "XDG_DATA_HOME=$__fixture_dir/xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_mise_config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_CEILING_PATHS=$__fixture_repository"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_DATA_DIR=$__fixture_dir/mise-data"
    "MISE_STATE_DIR=$__fixture_dir/mise-state"
    "MISE_CACHE_DIR=$__fixture_dir/mise-cache"
    "MISE_TMP_DIR=$__fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_dir/system-shims"
    "MISE_ENV_CONF_D=true"
    "MISE_NO_HOOKS=1"
    "MISE_AUTO_INSTALL=false"
    "MISE_EXEC_AUTO_INSTALL=false"
    "MISE_NOT_FOUND_AUTO_INSTALL=false"
)
mkdir -p \
    "$__fixture_dir/xdg/data" \
    "$__fixture_dir/xdg/state" \
    "$__fixture_dir/xdg/cache" \
    "$__fixture_dir/mise-data" \
    "$__fixture_dir/mise-state" \
    "$__fixture_dir/mise-cache" \
    "$__fixture_dir/mise-tmp" \
    "$__fixture_dir/system-config" \
    "$__fixture_dir/mise-installs" \
    "$__fixture_dir/mise-install-store" \
    "$__fixture_dir/mise-plugins" \
    "$__fixture_dir/mise-downloads" \
    "$__fixture_dir/mise-shims" \
    "$__fixture_dir/system-data" \
    "$__fixture_dir/system-installs" \
    "$__fixture_dir/system-shims"

env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
    mise -C "$__fixture_repository" trust "$__fixture_global_config" >/dev/null ||
    fail "could not trust 1Password fixture global config"

local __target="$__fixture_xdg_config/1Password/ssh/agent.toml"
local __ssh_target="$__fixture_home/.ssh/config"
for __profile in work personal; do
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_SAFE "${__fixture_env[@]}" \
        mise -C "$__fixture_repository" -E "$__profile" bootstrap --only dotfiles --yes >/dev/null ||
        fail "1Password fixture bootstrap failed for the $__profile profile"

    local __status="$(
        env -u MISE_ENV -u MISE_AUTO_ENV "${__fixture_env[@]}" \
            MISE_SAFE=1 MISE_NO_HOOKS=1 \
            mise -C "$__fixture_repository" -E "$__profile" dot status --json
    )" || fail "1Password fixture status failed for the $__profile profile"
    if ! print -r -- "$__status" |
        jq -e --arg target "$__target" \
            'any(.files[]; .target == $target and .mode == "symlink" and .state == "applied")' >/dev/null; then
        print -r -- "$__status" >&2
        fail "1Password target did not resolve under XDG_CONFIG_HOME for the $__profile profile"
    fi
done

[[ -d "$__fixture_xdg_config/1Password" && ! -L "$__fixture_xdg_config/1Password" ]] ||
    fail "1Password fixture target parent is not a physical directory"
[[ -L "$__target" ]] || fail "1Password fixture target is not a symlink"
case "$(readlink "$__target")" in
    /*) fail "1Password fixture link is absolute" ;;
esac
[[ "$(realpath "$__target")" == "$(realpath "$__root_dir/$__source")" ]] ||
    fail "1Password fixture target does not resolve to the tracked source"
[[ -f "$__ssh_config" && -L "$__ssh_target" ]] ||
    fail "SSH config fixture source or target is missing"
case "$(readlink "$__ssh_target")" in
    /*) fail "SSH config fixture link is absolute" ;;
esac
[[ "$(realpath "$__ssh_target")" == "$(realpath "$__root_dir/$__ssh_config")" ]] ||
    fail "SSH config fixture target does not resolve to the tracked source"
grep -qF 'IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"' \
    "$__ssh_target" || fail "SSH fixture does not retain the 1Password agent path"
grep -qF 'Include ~/.ssh/1Password/config' "$__ssh_target" ||
    fail "SSH fixture does not retain the 1Password include"

echo "1Password bootstrap configuration passed."
