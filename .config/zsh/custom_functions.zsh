#!/usr/bin/env zsh

# Set terminal title
function set_terminal_title() {
    local icon_dir=" "
    local start_dir current_dir project_root project_name package_json tsconfig detected_project_name

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

    if [ "$TERM_PROGRAM" = "WezTerm" ] && command -v wezterm >/dev/null 2>&1; then
        wezterm cli set-tab-title "$icon_dir $project_name"
    fi
}

# Reset terminal title
function reset_terminal_title() {
    if [ "$TERM_PROGRAM" = "WezTerm" ] && command -v wezterm >/dev/null 2>&1; then
        wezterm cli set-tab-title ""
    fi
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
