#!/usr/bin/env zsh
#MISE description="Authenticate the GitHub CLI for a hostname"
#MISE raw=true
#USAGE flag "--hostname <hostname>" help="GitHub hostname" default="github.com"

set -euo pipefail

local __hostname="${usage_hostname?}"

if mise exec gh@latest -- gh auth status --hostname "$__hostname" >/dev/null 2>&1; then
    exit 0
fi

if ! mise exec gh@latest -- gh auth login \
    --hostname "$__hostname" \
    --git-protocol https \
    --web; then
    print -u2 -- "error: GitHub CLI login failed for $__hostname"
    exit 1
fi

if ! mise exec gh@latest -- gh auth status --hostname "$__hostname" >/dev/null 2>&1; then
    print -u2 -- "error: GitHub CLI authentication did not complete for $__hostname"
    exit 1
fi
