#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing tracked Git config policy..."

local __checker="$__root_dir/scripts/check-git-config.zsh"
local __domains_helper="$__root_dir/home/.config/mise/utils/git-domains.zsh"
[[ -x "$__checker" ]] || fail "Git config checker is missing or not executable"
[[ -f "$__domains_helper" ]] || fail "Git domains helper is missing"
zsh -n "$__checker" || fail "Git config checker has syntax errors"
zsh -n "$__domains_helper" || fail "Git domains helper has syntax errors"
grep -qF '["git_config_policy"]' "$__root_dir/hk.pkl" ||
    fail "Git config policy is not registered with hk"
grep -qF 'check = "scripts/check-git-config.zsh"' "$__root_dir/hk.pkl" ||
    fail "hk does not run the Git config checker"
source "$__domains_helper"

local __fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/git-config-check.XXXXXX")"
local __repo="$__fixture_dir/repo"
local __domains="$__repo/home/dev/personal/.domains"
local __config="$__repo/home/.config/git/config"
local __profile_config="$__repo/home/dev/personal/profile.gitconfig"
local __ignored_config="$__repo/home/.config/git/ignore"
mkdir -p "$__repo/home/dev/personal" "$__repo/home/.config/git"
trap 'rm -rf -- "$__fixture_dir"' EXIT
git init -q "$__repo"

printf ' # personal Git hosts\n\n GitHub.com. \n' > "$__domains"
cat > "$__config" <<'EOF'
[http "https://github.com"]
    sslVerify = true
[url "ssh://git@github.com/"]
    insteadOf = https://github.com/
    pushInsteadOf = git@github.com:
[include]
    path = "~/.config/delta/themes/catppuccin.gitconfig"
[includeIf "gitdir:~/dev/work/"]
    path = ~/dev/work/.gitconfig
[includeIf "gitdir:~/Notes/Work/"]
    path = ~/dev/work/.gitconfig
[includeIf "gitdir:~/dev/personal/"]
    path = ~/dev/personal/.gitconfig
[includeIf "gitdir:~/Notes/Personal/"]
    path = ~/dev/personal/.gitconfig
EOF
cat > "$__profile_config" <<'EOF'
[credential "https://sub.github.com"]
    useHttpPath
EOF
printf 'this is not Git config and must not be parsed\n' > "$__ignored_config"
git -C "$__repo" add home/dev/personal/.domains home/.config/git/config \
    home/dev/personal/profile.gitconfig home/.config/git/ignore

local __before_status="$(git -C "$__repo" status --porcelain)"
(
    cd "$__repo"
    zsh "$__checker"
)
[[ "$(git -C "$__repo" status --porcelain)" == "$__before_status" ]] ||
    fail "Git config checker changed the index or worktree"

git_domains_load "$__domains" || fail "valid domains list did not parse"
[[ "${git_domains[1]}" == "github.com" ]] || fail "hostname normalization changed"
git_domain_matches "API.GITHUB.COM." || fail "listed domain did not match its subdomain"
if git_domain_matches "github.com.attacker.example"; then
    fail "domain matching accepted a suffix spoof"
