#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing aliases bootstrap configuration..."

local __config="home/.config/mise/conf.d/aliases.toml"
local __source="home/.config/aliases/.aliases"
local __alias_source="home/.config/aliases/zshrc.zsh"
local __zone_source="home/.config/zsh/.zshrc-zone-2.zsh"
local __control_plane="home/.config/mise/conf.d/mise.toml"
local __zsh_config="home/.config/mise/conf.d/zsh.toml"

[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing $__source"
[[ -f "$__alias_source" ]] || fail "missing $__alias_source"
grep -qF '[dotfiles]' "$__config" || fail "aliases dotfiles section is missing"
grep -qF '"~/.config/zsh/.aliases" = { source = "~/dev/personal/dot/home/.config/aliases/.aliases", mode = "symlink" }' "$__config" ||
    fail "aliases symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-2.zsh/aliases" = { source = "~/dev/personal/dot/home/.config/aliases/zshrc.zsh", template = "tera" }' "$__config" ||
    fail "aliases Zone 2 declaration is missing"
for __section in '[bootstrap.packages]' '[bootstrap.repos]' '[bootstrap.hooks]' '[tools]'; do
    if grep -qF "$__section" "$__config"; then
        fail "aliases module must not declare $__section"
    fi
done
grep -qF '"~/.config/mise/conf.d/aliases.toml"' "$__control_plane" ||
    fail "mise control-plane module does not deploy aliases.toml"
for __profile in work personal; do
    local __profile_config="$(
        env MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "aliases.toml" ||
        fail "aliases must be selected by the $__profile profile"
done
if grep -qF '.aliases' "$__zsh_config"; then
    fail "generic Zsh module must not own aliases"
fi
grep -qF '.config/zsh/.zshrc-zone-2.zsh	aliases' home/.config/mise/cleanup.blocks ||
    fail "cleanup inventory does not record the aliases block"

zsh -n "$__alias_source" || fail "aliases Zone 2 source has syntax errors"
zsh -n "$__zone_source" || fail "generic Zone 2 source has syntax errors"
[[ "$(grep -cF 'source "$ZDOTDIR/.aliases"' "$__alias_source")" -eq 1 ]] ||
    fail "aliases source must contain one active import"
[[ "$(find home -type f -name .aliases | wc -l | tr -d ' ')" -eq 1 ]] ||
    fail "aliases must have one authoritative source"
grep -qF 'after shell plugins' "$__alias_source" ||
    fail "aliases source does not document post-plugin timing"
if grep -qF '.aliases' "$__zone_source"; then
    fail "generic Zone 2 source still imports .aliases"
fi
grep -qF 'KEYTIMEOUT=1' "$__zone_source" ||
    fail "generic Zone 2 settings were removed"
[[ "$(find home/.config/aliases -type f -name .aliases | wc -l | tr -d ' ')" -eq 1 ]] ||
    fail "aliases must have one dedicated source"
if grep -qF '"~/.config/aliases"' "$__config"; then
    fail "aliases module must not deploy the source directory"
fi
[[ ! -e "home/.config/zsh/.zsh_history" && ! -e "home/.config/zsh/.zcompdump" ]] ||
    fail "Zsh runtime files must remain outside the tracked source"

local __fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/aliases-module.XXXXXX")"
local __fixture_home="$__fixture_dir/home"
local __fixture_config="$__fixture_home/.config/mise"
local __fixture_zone="$__fixture_home/.config/zsh/.zshrc-zone-2.zsh"
local __fixture_zone_before="$__fixture_dir/zone-2.before"
local __fixture_aliases="$__fixture_home/.config/zsh/.aliases"
local __fixture_unmanaged="$__fixture_home/unmanaged.fixture"
local __fixture_unmanaged_before="$__fixture_dir/unmanaged.before"
local __host_mise_config="$HOME/.config/mise"
local __fixture_output="$__fixture_dir/dry-run.log"
local __fixture_apply_output="$__fixture_dir/apply.log"
mkdir -p "$__fixture_home/dev/personal" "$__fixture_config" "$__fixture_home/.config/zsh"
ln -s "$__root_dir" "$__fixture_home/dev/personal/dot"
trap 'rm -rf "$__fixture_dir"' EXIT

cat > "$__fixture_config/config.toml" <<EOF
[settings.dotfiles]
relative_symlinks = true

[dotfiles]
"~/.config/zsh/.zshrc-zone-2.zsh/user" = { source = "~/dev/personal/dot/home/.config/zsh/.zshrc-zone-2.zsh", template = "tera" }
EOF
cat > "$__fixture_zone" <<'EOF'
# Generic settings
KEYTIMEOUT=1
# >>> mise:user >>> managed by mise — do not edit between markers
# Legacy aliases were loaded here.
if [[ -f "$ZDOTDIR/.aliases" ]]; then
    source "$ZDOTDIR/.aliases"
fi
# <<< mise:user <<<
EOF
tail -n +2 "$__config" >> "$__fixture_config/config.toml"
cp "$__fixture_zone" "$__fixture_zone_before"
printf '%s\n' unmanaged > "$__fixture_unmanaged"
cp "$__fixture_unmanaged" "$__fixture_unmanaged_before"

local __mise_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_home/.config"
    "MISE_GLOBAL_CONFIG_FILE=$__fixture_config/config.toml"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_config"
    "MISE_CONFIG_DIR=$__fixture_config"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_CEILING_PATHS=$__fixture_home"
    "MISE_DATA_DIR=$__fixture_home/.local/share/mise"
    "MISE_CACHE_DIR=$__fixture_home/.cache/mise"
    "MISE_STATE_DIR=$__fixture_home/.local/state/mise"
    "MISE_ENV_CONF_D=true"
)
mkdir -p "$__fixture_home/.local/share/mise" "$__fixture_home/.cache/mise"

