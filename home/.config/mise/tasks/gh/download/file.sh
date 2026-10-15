#!/usr/bin/env bash
#MISE description="Download a GitHub repository file atomically"
#MISE quiet=true
#USAGE flag "--api-path <path>" help="GitHub API path to download"
#USAGE flag "--output <path>" help="Destination file"

set -euo pipefail

local_api_path="${usage_api_path:-}"
local_output="${usage_output:-}"

if [[ -z "$local_api_path" || -z "$local_output" ]]; then
    printf 'error: --api-path and --output are required\n' >&2
    exit 1
fi

local_tmp_file="$(mktemp "${local_output}.tmp.XXXXXX")"
cleanup() {
    if [[ -n "$local_tmp_file" ]]; then
        rm -f "$local_tmp_file"
    fi
}
trap cleanup EXIT

mise exec gh@latest -- gh api \
    -H "Accept: application/vnd.github.raw" \
    "$local_api_path" > "$local_tmp_file"
chmod 644 "$local_tmp_file"
mv "$local_tmp_file" "$local_output"
local_tmp_file=""
