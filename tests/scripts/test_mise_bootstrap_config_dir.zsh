#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise bootstrap config-dir contract..."

local __fixture_dir
__fixture_dir="$(test_fixture_dir config-dir)"
[[ -n "$__fixture_dir" && -d "$__fixture_dir" ]] ||
    fail "could not create fixture directory"

local __fixture_home="$__fixture_dir/home"
local __fixture_source="$__fixture_dir/dotfiles-source"
local __fixture_checkout="$__fixture_home/.dotfiles"
local __fixture_config="$__fixture_home/.config/mise"
local __fixture_external_config="$__fixture_dir/held-config"
local __fixture_git_config="$__fixture_dir/gitconfig"
local __fixture_origin="https://github.com/minusfive/dot.git"
local __fixture_log="$__fixture_dir/command.log"
local __fixture_work="$__fixture_dir/work"
local __signal_probe="${CONFIG_DIR_SIGNAL_PROBE:-0}"
local __script_path
__script_path="$(realpath "$0")"

cleanup_fixture() {
    local __status
    if (( $# > 0 )); then
        __status="$1"
    else
        __status="$?"
    fi
    trap - EXIT INT TERM
    rm -rf -- "$__fixture_dir"
    exit "$__status"
}

trap 'cleanup_fixture "$?"' EXIT
trap 'trap - EXIT INT TERM; cleanup_fixture 130' INT
trap 'trap - EXIT INT TERM; cleanup_fixture 143' TERM

fixture_git() {
    env -i \
        PATH="$PATH" \
        HOME="$__fixture_home" \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL="$__fixture_git_config" \
        git "$@"
}

mkdir -p \
    "$__fixture_source/setup/mise/conf.d" \
    "$__fixture_source/.config/kitty" \
    "$__fixture_home/.config" \
    "$__fixture_dir/data" \
    "$__fixture_dir/state" \
    "$__fixture_dir/cache" \
    "$__fixture_dir/mise-tmp" \
    "$__fixture_dir/system-config" \
    "$__fixture_work"

export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL="$__fixture_git_config"

if [[ "$__signal_probe" == 1 ]]; then
    print -r -- "$__fixture_dir" >| "$CONFIG_DIR_SIGNAL_PROBE_READY"
    while :; do
        sleep 1 || true
    done
fi

fixture_git -C "$__fixture_source" init -q -b main
fixture_git -C "$__fixture_source" config user.email test@example.com
fixture_git -C "$__fixture_source" config user.name "mise test"
fixture_git -C "$__fixture_source" config commit.gpgsign false
fixture_git -C "$__fixture_source" remote add origin "$__fixture_origin"

cat >| "$__fixture_source/setup/mise/config.toml" <<'EOF_CONFIG'
[dotfiles]
"~/.config/kitty" = { mode = "symlink" }

[bootstrap.directories."~/.config/config-dir-contract"]
mode = "0755"

[bootstrap.files."~/.config/config-dir-contract/managed.txt"]
content = "managed-v1\n"

[tasks.bootstrap]
run = 'printf "%s" "{{ mise_config_dir }}" > "$HOME/config-dir-seen"'
EOF_CONFIG
cat >| "$__fixture_source/setup/mise/miserc.toml" <<'EOF_MISERC'
env = ["work"]
EOF_MISERC
cat >| "$__fixture_source/setup/mise/config.work.toml" <<'EOF_WORK'
[dotfiles]
"~/.work-marker" = {}
EOF_WORK
cat >| "$__fixture_source/setup/mise/config.personal.toml" <<'EOF_PERSONAL'
[dotfiles]
"~/.personal-marker" = {}
EOF_PERSONAL
cat >| "$__fixture_source/setup/mise/conf.d/zsh.toml" <<'EOF_ZSH'
[dotfiles]
"~/.zshrc" = {}
EOF_ZSH
printf '%s\n' work >| "$__fixture_source/.work-marker"
printf '%s\n' personal >| "$__fixture_source/.personal-marker"
printf '%s\n' 'export ZSH=1' >| "$__fixture_source/.zshrc"
printf '%s\n' 'font_size 12' >| "$__fixture_source/.config/kitty/kitty.conf"

fixture_git -C "$__fixture_source" add .
fixture_git -C "$__fixture_source" commit -qm initial

# Keep the fixture local while preserving the exact URL that mise validates as origin.
fixture_git config --file "$__fixture_git_config" \
    "url.$__fixture_source.insteadOf" "$__fixture_origin"

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_home/.config"
    "XDG_DATA_HOME=$__fixture_dir/data"
    "XDG_STATE_HOME=$__fixture_dir/state"
    "XDG_CACHE_HOME=$__fixture_dir/cache"
    "MISE_DATA_DIR=$__fixture_dir/data"
    "MISE_STATE_DIR=$__fixture_dir/state"
    "MISE_CACHE_DIR=$__fixture_dir/cache"
    "MISE_TMP_DIR=$__fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/system-config"
    "MISE_CEILING_PATHS=$__fixture_home"
    "MISE_NO_HOOKS=1"
    "MISE_AUTO_INSTALL=false"
    "MISE_EXEC_AUTO_INSTALL=false"
    "MISE_NOT_FOUND_AUTO_INSTALL=false"
    "GIT_CONFIG_NOSYSTEM=1"
    "GIT_CONFIG_GLOBAL=$__fixture_git_config"
)

fixture_mise() {
    env -i \
        -u MISE_CONFIG_DIR -u MISE_ENV -u MISE_AUTO_ENV -u MISE_GLOBAL_CONFIG_FILE -u MISE_GLOBAL_CONFIG_ROOT \
        PATH="$PATH" \
        "${__fixture_env[@]}" mise "$@"
}

fixture_mise_at() {
    local __config_dir="$1"
    shift
    env -i \
        -u MISE_ENV -u MISE_AUTO_ENV -u MISE_GLOBAL_CONFIG_FILE -u MISE_GLOBAL_CONFIG_ROOT \
        PATH="$PATH" \
        "${__fixture_env[@]}" "MISE_CONFIG_DIR=$__config_dir" mise "$@"
}

expect_failure() {
    local __message="$1"
    local __expected="$2"
    shift 2
    if "$@" >| "$__fixture_log" 2>&1; then
        cat "$__fixture_log"
        fail "$__message unexpectedly succeeded"
    fi
    grep -qiF -- "$__expected" "$__fixture_log" || {
        cat "$__fixture_log"
        fail "$__message did not report $__expected"
    }
}

path_identity() {
    local __identity
    if __identity="$(stat -f '%d:%i' "$1" 2>/dev/null)"; then
        print -r -- "$__identity"
    else
        stat -c '%d:%i' "$1"
    fi
}

snapshot_invalid_state() {
    typeset -g __invalid_checkout_remote="$(
        fixture_git -C "$__fixture_checkout" config --local --get-regexp '^remote\..*\.url$'
    )"
    typeset -g __invalid_checkout_branch="$(fixture_git -C "$__fixture_checkout" symbolic-ref --short HEAD)"
    typeset -g __invalid_checkout_head="$(fixture_git -C "$__fixture_checkout" rev-parse HEAD)"
    typeset -g __invalid_checkout_status="$(
        fixture_git -C "$__fixture_checkout" status --porcelain=v1 --untracked-files=all
    )"
    typeset -g __invalid_config_link="$(readlink "$__fixture_config")"
    typeset -g __invalid_config_contents="$(
        find -L "$__fixture_config" -type f -exec shasum -a 256 {} + | sort
    )"
    typeset -g __invalid_local_miserc="$(cat "$__fixture_config/miserc.local.toml")"
    typeset -g __invalid_managed_dir="$__fixture_home/.config/config-dir-contract"
    typeset -g __invalid_managed="$(
        cat "$__fixture_home/.config/config-dir-contract/managed.txt"
    )"
    typeset -g __invalid_managed_contents="$(
        find "$__invalid_managed_dir" -type f -exec shasum -a 256 {} + | sort
    )"
    typeset -g __invalid_external_config_contents="$(
        if [[ -d "$__fixture_external_config" ]]; then
            find "$__fixture_external_config" -type f -exec shasum -a 256 {} + | sort
        fi
    )"
    typeset -g __invalid_external_config_kind="$(
        if [[ -d "$__fixture_external_config" && ! -L "$__fixture_external_config" ]]; then
            print -r -- physical-directory
        elif [[ -L "$__fixture_external_config" ]]; then
            print -r -- symlink
        elif [[ -e "$__fixture_external_config" ]]; then
            print -r -- other
        else
            print -r -- absent
        fi
    )"
    typeset -g __invalid_external_config_identity=""
    if [[ "$__invalid_external_config_kind" == physical-directory ]]; then
        typeset -g __invalid_external_config_identity="$(
            path_identity "$__fixture_external_config"
        )"
    fi
    typeset -g __invalid_linked_config_target="$(
        if [[ -L "$__fixture_dir/linked-config" ]]; then
            readlink "$__fixture_dir/linked-config"
        fi
    )"
}

