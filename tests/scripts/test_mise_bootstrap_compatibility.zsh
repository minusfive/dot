#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing init.zsh compatibility forwarding..."

local __init="scripts/init.zsh"
[[ -x "$__init" ]] || fail "initializer is missing or not executable"
zsh -n "$__init" || fail "initializer has syntax errors"
if grep -qE '_v_|mise\.zsh|functions\.zsh' "$__init"; then
    fail "initializer retains retired lifecycle or UI helpers"
fi

local __fixture_dir="$__root_dir/.agents/projects.local/issue-61-mise-bootstrap/tmp/init-test.$$"
local __bin_dir="$__fixture_dir/bin"
local __installer_dir="$__fixture_dir/installer"
local __home="$__fixture_dir/home"
local __zdotdir="$__fixture_dir/zsh"
local __log_file="$__fixture_dir/init.log"
mkdir -p "$__bin_dir" "$__installer_dir" "$__home" "$__zdotdir"
trap 'rm -rf -- "$__fixture_dir"' EXIT

cat > "$__bin_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'root=%s args=%s marker=%s\n' "$PWD" "$*" "${DOT_MISE_INSTALLED_DURING_RUN:-}" >> "$INIT_LOG"
EOF
chmod +x "$__bin_dir/mise"

env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__init" --mise --profile personal
grep -qF "args=run system:bootstrap --profile personal" "$__log_file" ||
    fail "explicit profile was not forwarded to the canonical task"
grep -qF "marker=false" "$__log_file" || fail "existing mise was marked as newly installed"
grep -qF "root=$__root_dir" "$__log_file" || fail "initializer did not run from the repository root"

: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__init" --mise
grep -qF "args=run system:bootstrap" "$__log_file" ||
    fail "profile-free compatibility invocation was not forwarded"
if grep -qF -- '--profile' "$__log_file"; then
    fail "profile-free compatibility invocation supplied an unexpected profile"
fi

cat > "$__installer_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mkdir -p "$HOME/.local/bin"\ncp "$MISE_SOURCE" "$HOME/.local/bin/mise"\nchmod +x "$HOME/.local/bin/mise"\n'
EOF
chmod +x "$__installer_dir/curl"

: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__installer_dir:/usr/bin:/bin" \
    MISE_SOURCE="$__bin_dir/mise" INIT_LOG="$__log_file" zsh "$__init" --mise
grep -qF "args=run system:bootstrap" "$__log_file" ||
    fail "clean-home acquisition did not reach the canonical task"
grep -qF "marker=true" "$__log_file" ||
    fail "clean-home acquisition did not preserve the installer marker"

cat > "$__installer_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'help unexpectedly acquired mise\n' >> "$INIT_LOG"
exit 17
EOF
chmod +x "$__installer_dir/curl"
: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__installer_dir:/usr/bin:/bin" \
    INIT_LOG="$__log_file" zsh "$__init" --help > "$__fixture_dir/help.txt"
grep -qF "Usage: scripts/init.zsh [options]" "$__fixture_dir/help.txt" ||
    fail "help output is missing without mise"
[[ ! -s "$__log_file" ]] || fail "help attempted to acquire mise"

echo "init.zsh compatibility forwarding passed."
