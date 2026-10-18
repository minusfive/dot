#!/usr/bin/env zsh

set -euo pipefail

typeset -gr BETTERDISPLAY_BUNDLE_ID="pro.betterdisplay.BetterDisplay"
typeset -gr BETTERDISPLAY_UTIL_DIR="${${(%):-%N}:A:h}"
typeset -gr BETTERDISPLAY_LOCK_STALE_AFTER=120
typeset -g BETTERDISPLAY_LOCK_DIR=""
typeset -g BETTERDISPLAY_LOCK_TOKEN=""

betterdisplay_repo_root() {
    local candidate root

    for candidate in "${MISE_PROJECT_ROOT:-}" "${MISE_ORIGINAL_CWD:-}"; do
        [[ -n "$candidate" ]] || continue
        if [[ -f "$candidate/home/.config/BetterDisplay/config.plist" ]]; then
            root="$(cd "$candidate" && pwd -P)"
            print -r -- "$root"
            return 0
        fi
    done

    for candidate in "${MISE_ORIGINAL_CWD:-}" "$PWD"; do
        [[ -n "$candidate" ]] || continue
        root="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)" || continue
        print -r -- "$root"
        return 0
    done

    print -u2 -- "error: could not find the dotfiles repository"
    return 1
}

betterdisplay_source_file() {
    local repo_root="${1:-$(betterdisplay_repo_root)}"
    print -r -- "$repo_root/home/.config/BetterDisplay/config.plist"
}

betterdisplay_require_installed() {
    if [[ -d "/Applications/BetterDisplay.app" || -d "$HOME/Applications/BetterDisplay.app" ]]; then
        return 0
    fi

    print -u2 -- "error: BetterDisplay is not installed"
    return 1
}

betterdisplay_is_running() {
    pgrep -x "BetterDisplay" >/dev/null 2>&1
}

betterdisplay_validate_plist() {
    local plist_file="$1"

    [[ -f "$plist_file" ]] || {
        print -u2 -- "error: plist does not exist: $plist_file"
        return 1
    }
    plutil -lint "$plist_file" >/dev/null || {
        print -u2 -- "error: invalid plist: $plist_file"
        return 1
    }
}

betterdisplay_make_temp_file() {
    local directory="$1"
    local candidate
    integer attempt

    mkdir -p "$directory"
    for (( attempt = 1; attempt <= 20; attempt++ )); do
        candidate="$directory/.betterdisplay.$$.$RANDOM.$attempt"
        if (set -C; : > "$candidate") 2>/dev/null; then
            print -r -- "$candidate"
            return 0
        fi
    done

    print -u2 -- "error: could not create a temporary BetterDisplay file in $directory"
    return 1
}

betterdisplay_runtime_dir() {
    print -r -- "${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/BetterDisplay"
}

betterdisplay_process_start() {
    local pid="$1"

    ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^[[:space:]]*//'
}