assert_invalid_state_unchanged() {
    local __message="$1"
    [[ "$(fixture_git -C "$__fixture_checkout" config --local --get-regexp '^remote\..*\.url$')" == "$__invalid_checkout_remote" ]] ||
        fail "$__message changed a checkout remote URL"
    [[ "$(fixture_git -C "$__fixture_checkout" symbolic-ref --short HEAD)" == "$__invalid_checkout_branch" ]] ||
        fail "$__message changed the checkout branch"
    [[ "$(fixture_git -C "$__fixture_checkout" rev-parse HEAD)" == "$__invalid_checkout_head" ]] ||
        fail "$__message changed the checkout revision"
    [[ "$(fixture_git -C "$__fixture_checkout" status --porcelain=v1 --untracked-files=all)" == "$__invalid_checkout_status" ]] ||
        fail "$__message changed the checkout"
    [[ -L "$__fixture_config" ]] || fail "$__message removed the config directory link"
    [[ "$(readlink "$__fixture_config")" == "$__invalid_config_link" ]] ||
        fail "$__message changed the config directory link"
    [[ "$(find -L "$__fixture_config" -type f -exec shasum -a 256 {} + | sort)" == "$__invalid_config_contents" ]] ||
        fail "$__message changed config-link contents"
    [[ "$(cat "$__fixture_config/miserc.local.toml")" == "$__invalid_local_miserc" ]] ||
        fail "$__message changed local miserc.local.toml"
    [[ -d "$__invalid_managed_dir" && ! -L "$__invalid_managed_dir" ]] ||
        fail "$__message changed the managed directory"
    [[ -f "$__invalid_managed_dir/managed.txt" && ! -L "$__invalid_managed_dir/managed.txt" ]] ||
        fail "$__message changed the managed file path"
    [[ "$(cat "$__fixture_home/.config/config-dir-contract/managed.txt")" == "$__invalid_managed" ]] ||
        fail "$__message changed the managed file"
    [[ "$(find "$__invalid_managed_dir" -type f -exec shasum -a 256 {} + | sort)" == "$__invalid_managed_contents" ]] ||
        fail "$__message changed managed path contents"
    [[ "$(
        if [[ -d "$__fixture_external_config" ]]; then
            find "$__fixture_external_config" -type f -exec shasum -a 256 {} + | sort
        fi
    )" == "$__invalid_external_config_contents" ]] ||
        fail "$__message changed the external config contents"
    case "$__invalid_external_config_kind" in
        physical-directory)
            [[ -d "$__fixture_external_config" && ! -L "$__fixture_external_config" ]] ||
                fail "$__message changed the external config directory type"
            [[ "$(path_identity "$__fixture_external_config")" == "$__invalid_external_config_identity" ]] ||
                fail "$__message replaced the external config directory"
            ;;
        symlink)
            [[ -L "$__fixture_external_config" ]] ||
                fail "$__message changed the external config symlink"
            ;;
        other)
            [[ -e "$__fixture_external_config" && ! -d "$__fixture_external_config" && ! -L "$__fixture_external_config" ]] ||
                fail "$__message changed the external config path type"
            ;;
        absent)
            [[ ! -e "$__fixture_external_config" && ! -L "$__fixture_external_config" ]] ||
                fail "$__message created the external config path"
            ;;
    esac
    [[ "$(
        if [[ -L "$__fixture_dir/linked-config" ]]; then
            readlink "$__fixture_dir/linked-config"
        fi
    )" == "$__invalid_linked_config_target" ]] ||
        fail "$__message changed the unrelated config link"
}

