#!/usr/bin/env zsh
# Smoke tests for mise package bootstrap profile wiring.

set -euo pipefail

local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"

fail() {
    echo "FAIL: $1"
    exit 1
}

line_of() {
    local __needle="$1"
    local __line
    __line="$(grep -nF "$__needle" scripts/mise.zsh | head -n1 | cut -d: -f1 || true)"
    print -r -- "$__line"
}

echo "Testing mise bootstrap profile wiring..."
cd "$__root_dir"

[[ -f ".mise/config.toml" ]] || fail "missing .mise/config.toml"
[[ -f ".mise/conf.d/tasks.toml" ]] || fail "missing .mise/conf.d/tasks.toml"
[[ -f ".mise/conf.d/tools.toml" ]] || fail "missing .mise/conf.d/tools.toml"
[[ -f ".mise/mise.lock" ]] || fail "missing .mise/mise.lock"
[[ ! -f "mise.toml" ]] || fail "root mise.toml should be removed"
[[ ! -f "mise.lock" ]] || fail "root mise.lock should be removed"

[[ -f ".config/mise/config.toml" ]] || fail "missing .config/mise/config.toml"
[[ -f ".config/mise/miserc.toml" ]] || fail "missing .config/mise/miserc.toml"
[[ -f ".config/mise/mise.lock" ]] || fail "missing .config/mise/mise.lock"
[[ -f ".config/mise/conf.d/bootstrap-repos.toml" ]] || fail "missing .config/mise/conf.d/bootstrap-repos.toml"
[[ -f ".config/mise/conf.d/bootstrap-packages.toml" ]] || fail "missing .config/mise/conf.d/bootstrap-packages.toml"
[[ -f ".config/mise/conf.d/bootstrap-packages.personal.toml" ]] || fail "missing .config/mise/conf.d/bootstrap-packages.personal.toml"
[[ -f ".config/mise/conf.d/bootstrap-gh.toml" ]] || fail "missing .config/mise/conf.d/bootstrap-gh.toml"
[[ -f "home/dev/profile.mise.toml" ]] || fail "missing shared profile mise source"
[[ ! -e ".config/mise/files" ]] || fail "obsolete mise files directory should be removed"
[[ -f "home/.config/gh/personal/hosts.yml" ]] || fail "missing tracked personal gh hosts"
if grep -qF "oauth_token:" "home/.config/gh/personal/hosts.yml"; then
    fail "personal gh hosts must not contain an oauth token"
fi
git check-ignore -q --no-index ".config/gh/work/hosts.yml" || fail "work gh hosts should be ignored"
[[ -f ".config/mise/conf.d/tools.toml" ]] || fail "missing .config/mise/conf.d/tools.toml"
[[ ! -f ".config/mise/mise.personal.toml" ]] || fail ".config/mise/mise.personal.toml should be removed"

zsh -n scripts/mise.zsh || fail "scripts/mise.zsh has syntax errors"

grep -qF 'curl -fsSL https://mise.run | sh' scripts/mise.zsh || fail "mise installer bridge missing"
grep -qF 'if [[ -x "$HOME/.local/bin/mise" ]]; then' scripts/mise.zsh || fail "PATH refresh bridge missing"
grep -qF 'if [[ $(command -v mise) == "" ]]; then' scripts/mise.zsh || fail "mise availability check missing"

local __apply_line="$(line_of "mise bootstrap packages apply --yes")"
local __pkg_upgrade_line="$(line_of "mise bootstrap packages upgrade --yes")"
local __pkg_prune_line="$(line_of "mise bootstrap packages prune --yes")"
local __files_apply_line="$(line_of "mise bootstrap files apply --yes")"
local __personal_trust_line="$(line_of 'mise trust --yes "$HOME/dev/personal/mise.toml"')"
local __work_trust_line="$(line_of 'mise trust --yes "$HOME/dev/work/mise.toml"')"
local __mise_prune_line="$(line_of "mise prune")"
local __install_line="$(line_of "mise install")"
local __upgrade_line="$(line_of "mise upgrade")"
local __reshim_line="$(line_of "mise reshim -f")"

