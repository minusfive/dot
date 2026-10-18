#!/usr/bin/env zsh

set -euo pipefail

function _v_mise_is_valid {
    local __mise_path="$1"
    local __mise_version

    [[ -f "$__mise_path" && -x "$__mise_path" ]] || return 1
    __mise_version="$("$__mise_path" --version 2>/dev/null)" || return 1
    [[ "$__mise_version" =~ '^(mise[[:space:]]+)?[0-9]+\.[0-9]+\.[0-9]+([[:space:]].*)?$' ]]
}

function _v_mise_ensure_stable_path {
    local __mise_path="${1:-}"
    local __stable_path="$HOME/.local/bin/mise"
    local __physical_path
    local __path_dir

    if [[ "$__mise_path" == "$__stable_path" && ! -L "$__stable_path" ]] &&
        _v_mise_is_valid "$__stable_path"; then
            export PATH="$HOME/.local/bin:$PATH"
            hash -r
            return 0
    fi
    if [[ "$__mise_path" == "$__stable_path" || -z "$__mise_path" ]]; then
        local -a __path_entries=("${(@s/:/)PATH}")
        __mise_path=""
        for __path_dir in "${__path_entries[@]}"; do
            [[ "$__path_dir" == "$HOME/.local/bin" ]] && continue
            if [[ -x "$__path_dir/mise" ]]; then
                __mise_path="$__path_dir/mise"
                break
            fi
        done
    fi
    if [[ -z "$__mise_path" && -L "$__stable_path" ]] &&
        _v_mise_is_valid "$__stable_path"; then
        export PATH="$HOME/.local/bin:$PATH"
        hash -r
        return 0
    fi
    if [[ -z "$__mise_path" ]]; then
        print -u2 -- "error: no valid mise executable was found"
        return 1
    fi
    if [[ "$__mise_path" != /* ]]; then
        __mise_path="$(cd "${__mise_path:h}" 2>/dev/null && pwd -P)/${__mise_path:t}" || {
            print -u2 -- "error: selected mise entrypoint is invalid"
            return 1
        }
    fi

    if [[ -e "$__stable_path" || -L "$__stable_path" ]]; then
        if [[ ! -L "$__stable_path" ]]; then
            print -u2 -- "error: $__stable_path is not a valid mise executable"
            return 1
        fi
        command rm "$__stable_path"
    fi

    hash -r
    __physical_path="$(realpath "$__mise_path" 2>/dev/null || true)"
    if [[ -z "$__physical_path" || "$__physical_path" == "$__stable_path" ]] ||
        ! _v_mise_is_valid "$__physical_path"; then
        if [[ "$__physical_path" == "$__stable_path" ]]; then
            print -u2 -- "error: cannot create stable mise path recursively"
        else
            print -u2 -- "error: no valid mise executable was found"
        fi
        return 1
    fi

    command mkdir -p "$HOME/.local/bin"
    command ln -s "$__mise_path" "$__stable_path"
    export PATH="$HOME/.local/bin:$PATH"
    hash -r
    _v_mise_is_valid "$__stable_path" || {
        print -u2 -- "error: stable mise path was not created"
        return 1
    }
}
