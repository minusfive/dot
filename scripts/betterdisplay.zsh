#!/usr/bin/env zsh
# BetterDisplay settings management

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function with the script's path as its only argument
# used to contain variables and functions in a local scope
function {
    local __context="DISP"
    local __proceed="$__manage_betterdisplay"

    # BetterDisplay configuration
    local __betterdisplay_bundle_id="pro.betterdisplay.BetterDisplay"
    local __config_dir="$__dotfiles_dir/.config/BetterDisplay"
    local __config_file="$__config_dir/config.plist"
    local __temp_export_file="/tmp/BetterDisplay_export.plist"

    if [[ "$__proceed" == true ]]; then
        echo "\n"
        _v_log_info $__context "Managing $(_v_fmt_u BetterDisplay) settings..."
        _v_log_info $__context "Config directory: $(_v_color_fg yellow "'$__config_dir'")"
        _v_log_info $__context "Config file: $(_v_color_fg yellow "'$__config_file'")"

        _v_confirm_proceed
    fi

    if [[ "$__proceed" != true ]]; then
        echo "\n"
        _v_log_warn $__context "Skipping $(_v_fmt_u BetterDisplay) settings management"
        return 0
    fi

    # Function to check if BetterDisplay is installed
    function __check_betterdisplay_installed {
        if [[ ! -d "/Applications/BetterDisplay.app" ]] && [[ ! -d "$HOME/Applications/BetterDisplay.app" ]]; then
            _v_log_error $__context "$(_v_fmt_u BetterDisplay) app not found. Please install BetterDisplay first."
            return 1
        fi
        return 0
    }

    # Function to check if BetterDisplay is running
    function __check_betterdisplay_running {
        if pgrep -x "BetterDisplay" > /dev/null; then
            return 0
        else
            return 1
        fi
    }

    # Function to export BetterDisplay settings
    function __export_betterdisplay_settings {
        _v_log_info $__context "Exporting $(_v_fmt_u BetterDisplay) settings..."

        # Create config directory if it doesn't exist
        if [[ ! -d "$__config_dir" ]]; then
            _v_log_info $__context "Creating config directory: $__config_dir"
            mkdir -p "$__config_dir"

            if [[ $? == 0 ]]; then
                _v_log_ok $__context "Config directory created: $__config_dir"
            else
                _v_log_error $__context "Failed to create config directory: $__config_dir"
                return 1
            fi
        fi

        # Export settings using defaults command
        _v_log_info $__context "Exporting settings from $__betterdisplay_bundle_id to $__temp_export_file"
        defaults export "$__betterdisplay_bundle_id" "$__temp_export_file" 2>/dev/null

        if [[ $? == 0 ]]; then
            # Move the exported file to the config location
            mv "$__temp_export_file" "$__config_file"
            _v_log_ok $__context "Settings exported to $__config_file"
        else
            _v_log_error $__context "Failed to export $(_v_fmt_u BetterDisplay) settings. Make sure the app has been configured at least once."
            return 1
        fi
    }

    # Function to import BetterDisplay settings
    function __import_betterdisplay_settings {
        _v_log_info $__context "Importing $(_v_fmt_u BetterDisplay) settings..."

        # Check if config file exists
        if [[ ! -f "$__config_file" ]]; then
            _v_log_error $__context "Config file not found: $__config_file"
            _v_log_info $__context "Run export first or ensure the file exists"
            return 1
        fi

        # Warn if BetterDisplay is running
        if __check_betterdisplay_running; then
            _v_log_warn $__context "$(_v_fmt_u BetterDisplay) is currently running"
            _v_log_warn $__context "Settings import should be done when the app is not running"

            local __quit_reply
            vared -p "$(print -P "$(_v_log_q $__context "Quit BetterDisplay and continue?") $(_v_color_fg green $(_v_fmt_u y))es | $(_v_color_fg yellow $(_v_fmt_u N))o $(_v_color_fg green $(_v_fmt_b ⟩)) ")" -c __quit_reply

            if [[ $__quit_reply =~ ^[Yy]$ ]]; then
                _v_log_info $__context "Quitting $(_v_fmt_u BetterDisplay)..."
                osascript -e 'tell application "BetterDisplay" to quit' 2>/dev/null || true
                # Wait for the app to quit
                sleep 2

                if __check_betterdisplay_running; then
                    _v_log_error $__context "Failed to quit $(_v_fmt_u BetterDisplay). Please quit manually and try again."
                    return 1
                else
                    _v_log_ok $__context "$(_v_fmt_u BetterDisplay) quit successfully"
                fi
            else
                _v_log_warn $__context "Import cancelled. Quit $(_v_fmt_u BetterDisplay) manually and try again."
                return 1
            fi
        fi

        # Import settings using defaults command
        _v_log_info $__context "Importing settings from $__config_file to $__betterdisplay_bundle_id"
        defaults import "$__betterdisplay_bundle_id" "$__config_file"

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "Settings imported successfully from $__config_file"
            _v_log_info $__context "You can now start $(_v_fmt_u BetterDisplay) to use the imported settings"
        else
            _v_log_error $__context "Failed to import $(_v_fmt_u BetterDisplay) settings"
            return 1
        fi
    }

    # Function to backup current settings before import
    function __backup_current_settings {
        local __backup_file="$__config_dir/config.backup.$(date +%Y%m%d_%H%M%S).plist"

        _v_log_info $__context "Creating backup of current settings to $__backup_file"
        defaults export "$__betterdisplay_bundle_id" "$__backup_file" 2>/dev/null

        if [[ $? == 0 ]]; then
            _v_log_ok $__context "Current settings backed up to $__backup_file"
        else
            _v_log_warn $__context "Could not create backup of current settings (app may not be configured yet)"
        fi
    }

    # Main execution
    if ! __check_betterdisplay_installed; then
        return 1
    fi

    # Determine operation based on whether config file exists
    if [[ -f "$__config_file" ]]; then
        echo "\n"
        _v_log_info $__context "Found existing config file: $__config_file"

        local __action_reply
        vared -p "$(print -P "$(_v_log_q $__context "Action:") $(_v_color_fg green $(_v_fmt_u i))mport | $(_v_color_fg yellow $(_v_fmt_u e))xport (overwrite) | $(_v_color_fg red $(_v_fmt_u s))kip $(_v_color_fg green $(_v_fmt_b ⟩)) ")" -c __action_reply

        case "$__action_reply" in
            [Ii])
                __backup_current_settings
                __import_betterdisplay_settings
                ;;
            [Ee])
                __export_betterdisplay_settings
                ;;
            [Ss]|"")
                _v_log_warn $__context "Skipping $(_v_fmt_u BetterDisplay) settings management"
                ;;
            *)
                _v_log_error $__context "Invalid input. Skipping $(_v_fmt_u BetterDisplay) settings management"
                ;;
        esac
    else
        echo "\n"
        _v_log_info $__context "No existing config file found. Exporting current settings..."
        __export_betterdisplay_settings
    fi
}