[[ -n "$__apply_line" ]] || fail "missing package apply step"
[[ -n "$__pkg_upgrade_line" ]] || fail "missing package upgrade step"
[[ -n "$__pkg_prune_line" ]] || fail "missing package prune step"
[[ -n "$__files_apply_line" ]] || fail "missing workspace mise configuration step"
[[ -n "$__personal_trust_line" ]] || fail "missing personal mise config trust step"
[[ -n "$__work_trust_line" ]] || fail "missing work mise config trust step"
[[ -n "$__mise_prune_line" ]] || fail "missing mise prune step"
[[ -n "$__install_line" ]] || fail "missing mise install step"
[[ -n "$__upgrade_line" ]] || fail "missing mise upgrade step"
[[ -n "$__reshim_line" ]] || fail "missing mise reshim step"

if ! (( __apply_line < __pkg_upgrade_line &&
    __pkg_upgrade_line < __pkg_prune_line &&
    __pkg_prune_line < __files_apply_line &&
    __files_apply_line < __personal_trust_line &&
    __personal_trust_line < __work_trust_line &&
    __work_trust_line < __mise_prune_line &&
    __mise_prune_line < __install_line &&
    __install_line < __upgrade_line &&
    __upgrade_line < __reshim_line )); then
    fail "mise package/tool phase order is incorrect"
fi

grep -qF 'includes = ["scripts/tasks"]' .mise/conf.d/tasks.toml || fail "task include path should use scripts/tasks from .mise/conf.d/tasks.toml"
local __task_listing
__task_listing="$(XDG_CONFIG_HOME="$__root_dir/.config" DOT_PROFILE=work mise -C "$__root_dir" tasks ls)"
print -r -- "$__task_listing" | grep -q '^setup[[:space:]]' || fail "local setup task should be discoverable from scripts/tasks"
print -r -- "$__task_listing" | grep -q '^check[[:space:]]' || fail "local check task should be discoverable from scripts/tasks"
grep -qF '^/\.mise' .stow-local-ignore || fail ".stow-local-ignore should ignore .mise"
grep -qF '^/\.config/gh' .stow-local-ignore || fail ".stow-local-ignore should ignore gh config"
grep -qF '^/home' .stow-local-ignore || fail ".stow-local-ignore should ignore managed home sources"
grep -qF "env = [\"{{ env.DOT_PROFILE | default(value='work') }}\"]" .config/mise/miserc.toml || fail "miserc profile bridge missing default work fallback"
grep -qF "env_conf_d = true" .config/mise/miserc.toml || fail "miserc env_conf_d should be enabled"
grep -qF 'minimum_release_age = "7d"' .config/mise/config.toml || fail "global config should set minimum_release_age to 7d"
grep -qF "[bootstrap.brew]" .config/mise/conf.d/bootstrap-packages.toml || fail "missing [bootstrap.brew] section"
grep -qF "adopt = true" .config/mise/conf.d/bootstrap-packages.toml || fail "bootstrap.brew.adopt should default to true"
grep -qF 'source = "../../../home/dev/profile.mise.toml"' .config/mise/conf.d/bootstrap-gh.toml || fail "workspace profile source should use the managed home tree"
grep -qF '[bootstrap.directories."~/.config/gh/personal"]' .config/mise/conf.d/bootstrap-gh.toml || fail "personal gh config directory should be managed by mise bootstrap"
grep -qF '[bootstrap.files."~/.config/gh/personal/hosts.yml"]' .config/mise/conf.d/bootstrap-gh.toml || fail "personal gh hosts should be managed by mise bootstrap"
grep -qF 'source = "../../../home/.config/gh/personal/hosts.yml"' .config/mise/conf.d/bootstrap-gh.toml || fail "personal gh hosts source missing"
grep -qF 'mode = "0644"' .config/mise/conf.d/bootstrap-gh.toml || fail "personal gh hosts mode missing"
if grep -qF "[bootstrap.brew]" .config/mise/config.toml; then
    fail "bootstrap.brew should live in conf.d/bootstrap-packages.toml"
fi
if grep -qF "[bootstrap.brew.taps]" .config/mise/conf.d/bootstrap-packages.toml; then
    fail "bootstrap.brew.taps should be removed"
