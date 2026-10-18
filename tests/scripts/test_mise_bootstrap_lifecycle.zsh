#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap lifecycle..."

grep -qF 'export MISE_CONFIG_DIR="$__mise_config_dir"' scripts/mise.zsh ||
    fail "mise config directory is not exported"
grep -qF 'export MISE_ENV_CONF_D=true' scripts/mise.zsh ||
    fail "MISE_ENV_CONF_D is not enabled"
grep -qF 'function _v_mise_ensure_stable_path' scripts/mise.zsh ||
    fail "stable mise path helper is missing"
grep -qF 'function _v_mise_is_valid' scripts/mise.zsh ||
    fail "stable mise validation helper is missing"
grep -qF 'command ln -s "$__mise_path" "$__stable_path"' scripts/mise.zsh ||
    fail "stable mise path symlink is missing"
grep -qF 'Cannot create stable mise path recursively' scripts/mise.zsh ||
    fail "stable mise path recursion guard is missing"
grep -qF 'unset MISE_ENV' scripts/mise.zsh ||
    fail "inherited MISE_ENV is not cleared"
grep -qF 'unset MISE_AUTO_ENV' scripts/mise.zsh ||
    fail "inherited MISE_AUTO_ENV is not cleared"
grep -qF 'mise -C "$__dotfiles_dir" bootstrap --yes' scripts/mise.zsh ||
    fail "full mise bootstrap command is missing"
if grep -qF 'mise install' scripts/mise.zsh; then
    fail "mise install must remain owned by mise bootstrap"
fi
if grep -qF 'mise bootstrap repos apply --yes' scripts/mise.zsh; then
    fail "repository apply must remain owned by mise bootstrap"
fi
if grep -qE 'MISE_GLOBAL_CONFIG_FILE|--only|--skip|mise -E ' scripts/mise.zsh; then
    fail "mise lifecycle must use the repository context without filters"
fi
grep -qF 'command -v gh >/dev/null 2>&1 && gh auth status --hostname github.com >/dev/null 2>&1' scripts/mise.zsh ||
    fail "GitHub CLI authentication status check is missing"
grep -qF 'mise exec gh@latest -- gh auth login --hostname github.com --git-protocol https --web' scripts/mise.zsh ||
    fail "GitHub CLI web authentication is missing"
grep -qF 'mise exec gh@latest -- gh auth setup-git --hostname github.com' scripts/mise.zsh ||
    fail "GitHub CLI git authentication setup is missing"

local __gh_config="home/.config/mise/conf.d/module.gh.toml"
local __mise_config="home/.config/mise/conf.d/module.mise.toml"
grep -qF 'final = [' "$__mise_config" ||
    fail "mise final bootstrap hook is missing"
grep -qF '"mise run mise:cleanup"' "$__mise_config" ||
    fail "mise stale-link cleanup is missing from the final hook"
grep -qF '"mise run mise:cleanup:inventory"' "$__mise_config" ||
    fail "mise cleanup inventory is missing from the final hook"
grep -qF '"mise fix"' "$__mise_config" ||
    fail "mise fix is missing from the final hook"
for __quiet_task in \
    "home/.config/mise/tasks/global-install-packages-all.sh" \
    "home/.config/mise/tasks/global-install-packages-npm.sh" \
    "home/.config/mise/tasks/global-install-packages-python.sh" \
    "home/.config/mise/tasks/global-install-packages-ruby.sh" \
    "home/.config/mise/tasks/lint-skill-index.zsh" \
    "home/.config/mise/tasks/ai/skills/evals/validate.zsh" \
    "scripts/tasks/fix.zsh"; do
    grep -qF '#MISE quiet=true' "$__quiet_task" ||
        fail "hook-invoked task is not quiet: $__quiet_task"
done
grep -qF '[bootstrap.hooks]' "$__gh_config" ||
    fail "GitHub module hook declaration is missing"
grep -qF "post-packages = 'gh extension install --force" "$__gh_config" ||
    fail "GitHub post-packages hook is missing"
grep -qF 'gh extension install --force "yusukebe/gh-markdown-preview"' "$__gh_config" ||
    fail "GitHub extension install is missing from the module hook"
if grep -qF 'gh extension list' "$__gh_config"; then
    fail "GitHub hook should force the extension update instead of checking first"
fi
[[ ! -e "home/.config/mise/tasks/bootstrap.sh" ]] ||
    fail "single-purpose bootstrap task should be removed"
