#!/usr/bin/env zsh

set -euo pipefail

typeset -ga git_domains
typeset -g git_domains_error=""
typeset -g git_domains_error_line=0

git_domain_normalize() {
    local __host="${1:l}"
    __host="${__host%.}"

    [[ -n "$__host" && "${#__host}" -le 253 ]] || return 1
    [[ ! "$__host" =~ '^(0x[0-9a-f]+|[0-9]+)(\.(0x[0-9a-f]+|[0-9]+)){0,3}$' ]] ||
        return 1
    [[ "$__host" =~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)*$' ]] ||
        return 1

    local -a __labels
    local __label
    __labels=("${(@s:.:)__host}")
    for __label in "${__labels[@]}"; do
        (( ${#__label} <= 63 )) || return 1
    done

    print -r -- "$__host"
}

git_domains_load() {
    local __file="$1"
    local __line=""
    local __line_number=0
    local __host=""
    local __existing=""
    git_domains=()
    git_domains_error=""
    git_domains_error_line=0

    if [[ ! -f "$__file" ]]; then
        git_domains_error="missing"
        return 1
    fi

    while IFS= read -r __line || [[ -n "$__line" ]]; do
        (( __line_number += 1 ))
        __line="${__line#"${__line%%[![:space:]]*}"}"
        __line="${__line%"${__line##*[![:space:]]}"}"
        [[ -z "$__line" || "$__line" == \#* ]] && continue

        if ! __host="$(git_domain_normalize "$__line")"; then
            git_domains_error="invalid"
            git_domains_error_line="$__line_number"
            return 1
        fi

        for __existing in "${git_domains[@]}"; do
            if [[ "$__existing" == "$__host" ]]; then
                git_domains_error="duplicate"
                git_domains_error_line="$__line_number"
                return 1
            fi
        done
        git_domains+=("$__host")
    done < "$__file"

    if (( ${#git_domains[@]} == 0 )); then
        git_domains_error="empty"
        return 1
    fi
    return 0
}

git_domain_matches() {
    local __host
    __host="$(git_domain_normalize "$1")" || return 1

    local __domain
    for __domain in "${git_domains[@]}"; do
        [[ "$__host" == "$__domain" || "$__host" == *."$__domain" ]] && return 0
    done
    return 1
}

git_domain_host_from_url() {
    local __url="$1"
    local __authority
    local __host
    local __rest
    local __path

    case "$__url" in
        https://*)
            __rest="${__url#https://}"
            __authority="${__rest%%/*}"
            if [[ "$__rest" == */* ]]; then
                __path="/${__rest#*/}"
                [[ "$__path" == "/" ]] || return 1
            fi
            ;;
        ssh://git@*)
            __rest="${__url#ssh://git@}"
            __authority="${__rest%%/*}"
            if [[ "$__rest" == */* ]]; then
                __path="/${__rest#*/}"
                [[ "$__path" == "/" ]] || return 1
            fi
            ;;
        git@*:* )
            __host="${__url#git@}"
            __host="${__host%%:*}"
            __path="${__url#*:}"
            [[ -z "$__path" ]] || return 1
            __host="$(git_domain_normalize "$__host")" || return 1
            print -r -- "$__host"
            return
            ;;
        *)
            return 1
            ;;
    esac

    [[ -n "$__authority" && "$__authority" != *"@"* && "$__authority" != *":"* ]] ||
        return 1
    __authority="$(git_domain_normalize "$__authority")" || return 1
    print -r -- "$__authority"
}
