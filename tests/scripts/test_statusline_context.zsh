#!/usr/bin/env zsh
# Tests for Copilot statusline context rendering behavior.

set -euo pipefail

local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"
local __script="$__root_dir/.copilot/statusline-context.sh"

cd "$__root_dir"

echo "Testing statusline context script..."

if [[ ! -f "$__script" ]]; then
  echo "✗ statusline-context.sh not found"
  exit 1
fi

if ! bash -n "$__script"; then
  echo "✗ statusline-context.sh has syntax errors"
  exit 1
fi
echo "✓ statusline-context.sh syntax is valid"

strip_ansi() {
  sed -E $'s/\x1B\\[[0-9;]*[[:alpha:]]//g'
}

run_case() {
  local name="$1"
  local payload="$2"
  local expected="$3"
  local unexpected="${4:-}"

  local raw
  raw=$(printf '%s' "$payload" | bash "$__script")
  local plain
  plain=$(printf '%s' "$raw" | strip_ansi)

  if [[ "$plain" != *"$expected"* ]]; then
    echo "✗ $name: expected '$expected' in output, got: $plain"
    exit 1
  fi

  if [[ -n "$unexpected" && "$plain" == *"$unexpected"* ]]; then
    echo "✗ $name: unexpected '$unexpected' in output, got: $plain"
    exit 1
  fi

  echo "✓ $name"
}

run_case \
  "canonical context_window path" \
  '{"context_window":{"used_percentage":42}}' \
  "42%"

run_case \
  "alternate usage.contextWindow path" \
  '{"usage":{"contextWindow":{"usedPercentage":17}}}' \
  "17%"

run_case \
  "prefer canonical over stale nested value" \
  '{"context_window":{"used_percentage":12},"history":[{"used_percentage":88}]}' \
  "12%" \
  "88%"

run_case \
  "missing usage renders zero percent" \
  '{"session_id":"abc"}' \
  "0%"

echo ""
echo "All statusline context tests passed! ✅"