if grep -qF 'tasks/bootstrap.sh' home/.config/mise/conf.d/module.mise.toml; then
    fail "removed bootstrap task is still deployed"
fi

local __work_dry_run
__work_dry_run="$(env -u MISE_ENV DOT_PROFILE=work MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true mise -C "$__root_dir" bootstrap --dry-run 2>&1)"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: system packages' ||
    fail "work dry run is missing package bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: repos' ||
    fail "work dry run is missing repository bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: dotfiles' ||
    fail "work dry run is missing dotfile bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: system defaults' ||
    fail "work dry run is missing macOS defaults"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: post-defaults hooks' ||
    fail "work dry run is missing macOS post-defaults maintenance"
print -r -- "$__work_dry_run" | grep -qF "killall Dock Finder SystemUIServer" ||
    fail "work dry run is missing macOS application restart maintenance"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: tools' ||
    fail "work dry run is missing tool bootstrap"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: post-packages hooks' ||
    fail "work dry run is missing the GitHub post-packages hook"
print -r -- "$__work_dry_run" | grep -qF 'gh extension install --force "yusukebe/gh-markdown-preview"' ||
    fail "work dry run is missing the GitHub extension install"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap packages upgrade --yes' ||
    fail "work dry run is missing package upgrade maintenance"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap packages prune --yes' ||
    fail "work dry run is missing package prune maintenance"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: post-tools hooks' ||
    fail "work dry run is missing tool maintenance hooks"
print -r -- "$__work_dry_run" | grep -qF 'mise upgrade --prune' ||
    fail "work dry run is missing tool upgrade maintenance"
print -r -- "$__work_dry_run" | grep -qF 'mise reshim -f' ||
    fail "work dry run is missing tool reshim maintenance"
print -r -- "$__work_dry_run" | grep -qF 'mise bootstrap: final hooks' ||
    fail "work dry run is missing the final hook"
print -r -- "$__work_dry_run" | grep -qF 'mise run mise:cleanup' ||
    fail "work dry run is missing stale-link cleanup"
print -r -- "$__work_dry_run" | grep -qF 'mise run mise:cleanup:inventory' ||
    fail "work dry run is missing cleanup inventory"
print -r -- "$__work_dry_run" | grep -qF 'mise fix' ||
    fail "work dry run is missing mise fix"
local __cleanup_line="$(print -r -- "$__work_dry_run" | grep -nF "mise run mise:cleanup'" | cut -d: -f1)"
local __inventory_line="$(print -r -- "$__work_dry_run" | grep -nF "mise run mise:cleanup:inventory'" | cut -d: -f1)"
local __fix_line="$(print -r -- "$__work_dry_run" | grep -nF 'mise fix' | cut -d: -f1)"
(( __inventory_line < __cleanup_line && __cleanup_line < __fix_line )) ||
    fail "cleanup inventory, cleanup, and mise fix order is incorrect"
local __personal_packages
__personal_packages="$(env -u MISE_ENV DOT_PROFILE=personal MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true mise -C "$__root_dir" bootstrap packages status 2>&1)"
print -r -- "$__personal_packages" | grep -qE '^brew-cask +(discord|softraid|whatsapp)' ||
    fail "personal profile does not include personal-only packages"

local __work_packages
__work_packages="$(env -u MISE_ENV DOT_PROFILE=work MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
    MISE_ENV_CONF_D=true mise -C "$__root_dir" bootstrap packages status 2>&1)"
if print -r -- "$__work_packages" | grep -qE '^brew-cask +(discord|softraid|whatsapp)'; then
    fail "work profile includes personal-only packages"
fi

local __fixture_dir="$(mktemp -d)"
local __stub_dir="$__fixture_dir/bin"
local __installer_dir="$__fixture_dir/installer"
local __log_file="$__fixture_dir/mise.log"
local __output_file="$__fixture_dir/output.log"
mkdir -p "$__stub_dir" "$__installer_dir"

cat > "$__stub_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${MISE_CONFIG_DIR:-}" == "${MISE_EXPECT_CONTEXT}/home/.config/mise" ]] || exit 91
[[ "${MISE_ENV_CONF_D:-}" == "true" ]] || exit 92
[[ -z "${MISE_ENV:-}" ]] || exit 93
[[ -z "${MISE_AUTO_ENV:-}" ]] || exit 96