cd "$__fixture_work"

# A dry run may describe a missing checkout, but must not clone or link anything.
fixture_mise --no-hooks bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir setup/mise \
    --dry-run --only files --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "config-dir dry run failed"
}
[[ ! -e "$__fixture_checkout" && ! -L "$__fixture_checkout" ]] ||
    fail "dry run created the bootstrap checkout"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "dry run created the config directory link"

# The hook-free files-only invocation clones the fixture, creates the link, and
# applies native directory/file resources without touching hooks or dotfiles.
fixture_mise --no-hooks bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir setup/mise \
    --only files --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "config-dir files bootstrap failed"
}
[[ -L "$__fixture_config" ]] || fail "mise config directory was not linked"
[[ "$(readlink "$__fixture_config")" == "$__fixture_checkout/setup/mise" ]] ||
    fail "mise config directory points to the wrong checkout"
[[ -d "$__fixture_home/.config/config-dir-contract" && ! -L "$__fixture_home/.config/config-dir-contract" ]] ||
    fail "bootstrap directory resource is not a physical directory"
grep -Fxq managed-v1 "$__fixture_home/.config/config-dir-contract/managed.txt" ||
    fail "bootstrap file resource was not applied"
[[ "$(fixture_git -C "$__fixture_checkout" config --local --get-regexp '^remote\..*\.url$')" == "remote.origin.url $__fixture_origin" ]] ||
    fail "fixture checkout origin was not preserved"
