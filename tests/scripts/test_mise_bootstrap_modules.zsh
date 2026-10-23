#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise module declarations..."

local __control_plane="home/.config/mise/conf.d/module.mise.toml"
local __control_plane_dotfiles="$(
    mise config get --file "$__control_plane" dotfiles
)" || fail "could not parse the mise control-plane dotfiles"
local __work_profile_config="$(
    env -u MISE_ENV DOT_PROFILE=work \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" config ls --no-truncate
)"
local __personal_profile_config="$(
    env -u MISE_ENV DOT_PROFILE=personal \
        MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" config ls --no-truncate
)"

assert_module_contract() {
    local __kind="$1"
    local __module="$2"
    local __declaration="$3"
    local __config="home/.config/mise/conf.d/module.$__module.toml"
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
    print -r -- "$__control_plane_dotfiles" |
        grep -qF "\"~/.config/mise/conf.d/module.$__module.toml\"" ||
        fail "control-plane module does not deploy module.$__module.toml"
    if [[ "$__kind" == personal ]]; then
        if print -r -- "$__work_profile_config" | grep -qF "module.$__module.toml"; then
            fail "$__module must not be selected by the work profile"
        fi
    else
        print -r -- "$__work_profile_config" | grep -qF "module.$__module.toml" ||
            fail "$__module must be selected by the work profile"
    fi
    print -r -- "$__personal_profile_config" | grep -qF "module.$__module.toml" ||
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
    'softraid|brew-cask:softraid'
    'whatsapp|brew-cask:whatsapp'
)
for __entry in "${__personal_modules[@]}"; do
    assert_module_contract personal "${__entry%%|*}" "${__entry#*|}"
done

echo "Mise module declarations passed."