if [[ "$*" == "--version" ]]; then
    printf '%s\n' '2026.10.7 macos-arm64 (fixture)'
    exit 0
fi
printf '%s\n' "${*:-<none>}" >> "$MISE_CALL_LOG"
if [[ "$*" == *"bootstrap --yes"* ]]; then
    [[ "${MISE_STUB_BOOTSTRAP_STATUS:-ok}" == "ok" ]] || exit 94
fi
if [[ "$*" == *"gh auth status --hostname github.com"* ]]; then
    [[ "${MISE_STUB_GH_AUTH_STATUS:-ok}" == "ok" ]] || exit 95
fi
EOF
chmod +x "$__stub_dir/mise"

cat > "$__installer_dir/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' 'mkdir -p "$HOME/.local/bin"' \
    'cp "$MISE_STUB_SOURCE" "$HOME/.local/bin/mise"' \
    'chmod +x "$HOME/.local/bin/mise"'
EOF
chmod +x "$__installer_dir/curl"

cat > "$__fixture_dir/run-mise.zsh" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

function _v_profile_is_valid { [[ "$1" == "work" || "$1" == "personal" ]] }
function _v_fmt_u { print -r -- "$@" }
function _v_color_fg { shift; print -r -- "$@" }
function _v_log_error { print -r -- "$@" >&2 }
function _v_log_info { print -r -- "$@" }
function _v_log_ok { print -r -- "$@" }
function _v_log_warn { print -r -- "$@" }
function _v_confirm_proceed {
    typeset -g __proceed="$([[ "$__fixture_confirm" == "yes" ]] && print true || print false)"
}

function {
    local __dotfiles_dir="$FIXTURE_ROOT"
    local __install_mise_dev_tools=true
    local __fixture_confirm="${FIXTURE_CONFIRM:-no}"
    source "$FIXTURE_ROOT/scripts/mise.zsh"
}
EOF
chmod +x "$__fixture_dir/run-mise.zsh"

local __run_fixture_status
run_fixture() {
    local __path="$1"
    shift
    local __fixture_bootstrap_status="${MISE_STUB_BOOTSTRAP_STATUS:-ok}"
    local __fixture_home="${FIXTURE_HOME:-$__fixture_dir/home}"
    local __fixture_cwd="${FIXTURE_CWD:-$__root_dir}"
    : > "$__log_file"
    if (
        cd "$__fixture_cwd"
        env -u MISE_ENV HOME="$__fixture_home" PATH="$__path" \
            FIXTURE_CONFIRM="${FIXTURE_CONFIRM:-no}" \
            FIXTURE_ROOT="$__root_dir" MISE_CALL_LOG="$__log_file" MISE_EXPECT_CONTEXT="$__root_dir" \
            MISE_STUB_BOOTSTRAP_STATUS="$__fixture_bootstrap_status" \
            MISE_STUB_GH_AUTH_STATUS="${MISE_STUB_GH_AUTH_STATUS:-ok}" \
            MISE_STUB_SOURCE="$__stub_dir/mise" "$@" /bin/zsh "$__fixture_dir/run-mise.zsh"
    ) > "$__output_file" 2>&1; then
        __run_fixture_status=0
    else
        __run_fixture_status=$?
    fi
}

local __expected_file="$__fixture_dir/expected.log"
mkdir -p "$__fixture_dir/home"

FIXTURE_CONFIRM=no run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "declined confirmation failed"
[[ ! -s "$__log_file" ]] || fail "declined confirmation ran mise commands"

FIXTURE_CONFIRM=yes MISE_STUB_BOOTSTRAP_STATUS=fail run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -ne 0 ]] || fail "bootstrap failure was ignored"
if grep -qF -- '-C '"$__root_dir"' bootstrap packages upgrade --yes' "$__log_file"; then
    fail "maintenance ran after bootstrap failure"
fi

FIXTURE_CONFIRM=yes run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "successful lifecycle fixture failed"
cat > "$__expected_file" <<EOF
-C $__root_dir self-update --yes
exec gh@latest -- gh auth status --hostname github.com
-C $__root_dir bootstrap --yes
EOF
diff -u "$__expected_file" "$__log_file" || fail "successful lifecycle order is incorrect"
grep -qF "Mise self-update complete" "$__output_file" ||
    fail "self-update completion log is missing"
grep -qF "Mise bootstrap and maintenance complete" "$__output_file" ||
    fail "bootstrap completion log is missing"
