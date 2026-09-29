#!/usr/bin/env bash
#MISE description="Install GitHub CLI extensions required by global mise tasks."
#MISE quiet=true

set -euo pipefail

readonly MARKDOWN_PREVIEW_EXTENSION="yusukebe/gh-markdown-preview"

if ! command -v gh >/dev/null 2>&1; then
    printf '%s\n' "error: gh is required to install ${MARKDOWN_PREVIEW_EXTENSION}" >&2
    exit 127
fi

if gh extension list | awk '$1 == "gh" && $2 == "markdown-preview" { found = 1 } END { exit !found }'; then
    exit 0
fi

gh extension install "$MARKDOWN_PREVIEW_EXTENSION"
