#!/usr/bin/env zsh
#MISE description="Update the historical mise cleanup path inventory"
#MISE quiet=true
#USAGE flag "--dry-run" help="Show inventory changes without writing them"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

__dry_run="${usage_dry_run:-false}"
__project_root="${MISE_PROJECT_ROOT:-}"
if [[ -z "$__project_root" ]]; then
    __project_root="$(git -C "${MISE_ORIGINAL_CWD:-$PWD}" rev-parse --show-toplevel 2>/dev/null)" ||
        die "this task must run inside the dotfiles repository"
fi
__project_root="$(cd "$__project_root" 2>/dev/null && pwd -L)" ||
    die "dotfiles repository does not exist: $__project_root"

__manifest="$__project_root/home/.config/mise/cleanup.paths"
__module_dir="$__project_root/home/.config/mise/conf.d"
[[ -d "$__module_dir" ]] || die "missing mise module directory: $__module_dir"
__head="$(git -C "$__project_root" rev-parse HEAD 2>/dev/null)" ||
    die "cannot identify the repository revision"

typeset -A __paths=()
typeset -A __blocks=()
__history_head=""

add_path() {
    local __path="$1"
    [[ -n "$__path" && "$__path" != "." && "$__path" != "./" ]] || return
    __paths[${__path#\~/}]=1
}

if [[ -f "$__manifest" ]]; then
    while IFS= read -r __path; do
        if [[ "$__path" == "# History scanned at commit: "* ]]; then
            __history_head="${__path#*: }"
            continue
        fi
        [[ -n "$__path" && "$__path" != \#* ]] || continue
        __paths[$__path]=1
    done < "$__manifest"
fi

add_source_path() {
    local __path="$1"
    local __relative="${__path#home/}"
    local __parent="$(dirname "$__relative")"
    if [[ "$__relative" == dev/* ]]; then
        add_path "$__relative"
        return
    fi
    if [[ "$__parent" == "." ]]; then
        add_path "$__relative"
    else
        add_path "$__parent"
    fi
}

add_block() {
    local __target="$1"
    local __relative="${__target#\~/}"
    local __id="${__relative##*/}"
    local __block_target="${__relative%/*}"

    [[ "$__block_target" != "$__relative" ]] || return
    [[ "$(basename "$__block_target")" == *.* ]] || return
    __blocks["$__block_target|$__id"]=1
}

collect_module_targets() {
    local __line __target __relative __parent
    while IFS=$'\t' read -r __target __line; do
        [[ "$__line" == *'source = '* ]] || continue
        case "$__target" in
            "~/"*) __relative="${__target#\~/}" ;;
            *) continue ;;
        esac
        if [[ "$__line" == *'mode = "symlink-each"'* ]]; then
            add_path "$__relative"
        else
            __parent="$(dirname "$__relative")"
            if [[ "$__parent" == "." ]]; then
                add_path "$__relative"
            else
                add_path "$__parent"
            fi
        fi
    done < <(sed -E -n 's/^[-+]?"([^"]*)".*/\1\t&/p')
}

collect_module_blocks() {
    local __line __target __relative __block_target
    while IFS=$'\t' read -r __target __line; do
        [[ "$__line" == *'block = '* ||
            "$__line" == *'template = "tera"'* ]] || continue
        [[ "$__line" != *'merge = '* ]] || continue
        case "$__target" in
            "~/"*) __relative="${__target#\~/}" ;;
            *) continue ;;
        esac
        __block_target="${__relative%/*}"
        [[ "$__block_target" != "$__relative" ]] || continue
        [[ "$(basename "$__block_target")" == *.* ]] || continue
        add_block "$__target"
    done < <(sed -E -n 's/^[-+]?"([^"]*)".*/\1\t&/p')
}

validate_module_file() {
    local __in_dotfiles=false
    local __line
    while IFS= read -r __line; do
        case "$__line" in
            "[dotfiles]") __in_dotfiles=true; continue ;;
            "["*"]") __in_dotfiles=false; continue ;;
        esac
        if [[ "$__in_dotfiles" == true &&
            "$__line" == \"~/* &&
            "$__line" == *" = {"* &&
            "$__line" != *"line = "* &&
            "$__line" != *"block = "* &&
            "$__line" != *"content = "* &&
            "$__line" != *"template = "* &&
            "$__line" != *"source = "* ]]; then
            die "dotfile declarations must keep source and mode on one line: $__line"
        fi
    done
}

if [[ "$__history_head" != "$__head" ]]; then
    while IFS= read -r __source_path; do
        [[ -n "$__source_path" ]] || continue
        add_source_path "$__source_path"
    done < <(git -C "$__project_root" log --all --format= --name-only -- home)
fi

while IFS= read -r -d '' __module; do
    validate_module_file < "$__module"
    collect_module_targets < "$__module"
    collect_module_blocks < "$__module"
done < <(find "$__module_dir" -type f -name '*.toml' -print0)

if [[ "$__history_head" != "$__head" ]]; then
    git -C "$__project_root" log --all --format= --patch -- home/.config/mise/conf.d |
        collect_module_targets
    git -C "$__project_root" log --all --format= --patch -- home/.config/mise/conf.d |
        collect_module_blocks
fi

__temporary_manifest="$(mktemp "${__manifest}.tmp.XXXXXX")"
__blocks_manifest="$__project_root/home/.config/mise/cleanup.blocks"
__temporary_blocks_manifest="$(mktemp "${__blocks_manifest}.tmp.XXXXXX")"
trap 'rm -f "$__temporary_manifest" "$__temporary_blocks_manifest"' EXIT
__sorted_paths=("${(@f)$(printf '%s\n' ${(k)__paths} | LC_ALL=C sort)}")
{
    print -r -- "# Relative paths under \$HOME that historically contained repository-managed targets."
    print -r -- "# Generated by mise:cleanup:inventory."
    print -r -- "# History scanned at commit: $__head"
    printf '%s\n' "${__sorted_paths[@]}"
} > "$__temporary_manifest"

{
    print -r -- "# Relative target paths and block IDs that historically belonged to this repository."
    print -r -- "# Generated by mise:cleanup:inventory."
    print -r -- "# History scanned at commit: $__head"
    for __block_key in ${(k)__blocks}; do
        __block_key="${(Q)__block_key}"
        printf '%s\t%s\n' "${__block_key%%|*}" "${__block_key#*|}"
    done | LC_ALL=C sort
} > "$__temporary_blocks_manifest"

if cmp -s "$__temporary_manifest" "$__manifest" 2>/dev/null &&
    cmp -s "$__temporary_blocks_manifest" "$__blocks_manifest" 2>/dev/null; then
    print -r -- "mise cleanup inventory is current."
elif [[ "$__dry_run" == "true" ]]; then
    diff -u "$__manifest" "$__temporary_manifest" || true
    diff -u "$__blocks_manifest" "$__temporary_blocks_manifest" || true
else
    mv "$__temporary_manifest" "$__manifest"
    mv "$__temporary_blocks_manifest" "$__blocks_manifest"
    trap - EXIT
    print -r -- "mise cleanup inventory updated: $__manifest and $__blocks_manifest"
fi
