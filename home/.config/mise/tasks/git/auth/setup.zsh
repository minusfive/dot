#!/usr/bin/env zsh
#MISE description="Configure a profile-specific Git credential helper"
#MISE quiet=true
#USAGE flag "--profile <profile>" help="Required Git profile: work or personal" {
#USAGE   choices "work" "personal"
#USAGE }
#USAGE flag "--hostname <hostname>" help="Required authenticated hostname from the profile domain list"

set -euo pipefail

source "${${(%):-%N}:A:h}/../../../utils/git-domains.zsh"

local __profile="${usage_profile:-}"
local __raw_hostname="${usage_hostname:-}"

if [[ "$__profile" != "work" && "$__profile" != "personal" ]]; then
    print -u2 -- "error: --profile must be work or personal"
    exit 2
fi

local __hostname
if ! __hostname="$(git_domain_normalize "$__raw_hostname")"; then
    print -u2 -- "error: --hostname must be a valid DNS hostname"
    exit 2
fi

local __profile_dir="$HOME/dev/$__profile"
local __profile_config="$__profile_dir/.gitconfig"
local __domains_file="$__profile_dir/.domains"
local __gh_config_dir="$HOME/.config/gh/$__profile"

if [[ -L "$__profile_dir" || ! -d "$__profile_dir" ]]; then
    print -u2 -- "error: selected Git profile directory is missing or is a symlink"
    exit 1
fi
if [[ -L "$__profile_config" || ( -e "$__profile_config" && ! -f "$__profile_config" ) ]]; then
    print -u2 -- "error: selected Git profile config must be a regular file"
    exit 1
fi
if [[ ! -d "$__gh_config_dir" ]]; then
    print -u2 -- "error: selected GitHub profile config directory is missing"
    exit 1
fi

if ! git_domains_load "$__domains_file"; then
    print -u2 -- "error: selected Git profile domain list is missing or invalid"
    exit 1
fi
if ! git_domain_matches "$__hostname"; then
    print -u2 -- "error: hostname is not listed for the selected Git profile"
    exit 1
fi

if ! env GH_CONFIG_DIR="$__gh_config_dir" GIT_CONFIG_GLOBAL="$__profile_config" \
    mise exec -C "$__profile_dir" gh@latest -- gh auth status --hostname "$__hostname" >/dev/null 2>&1; then
    print -u2 -- "error: the selected GitHub profile is not authenticated for this hostname"
    exit 1
fi

if ! env GH_CONFIG_DIR="$__gh_config_dir" GIT_CONFIG_GLOBAL="$__profile_config" \
    mise exec -C "$__profile_dir" gh@latest -- gh auth setup-git --hostname "$__hostname" >/dev/null 2>&1; then
    print -u2 -- "error: GitHub credential helper setup failed"
    exit 1
fi

local __credential_key="credential.https://$__hostname.helper"
local __profile_helper="!GH_CONFIG_DIR=\"\$HOME/.config/gh/$__profile\" gh auth git-credential"

if ! git config --file "$__profile_config" --replace-all "$__credential_key" ""; then
    print -u2 -- "error: could not reset the selected host credential helpers"
    exit 1
fi
if ! git config --file "$__profile_config" --add "$__credential_key" "$__profile_helper"; then
    print -u2 -- "error: could not write the profile-specific GitHub helper"
    exit 1
fi