local __config_link_target="$(readlink "$__fixture_config")"

# Reusing the checkout accepts the existing link and keeps its target stable.
fixture_mise --no-hooks bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir setup/mise \
    --only files --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "config-dir link reuse failed"
}
[[ "$(readlink "$__fixture_config")" == "$__config_link_target" ]] ||
    fail "config-dir link target changed during reuse"

# The linked directory is normal global config: profile fragments, tasks, and
# dotfiles outside the config directory are loaded from the checkout.
fixture_mise -E work bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir setup/mise \
    --only dotfiles,task --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "normal profile/task bootstrap failed"
}
[[ "$(cat "$__fixture_home/config-dir-seen")" == "$__fixture_config" ]] ||
    fail "bootstrap task did not see the linked config directory"
[[ -L "$__fixture_home/.config/kitty" ]] || fail "external directory dotfile was not linked"
[[ "$(cat "$__fixture_home/.config/kitty/kitty.conf")" == "font_size 12" ]] ||
    fail "external directory dotfile content is incorrect"
[[ "$(cat "$__fixture_home/.work-marker")" == work ]] || fail "work profile dotfile was not applied"
[[ "$(cat "$__fixture_home/.zshrc")" == "export ZSH=1" ]] || fail "conf.d external dotfile was not applied"
fixture_mise -E work -C "$__fixture_checkout" config ls --no-truncate | grep -qF config.work.toml ||
    fail "work profile config was not loaded"

# A local selector is external state in the linked config and must be honored.
cat >| "$__fixture_config/miserc.local.toml" <<'EOF_LOCAL'
env = ["personal"]
EOF_LOCAL
fixture_mise -C "$__fixture_checkout" bootstrap --only dotfiles --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "external miserc.local.toml selector probe failed"
}
[[ "$(cat "$__fixture_home/.personal-marker")" == personal ]] ||
    fail "miserc.local.toml did not select the personal profile"
