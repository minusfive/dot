#!/usr/bin/env zsh
#MISE description="Migrate the legacy linked Zsh startup file"
#MISE quiet=true

set -euo pipefail

__target="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc"
__backup="$__target.bak"
__legacy_path="home/.config/zsh/.zshrc"

if [[ ! -L "$__target" ]]; then
    exit 0
fi

if [[ -L "$__backup" || ( -e "$__backup" && ! -f "$__backup" ) ]]; then
    print -u2 -- "error: cannot migrate $__target because $__backup is not a regular backup file"
    exit 1
fi

__project_root="$(git -C "${MISE_PROJECT_ROOT:-${MISE_ORIGINAL_CWD:-$PWD}}" rev-parse --show-toplevel)"
__link_value="$(readlink "$__target")"
if [[ "$__link_value" = /* ]]; then
    __link_path="$__link_value"
else
    __link_path="$(dirname "$__target")/$__link_value"
fi
__link_dir="$(dirname "$__link_path")"
if ! __link_dir="$(cd "$__link_dir" 2>/dev/null && pwd -P)"; then
    print -u2 -- "error: cannot resolve the legacy Zsh startup symlink at $__target"
    exit 1
fi
if [[ "$__link_dir/$(basename "$__link_path")" != "$__project_root/$__legacy_path" ]]; then
    print -u2 -- "error: refusing to replace non-repository Zsh startup symlink at $__target"
    exit 1
fi

if [[ -e "$__backup" ]]; then
    if [[ -e "$__target" ]] && ! cmp -s "$__target" "$__backup"; then
        print -u2 -- "error: existing backup $__backup does not match the legacy Zsh startup file"
        exit 1
    fi
    if [[ ! -e "$__target" ]]; then
        __legacy_commit=""
        while IFS= read -r __commit; do
            if git -C "$__project_root" cat-file -e "$__commit:$__legacy_path" 2>/dev/null; then
                __legacy_commit="$__commit"
                break
            fi
        done < <(git -C "$__project_root" rev-list --all -- "$__legacy_path")
        [[ -n "$__legacy_commit" ]] || {
            print -u2 -- "error: cannot verify existing backup $__backup against Git history"
            exit 1
        }
        git -C "$__project_root" show "$__legacy_commit:$__legacy_path" | cmp -s - "$__backup" || {
            print -u2 -- "error: existing backup $__backup does not match the last committed Zsh startup file"
            exit 1
        }
    fi
    print -r -- "info: keeping the existing Zsh startup backup at $__backup"
else
    if [[ -e "$__target" ]]; then
        cp -pL "$__target" "$__backup"
        print -r -- "info: backed up the legacy Zsh startup file to $__backup"
    else
        __legacy_commit=""
        while IFS= read -r __commit; do
            if git -C "$__project_root" cat-file -e "$__commit:$__legacy_path" 2>/dev/null; then
                __legacy_commit="$__commit"
                break
            fi
        done < <(git -C "$__project_root" rev-list --all -- "$__legacy_path")
        [[ -n "$__legacy_commit" ]] || {
            print -u2 -- "error: cannot back up the dangling Zsh startup symlink"
            exit 1
        }
        git -C "$__project_root" show "$__legacy_commit:$__legacy_path" > "$__backup"
        chmod 644 "$__backup"
        print -r -- "info: backed up the missing legacy Zsh startup file from Git history to $__backup"
    fi
fi

rm "$__target"
print -r -- "info: removed the legacy Zsh startup symlink; mise will rebuild $__target from managed blocks"
