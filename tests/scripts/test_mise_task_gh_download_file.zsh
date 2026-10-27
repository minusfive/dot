#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing gh:download:file task..."

local __task="home/.config/mise/tasks/gh/download/file.sh"
local __fixture_dir
__fixture_dir="$(test_fixture_dir gh-download-file)" || exit 1
local __bin_dir="$__fixture_dir/bin"
local __output="$__fixture_dir/theme.txt"
local __invocation="$__fixture_dir/invocation.txt"
grep -qF '"mise/config/mise/tasks/gh/download/file.sh" = {' home/.config/mise/conf.d/mise.toml &&
    grep -qF 'target = "{{ xdg_config_home }}/mise/tasks/gh/download/file.sh"' \
        home/.config/mise/conf.d/mise.toml ||
    fail "gh download task is not deployed by the mise control plane"
mkdir -p "$__bin_dir"
trap 'rm -rf "$__fixture_dir"' EXIT

cat > "$__bin_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" > "$GH_DOWNLOAD_INVOCATION"
if [[ "${GH_DOWNLOAD_FAIL:-false}" == true ]]; then
    exit 1
fi
printf 'downloaded theme\n'
EOF
chmod +x "$__bin_dir/mise"

printf 'original theme\n' > "$__output"
if env \
    PATH="$__bin_dir:$PATH" \
    GH_DOWNLOAD_INVOCATION="$__invocation" \
    GH_DOWNLOAD_FAIL=true \
    usage_api_path="repos/example/theme/contents/theme.txt?ref=main" \
    usage_output="$__output" \
    bash "$__task"; then
    fail "download task succeeded when gh failed"
fi
grep -qF 'original theme' "$__output" || fail "failed download changed the destination"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] ||
    fail "failed download left a temporary file"

env \
    PATH="$__bin_dir:$PATH" \
    GH_DOWNLOAD_INVOCATION="$__invocation" \
    usage_api_path="repos/example/theme/contents/theme.txt?ref=main" \
    usage_output="$__output" \
    bash "$__task"
grep -qF 'downloaded theme' "$__output" || fail "successful download did not replace the destination"
grep -qF 'exec gh@latest -- gh api' "$__invocation" || fail "task did not invoke gh through mise exec"
grep -qF 'repos/example/theme/contents/theme.txt?ref=main' "$__invocation" ||
    fail "task did not pass the API path"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] ||
    fail "successful download left a temporary file"

echo "gh:download:file task passed."
