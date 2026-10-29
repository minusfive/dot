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

is_active_source_tree_path() {
    local __path="$1"
    case "$__path" in
        "$__project_root/home/.config/mise"|"$__project_root/home/.config/mise"/*|"$__project_root_physical/home/.config/mise"|"$__project_root_physical/home/.config/mise"/*)
            return 0
            ;;
    esac

    local __parent="$(dirname "$__path")"
    local __physical_parent
    __physical_parent="$(cd "$__parent" 2>/dev/null && pwd -P)" || return 1
    case "$__physical_parent/$(basename "$__path")" in
        "$__project_root_physical/home/.config/mise"|"$__project_root_physical/home/.config/mise"/*)
            return 0
            ;;
    esac
    return 1
}

resolve_physical_source() {
    local __path="$1"
    local -i __depth="${2:-0}"
    local __suffix=""
    local __parent
    local __link_value
    local __link_target

    (( __depth < 40 )) || return 1

    while [[ ! -e "$__path" && ! -L "$__path" ]]; do
        __parent="$(dirname "$__path")"
        __suffix="/$(basename "$__path")$__suffix"
        [[ "$__parent" != "$__path" ]] || return 1
        __path="$__parent"
    done

    if [[ -L "$__path" ]]; then
        __link_value="$(readlink "$__path")" || return 1
        if [[ "$__link_value" = /* ]]; then
            __link_target="$__link_value"
        else
            __link_target="$(dirname "$__path")/$__link_value"
        fi
        resolve_physical_source "$__link_target$__suffix" "$((__depth + 1))"
    elif [[ -d "$__path" ]]; then
        __path="$(cd -P "$__path" 2>/dev/null && pwd -P)" || return 1
        normalize_path "$__path$__suffix"
    else
        __parent="$(cd -P "$(dirname "$__path")" 2>/dev/null && pwd -P)" || return 1
        normalize_path "$__parent/$(basename "$__path")$__suffix"
    fi
}

remove_stale_link() {
    local __link="$1"
    local __source_path="$2"

    if [[ "$__restrict_cleanup_to_config_roots" == true ]] &&
        ! is_config_root_path "$__link"; then
        return 0
    fi

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

__active_source_dir="$(normalize_path "$__project_root/home/.config/mise")"
__active_source_dir_physical="$(cd "$__active_source_dir" 2>/dev/null && pwd -P)" ||
    die "active mise source directory does not exist: $__active_source_dir"
__xdg_config_dir="$(normalize_path "${XDG_CONFIG_HOME:-$HOME/.config}/mise")"
__configured_config_dir="${MISE_CONFIG_DIR:-$__xdg_config_dir}"
if [[ -n "${MISE_CONFIG_DIR:-}" && "$__configured_config_dir" != /* ]]; then
    __configured_config_dir="$PWD/$__configured_config_dir"
fi
__configured_config_dir="$(normalize_path "$__configured_config_dir")"
__configured_config_physical=""
if [[ ! -L "$__configured_config_dir" ]]; then
    [[ -d "$__configured_config_dir" ]] ||
        die "mise configuration directory does not exist: $__configured_config_dir"
    __configured_config_physical="$(cd "$__configured_config_dir" 2>/dev/null && pwd -P)" ||
        die "mise configuration directory does not exist: $__configured_config_dir"
fi
__xdg_config_physical=""
if [[ ! -L "$__xdg_config_dir" && -d "$__xdg_config_dir" ]]; then
    __xdg_config_physical="$(cd "$__xdg_config_dir" 2>/dev/null && pwd -P)" ||
        die "XDG mise configuration directory does not exist: $__xdg_config_dir"
fi
__mise_state_dir="${MISE_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mise}"
__mise_data_dir="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}"
__mise_cache_dir="${MISE_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mise}"
__home_path="$(normalize_path "$HOME")"
__blocks_manifest="$__project_root/home/.config/mise/cleanup.blocks"
__migrations_manifest="$__project_root/home/.config/mise/cleanup.migrations"

typeset -A __scan_paths=()
typeset -A __config_root_prefixes=()
typeset -A __migration_sources=()
typeset -A __active_targets=()
typeset -A __active_symlink_each=()

__restrict_cleanup_to_config_roots=false
if [[ -n "${MISE_CONFIG_DIR:-}" &&
    ( "$__configured_config_dir" != "$__xdg_config_dir" ||
        "$__configured_config_physical" != "$__xdg_config_physical" ) ]]; then
    __restrict_cleanup_to_config_roots=true
fi

if [[ -f "$__migrations_manifest" ]]; then
    while IFS=$'\t' read -r __target __source; do
        [[ -n "$__target" && "$__target" != \#* && -n "$__source" ]] || continue
        [[ "$__target" != /* && "$__target" != "~/"* ]] ||
            die "migration target must be HOME-relative: $__target"
        [[ "/$__target/" != */../* ]] ||
            die "migration target must stay under HOME: $__target"
        [[ "$__source" == home/* && "/$__source/" != */../* ]] ||
            die "migration source must be repository-relative under home/: $__source"
        __migration_sources[$__target]="$__source"
    done < "$__migrations_manifest"
fi

add_active_target() {
    local __target="$1"
    local __mode="$2"
    local __normalized_path
    __normalized_path="$(normalize_path "$__target")"
    if [[ "$__mode" == "symlink-each" ]]; then
        __active_symlink_each[$__normalized_path]=1
    else
        __active_targets[$__normalized_path]=1
    fi
}

is_active_target() {
    local __target="$1"
    local __normalized_path
    __normalized_path="$(normalize_path "$__target")"
    [[ -n "${__active_targets[$__normalized_path]-}" ]] && return 0

    local __root
    for __root in ${(k)__active_symlink_each}; do
        [[ "$__normalized_path" == "$__root" || "$__normalized_path" == "$__root"/* ]] &&
            return 0
    done
    return 1
}

add_scan_path() {
    local __path="$1"
    [[ -n "$__path" ]] || return 0

    case "$__path" in
        "~/"*) __path="$HOME/${__path#\~/}" ;;
        /*) ;;
        *) die "mise reported a non-absolute dotfile target: $__path" ;;
    esac

    local __normalized_path
    __normalized_path="$(normalize_path "$__path")"
    [[ "$__normalized_path" == "$__home_path" ]] && return 0
    __scan_paths[$__normalized_path]=1
}

add_config_root() {
    local __root="$1"
    local __prefix=""

    [[ -n "$__root" ]] || return 0
    if [[ "$__root" == "$__xdg_config_dir" ||
        "$__root" == "$__configured_config_dir" ]]; then
        __prefix=".config/mise"
    else
        case "$__root" in
            "$HOME"/*) __prefix="${__root#$HOME/}" ;;
            "$HOME") ;;
            *) __prefix="__outside_home__" ;;
        esac
    fi
    __config_root_prefixes[$__root]="$__prefix"
    add_scan_path "$__root"
}

is_config_root_path() {
    local __path="$1"
    local __root
    for __root in ${(k)__config_root_prefixes}; do
        [[ "$__path" == "$__root" || "$__path" == "$__root"/* ]] &&
            return 0
    done
    return 1
}

migration_key_for_path() {
    local __path="$1"
    local __root __matched_root="" __suffix __prefix
    for __root in ${(k)__config_root_prefixes}; do
        if [[ "$__path" == "$__root" || "$__path" == "$__root"/* ]]; then
            if [[ -z "$__matched_root" ]] ||
                (( ${#__root} > ${#__matched_root} )); then
                __matched_root="$__root"
            fi
        fi
    done
    if [[ -n "$__matched_root" ]]; then
        __prefix="${__config_root_prefixes[$__matched_root]}"
        [[ "$__prefix" != "__outside_home__" ]] || return 1
        if [[ "$__path" == "$__matched_root" ]]; then
            print -r -- "$__prefix"
        else
            __suffix="${__path#$__matched_root/}"
            if [[ -n "$__prefix" ]]; then
                print -r -- "$__prefix/$__suffix"
            else
                print -r -- "$__suffix"
            fi
        fi
        return 0
    fi
    [[ "$__path" == "$HOME"/* ]] || return 1
    print -r -- "${__path#$HOME/}"
}

collect_target_scan_paths() {
    local __profile="$1"
    local __status
    __status="$(
        env MISE_SAFE=1 MISE_NO_HOOKS=1 \
            mise -C "$__project_root" -E "$__profile" dot status --json
    )" || die "cannot read resolved dotfile targets for the $__profile profile"

    print -r -- "$__status" |
        jq -e '.files | type == "array"' >/dev/null ||
        die "invalid dotfile status response for the $__profile profile"

    local __target __mode __parent
    while IFS=$'\t' read -r __target __mode; do
        [[ -n "$__target" && -n "$__mode" ]] || continue
        case "$__target" in
            "~/"*) __target="$HOME/${__target#\~/}" ;;
            /*) ;;
            *) die "mise reported a non-absolute dotfile target: $__target" ;;
        esac
        add_active_target "$__target" "$__mode"
        if [[ "$__mode" != "symlink-each" ]]; then
            __parent="$(dirname "$__target")"
            if [[ "$(normalize_path "$__parent")" != "$__home_path" ]]; then
                __target="$__parent"
            fi
        fi
        add_scan_path "$__target"
    done < <(
        print -r -- "$__status" |
            jq -r '.files[] | select((.target | type) == "string" and (.mode | type) == "string") | [.target, .mode] | @tsv'
    )
}

while IFS= read -r __scan_root; do
    [[ -n "$__scan_root" && "$__scan_root" != \#* ]] || continue
    add_scan_path "$HOME/$__scan_root"
done < "$__project_root/home/.config/mise/cleanup.paths"

collect_target_scan_paths work
collect_target_scan_paths personal
add_config_root "$__xdg_config_dir"
if [[ "$__configured_config_dir" != "$__active_source_dir" &&
    "$__configured_config_physical" != "$__active_source_dir_physical" ]]; then
    add_config_root "$__configured_config_dir"
fi

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
    __scan_path="$__scan_root"
    [[ -e "$__scan_path" || -L "$__scan_path" ]] || continue

    while IFS= read -r __link; do
    is_active_source_tree_path "$__link" && continue
    if [[ "$__restrict_cleanup_to_config_roots" == true ]] &&
        ! is_config_root_path "$__link"; then
        continue
    fi
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

    if [[ "$__link" == "$__xdg_config_dir" ||
        "$__link" == "$__configured_config_dir" ]]; then
        __source_physical_path="$(resolve_physical_source "$__source_path")" ||
            die "cannot resolve global mise config directory source: $__link"

        if [[ "$__source_physical_path" == "$__active_source_dir_physical" ]]; then
            continue
        fi
        if is_repo_source "$__source_physical_path"; then
            remove_stale_link "$__link" "$__source_physical_path"
        fi
        continue
    fi

    __source_physical_path="$(resolve_physical_source "$__source_path")" ||
        die "cannot resolve stale link source path: $__link"

    if [[ -e "$__source_physical_path" || -L "$__source_physical_path" ]]; then
        __target_relative="$(migration_key_for_path "$__link")" || continue
        __migration_source="${__migration_sources[$__target_relative]-}"
        if [[ -n "$__migration_source" ]]; then
            __expected_source="$(resolve_physical_source "$__project_root/$__migration_source")" ||
                die "cannot resolve migrated link source path: $__link"
            if [[ "$__source_physical_path" == "$__expected_source" ]] &&
                ! is_active_target "$__link"; then
                if [[ "$__dry_run" == "true" ]]; then
                    print -r -- "would remove migrated mise link $__link"
                else
                    rm -f "$__link"
                    print -r -- "info: removed migrated mise link $__link"
                fi
            fi
        fi
        continue
    fi

    if is_repo_source "$__source_physical_path"; then
        remove_stale_link "$__link" "$__source_physical_path"
    fi
    done < <(find "$__scan_path" -xdev -type l -print)
done

typeset -a __active_blocks=()

add_active_block() {
    local __target="$1"
    local __relative="${__target#\~/}"
    local __id="${__relative##*/}"
    local __block_target="${__relative%/*}"

    [[ "$__block_target" != "$__relative" ]] || return 0
    [[ "$(basename "$__block_target")" == *.* ]] || return 0
    __active_blocks+=("$__block_target|$__id")
}

