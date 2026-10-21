#!/usr/bin/env zsh

function {
    emulate -L zsh
    setopt errexit nounset pipefail

    local __profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile"
    local __profile="work"

    if [[ -r "$__profile_file" ]]; then
        local __stored_profile
        __stored_profile="$(<"$__profile_file")"
        __stored_profile="${__stored_profile//$'\n'/}"

        if [[ "$__stored_profile" == work || "$__stored_profile" == personal ]]; then
            __profile="$__stored_profile"
        fi
    fi

    path=("$HOME/.local/bin" $path)
    export PATH
    if [[ -z "${DOT_PROFILE:-}" ]]; then
        export DOT_PROFILE="$__profile"
    fi
    rehash
} "$@"
