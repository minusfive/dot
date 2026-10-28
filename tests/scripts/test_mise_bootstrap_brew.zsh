#!/usr/bin/env zsh
# Test the brew bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing shared package bootstrap configuration..."

local __config="home/.config/mise/conf.d/brew.toml"
[[ -f "$__config" ]] || fail "missing $__config"
if [[ -e "home/.config/mise/conf.d/bootstrap-packages.toml" ]]; then
    fail "legacy shared package declaration must be retired"
fi
grep -qF "[bootstrap.brew]" "$__config" || fail "Homebrew bootstrap section is missing"
grep -qF "adopt = true" "$__config" || fail "Homebrew adoption is missing"
grep -qF 'pre-packages = "mise run brew:install"' "$__config" ||
    fail "Homebrew installation hook is missing"
[[ -x "home/.config/mise/tasks/brew/install.zsh" ]] ||
    fail "Homebrew installation task is missing or not executable"
grep -qF 'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh' \
    home/.config/mise/tasks/brew/install.zsh ||
    fail "Homebrew installation task does not use the official installer"
grep -qF 'eval "$(/opt/homebrew/bin/brew shellenv)"' \
    home/.config/mise/tasks/brew/install.zsh ||
    fail "Homebrew installation task does not initialize the shell environment"
if grep -qF "/usr/local/bin/brew" home/.config/mise/tasks/brew/install.zsh; then
    fail "Homebrew installation task must not include the Intel prefix"
fi
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
        mise -C "$__test_mise_repository" tasks info brew:install
)"
print -r -- "$__task_info" | grep -qF "~/.config/mise/tasks/brew/install.zsh" ||
    fail "MISE_CONFIG_DIR does not discover the Homebrew installation task"
grep -qF '"~/.config/zsh/.zprofile/brew-shellenv"' "$__config" ||
    fail "Homebrew shell environment dotfile entry is missing"
grep -qF 'position = "prepend"' "$__config" ||
    fail "Homebrew shell environment line is not prepended"
if grep -qF "[bootstrap.packages]" "$__config"; then
    fail "shared package declarations should be moved to package modules"
fi

for __profile in work personal; do
    local __profile_config="$(
        env MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
            mise -C "$__test_mise_repository" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "brew.toml" ||
        fail "Homebrew module must be selected by the $__profile profile"
done

if grep -qF "[bootstrap.brew.taps]" "$__config"; then
    fail "Homebrew taps should not be declared here"
fi
if grep -qF '"brew:mise" = "latest"' "$__config"; then
    fail "mise should not be installed as a bootstrap package"
fi

echo "Shared package bootstrap configuration passed."