[[ -f "$__fixture_checkout/setup/mise/miserc.local.toml" ]] ||
    fail "external miserc.local.toml state was not retained in the checkout"

# Updating fast-forwards the checkout, applies the new file declaration, and
# preserves the approved local selector file.
python3 - "$__fixture_source/setup/mise/config.toml" <<'PY_UPDATE'
from pathlib import Path

path = Path(__import__("sys").argv[1])
path.write_text(path.read_text().replace("managed-v1", "managed-v2"))
PY_UPDATE
fixture_git -C "$__fixture_source" add setup/mise/config.toml
fixture_git -C "$__fixture_source" commit -qm update
fixture_mise --no-hooks bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir setup/mise \
    --update --only files --yes >| "$__fixture_log" 2>&1 || {
    cat "$__fixture_log"
    fail "config-dir update failed"
}
grep -Fxq managed-v2 "$__fixture_home/.config/config-dir-contract/managed.txt" ||
    fail "config-dir update did not apply the new managed file"
grep -Fxq 'env = ["personal"]' "$__fixture_config/miserc.local.toml" ||
    fail "approved local miserc.local.toml state was not preserved"

# A reused checkout with the wrong origin is rejected before bootstrap changes.
fixture_git -C "$__fixture_checkout" remote set-url origin https://github.com/example/wrong.git
snapshot_invalid_state
expect_failure "origin mismatch" "origin" \
    fixture_mise --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir setup/mise \
        --only files --yes
assert_invalid_state_unchanged "origin mismatch"
fixture_git -C "$__fixture_checkout" remote set-url origin "$__fixture_origin"

# Existing config directories and links owned by another location are never
# replaced, including their contents.
mkdir -p "$__fixture_external_config"
printf '%s\n' '[env]' >| "$__fixture_external_config/config.toml"
printf '%s\n' keep >| "$__fixture_external_config/keep.txt"
snapshot_invalid_state
expect_failure "physical target conflict" "already holds a global config" \
    fixture_mise_at "$__fixture_external_config" --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir setup/mise \
        --only files --yes
assert_invalid_state_unchanged "physical target conflict"
ln -s "$__fixture_external_config" "$__fixture_dir/linked-config"
snapshot_invalid_state
expect_failure "linked target conflict" "already a link" \
    fixture_mise_at "$__fixture_dir/linked-config" --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir setup/mise \
        --only files --yes
assert_invalid_state_unchanged "linked target conflict"

# Missing, unknown, and escaping config-dir paths fail closed.
local __missing_config_dir="$__fixture_checkout/missing"
snapshot_invalid_state
expect_failure "missing config-dir path" "not a directory" \
    fixture_mise --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir missing \
        --only files --yes
[[ ! -e "$__missing_config_dir" && ! -L "$__missing_config_dir" ]] ||
    fail "missing config-dir path was created"
assert_invalid_state_unchanged "missing config-dir path"

local __unknown_config_dir="$__fixture_checkout/unknown-config"
printf '%s\n' unknown >| "$__fixture_checkout/unknown-config"
local __unknown_config_hash="$(shasum -a 256 "$__unknown_config_dir" | cut -d ' ' -f 1)"
snapshot_invalid_state
expect_failure "unknown config-dir file" "not a directory" \
    fixture_mise --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir unknown-config \
        --only files --yes
[[ -e "$__unknown_config_dir" && ! -L "$__unknown_config_dir" ]] ||
    fail "unknown config-dir file changed during rejection"
[[ "$(shasum -a 256 "$__unknown_config_dir" | cut -d ' ' -f 1)" == "$__unknown_config_hash" ]] ||
    fail "unknown config-dir file contents changed during rejection"
assert_invalid_state_unchanged "unknown config-dir file"

local __escape_config_dir="$__fixture_checkout/escape"
ln -s "$__fixture_home" "$__escape_config_dir"
snapshot_invalid_state
expect_failure "escaping config-dir symlink" "outside the checkout" \
    fixture_mise --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir escape \
        --only files --yes