is_active_block() {
    local __active_block
    for __active_block in "${__active_blocks[@]}"; do
        [[ "$__active_block" == "$1" ]] && return 0
    done
    return 1
}

collect_active_blocks() {
    local __line __target
    while IFS=$'\t' read -r __target __line; do
        [[ "$__line" == *'block = '* ||
            "$__line" == *'template = "tera"'* ]] || continue
        [[ "$__line" != *'merge = '* ]] || continue
        add_active_block "$__target"
    done < <(sed -E -n 's/^"([^"]*)".*/\1\t&/p' "$1")
}

remove_stale_block() {
    local __target="$1"
    local __id="$2"
    local __start="# >>> mise:$__id >>> managed by mise — do not edit between markers"
    local __end="# <<< mise:$__id <<<"
    local __temporary="$(mktemp "${__target}.stale.XXXXXX")"
    local __awk_status=0

    awk -v start="$__start" -v end="$__end" '
        $0 == start {
            if (in_block) exit 2
            in_block = 1
            removed = 1
            next
        }
        $0 == end {
            if (!in_block) exit 3
            in_block = 0
            next
        }
        !in_block { print }
        END {
            if (in_block) exit 4
            if (!removed) exit 5
        }
    ' "$__target" > "$__temporary" || __awk_status=$?

    case "$__awk_status" in
        0)
            if [[ "$__dry_run" == "true" ]]; then
                rm -f "$__temporary"
                print -r -- "would remove stale mise block $__target (block:$__id)"
            else
                cat "$__temporary" > "$__target"
                rm -f "$__temporary"
                print -r -- "info: removed stale mise block $__target (block:$__id)"
            fi
            ;;
        5)
            rm -f "$__temporary"
            ;;
        *)
            rm -f "$__temporary"
            die "cannot remove malformed mise block $__target (block:$__id)"
            ;;
    esac
}

if [[ -f "$__blocks_manifest" ]]; then
    while IFS= read -r -d '' __module; do
        collect_active_blocks "$__module"
    done < <(find "$__project_root/home/.config/mise/conf.d" -type f -name '*.toml' -print0)

    while IFS=$'\t' read -r __relative __id; do
        [[ -n "$__relative" && "$__relative" != \#* && -n "$__id" ]] || continue
        __block_key="$__relative|$__id"
        is_active_block "$__block_key" && continue
        __target="$(normalize_path "$HOME/$__relative")"
        case "$__target" in
            "$HOME"/*) ;;
            *) die "refusing stale mise block outside HOME: $__target" ;;
        esac
        if [[ "$__restrict_cleanup_to_config_roots" == true ]] &&
            ! is_config_root_path "$__target"; then
            continue
        fi
        [[ -f "$__target" && ! -L "$__target" ]] || continue
        remove_stale_block "$__target" "$__id"
    done < "$__blocks_manifest"
fi