env -u MISE_ENV "${__mise_env[@]}" \
    mise -C "$__fixture_home" dot apply --dry-run --verbose > "$__fixture_output" 2>&1 ||
    fail "isolated aliases dotfile dry run failed"
grep -qF 'ln -sfr' "$__fixture_output" ||
    fail "dry run did not plan a relative aliases symlink"
grep -qF 'edit ~/.config/zsh/.zshrc-zone-2.zsh (block:aliases)' "$__fixture_output" ||
    fail "dry run did not plan the aliases Zone 2 block"
if grep -qE 'bootstrap (packages|repos)|git clone|brew install' "$__fixture_output"; then
    fail "aliases dry run attempted package or repository work"
fi
cmp -s "$__fixture_zone" "$__fixture_zone_before" ||
    fail "dry run changed the seeded Zone 2 file"
[[ ! -e "$__fixture_aliases" ]] ||
    fail "dry run created the aliases symlink"

env -u MISE_ENV "${__mise_env[@]}" \
    mise -C "$__fixture_home" dot apply > "$__fixture_apply_output" 2>&1 ||
    fail "isolated aliases dotfile apply failed"
[[ -L "$__fixture_aliases" ]] || fail "aliases target is not a symlink"
case "$(readlink "$__fixture_aliases")" in
    /*) fail "aliases target link is absolute" ;;
esac
[[ "$(realpath "$__fixture_aliases")" == "$(realpath "$__root_dir/home/.config/aliases/.aliases")" ]] ||
    fail "aliases target resolves to the wrong source"
[[ "$(grep -cF 'source "$ZDOTDIR/.aliases"' "$__fixture_zone")" -eq 1 ]] ||
    fail "rendered Zone 2 file must contain one active aliases import"
local __user_block="$(
    sed -n '/>>> mise:user >>>/,/<<< mise:user <<</p' "$__fixture_zone"
)"
if print -r -- "$__user_block" | grep -qF '.aliases'; then
    fail "generic Zone 2 block still imports .aliases"
fi
[[ "$(grep -cF 'mise:aliases' "$__fixture_zone")" -eq 2 ]] ||
    fail "aliases block was not rendered exactly once"
cmp -s "$__fixture_unmanaged" "$__fixture_unmanaged_before" ||
    fail "unmanaged fixture file changed"
zsh -n "$__fixture_zone" || fail "generated Zone 2 file has syntax errors"

rm -rf -- "$__fixture_dir"
trap - EXIT

echo "aliases bootstrap configuration passed."
