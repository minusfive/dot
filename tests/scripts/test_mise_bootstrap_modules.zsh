#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise module declarations..."

local __control_plane="home/.config/mise/conf.d/mise.toml"
local __control_plane_dotfiles="$(
    mise config get --file "$__control_plane" dotfiles
)" || fail "could not parse the mise control-plane dotfiles"
if print -r -- "$__control_plane_dotfiles" | grep -qF '"mise/config/mise/'; then
    fail "control-plane module still declares per-file mise config ownership"
fi
local __work_profile_config="$(
    env MISE_ENV=work \
        MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
        mise -C "$__test_mise_repository" config ls --no-truncate
)"
local __personal_profile_config="$(
    env MISE_ENV=personal \
        MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
        mise -C "$__test_mise_repository" config ls --no-truncate
)"

assert_module_contract() {
    local __kind="$1"
    local __module="$2"
    local __declaration="$3"
    local __module_file="$(module_filename "$__module")"
    local __config="home/.config/mise/conf.d/$__module_file"
    local __declarations

    [[ -f "$__config" ]] || fail "missing $__config"
    case "$__kind" in
        package)
            __declarations="$(
                mise config get --file "$__config" bootstrap.packages
            )" || fail "could not parse $__config package declarations"
            print -r -- "$__declarations" |
                grep -qF "\"$__declaration\" = \"latest\"" ||
                fail "$__declaration is missing from $__config"
            ;;
        tool)
            __declarations="$(
                mise config get --file "$__config" tools
            )" || fail "could not parse $__config tool declarations"
            print -r -- "$__declarations" | grep -qF "$__declaration" ||
                fail "$__declaration is missing from $__config"
            ;;
        personal)
            __declarations="$(
                mise config get --file "$__config" bootstrap.packages
            )" || fail "could not parse $__config package declarations"
            print -r -- "$__declarations" |
                grep -qF "\"$__declaration\" = \"latest\"" ||
                fail "$__declaration is missing from $__config"
            ;;
        *)
            fail "unknown module contract kind: $__kind"
            ;;
    esac
    if [[ "$__kind" == personal ]]; then
        if print -r -- "$__work_profile_config" | grep -qF "$__module_file"; then
            fail "$__module must not be selected by the work profile"
        fi
    else
        print -r -- "$__work_profile_config" | grep -qF "$__module_file" ||
            fail "$__module must be selected by the work profile"
    fi
    print -r -- "$__personal_profile_config" | grep -qF "$__module_file" ||
        fail "$__module must be selected by the personal profile"
}

local -a __package_modules=(
    'eza|brew:eza'
    'ghostscript|brew:ghostscript'
    'google-chrome|brew-cask:google-chrome'
    'gpg-suite|brew-cask:gpg-suite'
    'htop|brew:htop'
    'imagemagick|brew:imagemagick'
    'imageoptim|brew-cask:imageoptim'
    'jq|brew:jq'
    'just|brew:just'
    'libtiff|brew:libtiff'
    'libyaml|brew:libyaml'
    'luarocks|brew:luarocks'
    'mas|brew:mas'
    'obsidian|brew-cask:obsidian'
    'pkl-lsp|brew:pkl-lsp'
    'sqlite|brew:sqlite'
    'stow|brew:stow'
    'tectonic|brew:tectonic'
    'wallpaper|brew:wallpaper'
    'wget|brew:wget'
    'yq|brew:yq'
    'yubico-authenticator|mas:1497506650'
    'zoxide|brew:zoxide'
)
local __entry
for __entry in "${__package_modules[@]}"; do
    assert_module_contract package "${__entry%%|*}" "${__entry#*|}"
done

local -a __tool_modules=(
    'bun|bun = "latest"'
    'github-copilot|"npm:@github/copilot" = "latest"'
    'go|go = "latest"'
    'mermaid-formatter|"npm:mermaid-formatter" = "latest"'
    'pitchfork|pitchfork = "latest"'
    'prettier|prettier = "latest"'
    'qmd|"npm:@tobilu/qmd" = "latest"'
    'rumdl|rumdl = "latest"'
    'stylua|stylua = "latest"'
    'tree-sitter|tree-sitter = "latest"'
    'tuicr|"github:agavra/tuicr" = "latest"'
)
for __entry in "${__tool_modules[@]}"; do
    assert_module_contract tool "${__entry%%|*}" "${__entry#*|}"
done

local -a __personal_modules=(
    'discord|brew-cask:discord'
    'opencode|brew:opencode'
    'softraid|brew-cask:softraid'
    'whatsapp|brew-cask:whatsapp'
)
for __entry in "${__personal_modules[@]}"; do
    assert_module_contract personal "${__entry%%|*}" "${__entry#*|}"
done

echo "Mise module declarations passed."
