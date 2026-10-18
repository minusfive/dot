#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing setup task tool provisioning..."

local __fixture_dir="$__root_dir/.mise-test-setup-$$"
local __stub_dir="$__fixture_dir/bin"
local __log_file="$__fixture_dir/setup.log"
local __real_mise="$(command -v mise)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
mkdir -p "$__stub_dir"

cat > "$__stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "$SETUP_CALL_LOG"
if [[ "$*" == "install" ]]; then
    for __tool in bun hk; do
        cat > "$SETUP_TOOL_BIN/$__tool" <<'TOOL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s %s\n' "$(basename "$0")" "$*" >> "$SETUP_CALL_LOG"
TOOL
        chmod +x "$SETUP_TOOL_BIN/$__tool"
    done
fi
EOF
chmod +x "$__stub_dir/mise"

[[ ! -e "$__stub_dir/bun" && ! -e "$__stub_dir/hk" ]] ||
    fail "development tools must be absent before setup"

env HOME="$__fixture_dir/home" PATH="$__stub_dir:/usr/bin:/bin" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    MISE_DATA_DIR="$__fixture_dir/data" MISE_CACHE_DIR="$__fixture_dir/cache" \
    MISE_OFFLINE=1 SETUP_CALL_LOG="$__log_file" SETUP_TOOL_BIN="$__stub_dir" \
    "$__real_mise" -C "$__root_dir" run setup >/dev/null

[[ -x "$__stub_dir/bun" && -x "$__stub_dir/hk" ]] ||
    fail "mise install did not provision the development tools"

env HOME="$__fixture_dir/home" PATH="$__stub_dir:/usr/bin:/bin" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    MISE_DATA_DIR="$__fixture_dir/data" MISE_CACHE_DIR="$__fixture_dir/cache" \
    MISE_OFFLINE=1 SETUP_CALL_LOG="$__log_file" SETUP_TOOL_BIN="$__stub_dir" \
    "$__real_mise" -C "$__root_dir" run check >/dev/null
env HOME="$__fixture_dir/home" PATH="$__stub_dir:/usr/bin:/bin" \
    MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    MISE_DATA_DIR="$__fixture_dir/data" MISE_CACHE_DIR="$__fixture_dir/cache" \
    MISE_OFFLINE=1 SETUP_CALL_LOG="$__log_file" SETUP_TOOL_BIN="$__stub_dir" \
    "$__real_mise" -C "$__root_dir" run fix >/dev/null

[[ "$(<"$__log_file")" == $'mise install\nbun install\nhk install --mise\nhk run check\nhk run fix' ]] ||
    fail "setup did not provision tools before project dependencies and hooks"

echo "Setup task tool provisioning passed."
