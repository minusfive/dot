#!/usr/bin/env zsh

set -euo pipefail

typeset -g __root_dir="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$__root_dir/tests/scripts/mise_test_helpers.zsh"

fail() {
    print -u2 -- "FAIL: $1"
    exit 1
}

assert_no_fixture() {
    local __root="$1"
    local __name="$2"
    [[ -z "$(find "$__root" -mindepth 1 -maxdepth 1 -name "mise-${__name}.*" -print -quit)" ]] ||
        fail "fixture helper mutated $__root"
}

local __requested_tmp_root="${TEST_TMPDIR:-${TMPDIR:-/tmp}}"
local __test_tmp_root
__test_tmp_root="$(
    TMPDIR="$__requested_tmp_root" test_fixture_dir mise-helper
)" || fail "could not create helper test directory"
trap 'rm -rf -- "$__test_tmp_root"' EXIT

local __fake_bin="$__test_tmp_root/bin"
local __prunable_root="$__test_tmp_root/prunable"
local __missing_root="$__test_tmp_root/missing"
local __safe_fixture_root="$__test_tmp_root/safe-fixtures"
local __existing_worktree="$__test_tmp_root/existing-worktree"
local __existing_prunable_root="$__test_tmp_root/existing-prunable"
mkdir -p "$__fake_bin" "$__safe_fixture_root" "$__existing_worktree" "$__existing_prunable_root"
[[ ! -e "$__prunable_root" && ! -e "$__missing_root" ]] ||
    fail "missing worktree metadata paths unexpectedly exist"

cat >| "$__fake_bin/git" <<'EOF'
#!/usr/bin/env zsh

case "$GIT_HELPER_TEST_MODE" in
    list)
        cat <<EOF_LIST
worktree $GIT_HELPER_TEST_REPOSITORY
HEAD 0000000000000000000000000000000000000000
branch refs/heads/main

worktree $GIT_HELPER_TEST_PRUNABLE
HEAD 0000000000000000000000000000000000000000
prunable gitdir file points to non-existent location

worktree $GIT_HELPER_TEST_MISSING
HEAD 0000000000000000000000000000000000000000
prunable gitdir file points to non-existent location
EOF_LIST
        ;;
    error)
        exit 1
        ;;
    reject)
        print -r -- "worktree $GIT_HELPER_TEST_REPOSITORY"
        print -r -- "worktree $GIT_HELPER_TEST_WORKTREE"
        ;;
    prunable-reject)
        print -r -- "worktree $GIT_HELPER_TEST_REPOSITORY"
        print -r -- "worktree $GIT_HELPER_TEST_EXISTING_PRUNABLE"
        print -r -- "prunable gitdir file points to non-existent location"
        ;;
esac
EOF
chmod +x "$__fake_bin/git"

cat >| "$__fake_bin/mktemp" <<'EOF'
#!/usr/bin/env zsh

[[ "$1" == "-d" && "$2" == *XXXXXX ]] || exit 2
local __path="${2/XXXXXX/${PPID}-${RANDOM}}"
mkdir -p "$__path" || exit 1
print -r -- "$__path"
EOF
chmod +x "$__fake_bin/mktemp"

local __fixture
local __output
local __repo="$__root_dir"
local __reject_name="helper-reject-$$"
local __worktree_reject_name="helper-worktree-reject-$$"
local __error_name="helper-error-$$"
local __path_env=(
    "PATH=$__fake_bin:$PATH"
    "GIT_HELPER_TEST_REPOSITORY=$__repo"
    "GIT_HELPER_TEST_PRUNABLE=$__prunable_root"
    "GIT_HELPER_TEST_MISSING=$__missing_root"
    "GIT_HELPER_TEST_WORKTREE=$__existing_worktree"
    "GIT_HELPER_TEST_EXISTING_PRUNABLE=$__existing_prunable_root"
    "GIT_HELPER_TEST_MODE=list"
    "TMPDIR=$__safe_fixture_root"
)
__output="$(
    env "${__path_env[@]}" zsh -c '
        source "$1"
        test_fixture_dir helper-safety
    ' zsh "$__root_dir/tests/scripts/mise_test_helpers.zsh"
)" || {
    print -u2 -- "$__output"
    fail "fixture helper rejected missing or prunable worktrees"
}
[[ -d "$__output" ]] || fail "fixture helper did not create a fixture"
[[ "$__output" == "$__safe_fixture_root"/mise-helper-safety.* ]] ||
    fail "fixture helper created a fixture outside the safe root"
rm -rf -- "$__output"

if env "${__path_env[@]}" TMPDIR="$__repo/tests" \
    GIT_HELPER_TEST_MODE=reject \
    zsh -c '
        source "$1"
        test_fixture_dir "$2"
    ' zsh "$__root_dir/tests/scripts/mise_test_helpers.zsh" "$__reject_name" >/dev/null 2>&1; then
    fail "fixture helper accepted a repository path"
fi
assert_no_fixture "$__repo/tests" "$__reject_name"

if env "${__path_env[@]}" TMPDIR="$__existing_worktree" \
    GIT_HELPER_TEST_MODE=reject \
    zsh -c '
        source "$1"
        test_fixture_dir "$2"
    ' zsh "$__root_dir/tests/scripts/mise_test_helpers.zsh" "$__worktree_reject_name" >/dev/null 2>&1; then
    fail "fixture helper accepted an existing worktree path"
fi
assert_no_fixture "$__existing_worktree" "$__worktree_reject_name"

local __prunable_reject_name="helper-prunable-reject-$$"
if env "${__path_env[@]}" TMPDIR="$__existing_prunable_root" \
    GIT_HELPER_TEST_MODE=prunable-reject \
    zsh -c '
        source "$1"
        test_fixture_dir "$2"
    ' zsh "$__root_dir/tests/scripts/mise_test_helpers.zsh" "$__prunable_reject_name" >/dev/null 2>&1; then
    fail "fixture helper accepted an existing prunable worktree path"
fi
assert_no_fixture "$__existing_prunable_root" "$__prunable_reject_name"

if env "${__path_env[@]}" GIT_HELPER_TEST_MODE=error \
    zsh -c '
        source "$1"
        test_fixture_dir "$2"
    ' zsh "$__root_dir/tests/scripts/mise_test_helpers.zsh" "$__error_name" >/dev/null 2>&1; then
    fail "fixture helper accepted a worktree-list command error"
fi
assert_no_fixture "$__safe_fixture_root" "$__error_name"