betterdisplay_lock_entries_are_safe() {
    local lock_dir="$1"
    local entry name
    local -a entries

    entries=("$lock_dir"/*(N) "$lock_dir"/.[!.]*(N) "$lock_dir"/..?*(N))
    for entry in "${entries[@]}"; do
        name="${entry:t}"
        if [[ "$name" == "owner" || "$name" == .owner.* ]] &&
            [[ -f "$entry" && ! -L "$entry" ]]; then
            continue
        fi
        return 1
    done
}

betterdisplay_lock_is_old_enough() {
    local lock_dir="$1"
    local modified_at now

    modified_at="$(/usr/bin/stat -f %m "$lock_dir" 2>/dev/null)" || return 1
    now="$(date +%s)"
    (( now >= modified_at + BETTERDISPLAY_LOCK_STALE_AFTER ))
}

betterdisplay_lock_owner_is_live() {
    local owner_file="$1"
    local owner_pid owner_start current_start

    owner_pid="$(sed -n 's/^pid=\([0-9][0-9]*\)$/\1/p' "$owner_file")"
    owner_start="$(sed -n 's/^start=\(.*\)$/\1/p' "$owner_file")"
    [[ "$owner_pid" == <-> && "$owner_pid" -gt 0 && -n "$owner_start" ]] || return 1
    current_start="$(betterdisplay_process_start "$owner_pid")"
    [[ -n "$current_start" && "$current_start" == "$owner_start" ]]
}

betterdisplay_lock_owner_token() {
    sed -n 's/^token=\([[:alnum:]._-]*\)$/\1/p' "$1"
}

betterdisplay_remove_stale_lock() {
    local lock_dir="$1"
    local entry name
    local -a entries

    betterdisplay_lock_entries_are_safe "$lock_dir" || return 1
    entries=("$lock_dir"/*(N) "$lock_dir"/.[!.]*(N) "$lock_dir"/..?*(N))
    for entry in "${entries[@]}"; do
        name="${entry:t}"
        [[ "$name" == owner || "$name" == .owner.* ]] || return 1
        rm -f "$entry"
    done
    rmdir "$lock_dir"
}

betterdisplay_restore_quarantined_lock() {
    local lock_dir="$1"
    local quarantine_dir="$2"

    [[ ! -e "$lock_dir" ]] || return 1
    mv "$quarantine_dir" "$lock_dir"
}

betterdisplay_quarantine_stale_lock() {
    local runtime_dir="$1"
    local lock_dir="$2"
    local quarantine_dir owner_file owner_metadata
    local owner_present=false moved=false
    integer attempt

    betterdisplay_lock_is_old_enough "$lock_dir" || return 1
    betterdisplay_lock_entries_are_safe "$lock_dir" || return 1
    owner_file="$lock_dir/owner"
    if [[ -f "$owner_file" && ! -L "$owner_file" ]]; then
        owner_present=true
        owner_metadata="$(cat "$owner_file")"
    fi

    for (( attempt = 1; attempt <= 20; attempt++ )); do
        quarantine_dir="$runtime_dir/.lock.reclaim.$$.$RANDOM.$attempt"
        [[ ! -e "$quarantine_dir" ]] || continue
        mv "$lock_dir" "$quarantine_dir" 2>/dev/null || return 1
        moved=true
        break
    done
    [[ "$moved" == true && -d "$quarantine_dir" && ! -L "$quarantine_dir" ]] || return 1

    if [[ "$owner_present" == true ]]; then
        if [[ ! -f "$quarantine_dir/owner" || -L "$quarantine_dir/owner" ||
            "$(cat "$quarantine_dir/owner")" != "$owner_metadata" ||
            -z "$(betterdisplay_lock_owner_token "$quarantine_dir/owner")" ]]; then
            betterdisplay_restore_quarantined_lock "$lock_dir" "$quarantine_dir" || true
            return 1
        fi
        if betterdisplay_lock_owner_is_live "$quarantine_dir/owner"; then
            betterdisplay_restore_quarantined_lock "$lock_dir" "$quarantine_dir" || true
            return 1
        fi
    elif [[ -e "$quarantine_dir/owner" ]]; then
        betterdisplay_restore_quarantined_lock "$lock_dir" "$quarantine_dir" || true
        return 1
    fi

    betterdisplay_lock_entries_are_safe "$quarantine_dir" || {
        betterdisplay_restore_quarantined_lock "$lock_dir" "$quarantine_dir" || true
        return 1
    }
    betterdisplay_remove_stale_lock "$quarantine_dir"
}

betterdisplay_cleanup_stale_candidates() {
    local runtime_dir="$1"
    local candidate name owner_file
    local -a candidates

    candidates=("$runtime_dir"/.lock.*(N))
    for candidate in "${candidates[@]}"; do
        name="${candidate:t}"
        [[ "$name" =~ '^\.lock\.[0-9]+\.[0-9]+\.[0-9]+$' ]] || continue
        [[ -d "$candidate" && ! -L "$candidate" ]] || continue
        owner_file="$candidate/owner"
        if [[ -f "$owner_file" && ! -L "$owner_file" ]] &&
            betterdisplay_lock_owner_is_live "$owner_file"; then
            continue
        fi
        betterdisplay_quarantine_stale_lock "$runtime_dir" "$candidate" || true
    done
}

betterdisplay_cleanup_orphaned_reclaims() {
    local runtime_dir="$1"
    local reclaim_dir name owner_file
    local -a reclaim_dirs

    reclaim_dirs=("$runtime_dir"/.lock.reclaim.*(N))
    for reclaim_dir in "${reclaim_dirs[@]}"; do
        name="${reclaim_dir:t}"
        [[ "$name" =~ '^\.lock\.reclaim\.[0-9]+\.[0-9]+\.[0-9]+$' ]] || continue
        [[ -d "$reclaim_dir" && ! -L "$reclaim_dir" ]] || continue
        betterdisplay_lock_is_old_enough "$reclaim_dir" || continue
        betterdisplay_lock_entries_are_safe "$reclaim_dir" || continue
        owner_file="$reclaim_dir/owner"
        if [[ -f "$owner_file" && ! -L "$owner_file" ]] &&
            betterdisplay_lock_owner_is_live "$owner_file"; then
            continue
        fi
        betterdisplay_remove_stale_lock "$reclaim_dir" || true
    done
}

betterdisplay_acquire_lock_unserialized() {
    local runtime_dir lock_dir candidate candidate_name owner_file owner_tmp lock_token installed_token
    local owner_pid owner_start
    integer attempt

    runtime_dir="$(betterdisplay_runtime_dir)"
    mkdir -p "$runtime_dir"
    betterdisplay_cleanup_orphaned_reclaims "$runtime_dir"
    betterdisplay_cleanup_stale_candidates "$runtime_dir"
    lock_dir="$runtime_dir/lock"

    owner_pid="${BETTERDISPLAY_LOCK_OWNER_PID:-$$}"
    owner_start="${BETTERDISPLAY_LOCK_OWNER_START:-$(betterdisplay_process_start "$owner_pid")}"
    lock_token="$owner_pid.$RANDOM.$(date +%s)"
    [[ -n "$owner_start" ]] || {
        print -u2 -- "error: could not determine BetterDisplay lock owner start time"
        return 1
    }
    installed_token=""

    for (( attempt = 1; attempt <= 20; attempt++ )); do
        candidate="$runtime_dir/.lock.$owner_pid.$RANDOM.$attempt"
        mkdir "$candidate" 2>/dev/null || continue
        owner_file="$candidate/owner"
        owner_tmp="$candidate/.owner.$lock_token"
        if ! {
            print -r -- "pid=$owner_pid"
            print -r -- "start=$owner_start"
            print -r -- "token=$lock_token"
        } > "$owner_tmp" || ! mv "$owner_tmp" "$owner_file"; then
            rm -f "$owner_tmp" "$owner_file"
            rmdir "$candidate" 2>/dev/null || true
            print -u2 -- "error: could not publish BetterDisplay lock owner metadata"
            return 1
        fi
        candidate_name="${candidate:t}"
        if [[ ! -e "$lock_dir" ]] &&
            mv -n "$candidate" "$lock_dir" 2>/dev/null &&
            [[ ! -e "$candidate" && -d "$lock_dir" && ! -L "$lock_dir" &&
                -f "$lock_dir/owner" && ! -L "$lock_dir/owner" ]]; then
            installed_token="$(betterdisplay_lock_owner_token "$lock_dir/owner")"
            if [[ "$installed_token" == "$lock_token" ]]; then
                BETTERDISPLAY_LOCK_DIR="$lock_dir"
                BETTERDISPLAY_LOCK_TOKEN="$lock_token"
                return 0
            fi
        fi
        if [[ -d "$lock_dir/$candidate_name" && ! -L "$lock_dir/$candidate_name" ]]; then
            rm -f "$lock_dir/$candidate_name/owner" "$lock_dir/$candidate_name"/.owner.*(N)
            rmdir "$lock_dir/$candidate_name" 2>/dev/null || true
        fi
        rm -f "$candidate/owner" "$candidate"/.owner.*(N)
        rmdir "$candidate" 2>/dev/null || true
        break
    done

    if [[ ! -d "$lock_dir" || -L "$lock_dir" ]]; then
        print -u2 -- "error: another BetterDisplay settings operation is running"
        return 1
    fi

    owner_file="$lock_dir/owner"
    if [[ -f "$owner_file" && ! -L "$owner_file" ]] &&
        betterdisplay_lock_owner_is_live "$owner_file"; then
        print -u2 -- "error: another BetterDisplay settings operation is running"
        return 1
    fi
    if ! betterdisplay_quarantine_stale_lock "$runtime_dir" "$lock_dir"; then
        if [[ -f "$owner_file" && ! -L "$owner_file" ]]; then
            print -u2 -- "error: BetterDisplay lock owner metadata is invalid or stale"
        else
            print -u2 -- "error: another BetterDisplay settings operation is running"
        fi
        return 1
    fi

    betterdisplay_acquire_lock_unserialized
}

betterdisplay_acquire_lock() {
    local runtime_dir operation_file lock_token owner_start

    runtime_dir="$(betterdisplay_runtime_dir)"
    mkdir -p "$runtime_dir"
    operation_file="$runtime_dir/.lock-operation"
    owner_start="$(betterdisplay_process_start "$$")" || {
        print -u2 -- "error: could not determine BetterDisplay lock owner start time"
        return 1
    }
    command -v lockf >/dev/null 2>&1 || {
        print -u2 -- "error: lockf is required for BetterDisplay lock recovery"
        return 1
    }
    lock_token="$(
        BETTERDISPLAY_LOCK_OWNER_PID="$$" \
        BETTERDISPLAY_LOCK_OWNER_START="$owner_start" \
        BETTERDISPLAY_LOCK_UTIL="$BETTERDISPLAY_UTIL_DIR/betterdisplay.zsh" \
            lockf -t 30 "$operation_file" zsh -f -c '
                source "$BETTERDISPLAY_LOCK_UTIL"
                betterdisplay_acquire_lock_unserialized
                print -r -- "$BETTERDISPLAY_LOCK_TOKEN"
            '
    )" || {
        print -u2 -- "error: could not acquire BetterDisplay lock recovery guard"
        return 1
    }
    [[ "$lock_token" == <->.<->.<-> ]] || {
        print -u2 -- "error: BetterDisplay lock owner token was not published"
        return 1
    }
    BETTERDISPLAY_LOCK_DIR="$runtime_dir/lock"
    BETTERDISPLAY_LOCK_TOKEN="$lock_token"
}

betterdisplay_atomic_swap() {
    local source_file="$1"
    local target_file="$2"
    local runtime_dir helper_dir helper_source helper_file helper_tmp

    runtime_dir="$(betterdisplay_runtime_dir)"
    helper_dir="$runtime_dir/tools"
    helper_source="$BETTERDISPLAY_UTIL_DIR/betterdisplay_atomic_swap.c"
    helper_file="$helper_dir/betterdisplay_atomic_swap"
    mkdir -p "$helper_dir"
    if [[ ! -x "$helper_file" ]]; then
        command -v clang >/dev/null 2>&1 || {
            print -u2 -- "error: clang is required for atomic BetterDisplay settings replacement"
            return 1
        }
        [[ -f "$helper_source" ]] || {
            print -u2 -- "error: atomic BetterDisplay replacement helper is missing"
            return 1
        }
        helper_tmp="$helper_file.$$.$RANDOM"
        if ! clang -O2 -Wall -Wextra -Werror "$helper_source" -o "$helper_tmp" ||
            ! mv "$helper_tmp" "$helper_file"; then
            rm -f "$helper_tmp"
            print -u2 -- "error: could not build atomic BetterDisplay replacement helper"
            return 1
        fi
    fi
    "$helper_file" "$source_file" "$target_file"
}

betterdisplay_release_lock() {
    local owner_token

    if [[ -n "$BETTERDISPLAY_LOCK_DIR" && -f "$BETTERDISPLAY_LOCK_DIR/owner" &&
        ! -L "$BETTERDISPLAY_LOCK_DIR/owner" ]]; then
        owner_token="$(sed -n 's/^token=\([[:alnum:]._-]*\)$/\1/p' "$BETTERDISPLAY_LOCK_DIR/owner")"
        if [[ "$owner_token" == "$BETTERDISPLAY_LOCK_TOKEN" ]]; then
            rm -f "$BETTERDISPLAY_LOCK_DIR/owner"
            rmdir "$BETTERDISPLAY_LOCK_DIR" 2>/dev/null || true
        fi
    fi
    BETTERDISPLAY_LOCK_DIR=""
    BETTERDISPLAY_LOCK_TOKEN=""
}

betterdisplay_backup_current_settings() {
    local backup_dir backup_file temporary_file

    backup_dir="$(betterdisplay_runtime_dir)/backups"
    mkdir -p "$backup_dir"
    backup_file="$backup_dir/config.$(date +%Y%m%d_%H%M%S).$$.plist"
    temporary_file="$(betterdisplay_make_temp_file "$backup_dir")"

    if ! defaults export "$BETTERDISPLAY_BUNDLE_ID" "$temporary_file" >/dev/null; then
        rm -f "$temporary_file"
        print -u2 -- "error: could not back up current BetterDisplay settings"
        return 1
    fi
    if ! betterdisplay_validate_plist "$temporary_file"; then
        rm -f "$temporary_file"
        return 1
    fi
    if ! mv "$temporary_file" "$backup_file"; then
        rm -f "$temporary_file"
        print -u2 -- "error: could not save BetterDisplay backup: $backup_file"
        return 1
    fi

    print -r -- "$backup_file"
}
