#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing git:auth:setup task..."

local __task="home/.config/mise/tasks/git/auth/setup.zsh"
local __domains_helper="home/.config/mise/utils/git-domains.zsh"
[[ -x "$__task" ]] || fail "Git auth setup task is missing or not executable"
[[ -f "$__domains_helper" ]] || fail "Git domains helper is missing"
zsh -n "$__task" || fail "Git auth setup task has syntax errors"
zsh -n "$__domains_helper" || fail "Git domains helper has syntax errors"
grep -qF '#USAGE flag "--profile <profile>"' "$__task" ||
    fail "Git auth profile Usage is missing"
grep -qF 'choices "work" "personal"' "$__task" ||
    fail "Git auth profile Usage does not limit profile choices"
grep -qF '#USAGE flag "--hostname <hostname>"' "$__task" ||
    fail "Git auth hostname Usage is missing"
grep -qF 'GH_CONFIG_DIR=' "$__task" || fail "Git auth setup must select a profile GH_CONFIG_DIR"
grep -qF 'GIT_CONFIG_GLOBAL=' "$__task" || fail "Git auth setup must select a profile Git config"
grep -qF 'gh auth setup-git --hostname' "$__task" ||
    fail "Git auth setup must use host-scoped GitHub CLI setup"
if grep -qF 'gh auth setup-git "$__hostname"' "$__task"; then
    fail "Git auth setup must not configure all authenticated hosts"
fi
grep -qF '"~/.config/mise/tasks/git/auth/setup.zsh"' \
    home/.config/mise/conf.d/module.mise.toml ||
    fail "Git auth setup task is not deployed by the mise control plane"
grep -qF '"~/.config/mise/utils/git-domains.zsh"' \
    home/.config/mise/conf.d/module.mise.toml ||
    fail "Git domains helper is not deployed by the mise control plane"
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" tasks info git:auth:setup
)"
print -r -- "$__task_info" | grep -qF "Task: git:auth:setup" ||
    fail "Git auth setup task is not discoverable"
local __task_help="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" run git:auth:setup --help
)"
print -r -- "$__task_help" | grep -qF 'possible values: work, personal' ||
    fail "Git auth profile choices are not discoverable"

local __fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/git-auth-setup.XXXXXX")"
local __home="$__fixture_dir/home"
local __bin="$__fixture_dir/bin"
local __log="$__fixture_dir/mise.log"
local __helper_log="$__fixture_dir/helper.log"
local __global_config="$__fixture_dir/global.gitconfig"
local __personal_config="$__home/dev/personal/.gitconfig"
local __work_config="$__home/dev/work/.gitconfig"
local __personal_domains="$__home/dev/personal/.domains"
local __work_domains="$__home/dev/work/.domains"
local __gh_config_personal="$__home/.config/gh/personal"
local __gh_config_work="$__home/.config/gh/work"
mkdir -p "$__bin" "$__home/dev/personal" "$__home/dev/work" \
    "$__gh_config_personal" "$__gh_config_work"
trap 'rm -rf -- "$__fixture_dir"' EXIT
print -r -- "github.com" > "$__personal_domains"
print -r -- "github.enterprise.example" > "$__work_domains"
printf '[user]\n name = sentinel\n' > "$__global_config"
local __generated_gh="$__bin/generated-gh"
local __generic_helper="$__bin/inherited-helper"
cat > "$__bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'GH_CONFIG_DIR=%s\nGIT_CONFIG_GLOBAL=%s\nARGS=%s\n' \
    "$GH_CONFIG_DIR" "$GIT_CONFIG_GLOBAL" "$*" >> "$GIT_AUTH_LOG"

if [[ "$*" == *"gh auth status"* ]]; then
    [[ "${GIT_AUTH_FAIL:-false}" != true ]]
    exit $?
fi

