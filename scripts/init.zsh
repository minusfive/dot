#!/usr/bin/env zsh

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function used to contain variables and functions scope
function {
    # Defaults
    local __profile="work" # work or personal; work = safest
    local __brew=false
    local __symlink_dotfiles=false
    local __install_zsh_theme_plugins=false
    local __install_mise_dev_tools=false
    local __configure_os_settings=false

    local __dotfiles_scripts_dir="$(realpath "$(dirname "$ZSH_ARGZERO")")"
    local __dotfiles_dir="$(dirname "$__dotfiles_scripts_dir")"

    # Load important environment variables
    source "$__dotfiles_dir/.zshenv"

    # Load functions
    source "$__dotfiles_scripts_dir/functions.zsh"

    if [[ $# -eq 0 ]]; then
        _v_log_error "ERROR" "No options provided.\n"
        _v_print_help
        exit 1
    fi

    if [[ $# -eq 1 && ( $1 == "-h" || $1 == "--help" ) ]]; then
        _v_print_help
        return 1
    fi

    # Parse parameters and or display help and exit
    while [ $# -gt 0 ]; do
        case "$1" in
            -b|--brew)
                __brew=true
                ;;
            -l|--link)
                __symlink_dotfiles=true
                ;;
            -z|--zsh)
                __install_zsh_theme_plugins=true
                ;;
            -m|--mise)
                __install_mise_dev_tools=true
                ;;
            -o|--os)
                __configure_os_settings=true
                ;;
            -p|--profile)
                if [[ -n "$2" && "$2" != -* ]]; then
                    __profile="$2"
                    shift 1
                else
                    _v_log_error "PROFILE" "Profile name is required after -p/--profile"
                    exit 1
                fi
                ;;
            *)
                _v_log_error "ERROR" "Unknown option: $1"
                _v_print_help
                return 1
                ;;
        esac
        shift 1
    done

    # Homebrew and Homebrew packages installation
    source "$__dotfiles_scripts_dir/brew.zsh"

    # Symlink dotfiles
    source "$__dotfiles_scripts_dir/symlink.zsh"

    # Install Zsh theme + plugins
    source "$__dotfiles_scripts_dir/zsh.zsh"

    # Install mise dev tools
    source "$__dotfiles_scripts_dir/mise.zsh"

    # Configure OS settings
    source "$__dotfiles_scripts_dir/os.zsh"

    # Finish
    echo "\n"
    _v_log_ok "DONE" "Bootstrap complete"
    _v_reload
} "$@"

