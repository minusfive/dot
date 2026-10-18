#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing init compatibility shim..."

local __fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
local __stub_dir="$__fixture_dir/bin"
local __home="$__fixture_dir/home"
local __log_file="$__fixture_dir/mise.log"
mkdir -p "$__stub_dir" "$__home"
cat > "$__stub_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/mise" <<'MISE'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--version" ]]; then
    printf '%s\n' '2026.10.7 macos-arm64'
    exit 0
fi
printf '%s\n' "$*" >> "$MISE_CALL_LOG"
MISE
chmod +x "$HOME/.local/bin/mise"
EOF
chmod +x "$__stub_dir/curl"

local __run_status
if (
    env HOME="$__home" ZDOTDIR="$__fixture_dir/zsh" PATH="$__stub_dir:/usr/bin:/bin" MISE_CALL_LOG="$__log_file" \
        zsh "$__root_dir/scripts/init.zsh" --mise --profile personal
); then
    __run_status=0
else
    __run_status=$?
fi
[[ "$__run_status" -eq 0 ]] || fail "compatibility forwarding failed"
[[ "$(<"$__log_file")" == "run bootstrap --profile personal" ]] ||
    fail "profile forwarding was not exact"
[[ ! -e "$__home/.local/state/minusfive/profile" ]] ||
    fail "compatibility shim persisted profile state"
[[ -x "$__home/.local/bin/mise" ]] || fail "installer did not place mise at the stable path"

rm "$__log_file"
if (
    env HOME="$__home" ZDOTDIR="$__fixture_dir/zsh" PATH="$__stub_dir:/usr/bin:/bin" MISE_CALL_LOG="$__log_file" \
        zsh "$__root_dir/scripts/init.zsh" -m
); then
    __run_status=0
else
    __run_status=$?
fi
[[ "$__run_status" -eq 0 ]] || fail "default compatibility forwarding failed"
[[ "$(<"$__log_file")" == "run bootstrap" ]] ||
    fail "default forwarding was not exact"

rm "$__log_file"
if (
    env HOME="$__home" ZDOTDIR="$__fixture_dir/zsh" PATH="$__stub_dir:/usr/bin:/bin" MISE_CALL_LOG="$__log_file" \
        zsh "$__root_dir/scripts/init.zsh" -p invalid -m
); then
    __run_status=0
else
    __run_status=$?
fi
[[ "$__run_status" -eq 0 ]] || fail "invalid profile was rejected by the shim"
[[ "$(<"$__log_file")" == "run bootstrap --profile invalid" ]] ||
    fail "invalid profile did not reach mise Usage"

[[ ! -e "$__home/.local/state/minusfive/profile" ]] ||
    fail "compatibility shim created profile state"

local __real_mise="$(command -v mise)"
local __native_stub_dir="$__fixture_dir/native-bin"
local __native_home="$__fixture_dir/native-home"
local __native_state="$__fixture_dir/native-state"
local __native_data="$__fixture_dir/native-data"
mkdir -p "$__native_stub_dir"
ln -s "$__real_mise" "$__native_stub_dir/mise"
if (
    env HOME="$__native_home" ZDOTDIR="$__fixture_dir/native-zsh" \
        XDG_STATE_HOME="$__native_state" PATH="$__native_stub_dir:/usr/bin:/bin" \
        MISE_DATA_DIR="$__native_data" MISE_CACHE_DIR="$__fixture_dir/native-cache" \
        MISE_OFFLINE=1 MISE_BOOTSTRAP_CONFIRM=no \
        zsh "$__root_dir/scripts/init.zsh" --mise --profile work
); then
    __run_status=0
else
    __run_status=$?
fi
[[ "$__run_status" -eq 0 ]] || fail "native compatibility decline failed"
[[ ! -e "$__native_state/minusfive/profile" ]] ||
    fail "native compatibility decline persisted profile state"
if [[ -d "$__native_data/installs" ]] &&
    find "$__native_data/installs" -type f -print -quit | grep -q .; then
    fail "native compatibility decline installed a tool before confirmation"
fi

rm -f "$__log_file"
zsh "$__root_dir/scripts/init.zsh" --profile personal >/dev/null
[[ ! -e "$__log_file" ]] || fail "no-mise compatibility path invoked mise"
[[ ! -e "$__home/.local/state/minusfive/profile" ]] ||
    fail "no-mise compatibility path created profile state"

echo "Init compatibility shim passed."
