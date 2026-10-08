#!/usr/bin/env zsh
# Test the shared package bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package bootstrap configuration..."

local __config=".config/mise/conf.d/bootstrap-packages.toml"
[[ -f "$__config" ]] || fail "missing $__config"
grep -qF "[bootstrap.brew]" "$__config" || fail "Homebrew bootstrap section is missing"
grep -qF "adopt = true" "$__config" || fail "Homebrew adoption is missing"
grep -qF '"mas:1497506650" = "latest"' "$__config" || fail "Yubico Authenticator is missing"
grep -qF '"mas:1569813296" = "latest"' "$__config" || fail "1Password for Safari is missing"

local -a __shared_casks=(
    1password
    1password-cli
    betterdisplay
    claude-code
    docker-desktop
    google-chrome
    ghostty
    gpg-suite
    hammerspoon
    imageoptim
    obsidian
    wezterm@nightly
)
for __cask in "${__shared_casks[@]}"; do
    grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__config" || fail "shared cask $__cask is missing"
done

for __cask in discord softraid whatsapp; do
    if grep -q "\"brew-cask:$__cask\" = \"latest\"" "$__config"; then
        fail "personal cask $__cask should not be in shared config"
    fi
done

if grep -qF "[bootstrap.brew.taps]" "$__config"; then
    fail "Homebrew taps should not be declared here"
fi
if grep -qF '"brew:mise" = "latest"' "$__config"; then
    fail "mise should not be installed as a bootstrap package"
fi

echo "Shared package bootstrap configuration passed."