fi
[[ "$(git_domain_host_from_url "https://api.github.com/")" == "api.github.com" ]] ||
    fail "HTTPS host parsing failed"
[[ "$(git_domain_host_from_url "ssh://git@github.com/")" == "github.com" ]] ||
    fail "SSH host parsing failed"
[[ "$(git_domain_host_from_url "git@github.com:")" == "github.com" ]] ||
    fail "SCP-style host parsing failed"
if git_domain_host_from_url "https://github.com:443/" >/dev/null; then
    fail "URL host parsing accepted a port"
fi
if git_domain_host_from_url "https://github.com/work-repo" >/dev/null; then
    fail "URL host parsing accepted a repository path"
fi
if git_domain_host_from_url "git@github.com:work-repo" >/dev/null; then
    fail "SCP-style host parsing accepted a repository path"
fi

local __invalid_domains="$__fixture_dir/invalid.domains"
for __invalid_host in "https://github.com" "*.github.com" "github.com:443" \
    "github.com/path" "github.com # comment" "127.0.0.1" "127.1" "0x7f000001" \
    "bad..example" "bad_domain.example"; do
    printf '%s\n' "$__invalid_host" > "$__invalid_domains"
    if git_domains_load "$__invalid_domains"; then
        fail "invalid hostname format was accepted"
    fi
done
printf 'github.com\n GitHub.com.\n' > "$__invalid_domains"
if git_domains_load "$__invalid_domains"; then
    fail "duplicate normalized hostname was accepted"
fi
: > "$__invalid_domains"
if git_domains_load "$__invalid_domains"; then
    fail "empty domain list was accepted"
fi

run_failure() {
    local __expected_category="$1"
    local -a __expected_markers=("${@:2}")
    local __output
    if __output="$(cd "$__repo" && zsh "$__checker" 2>&1)"; then
        fail "tracked Git config policy accepted an invalid $__expected_category entry"
    fi
    print -r -- "$__output" | grep -qF "$__expected_category" ||
        fail "Git config checker did not identify the failing category"
    for __expected_marker in "${__expected_markers[@]}"; do
        if [[ -n "$__expected_marker" && "$__output" == *"$__expected_marker"* ]]; then
            fail "Git config checker printed a sensitive configuration value"
        fi
    done
    if [[ "$__output" == *"unapproved.example"* || "$__output" == *"github.com.attacker.example"* ]]; then
        fail "Git config checker printed a hostname"
    fi
}

cat > "$__profile_config" <<'EOF'
[include]
    path = ~/dev/SECRET_INCLUDE_PATH/.gitconfig
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "include" "SECRET_INCLUDE_PATH"

cat > "$__profile_config" <<'EOF'
[includeIf "gitdir:~/SECRET_INCLUDE_IF/"]
    path = ~/dev/SECRET_INCLUDE_PATH/.gitconfig
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "include" "SECRET_INCLUDE_IF" "SECRET_INCLUDE_PATH"

cat > "$__profile_config" <<'EOF'
[credential "https://github.com"
    useHttpPath = true
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "invalid Git config"

cat > "$__profile_config" <<'EOF'
[credential "https://unapproved.example"]
    helper = SUPER_SECRET_CREDENTIAL_FIXTURE
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" "SUPER_SECRET_CREDENTIAL_FIXTURE"

cat > "$__profile_config" <<'EOF'
[credential]
    helper = SUPER_SECRET_CREDENTIAL_FIXTURE
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" "SUPER_SECRET_CREDENTIAL_FIXTURE"

: > "$__profile_config"
git config --file "$__profile_config" --add \
    credential.https://github.com/work-repo.useHttpPath true
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" "work-repo"

: > "$__profile_config"
git config --file "$__profile_config" --add credential.https://github.com.helper ""
git config --file "$__profile_config" --add credential.https://github.com.helper \
    '!GH_CONFIG_DIR="$HOME/.config/gh/personal" gh auth git-credential'
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" 'GH_CONFIG_DIR="$HOME/.config/gh/personal"'

: > "$__profile_config"
git config --file "$__profile_config" --add credential.https://github.com.helper \
    '!GH_CONFIG_DIR="$HOME/.config/gh/work" gh auth git-credential'
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" 'GH_CONFIG_DIR="$HOME/.config/gh/work"'

: > "$__profile_config"
git config --file "$__profile_config" --add credential.https://github.com.helper \
    '/opt/homebrew/bin/gh auth git-credential'
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" "/opt/homebrew/bin/gh"

cat > "$__profile_config" <<'EOF'
[credential "https://github.com"]
    username = work-user
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "identity" "work-user"

: > "$__profile_config"
git config --file "$__profile_config" --add credential.https://github.com.useHttpPath \
    WORK_PROFILE_MARKER
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "credential" "WORK_PROFILE_MARKER"

cat > "$__profile_config" <<'EOF'
[http "https://github.com"]
    extraHeader = Authorization: SUPER_SECRET_HTTP_FIXTURE
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "HTTP" "SUPER_SECRET_HTTP_FIXTURE"

: > "$__profile_config"
git config --file "$__profile_config" --add http.https://github.com.sslVerify false
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "HTTP" "false"

: > "$__profile_config"
git config --file "$__profile_config" --add http.https://github.com.sslVerify \
    SUPER_SECRET_HTTP_FIXTURE
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "HTTP" "SUPER_SECRET_HTTP_FIXTURE"

cat > "$__profile_config" <<'EOF'
[http "https://github.com.attacker.example"]
    extraHeader = SUPER_SECRET_HTTP_FIXTURE
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "HTTP" "SUPER_SECRET_HTTP_FIXTURE"

cat > "$__profile_config" <<'EOF'
[url "https://github.com/"]
    insteadOf = https://unapproved.example/
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "URL rewrite" "https://unapproved.example/"

cat > "$__profile_config" <<'EOF'
[url "https://unapproved.example/"]
    pushInsteadOf = https://github.com/
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "URL rewrite" "https://github.com/"

cat > "$__profile_config" <<'EOF'
[url "https://github.com/work-org/"]
    insteadOf = https://github.com/
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "URL rewrite" "work-org"

cat > "$__profile_config" <<'EOF'
[url "ssh://git@github.com/"]
    insteadOf = https://github.com/work-org/
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "URL rewrite" "work-org"

cat > "$__profile_config" <<'EOF'
[remote "work"]
    url = https://work-token@github.com/work-org/repository
    pushurl = https://work-token@github.com/work-org/repository
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "remote URL" "work-token"

cat > "$__profile_config" <<'EOF'
[user]
    name = work-user
    email = work@example.test
EOF
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "identity" "work@example.test"

local __host_named_config="$__repo/home/dev/personal/unapproved.example.gitconfig"
mkdir -p "$(dirname "$__host_named_config")"
git config --file "$__host_named_config" --add credential.https://unapproved.example.helper \
    SUPER_SECRET_HELPER_FIXTURE
git -C "$__repo" add home/dev/personal/unapproved.example.gitconfig
run_failure "credential" "unapproved.example"

local __outside_config="$__fixture_dir/outside.gitconfig"
printf '[credential "https://unapproved.example"]\n helper = hidden\n' > "$__outside_config"
rm "$__profile_config"
ln -s "$__outside_config" "$__profile_config"
git -C "$__repo" add home/dev/personal/profile.gitconfig
run_failure "Git config source"

git -C "$__repo" rm --cached -q home/dev/personal/.domains
local __missing_manifest_output
if __missing_manifest_output="$(cd "$__repo" && zsh "$__checker" 2>&1)"; then
    fail "Git config checker accepted an untracked personal domain manifest"
fi
print -r -- "$__missing_manifest_output" | grep -qF "tracked personal domain manifest" ||
    fail "Git config checker did not report missing tracked domain ownership"

local __outside_domains="$__fixture_dir/outside.domains"
printf 'github.com\n' > "$__outside_domains"
rm "$__domains"
ln -s "$__outside_domains" "$__domains"
git -C "$__repo" add home/dev/personal/.domains
local __symlink_manifest_output
if __symlink_manifest_output="$(cd "$__repo" && zsh "$__checker" 2>&1)"; then
    fail "Git config checker accepted a symlinked personal domain manifest"
fi
print -r -- "$__symlink_manifest_output" | grep -qF "symlink" ||
    fail "Git config checker did not report the symlinked domain manifest"

echo "tracked Git config policy passed."
