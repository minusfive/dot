#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing install-mise.zsh mise acquisition..."

local __installer="scripts/install-mise.zsh"
[[ -x "$__installer" ]] || fail "mise installer is missing or not executable"
zsh -n "$__installer" || fail "mise installer has syntax errors"
if grep -qE '_v_|mise\.zsh|functions\.zsh' "$__installer"; then
    fail "mise installer retains retired lifecycle or UI helpers"
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
if [[ "${1:-}" == "version" ]]; then
    printf 'test-version\n'
    exit 0
fi
printf 'root=%s args=%s\n' "$PWD" "$*" >> "$INIT_LOG"
EOF
chmod +x "$__bin_dir/mise"

local __message_file="$__fixture_dir/message.txt"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" > "$__message_file"
grep -qF $'\e[36mmise\e[0m is already installed' "$__message_file" ||
    fail "existing mise output is missing its teal code formatting"
grep -qF "test-version" "$__message_file" ||
    fail "existing mise version was not displayed"
grep -qF $'\e[36mmise system:bootstrap --help\e[0m' "$__message_file" ||
    fail "existing mise did not print next-step instructions"
[[ ! -s "$__log_file" ]] || fail "mise installer invoked mise instead of printing instructions"

: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" -h > "$__fixture_dir/help.txt"
grep -qF "Usage:" "$__fixture_dir/help.txt" ||
    fail "help output is missing"
grep -qF "[--help]" "$__fixture_dir/help.txt" ||
    fail "help output is missing its help option"
grep -qF "Installs " "$__fixture_dir/help.txt" ||
    fail "help output does not describe the installer's purpose"
grep -qF "if it is not available." "$__fixture_dir/help.txt" ||
    fail "help output does not describe the installer's purpose"
[[ ! -s "$__log_file" ]] || fail "help unexpectedly invoked mise"

: > "$__log_file"
if env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" --profile personal >/dev/null 2>&1; then
    fail "retired profile option was accepted"
fi
[[ ! -s "$__log_file" ]] || fail "retired profile option invoked mise"

cat > "$__installer_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'mkdir -p "$HOME/.local/bin"\ncp "$MISE_SOURCE" "$HOME/.local/bin/mise"\nchmod +x "$HOME/.local/bin/mise"\n'
EOF
chmod +x "$__installer_dir/curl"

: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__installer_dir:/usr/bin:/bin" \
    MISE_SOURCE="$__bin_dir/mise" INIT_LOG="$__log_file" zsh "$__installer" > "$__message_file"
grep -qF $'\e[36mmise\e[0m installed' "$__message_file" ||
    fail "installed mise output is missing its teal code formatting"
grep -qF $'\e[36m~/.local/bin/mise system:bootstrap --help\e[0m' "$__message_file" ||
    fail "clean-home acquisition did not print next-step instructions"
[[ ! -s "$__log_file" ]] || fail "clean-home acquisition invoked mise instead of printing instructions"

cat > "$__installer_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'help unexpectedly acquired mise\n' >> "$INIT_LOG"
exit 17
EOF
chmod +x "$__installer_dir/curl"
: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__installer_dir:/usr/bin:/bin" \
    INIT_LOG="$__log_file" zsh "$__installer" --help > "$__fixture_dir/help-without-mise.txt"
grep -qF "Usage:" "$__fixture_dir/help-without-mise.txt" ||
    fail "help output is missing without mise"
[[ ! -s "$__log_file" ]] || fail "help attempted to acquire mise"

echo "install-mise.zsh mise acquisition passed."