if [[ "$*" == *"gh auth setup-git"* ]]; then
    [[ "${GIT_AUTH_SETUP_FAIL:-false}" != true ]] || exit 17
    hostname=""
    while (($#)); do
        if [[ "$1" == "--hostname" && $# -ge 2 ]]; then
            hostname="$2"
            shift 2
        else
            shift
        fi
    done
    git config --file "$GIT_CONFIG_GLOBAL" --add \
        "credential.https://$hostname.helper" "!$GIT_AUTH_GENERATED_GH auth git-credential"
    exit 0
fi

exit 99
EOF
cat > "$__generated_gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
cat > "$__generic_helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'inherited\n' >> "$GIT_AUTH_HELPER_LOG"
EOF
cat > "$__bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s\n' "$GH_CONFIG_DIR" "$*" >> "$GIT_AUTH_HELPER_LOG"
EOF
chmod +x "$__bin/mise" "$__generated_gh" "$__generic_helper" "$__bin/gh"
export GIT_AUTH_LOG="$__log" GIT_AUTH_HELPER_LOG="$__helper_log"
export GIT_AUTH_GENERATED_GH="$__generated_gh"
git config --file "$__personal_config" --add credential.helper "$__generic_helper"

if env HOME="$__home" PATH="$__bin:$PATH" zsh "$__task" > /dev/null 2>&1; then
    fail "setup task accepted missing profile and hostname flags"
fi
if env HOME="$__home" PATH="$__bin:$PATH" usage_profile=personal zsh "$__task" > /dev/null 2>&1; then
    fail "setup task accepted a missing hostname"
fi
local __profile_backup="$__fixture_dir/personal.gitconfig"
mv "$__personal_config" "$__profile_backup"
ln -s "$__global_config" "$__personal_config"
if env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    usage_profile=personal usage_hostname=github.com zsh "$__task" > /dev/null 2>&1; then
    fail "setup task accepted a symlinked profile config"
fi
[[ "$(cat "$__global_config")" == $'[user]\n name = sentinel' ]] ||
    fail "setup task changed the symlink target"
rm "$__personal_config"
mv "$__profile_backup" "$__personal_config"

env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    usage_profile=personal usage_hostname=GitHub.com zsh "$__task"

grep -qF "GH_CONFIG_DIR=$__gh_config_personal" "$__log" ||
    fail "personal GH_CONFIG_DIR was not selected"
grep -qF "GIT_CONFIG_GLOBAL=$__personal_config" "$__log" ||
    fail "personal .gitconfig was not selected for gh setup"
grep -qF "ARGS=exec -C $__home/dev/personal gh@latest -- gh auth setup-git" "$__log" ||
    fail "GitHub setup did not run from the selected profile directory"
grep -qF "gh auth setup-git --hostname github.com" "$__log" ||
    fail "normalized hostname was not passed to host-scoped setup"
local __personal_helpers="$(
    git config --file "$__personal_config" --get-all credential.https://github.com.helper
)"
[[ "$__personal_helpers" == $'\n!GH_CONFIG_DIR="$HOME/.config/gh/personal" gh auth git-credential' ]] ||
    fail "personal helper list was not reset to the portable profile helper"
if [[ "$__personal_helpers" == *"$__generated_gh"* ]]; then
    fail "machine-specific GitHub CLI path remained in the profile helper"
fi
if printf 'protocol=https\nhost=github.com\n\n' |
    env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__personal_config" \
        GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 git credential fill >/dev/null 2>&1; then
    fail "fixture GitHub helper unexpectedly returned credentials"
fi
grep -qF "$__gh_config_personal|auth git-credential get" "$__helper_log" ||
    fail "personal Git credential helper did not use the personal authentication store"
if grep -qF "inherited" "$__helper_log"; then
    fail "inherited generic credential helper was not reset"
fi

env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    usage_profile=work usage_hostname=github.enterprise.example zsh "$__task"
grep -qF "GH_CONFIG_DIR=$__gh_config_work" "$__log" ||
    fail "work GH_CONFIG_DIR was not selected"
grep -qF "GIT_CONFIG_GLOBAL=$__work_config" "$__log" ||
    fail "work .gitconfig was not selected for gh setup"
grep -qF "ARGS=exec -C $__home/dev/work gh@latest -- gh auth setup-git" "$__log" ||
    fail "work GitHub setup did not run from the work profile directory"
git config --file "$__work_config" --get-all credential.https://github.enterprise.example.helper |
    grep -qF 'GH_CONFIG_DIR="$HOME/.config/gh/work" gh auth git-credential' ||
    fail "work profile helper was not written to the work profile file"
if git config --file "$__personal_config" --get credential.https://github.enterprise.example.helper >/dev/null 2>&1; then
    fail "work profile helper leaked into the personal profile file"
fi
grep -qF '[user]' "$__global_config" ||
    fail "Git auth setup modified the caller's global config"

local __before_unauthorized="$(wc -l < "$__log" | tr -d ' ')"
if env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    usage_profile=personal usage_hostname=attacker.example zsh "$__task"; then
    fail "unlisted hostname was accepted"
fi
[[ "$(wc -l < "$__log" | tr -d ' ')" == "$__before_unauthorized" ]] ||
    fail "unlisted hostname reached the GitHub CLI"

if env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_AUTH_FAIL=true usage_profile=personal usage_hostname=github.com zsh "$__task"; then
    fail "missing profile authentication was reported as successful"
fi
[[ "$(git config --file "$__personal_config" --get-all credential.https://github.com.helper | wc -l | tr -d ' ')" == 2 ]] ||
    fail "failed authentication changed the existing personal helper list"

local __helpers_before_setup_failure="$(
    git config --file "$__personal_config" --get-all credential.https://github.com.helper
)"
if env HOME="$__home" PATH="$__bin:$PATH" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_AUTH_SETUP_FAIL=true usage_profile=personal usage_hostname=github.com zsh "$__task"; then
    fail "failed native helper setup was reported as successful"
fi
[[ "$(git config --file "$__personal_config" --get-all credential.https://github.com.helper)" == \
    "$__helpers_before_setup_failure" ]] ||
    fail "failed native helper setup changed the profile helper list"

echo "git:auth:setup task passed."
