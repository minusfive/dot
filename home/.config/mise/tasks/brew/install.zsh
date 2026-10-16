#!/usr/bin/env zsh
#MISE quiet=true

set -euo pipefail

if command -v brew >/dev/null 2>&1; then
    exit 0
fi

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    print -u2 -- "error: Homebrew installation completed, but brew is not available at a supported prefix"
    exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
    print -u2 -- "error: Homebrew shell environment did not add brew to PATH"
    exit 1
fi