fi
if grep -qF '"brew:mise" = "latest"' .config/mise/conf.d/bootstrap-packages.toml; then
    fail "brew:mise should not be in bootstrap.packages"
fi

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
    grep -q "\"brew-cask:$__cask\" = \"latest\"" .config/mise/conf.d/bootstrap-packages.toml || fail "shared cask $__cask missing from base config"
done

local -a __personal_casks=(discord softraid whatsapp)
for __cask in "${__personal_casks[@]}"; do
    grep -q "\"brew-cask:$__cask\" = \"latest\"" .config/mise/conf.d/bootstrap-packages.personal.toml || fail "personal cask $__cask missing from personal config"
    if grep -q "\"brew-cask:$__cask\" = \"latest\"" .config/mise/conf.d/bootstrap-packages.toml; then
        fail "personal cask $__cask should not be in shared config"
    fi
done

grep -q '"mas:1497506650" = "latest"' .config/mise/conf.d/bootstrap-packages.toml || fail "missing Yubico Authenticator MAS app"
grep -q '"mas:1569813296" = "latest"' .config/mise/conf.d/bootstrap-packages.toml || fail "missing 1Password for Safari MAS app"

local __tmp_config_home
__tmp_config_home="$(mktemp -d)"
trap 'rm -rf "$__tmp_config_home"' EXIT

mkdir -p "$__tmp_config_home/mise/conf.d"
cp .config/mise/config.toml "$__tmp_config_home/mise/config.toml"
cp .config/mise/miserc.toml "$__tmp_config_home/mise/miserc.toml"
cp .config/mise/conf.d/bootstrap-repos.toml "$__tmp_config_home/mise/conf.d/bootstrap-repos.toml"
cp .config/mise/conf.d/bootstrap-packages.toml "$__tmp_config_home/mise/conf.d/bootstrap-packages.toml"
cp .config/mise/conf.d/bootstrap-packages.personal.toml "$__tmp_config_home/mise/conf.d/bootstrap-packages.personal.toml"
cp .config/mise/conf.d/bootstrap-gh.toml "$__tmp_config_home/mise/conf.d/bootstrap-gh.toml"
cp .config/mise/conf.d/tools.toml "$__tmp_config_home/mise/conf.d/tools.toml"
printf '[env]\nMISE_PROFILE_SMOKE_WORK = "1"\n' > "$__tmp_config_home/mise/config.work.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_BASE = "1"\n' >> "$__tmp_config_home/mise/config.toml"
printf '\n[env]\nMISE_PROFILE_SMOKE_PERSONAL = "1"\n' >> "$__tmp_config_home/mise/conf.d/bootstrap-packages.personal.toml"

local __work_env
__work_env="$(env -u MISE_ENV XDG_CONFIG_HOME="$__tmp_config_home" DOT_PROFILE=work mise -C "$__tmp_config_home" env --json)"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "work profile should load base config"
print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_WORK": "1"' || fail "work profile should load work fallback config"
if print -r -- "$__work_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "work profile should not load bootstrap-packages.personal.toml"
fi

local __default_env
__default_env="$(env -u MISE_ENV -u DOT_PROFILE XDG_CONFIG_HOME="$__tmp_config_home" mise -C "$__tmp_config_home" env --json)"
print -r -- "$__default_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "default profile should load base config"
print -r -- "$__default_env" | grep -q '"MISE_PROFILE_SMOKE_WORK": "1"' || fail "default profile should resolve to work"
if print -r -- "$__default_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"'; then
    fail "default profile should not load bootstrap-packages.personal.toml"
fi

local __personal_env
__personal_env="$(env -u MISE_ENV XDG_CONFIG_HOME="$__tmp_config_home" DOT_PROFILE=personal mise -C "$__tmp_config_home" env --json)"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_BASE": "1"' || fail "personal profile should load base config"
print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_PERSONAL": "1"' || fail "personal profile should load bootstrap-packages.personal.toml"
if print -r -- "$__personal_env" | grep -q '"MISE_PROFILE_SMOKE_WORK": "1"'; then
    fail "personal profile should not load config.work.toml"
fi

echo "All mise bootstrap profile tests passed."
