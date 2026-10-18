#!/usr/bin/env zsh

set -euo pipefail

typeset -gr BETTERDISPLAY_BUNDLE_ID="pro.betterdisplay.BetterDisplay"
typeset -g BETTERDISPLAY_LOCK_DIR=""

betterdisplay_repo_root_is_valid() {
    local repo_root="$1"

    [[ -d "$repo_root" &&
        -e "$repo_root/.git" &&
        -f "$repo_root/home/.config/BetterDisplay/config.plist" &&
        -f "$repo_root/scripts/utils/betterdisplay.zsh" ]]
}

betterdisplay_source_file() {
    local repo_root="$1"

    print -r -- "$repo_root/home/.config/BetterDisplay/config.plist"
}

betterdisplay_trusted_source_file() {
    local repo_root="$1"
    local source_file source_root source_directory

    source_file="$(betterdisplay_source_file "$repo_root")"
    [[ ! -L "$source_file" ]] || {
        print -u2 -- "error: tracked BetterDisplay plist must not be a symlink: $source_file"
        return 1
    }
    [[ -f "$source_file" ]] || {
        print -u2 -- "error: tracked BetterDisplay plist is not a regular file: $source_file"
        return 1
    }
    source_root="$(cd "$repo_root" 2>/dev/null && pwd -P)" || {
        print -u2 -- "error: could not resolve the trusted dotfiles repository"
        return 1
    }
    source_directory="$(cd "${source_file:h}" 2>/dev/null && pwd -P)" || {
        print -u2 -- "error: could not resolve the tracked BetterDisplay plist"
        return 1
    }
    source_file="$source_directory/${source_file:t}"
    [[ "$source_file" == "$source_root"/* ]] || {
        print -u2 -- "error: tracked BetterDisplay plist is outside the trusted repository"
        return 1
    }
    [[ -f "$source_file" && ! -L "$source_file" ]] || {
        print -u2 -- "error: tracked BetterDisplay plist is not a regular file"
        return 1
    }

    print -r -- "$source_file"
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

betterdisplay_acquire_lock() {
    local runtime_dir lock_dir

    runtime_dir="$(betterdisplay_runtime_dir)"
    mkdir -p "$runtime_dir"
    lock_dir="$runtime_dir/lock"

    if mkdir "$lock_dir" 2>/dev/null; then
        BETTERDISPLAY_LOCK_DIR="$lock_dir"
        return 0
    fi

    print -u2 -- "error: another BetterDisplay settings operation is running"
    return 1
}

betterdisplay_release_lock() {
    if [[ -n "$BETTERDISPLAY_LOCK_DIR" &&
        -d "$BETTERDISPLAY_LOCK_DIR" &&
        ! -L "$BETTERDISPLAY_LOCK_DIR" ]]; then
        rmdir "$BETTERDISPLAY_LOCK_DIR" 2>/dev/null || true
    fi
    BETTERDISPLAY_LOCK_DIR=""
}

betterdisplay_preserve_recovery_file() {
    local source_file="$1"
    local recovery_file

    recovery_file="$(betterdisplay_make_temp_file "$(betterdisplay_runtime_dir)/conflicts")" || return 1
    if ! cp "$source_file" "$recovery_file"; then
        rm -f "$recovery_file"
        return 1
    fi
    rm -f "$source_file" || return 1
    print -r -- "$recovery_file"
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
