#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing install-mise.zsh mise acquisition..."

local __installer="scripts/install-mise.zsh"
[[ -x "$__installer" ]] || fail "mise installer is missing or not executable"
zsh -n "$__installer" || fail "mise installer has syntax errors"
grep -qF 'curl -fsSL https://mise.run | sh' "$__installer" ||
    fail "mise installer bridge missing"
grep -qF 'local __code_color=$' "$__installer" ||
    fail "mise installer does not define terminal code formatting"
grep -qF 'mise bootstrap --help${__reset_color}' "$__installer" ||
    fail "mise installer does not print canonical task instructions"
if grep -qF 'DOT_MISE_INSTALLED_DURING_RUN' "$__installer"; then
    fail "mise installer retains obsolete installer state forwarding"
fi
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
if env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" > "$__message_file" 2>&1; then
    fail "package-managed mise was accepted"
fi
grep -qF "mise is installed outside" "$__message_file" ||
    fail "package-managed mise error is missing"

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
grep -qF "scripts/mise-env.zsh" "$__fixture_dir/help.txt" ||
    fail "help output does not describe the environment setup"
[[ ! -s "$__log_file" ]] || fail "help unexpectedly invoked mise"

: > "$__log_file"
if env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" --profile personal >/dev/null 2>&1; then
    fail "retired profile option was accepted"
fi
[[ ! -s "$__log_file" ]] || fail "retired profile option invoked mise"

mkdir -p "$__home/.local/bin"
cp "$__bin_dir/mise" "$__home/.local/bin/mise"
chmod +x "$__home/.local/bin/mise"
: > "$__log_file"
env HOME="$__home" ZDOTDIR="$__zdotdir" PATH="$__bin_dir:/usr/bin:/bin" INIT_LOG="$__log_file" \
    zsh "$__installer" > "$__message_file"
grep -qF $'\e[36mmise\e[0m is already installed' "$__message_file" ||
    fail "existing official mise output is missing its teal code formatting"
grep -qF "test-version" "$__message_file" ||
    fail "existing official mise version was not displayed"
grep -qF $'\e[36msource scripts/mise-env.zsh\e[0m' "$__message_file" ||
    fail "existing official mise did not print next-step instructions"
grep -qF $'\e[36mmise bootstrap --help\e[0m' "$__message_file" ||
    fail "existing official mise did not print the canonical task command"
grep -qF -- "bootstrap --help" "$__log_file" ||
    fail "existing official mise was not checked against the repository task"

rm -f "$__home/.local/bin/mise"
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
grep -qF $'\e[36msource scripts/mise-env.zsh\e[0m' "$__message_file" ||
    fail "clean-home acquisition did not print next-step instructions"
grep -qF $'\e[36mmise bootstrap --help\e[0m' "$__message_file" ||
    fail "clean-home acquisition did not print the canonical task command"
grep -qF -- "bootstrap --help" "$__log_file" ||
    fail "clean-home acquisition was not checked against the repository task"

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

mkdir -p "$__home/.local/state/minusfive"
print -r -- personal >| "$__home/.local/state/minusfive/profile"
local __env_output="$(
    env -u DOT_PROFILE HOME="$__home" XDG_STATE_HOME="$__home/.local/state" PATH="/usr/bin:/bin" \
        zsh -fc 'setopt no_unset; source scripts/mise-env.zsh; print -r -- "${DOT_PROFILE:-unset}"; print -r -- "$PATH"'
)"
print -r -- "$__env_output" | grep -q '^unset$' ||
    fail "mise environment source selected a profile"
print -r -- "$__env_output" | grep -qF "$__home/.local/bin" ||
    fail "mise environment source did not update PATH"
local __explicit_env_output="$(
    env HOME="$__home" XDG_STATE_HOME="$__home/.local/state" DOT_PROFILE=work PATH="/usr/bin:/bin" \
        zsh -fc 'source scripts/mise-env.zsh; print -r -- "$DOT_PROFILE"'
)"
[[ "$__explicit_env_output" == work ]] ||
    fail "mise environment source changed an existing profile variable"

local __mise_env_output="$(
    env -u MISE_CONFIG_DIR -u MISE_ENV_CONF_D -u MISE_AUTO_ENV \
        HOME="$__home" PATH="/usr/bin:/bin" \
        zsh -fc 'source scripts/mise-env.zsh; print -r -- "$MISE_CONFIG_DIR"; print -r -- "$MISE_ENV_CONF_D"; print -r -- "${MISE_AUTO_ENV:-unset}"'
)"
print -r -- "$__mise_env_output" | grep -qF "$PWD/home/.config/mise" ||
    fail "mise environment source did not select the repository config"
print -r -- "$__mise_env_output" | grep -q '^true$' ||
    fail "mise environment source did not enable conf.d modules"
print -r -- "$__mise_env_output" | grep -q '^unset$' ||
    fail "mise environment source did not clear auto environment selection"

echo "install-mise.zsh mise acquisition passed."
