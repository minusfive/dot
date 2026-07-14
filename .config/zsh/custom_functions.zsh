#!/usr/bin/env zsh

# Load once at startup so the prompt hook path avoids repeated module checks.
zmodload -F zsh/terminfo b:echoti 2>/dev/null || true

typeset -g _DOT_LAST_TAB_TITLE=""
typeset -g _DOT_TITLE_PROJECT_ROOT=""
typeset -g _DOT_TITLE_PROJECT_NAME=""
typeset -g _DOT_TITLE_ICON=" "

function _set_tab_title_osc1() {
    [[ -t 1 ]] || return 0
    printf '\e]1;%s\a' "$1"
}

function _dot_detect_project_root() {
    local current_dir="$PWD"

    while [[ -n "$current_dir" && "$current_dir" != "/" ]]; do
        if [[ -e "$current_dir/.git" ]]; then
            print -r -- "$current_dir"
            return 0
        fi

        current_dir="${current_dir:h}"
    done

    print -r -- "$PWD"
}

function _dot_update_title_project_cache() {
    local project_root package_json tsconfig detected_project_name project_name icon_dir
    project_root="$(_dot_detect_project_root)"

    if [[ "$_DOT_TITLE_PROJECT_ROOT" == "$project_root" ]]; then
        return 0
    fi

    package_json="$project_root/package.json"
    tsconfig="$project_root/tsconfig.json"
    project_name="${project_root:t}"
    icon_dir=" "

    if [[ "$project_root" == "$HOME" ]]; then
        icon_dir="󰋜 "
    fi

    if [[ -f "$package_json" ]]; then
        icon_dir="󰌞 "

        if (( $+commands[jq] )); then
            detected_project_name="$(jq -r '.name // empty' "$package_json" 2>/dev/null || true)"
            if [[ -n "$detected_project_name" ]]; then
                project_name="$detected_project_name"
            fi
        fi
    fi

    if [[ -f "$tsconfig" ]]; then
        icon_dir="󰛦 "
    fi

    _DOT_TITLE_PROJECT_ROOT="$project_root"
    _DOT_TITLE_PROJECT_NAME="$project_name"
    _DOT_TITLE_ICON="$icon_dir"
}

# Set terminal title
function set_terminal_title() {
    local git_ref title

    _dot_update_title_project_cache
    title="$_DOT_TITLE_ICON $_DOT_TITLE_PROJECT_NAME"

    if [[ -n ${VCS_STATUS_LOCAL_BRANCH:-} ]]; then
        git_ref="${(V)VCS_STATUS_LOCAL_BRANCH}"
    elif [[ -n ${VCS_STATUS_TAG:-} ]]; then
        git_ref="${(V)VCS_STATUS_TAG}"
    elif [[ -n ${VCS_STATUS_COMMIT:-} ]]; then
        git_ref="${VCS_STATUS_COMMIT[1,8]}"
    fi

    if [[ -n "$git_ref" ]]; then
        title="$title  $git_ref"
    fi

    if [[ "${_DOT_LAST_TAB_TITLE:-}" == "$title" ]]; then
        return
    fi

    _set_tab_title_osc1 "$title"
    _DOT_LAST_TAB_TITLE="$title"
}

# Reset terminal title
function reset_terminal_title() {
    _DOT_LAST_TAB_TITLE=""
    _set_tab_title_osc1 ""
}

# Terminal recovery used by the precmd hook and manual `ztfix` command.
# Keeps repair conservative: only restore the states commonly leaked by crashed TUIs.
function _ztfix_repair_terminal_state() {
    [[ -o interactive ]] || return 0
    [[ -t 0 && -t 1 ]] || return 0

    # Restore core line-editing behavior without broad `stty sane` resets.
    stty echo icanon opost isig -raw -cbreak 2>/dev/null || true
    # Disable leaked mouse modes + bracketed paste, and ensure cursor is visible.
    printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?2004l\e[?25h' 2>/dev/null || true

    # Reset application cursor-key mode (DECCKM) if terminfo support is available.
    if (( $+builtins[echoti] )); then
        echoti rmkx 2>/dev/null || true
    fi

    # Pop Kitty keyboard protocol state when running in known supporting terminals.
    if [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM_PROGRAM:-}" == "WezTerm" ]]; then
        printf '\e[<u' 2>/dev/null || true
    fi
}

# Manual escape hatch when terminal state breaks mid-session.
function ztfix() {
    _ztfix_repair_terminal_state
}

function read_dot_profile() {
    local profile_file="${XDG_STATE_HOME:-$HOME/.local/state}/minusfive/profile"
    local profile="work"

    if [[ -r "$profile_file" ]]; then
        local stored_profile
        stored_profile="$(<"$profile_file")"
        stored_profile="${stored_profile//$'\n'/}"

        if [[ "$stored_profile" == "work" || "$stored_profile" == "personal" ]]; then
            profile="$stored_profile"
        fi
    fi

    print -r -- "$profile"
}
