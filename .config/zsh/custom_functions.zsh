#!/usr/env zsh

# Set terminal title
function set_terminal_title() {
    local title="$1"
    if [[ -z "$title" ]]; then
        echo "Usage: set_terminal_title <title>"
        return 1
    fi

    case "$TERM" in
        wezterm)
            wezterm cli set-tab-title "$title"
            ;;
    esac
}

# Reset terminal title
function reset_terminal_title() {
    case "$TERM" in
        wezterm)
            wezterm cli set-tab-title ""
            ;;
    esac
}