if grep -qF "Mise updated" "$__output_file"; then
    fail "self-update log claims that mise changed when the command may be a no-op"
fi
if grep -qF "Mise maintenance complete" "$__output_file"; then
    fail "bootstrap completion is logged twice"
fi

FIXTURE_CONFIRM=yes MISE_STUB_GH_AUTH_STATUS=fail run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "GitHub CLI authentication fixture failed"
grep -qF -- 'exec gh@latest -- gh auth login --hostname github.com --git-protocol https --web' "$__log_file" ||
    fail "GitHub CLI login was not attempted"
grep -qF -- 'exec gh@latest -- gh auth setup-git --hostname github.com' "$__log_file" ||
    fail "GitHub CLI git setup was not attempted"

local __external_mise_home="$__fixture_dir/external-mise-home"
mkdir -p "$__external_mise_home"
FIXTURE_HOME="$__external_mise_home" FIXTURE_CONFIRM=yes run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "external mise installation fixture failed"
local __stable_mise="$__external_mise_home/.local/bin/mise"
[[ -L "$__stable_mise" ]] || fail "external mise installation did not create a stable symlink"
[[ "$(readlink "$__stable_mise")" == "$(realpath "$__stub_dir/mise")" ]] ||
    fail "stable mise symlink points to the wrong existing installation"
[[ -x "$__stable_mise" ]] || fail "stable mise symlink is not executable"
grep -qF -- '-C '"$__root_dir"' self-update --yes' "$__log_file" ||
    fail "external mise installation did not invoke the stable path"
env MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
    MISE_EXPECT_CONTEXT="$__root_dir" MISE_CALL_LOG="$__log_file" \
    "$__stable_mise" --stable-path-probe
grep -qF -- '--stable-path-probe' "$__log_file" ||
    fail "stable mise path did not invoke the existing mise installation"

local __relative_fixture_dir="$__fixture_dir/relative"
mkdir -p "$__relative_fixture_dir/bin"
cp "$__stub_dir/mise" "$__relative_fixture_dir/bin/mise"
FIXTURE_CWD="$__relative_fixture_dir" FIXTURE_HOME="$__relative_fixture_dir/home" FIXTURE_CONFIRM=yes \
    run_fixture "./bin:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "relative mise installation fixture failed"
[[ -L "$__relative_fixture_dir/home/.local/bin/mise" ]] ||
    fail "relative mise installation did not create a stable symlink"
[[ "$(readlink "$__relative_fixture_dir/home/.local/bin/mise")" == "$(realpath "$__relative_fixture_dir/bin/mise")" ]] ||
    fail "relative mise stable symlink was not resolved to an absolute physical path"

local __unrelated_executable_home="$__fixture_dir/unrelated-executable-home"
mkdir -p "$__unrelated_executable_home/.local/bin"
printf '%s\n' 'unrelated executable' > "$__unrelated_executable_home/.local/bin/mise"
chmod +x "$__unrelated_executable_home/.local/bin/mise"
FIXTURE_HOME="$__unrelated_executable_home" FIXTURE_CONFIRM=yes \
    run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -ne 0 ]] || fail "unrelated stable executable was accepted"
[[ -f "$__unrelated_executable_home/.local/bin/mise" ]] ||
    fail "unrelated stable executable was removed"
grep -qF 'unrelated executable' "$__unrelated_executable_home/.local/bin/mise" ||
    fail "unrelated stable executable was replaced"

local __directory_home="$__fixture_dir/directory-home"
mkdir -p "$__directory_home/.local/bin/mise"
FIXTURE_HOME="$__directory_home" FIXTURE_CONFIRM=yes \
    run_fixture "$__stub_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -ne 0 ]] || fail "stable mise directory was accepted"
[[ -d "$__directory_home/.local/bin/mise" ]] ||
    fail "stable mise directory was removed"

FIXTURE_CONFIRM=yes run_fixture "$__installer_dir:/usr/bin:/bin"
[[ "$__run_fixture_status" -eq 0 ]] || fail "newly installed mise fixture failed"
if grep -qF -- '-C '"$__root_dir"' self-update --yes' "$__log_file"; then
    fail "newly installed mise self-updated during the same run"
fi
grep -qF -- '-C '"$__root_dir"' bootstrap --yes' "$__log_file" ||
    fail "newly installed mise did not reach bootstrap"

rm -rf "$__fixture_dir"
trap - EXIT

echo "Mise bootstrap lifecycle passed."
