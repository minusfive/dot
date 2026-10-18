#!/usr/bin/env zsh

set -euo pipefail

function _v_profile_file_path {
    local __xdg_state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    print -r -- "$__xdg_state_home/minusfive/profile"
}

function _v_profile_is_valid {
    local __profile="${1:-}"
    [[ "$__profile" == "work" || "$__profile" == "personal" ]]
}

function _v_profile_read {
    local __profile_file="$(_v_profile_file_path)"
    local __profile="work"

    if [[ -r "$__profile_file" ]]; then
        local __stored_profile
        __stored_profile="$(<"$__profile_file")"
        __stored_profile="${__stored_profile//$'\n'/}"

        if _v_profile_is_valid "$__stored_profile"; then
            __profile="$__stored_profile"
        fi
    fi

    print -r -- "$__profile"
}

function _v_profile_write {
    local __profile="${1:-}"

    _v_profile_is_valid "$__profile" || return 1

    local __profile_file="$(_v_profile_file_path)"
    mkdir -p "${__profile_file:h}"
    print -r -- "$__profile" >| "$__profile_file"
}
