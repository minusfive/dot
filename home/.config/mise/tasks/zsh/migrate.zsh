#!/usr/bin/env zsh
#MISE description="Migrate legacy linked Zsh startup files"
#MISE quiet=true

set -euo pipefail

_migrate_legacy_link() {
    local __target="$1"
    local __backup="$2"
    local __legacy_path="$3"
    local __description="$4"

    if [[ ! -L "$__target" ]]; then
        return 0
    fi

    if [[ -L "$__backup" || ( -e "$__backup" && ! -f "$__backup" ) ]]; then
        print -u2 -- "error: cannot migrate $__target because $__backup is not a regular backup file"
        return 1
    fi

    local __project_root="$(git -C "${MISE_PROJECT_ROOT:-${MISE_ORIGINAL_CWD:-$PWD}}" rev-parse --show-toplevel)"
    local __link_value="$(readlink "$__target")"
    local __link_path
    if [[ "$__link_value" = /* ]]; then
        __link_path="$__link_value"
    else
        __link_path="$(dirname "$__target")/$__link_value"
    fi
    local __link_dir="$(dirname "$__link_path")"
    if ! __link_dir="$(cd "$__link_dir" 2>/dev/null && pwd -P)"; then
        print -u2 -- "error: cannot resolve the legacy $__description symlink at $__target"
        return 1
    fi
    if [[ "$__link_dir/$(basename "$__link_path")" != "$__project_root/$__legacy_path" ]]; then
        print -u2 -- "error: refusing to replace non-repository $__description symlink at $__target"
        return 1
    fi

    if [[ -e "$__backup" ]]; then
        if [[ -e "$__target" ]] && ! cmp -s "$__target" "$__backup"; then
            print -u2 -- "error: existing backup $__backup does not match the legacy $__description file"
            return 1
        fi
        if [[ ! -e "$__target" ]]; then
            local __legacy_commit=""
            while IFS= read -r __commit; do
                if git -C "$__project_root" cat-file -e "$__commit:$__legacy_path" 2>/dev/null; then
                    __legacy_commit="$__commit"
                    break
                fi
            done < <(git -C "$__project_root" rev-list --all -- "$__legacy_path")
            [[ -n "$__legacy_commit" ]] || {
                print -u2 -- "error: cannot verify existing backup $__backup against Git history"
                return 1
            }
            git -C "$__project_root" show "$__legacy_commit:$__legacy_path" | cmp -s - "$__backup" || {
                print -u2 -- "error: existing backup $__backup does not match the last committed $__description file"
                return 1
            }
        fi
        print -r -- "info: keeping the existing $__description backup at $__backup"
    else
        if [[ -e "$__target" ]]; then
            cp -pL "$__target" "$__backup"
            print -r -- "info: backed up the legacy $__description file to $__backup"
        else
            local __legacy_commit=""
            while IFS= read -r __commit; do
                if git -C "$__project_root" cat-file -e "$__commit:$__legacy_path" 2>/dev/null; then
                    __legacy_commit="$__commit"
                    break
                fi
            done < <(git -C "$__project_root" rev-list --all -- "$__legacy_path")
            [[ -n "$__legacy_commit" ]] || {
                print -u2 -- "error: cannot back up the dangling $__description symlink"
                return 1
            }
            git -C "$__project_root" show "$__legacy_commit:$__legacy_path" > "$__backup"
            chmod 644 "$__backup"
            print -r -- "info: backed up the missing legacy $__description file from Git history to $__backup"
        fi
    fi

    rm "$__target"
    print -r -- "info: removed the legacy $__description symlink; mise will rebuild $__target from managed blocks"
}

_migrate_legacy_link \
    "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zshrc.bak" \
    "home/.config/zsh/.zshrc" \
    "Zsh startup"
_migrate_legacy_link \
    "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zprofile" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/.zprofile.bak" \
    "home/.config/zsh/.zprofile" \
    "Zsh login profile"
