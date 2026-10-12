#!/usr/bin/env zsh
# Test the shared package bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"
if [[ -e "home/.config/mise/conf.d/bootstrap-packages.toml" ]]; then
    fail "legacy shared package declaration must be retired"
fi
grep -qF '"~/.config/mise/conf.d/module.packages.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.packages.toml"
grep -qF "[bootstrap.brew]" "$__config" || fail "Homebrew bootstrap section is missing"
grep -qF "adopt = true" "$__config" || fail "Homebrew adoption is missing"
if grep -qF "[bootstrap.packages]" "$__config"; then
    fail "shared package declarations should be moved to package modules"
fi

local __shared_profile_count="$(grep -o '"packages"' home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
[[ "$__shared_profile_count" -eq 2 ]] || fail "shared package module must be selected by both profiles"

local -a __module_packages=(
    "module.bat.toml|brew:bat"
    "module.btop.toml|brew:btop"
    "module.fd.toml|brew:fd"
    "module.fzf.toml|brew:fzf"
    "module.gh.toml|brew:gh"
    "module.git.toml|brew:git"
    "module.lazygit.toml|brew:lazygit"
    "module.nvim.toml|brew:neovim"
    "module.ripgrep.toml|brew:ripgrep"
    "module.tmux.toml|brew:tmux"
    "module.yazi.toml|brew:yazi"
    "module.zsh.toml|brew:zsh"
    "module.1password.toml|brew-cask:1password"
    "module.1password.toml|brew-cask:1password-cli"
    "module.1password.toml|mas:1569813296"
    "module.betterdisplay.toml|brew-cask:betterdisplay"
    "module.claude.toml|brew-cask:claude-code"
    "module.ghostty.toml|brew-cask:ghostty"
    "module.hammerspoon.toml|brew-cask:hammerspoon"
    "module.wezterm.toml|brew-cask:wezterm@nightly"
    "module.sqlite.toml|brew:sqlite"
    "module.coreutils.toml|brew:coreutils"
    "module.curl.toml|brew:curl"
    "module.dockutil.toml|brew:dockutil"
    "module.eza.toml|brew:eza"
    "module.findutils.toml|brew:findutils"
    "module.ghostscript.toml|brew:ghostscript"
    "module.htop.toml|brew:htop"
    "module.imagemagick.toml|brew:imagemagick"
    "module.jq.toml|brew:jq"
    "module.just.toml|brew:just"
    "module.libtiff.toml|brew:libtiff"
    "module.libyaml.toml|brew:libyaml"
    "module.luarocks.toml|brew:luarocks"
    "module.mas.toml|brew:mas"
    "module.pkl-lsp.toml|brew:pkl-lsp"
    "module.stow.toml|brew:stow"
    "module.tectonic.toml|brew:tectonic"
    "module.vivid.toml|brew:vivid"
    "module.wallpaper.toml|brew:wallpaper"
    "module.wget.toml|brew:wget"
    "module.yq.toml|brew:yq"
    "module.zoxide.toml|brew:zoxide"
    "module.docker-desktop.toml|brew-cask:docker-desktop"
    "module.google-chrome.toml|brew-cask:google-chrome"
    "module.gpg-suite.toml|brew-cask:gpg-suite"
    "module.imageoptim.toml|brew-cask:imageoptim"
    "module.obsidian.toml|brew-cask:obsidian"
    "module.yubico-authenticator.toml|mas:1497506650"
)
for __module_package in "${__module_packages[@]}"; do
    local __module="${__module_package%%|*}"
    local __package="${__module_package#*|}"
    local __module_name="${__module#module.}"
    __module_name="${__module_name%.toml}"
    grep -q "\"$__package\" = \"latest\"" "home/.config/mise/conf.d/$__module" ||
        fail "$__package is missing from $__module"
    if grep -q "\"$__package\" = \"latest\"" "$__config"; then
        fail "$__package should not remain in shared config"
    fi
    local __profile_count="$(grep -o "\"$__module_name\"" home/.config/mise/miserc.toml | wc -l | tr -d ' ')"
    [[ "$__profile_count" -eq 2 ]] || fail "$__module must be selected by both profiles"
done
grep -qF "# 1Password for Safari" home/.config/mise/conf.d/module.1password.toml ||
    fail "1Password for Safari comment is missing"
grep -qF "# Yubico Authenticator" home/.config/mise/conf.d/module.yubico-authenticator.toml ||
    fail "Yubico Authenticator comment is missing"

if grep -qF "[bootstrap.brew.taps]" "$__config"; then
    fail "Homebrew taps should not be declared here"
fi
if grep -qF '"brew:mise" = "latest"' "$__config"; then
    fail "mise should not be installed as a bootstrap package"
fi

echo "Shared package bootstrap configuration passed."
