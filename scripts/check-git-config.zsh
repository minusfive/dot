#!/usr/bin/env zsh

set -euo pipefail

local __script_dir="${${(%):-%N}:A:h}"
local __repo_root
if ! __repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    print -u2 -- "error: Git config checker must run inside a Git repository"
    exit 1
fi
cd "$__repo_root"
source "$__script_dir/../home/.config/mise/utils/git-domains.zsh"

local __manifest="home/dev/personal/.domains"
local __error_count=0

report_error() {
    local __file="$1"
    local __category="$2"
    local __source="tracked .gitconfig"
    if [[ "$__file" == "home/.config/git/config" ]]; then
        __source="home/.config/git/config"
    fi
    print -u2 -- "git-config-check: $__source: $__category setting is not allowed"
    (( __error_count += 1 ))
}

report_domain_error() {
    case "$git_domains_error" in
        invalid) print -u2 -- "git-config-check: personal domain manifest has an invalid hostname at line $git_domains_error_line" ;;
        duplicate) print -u2 -- "git-config-check: personal domain manifest has a duplicate hostname at line $git_domains_error_line" ;;
        empty) print -u2 -- "git-config-check: personal domain manifest has no hostnames" ;;
        *) print -u2 -- "git-config-check: personal domain manifest is missing or unreadable" ;;
    esac
    (( __error_count += 1 ))
}

include_is_allowed() {
    local __key="$1"
    local __value="$2"

    case "$__key:$__value" in
        "include.path:~/.config/delta/themes/catppuccin.gitconfig" | \
        "includeif.gitdir:~/dev/work/.path:~/dev/work/.gitconfig" | \
        "includeif.gitdir:~/Notes/Work/.path:~/dev/work/.gitconfig" | \
        "includeif.gitdir:~/dev/personal/.path:~/dev/personal/.gitconfig" | \
        "includeif.gitdir:~/Notes/Personal/.path:~/dev/personal/.gitconfig")
            return 0
            ;;
    esac
    return 1
}

config_scope_url() {
    local __key="$1"
    local __section="$2"
    local __scope="${__key#"$__section".}"
    local __path=""
    local -a match

    [[ "$__key" == "$__section".* ]] || return 1
    if [[ "$__scope" =~ '^(https://[^/]+)(/.*)?\.([a-z][a-z0-9-]*)$' ]]; then
        __path="${match[2]-}"
        [[ -z "$__path" || "$__path" == "/" ]] || return 1
        print -r -- "${match[1]}${match[2]-}"
        return 0
    fi
    return 1
}

inspect_entry() {
    local __file="$1"
    local __key="$2"
    local __value="$3"
    local __scope_url=""
    local __host=""
    local __attribute=""
    local __target_url=""
    local __target_host=""
    local __prefix_host=""

    case "$__key" in
        include.path|includeif.*.path)
            if ! include_is_allowed "$__key" "$__value"; then
                report_error "$__file" "include"
            fi
            return 0
            ;;
        user.name|user.email|user.signingkey)
            report_error "$__file" "identity"
            return 0
            ;;
        remote.*.url|remote.*.pushurl)
            report_error "$__file" "remote URL"
            return 0
            ;;
        credential.*)
            if ! __scope_url="$(config_scope_url "$__key" credential)"; then
                report_error "$__file" "credential"
                return 0
            fi
            if ! __host="$(git_domain_host_from_url "$__scope_url")" ||
                ! git_domain_matches "$__host"; then
                report_error "$__file" "credential"
                return 0
            fi
            __attribute="${__key##*.}"
            case "$__attribute" in
                helper) report_error "$__file" "credential" ;;
                usehttppath)
                    if [[ ! "${__value:l}" =~ '^(true|false|yes|no|on|off|1|0)$' ]]; then
                        report_error "$__file" "credential"
                    fi
                    ;;
                username)
                    report_error "$__file" "identity"
                    ;;
                *)
                    report_error "$__file" "credential"
                    ;;
            esac
            return 0
            ;;
        http.*)
            if ! __scope_url="$(config_scope_url "$__key" http)"; then
                report_error "$__file" "HTTP"
                return 0
            fi
            if ! __host="$(git_domain_host_from_url "$__scope_url")" ||
                ! git_domain_matches "$__host"; then
                report_error "$__file" "HTTP"
                return 0
            fi
            __attribute="${__key##*.}"
            case "$__attribute" in
                sslverify)
                    if [[ ! "${__value:l}" =~ '^(true|yes|on|1)$' ]]; then
                        report_error "$__file" "HTTP"
                    fi
                    ;;
                followredirects)
                    if [[ ! "${__value:l}" =~ '^(true|false|yes|no|on|off|1|0)$' ]]; then
                        report_error "$__file" "HTTP"
                    fi
                    ;;
                lowspeedlimit|lowspeedtime|postbuffer)
                    if [[ ! "$__value" =~ '^[0-9]+$' ]]; then
                        report_error "$__file" "HTTP"
                    fi
                    ;;
                *)
                    report_error "$__file" "HTTP"
                    ;;
            esac
            return 0
            ;;
        url.*.insteadof|url.*.pushinsteadof)
            __target_url="${__key#url.}"
            case "$__target_url" in
                *.insteadof) __target_url="${__target_url%.insteadof}" ;;
                *.pushinsteadof) __target_url="${__target_url%.pushinsteadof}" ;;
            esac
            if ! __target_host="$(git_domain_host_from_url "$__target_url")" ||
                ! git_domain_matches "$__target_host"; then
                report_error "$__file" "URL rewrite"
                return 0
            fi
            if ! __prefix_host="$(git_domain_host_from_url "$__value")" ||
                ! git_domain_matches "$__prefix_host"; then
                report_error "$__file" "URL rewrite"
            fi
            return 0
            ;;
    esac
}

if ! git ls-files --error-unmatch -- "$__manifest" >/dev/null 2>&1 ||
    [[ ! -f "$__manifest" || -L "$__manifest" ]]; then
    print -u2 -- "git-config-check: tracked personal domain manifest is missing or is a symlink"
    exit 1
fi
if ! git_domains_load "$__manifest"; then
    report_domain_error
fi

local __file=""
while IFS= read -r -d '' __file; do
    case "$__file" in
        .gitconfig|*/.gitconfig|*.gitconfig|home/.config/git/config) ;;
        *) continue ;;
    esac

    if [[ -L "$__file" || ! -f "$__file" ]]; then
        report_error "$__file" "Git config source"
        continue
    fi
    if ! git config --null --list --file "$__file" >/dev/null 2>&1; then
        report_error "$__file" "invalid Git config"
        continue
    fi

    local __record=""
    local __key=""
    local __value=""
    while IFS= read -r -d '' __record; do
        if [[ "$__record" == *$'\n'* ]]; then
            __key="${__record%%$'\n'*}"
            __value="${__record#*$'\n'}"
        else
            __key="$__record"
            __value="true"
        fi
        inspect_entry "$__file" "$__key" "$__value"
    done < <(git config --null --list --file "$__file" 2>/dev/null)
done < <(git ls-files -z)

if (( __error_count > 0 )); then
    exit 1
fi

print -r -- "Git config policy passed."
