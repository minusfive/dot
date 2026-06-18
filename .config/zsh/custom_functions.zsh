#!/usr/bin/env zsh

# Load once at startup so the prompt hook path avoids repeated module checks.
zmodload -F zsh/terminfo b:echoti 2>/dev/null || true

function git_branch_or_short_sha() {
    local repo_root="$1"
    local git_ref

    if [ ! -e "$repo_root/.git" ]; then
        return
    fi

    git_ref="$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
    if [ -z "$git_ref" ]; then
        git_ref="$(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || true)"
    fi

    if [ -n "$git_ref" ]; then
        echo "$git_ref"
    fi
}

# Set terminal title
function set_terminal_title() {
    local icon_dir=" "
    local start_dir current_dir project_root project_name package_json tsconfig detected_project_name git_ref title

    start_dir="$PWD"
    current_dir="$start_dir"
    project_root=""

    while [ -n "$current_dir" ] && [ "$current_dir" != "/" ]; do
        if [ -e "$current_dir/.git" ]; then
            icon_dir="󰊢 "
            project_root="$current_dir"
            break
        fi

        current_dir="$(dirname "$current_dir")"
    done

    if [ -z "$project_root" ]; then
        project_root="$start_dir"
    fi

    package_json="$project_root/package.json"
    tsconfig="$project_root/tsconfig.json"
    project_name="$(basename "$project_root")"

    if [ -f "$package_json" ]; then
        icon_dir="󰌞 "

        if command -v jq >/dev/null 2>&1; then
            detected_project_name="$(jq -r '.name // empty' "$package_json" 2>/dev/null || true)"
            if [ -n "$detected_project_name" ]; then
                project_name="$detected_project_name"
            fi
        fi
    fi

    if [ -f "$tsconfig" ]; then
        icon_dir="󰛦 "
    fi

    title="$icon_dir $project_name"
    git_ref="$(git_branch_or_short_sha "$project_root")"
    if [ -n "$git_ref" ]; then
        title="$title @ $git_ref"
    fi

    if [ "$TERM_PROGRAM" = "WezTerm" ] && command -v wezterm >/dev/null 2>&1; then
        wezterm cli set-tab-title "$title"
    fi
}

# Reset terminal title
function reset_terminal_title() {
    if [ "$TERM_PROGRAM" = "WezTerm" ] && command -v wezterm >/dev/null 2>&1; then
        wezterm cli set-tab-title ""
    fi
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
