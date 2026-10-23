#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing gh:auth:login task..."

local __task="home/.config/mise/tasks/gh/auth/login.zsh"
[[ -x "$__task" ]] || fail "GitHub auth task is missing or not executable"
zsh -n "$__task" || fail "GitHub auth task has syntax errors"
grep -qF '#MISE raw=true' "$__task" || fail "GitHub auth task must use raw terminal mode"
grep -qF '#USAGE flag "--hostname <hostname>"' "$__task" ||
    fail "GitHub auth hostname Usage is missing"
grep -qF 'default="github.com"' "$__task" || fail "GitHub auth hostname default is missing"
if grep -qF 'gh auth setup-git' "$__task"; then
    fail "GitHub auth task must not configure Git credentials"
fi
for __pr_task in sync stack stack-sync; do
    grep -qF 'ensureGitHubAuth(hostname)' "home/.config/mise/tasks/pr/$__pr_task.ts" ||
        fail "pr:$__pr_task does not authenticate its resolved hostname"
    if grep -qF '//MISE depends=["gh:auth:login"]' "home/.config/mise/tasks/pr/$__pr_task.ts"; then
        fail "pr:$__pr_task still uses a static GitHub authentication dependency"
    fi
done
if grep -qF 'gh:auth:login' home/.config/mise/tasks/pr/review-watch.ts \
    home/.config/mise/tasks/gh/download/file.sh; then
    fail "public or review-watch tasks force GitHub authentication"
fi
grep -qF '"~/.config/mise/tasks/gh/auth/login.zsh" = { source = "~/dev/personal/dot/home/.config/mise/tasks/gh/auth/login.zsh", mode = "symlink" }' \
    home/.config/mise/conf.d/mise.toml ||
    fail "GitHub auth task is not deployed by the mise control plane"

local __fixture_dir="$__root_dir/.agents/projects.local/issue-61-mise-bootstrap/tmp/gh-auth-test.$$"
local __bin_dir="$__fixture_dir/bin"
local __log_file="$__fixture_dir/gh.log"
local __state_file="$__fixture_dir/authenticated"
mkdir -p "$__bin_dir"
trap 'rm -rf -- "$__fixture_dir"' EXIT

cat > "$__bin_dir/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GH_AUTH_LOG"
if [[ "$*" == *"gh auth status"* ]]; then
    [[ -f "$GH_AUTH_STATE" && "${GH_AUTH_VERIFY_FAIL:-false}" != true ]]
    exit $?
fi
if [[ "$*" == *"gh auth login"* ]]; then
    [[ "${GH_AUTH_LOGIN_FAIL:-false}" != true ]] || exit 17
    touch "$GH_AUTH_STATE"
    exit 0
fi
exit 99
EOF
chmod +x "$__bin_dir/mise"

env PATH="$__bin_dir:$PATH" GH_AUTH_LOG="$__log_file" GH_AUTH_STATE="$__state_file" \
    usage_hostname=github.example zsh "$__task"
grep -qF 'gh auth status --hostname github.example' "$__log_file" ||
    fail "custom hostname was not passed to the status check"
grep -qF 'gh auth login --hostname github.example --git-protocol https --web' "$__log_file" ||
    fail "web login was not attempted"
grep -qF 'gh auth status --hostname github.example' "$__log_file" ||
    fail "post-login status was not checked"
if grep -qF 'gh auth setup-git' "$__log_file"; then
    fail "authentication configured Git credentials"
fi

: > "$__log_file"
env PATH="$__bin_dir:$PATH" GH_AUTH_LOG="$__log_file" GH_AUTH_STATE="$__state_file" \
    usage_hostname=github.example zsh "$__task"
[[ "$(wc -l < "$__log_file" | tr -d ' ')" == 1 ]] ||
    fail "already-authenticated task performed extra login work"

rm -f "$__state_file"
if env PATH="$__bin_dir:$PATH" GH_AUTH_LOG="$__log_file" GH_AUTH_STATE="$__state_file" \
    GH_AUTH_LOGIN_FAIL=true usage_hostname=github.example zsh "$__task"; then
    fail "failed login was reported as successful"
fi

echo "gh:auth:login task passed."
