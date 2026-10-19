#!/usr/bin/env zsh

set -euo pipefail

filesystem::physical_path() {
    local __path="$1"

    [[ -e "$__path" ]] || return 1
    print -r -- "${__path:A}"
}

filesystem::is_physical_file() {
    local __path="$1"
    local __physical_path

    [[ -f "$__path" && ! -L "$__path" ]] || return 1
    __physical_path="$(filesystem::physical_path "$__path")" || return 1
    [[ "$__physical_path" == "$__path" ]]
}

filesystem::validate_physical_file() {
    local __label="$1"
    local __path="$2"

    filesystem::is_physical_file "$__path" && return 0
    print -u2 -- "$__label is not a regular physical file: $__path"
    return 1
}

filesystem::identity() {
    /usr/bin/stat -f '%d:%i:%z:%m' "$1"
}

filesystem::identity_matches() {
    local __path="$1"
    local __expected_path="$2"
    local __expected_identity="$3"
    local __current_path
    local __current_identity

    filesystem::is_physical_file "$__path" || return 1
    __current_path="$(filesystem::physical_path "$__path")" || return 1
    [[ "$__current_path" == "$__expected_path" ]] || return 1
    __current_identity="$(filesystem::identity "$__path")" || return 1
    [[ -n "$__current_identity" && "$__current_identity" == "$__expected_identity" ]]
}

filesystem::cleanup_known_temp() {
    local __path="${1:-}"

    [[ -n "$__path" && -e "$__path" ]] || return 0
    rm -f -- "$__path"
}
