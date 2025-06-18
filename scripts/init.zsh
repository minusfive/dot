#!/usr/bin/env zsh

# Exit immediately if a command fails and treat unset vars as error
set -euo pipefail

# Immediately invoked anonymous function used to contain variables and functions scope
function {
    local __options
    local __dotfiles_scripts_dir="$(realpath "$(dirname "$ZSH_ARGZERO")")"
    local __dotfiles_dir="$(dirname "$__dotfiles_scripts_dir")"

    # Defaults
    local __brew=false
    local __configure_os_settings=false
    local __install_mise_dev_tools=false
    local __install_zsh_theme_plugins=false
    local __install_vm=false
    local __profile="work" # work or personal; work = safest
    local __symlink_dotfiles=false
    local __noop=false

    # Load important environment variables
    source "$__dotfiles_dir/.zshenv"

    # Load functions
    source "$__dotfiles_scripts_dir/functions.zsh"

    # Parse parameters and or display help and exit
    zmodload zsh/zutil
    zparseopts -D -E -F -A __options - \
        b -brew \
        h -help \
        l -link \
        m -mise \
        o -os \
        p: -profile: \
        v -vm \
        z -zsh ||
    (_v_log_error "ERROR" "Invalid options provided\n" && _v_print_help && exit 1)

    if [[ $#__options -eq 0 ]]; then
        _v_log_warn "WARN" "No options provided\n"
        _v_print_help
        __noop=true
    fi

    for opt arg in "${(kv@)__options}"; do
        case "$opt" in
            -b|--brew)
                __brew=true
                ;;
            -h|--help)
                _v_print_help
                exit 0
                ;;
            -l|--link)
                __symlink_dotfiles=true
                ;;
            -m|--mise)
                __install_mise_dev_tools=true
                ;;
            -o|--os)
                __configure_os_settings=true
                ;;
            -p|--profile)
                if [[ "$arg" == "work" || "$arg" == "personal" ]]; then
                    __profile="$arg"
                else
                    _v_log_error "ERROR" "Valid profile name is required for the \`$opt\` option. Use 'work' or 'personal'. Received: '$arg'"
                    _v_print_help
                    exit 1
                fi
                ;;
            -v|--vm)
                __install_vm=true
                ;;
            -z|--zsh)
                __install_zsh_theme_plugins=true
                ;;
        esac
    done

    # Homebrew and Homebrew packages installation
    source "$__dotfiles_scripts_dir/brew.zsh"

    # Symlink dotfiles
    source "$__dotfiles_scripts_dir/symlink.zsh"

    # Install Zsh theme + plugins
    source "$__dotfiles_scripts_dir/zsh.zsh"

    # Install mise dev tools
    source "$__dotfiles_scripts_dir/mise.zsh"

    # Install VM and containerization tools
    source "$__dotfiles_scripts_dir/vm.zsh"

    # Configure OS settings
    source "$__dotfiles_scripts_dir/os.zsh"

    # Exit if no options were provided
    if $__noop; then
        echo "\n"
        _v_log_warn "WARN" "Nothing to do. Bye  "
        exit 0
    fi

    # Finish
    echo "\n"
    _v_log_ok "DONE" "Bootstrap complete"
    _v_reload
} "$@"

