#!/usr/bin/env zsh
#MISE description="Remove stale repository-managed mise links"
#MISE quiet=true
#USAGE flag "--dry-run" help="Show stale links without removing them"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

__dry_run="${usage_dry_run:-false}"

normalize_path() {
    local __path="$1"
    local __component
    local __normalized=""
    local -a __components
    __components=("${(@s:/:)__path}")

    for __component in "${__components[@]}"; do
        case "$__component" in
            ""|.) continue ;;
            ..)
                [[ "$__normalized" == "/" || -z "$__normalized" ]] && continue
                __normalized="${__normalized%/*}"
                [[ -n "$__normalized" ]] || __normalized="/"
                ;;
            *)
                if [[ "$__normalized" == "/" ]]; then
                    __normalized="/$__component"
                elif [[ -n "$__normalized" ]]; then
                    __normalized="$__normalized/$__component"
                else
                    __normalized="/$__component"
                fi
                ;;
        esac
    done

    print -r -- "${__normalized:-/}"
}

is_repo_source() {
    case "$1" in
        "$__project_root/home"/*|"$__project_root_physical/home"/*) return 0 ;;
        *) return 1 ;;
    esac
}

resolve_physical_source() {
    local __path="$1"
    local __suffix=""
    local __parent

    while [[ ! -e "$__path" && ! -L "$__path" ]]; do
        __parent="$(dirname "$__path")"
        __suffix="/$(basename "$__path")$__suffix"
        [[ "$__parent" != "$__path" ]] || return 1
        __path="$__parent"
    done

    __path="$(cd "$__path" 2>/dev/null && pwd -P)" || return 1
    print -r -- "$__path$__suffix"
}

remove_stale_link() {
    local __link="$1"
    local __source_path="$2"

    is_repo_source "$__source_path" ||
        die "refusing to remove stale link with a source outside this repository: $__link"

    if [[ "$__dry_run" == "true" ]]; then
        print -r -- "would remove stale mise link $__link"
    else
        rm -f "$__link"
        print -r -- "info: removed stale mise link $__link"
    fi
}

__project_root="${MISE_PROJECT_ROOT:-}"
if [[ -z "$__project_root" ]]; then
    __project_root="$(git -C "${MISE_ORIGINAL_CWD:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" ||
        die "this task must run inside the dotfiles repository"
fi
__project_root="$(cd "$__project_root" 2>/dev/null && pwd -L)" ||
    die "dotfiles repository does not exist: $__project_root"
__project_root_physical="$(cd "$__project_root" 2>/dev/null && pwd -P)" ||
    die "dotfiles repository does not exist: $__project_root"

__mise_dir="$HOME/.config/mise"
[[ -d "$__mise_dir" ]] || die "mise configuration directory does not exist: $__mise_dir"
__mise_state_dir="${MISE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mise}"
__mise_data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
__mise_cache_dir="${MISE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mise}"

typeset -A __scan_paths=()
while IFS= read -r __scan_root; do
    [[ -n "$__scan_root" && "$__scan_root" != \#* ]] || continue
    __scan_paths[$__scan_root]=1
done < "$__project_root/home/.config/mise/cleanup.paths"

__sorted_scan_paths=("${(@f)$(printf '%s\n' ${(k)__scan_paths} | LC_ALL=C sort)}")
__scan_roots=()
for __scan_root in "${__sorted_scan_paths[@]}"; do
    __covered=false
    for __root in "${__scan_roots[@]}"; do
        if [[ "$__scan_root" == "$__root" || "$__scan_root" == "$__root"/* ]]; then
            __covered=true
            break
        fi
    done
    [[ "$__covered" == true ]] || __scan_roots+=("$__scan_root")
done

for __scan_root in "${__scan_roots[@]}"; do
    __scan_path="$HOME/$__scan_root"
    [[ -e "$__scan_path" || -L "$__scan_path" ]] || continue

    while IFS= read -r __link; do
    case "$__link" in
        "$__project_root"/*|"$__project_root_physical"/*) continue ;;
    esac
    if [[ "$__link" == "$__mise_state_dir" ||
        "$__link" == "$__mise_state_dir"/* ||
        "$__link" == "$__mise_data_dir" ||
        "$__link" == "$__mise_data_dir"/* ||
        "$__link" == "$__mise_cache_dir" ||
        "$__link" == "$__mise_cache_dir"/* ]]; then
        continue
    fi

    __link_value="$(readlink "$__link")"
    if [[ "$__link_value" = /* ]]; then
        __source_path="$__link_value"
    else
        __source_path="$(dirname "$__link")/$__link_value"
    fi

    __source_path="$(normalize_path "$__source_path")"
    is_repo_source "$__source_path" || continue

    [[ -e "$__source_path" || -L "$__source_path" ]] && continue

    __physical_source_path="$(resolve_physical_source "$__source_path")" ||
        die "cannot resolve stale link source path: $__link"

    remove_stale_link "$__link" "$__physical_source_path"
    done < <(find "$__scan_path" -xdev -type l -print)
done