[[ -L "$__escape_config_dir" && "$(readlink "$__escape_config_dir")" == "$__fixture_home" ]] ||
    fail "escaping config-dir symlink changed during rejection"
assert_invalid_state_unchanged "escaping config-dir symlink"

local __dangling_config_dir="$__fixture_checkout/dangling"
local __dangling_config_target="$__fixture_dir/missing-config-target"
ln -s "$__dangling_config_target" "$__dangling_config_dir"
local __dangling_config_link_target="$(readlink "$__dangling_config_dir")"
local __dangling_config_kind="$(
    if [[ -L "$__dangling_config_dir" ]]; then
        print -r -- symlink
    elif [[ -e "$__dangling_config_dir" ]]; then
        print -r -- existing
    else
        print -r -- absent
    fi
)"
snapshot_invalid_state
expect_failure "dangling config-dir symlink" "not a directory" \
    fixture_mise --no-hooks bootstrap \
        --from "$__fixture_origin" \
        --from-dir "$__fixture_checkout" \
        --config-dir dangling \
        --only files --yes
[[ "$__dangling_config_kind" == symlink && -L "$__dangling_config_dir" ]] ||
    fail "dangling config-dir symlink type changed during rejection"
[[ "$(readlink "$__dangling_config_dir")" == "$__dangling_config_link_target" ]] ||
    fail "dangling config-dir symlink target changed during rejection"
assert_invalid_state_unchanged "dangling config-dir symlink"

rm -f -- "$__fixture_checkout/unknown-config" "$__fixture_checkout/escape" "$__dangling_config_dir"
[[ ! -e "$__unknown_config_dir" && ! -L "$__unknown_config_dir" ]] ||
    fail "unknown config-dir fixture cleanup left a target"
[[ ! -e "$__escape_config_dir" && ! -L "$__escape_config_dir" ]] ||
    fail "escaping config-dir fixture cleanup left a link"
[[ ! -e "$__dangling_config_dir" && ! -L "$__dangling_config_dir" ]] ||
    fail "dangling config-dir fixture cleanup left a link"

run_signal_cleanup_probe() {
    local __signal="$1"
    local __expected_status="$2"
    local __signal_probe_ready="$__fixture_dir/signal-$__signal-ready"
    local __signal_probe_log="$__fixture_dir/signal-$__signal.log"
    TMPDIR="$__fixture_dir/signal-tmp" \
    CONFIG_DIR_SIGNAL_PROBE=1 \
    CONFIG_DIR_SIGNAL_PROBE_READY="$__signal_probe_ready" \
    zsh "$__script_path" >| "$__signal_probe_log" 2>&1 &
    local __signal_probe_pid=$!
    for __attempt in {1..50}; do
        [[ -f "$__signal_probe_ready" ]] && break
        sleep 0.1
    done
    [[ -f "$__signal_probe_ready" ]] || {
        kill -TERM "$__signal_probe_pid" 2>/dev/null || true
        wait "$__signal_probe_pid" 2>/dev/null || true
        cat "$__signal_probe_log"
        fail "$__signal signal cleanup probe did not become ready"
    }
    local __signal_probe_fixture="$(cat "$__signal_probe_ready")"
    kill "-$__signal" "$__signal_probe_pid"
    local __signal_probe_status=0
    wait "$__signal_probe_pid" || __signal_probe_status="$?"
    [[ "$__signal_probe_status" == "$__expected_status" ]] ||
        fail "$__signal signal cleanup exited with $__signal_probe_status instead of $__expected_status"
    [[ ! -e "$__signal_probe_fixture" && ! -L "$__signal_probe_fixture" ]] ||
        fail "$__signal signal cleanup left the fixture directory"
}

mkdir -p "$__fixture_dir/signal-tmp"
run_signal_cleanup_probe INT 130
run_signal_cleanup_probe TERM 143

echo "mise bootstrap config-dir contract passed."
