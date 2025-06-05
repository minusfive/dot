#!/usr/bin/env zsh

function _v_fmt_b { print -P "%B$@%b" } # Bold
function _v_fmt_s { print -P "%S$@%s" } # Standout (inverted colors)
function _v_fmt_u { print -P "%U$@%u" } # Underline

function _v_color_fg { print -P "%F{$1}${@:2}%f" } # Foreground color
function _v_color_bg { print -P "%K{$1}${@:2}%k" } # Background color

function _v_log_error { print -P "$(_v_color_fg red "$(_v_fmt_s "   $1 ") $2")" }
function _v_log_info { print -P "$(_v_color_fg blue "$(_v_fmt_s "   $1 ") $2")" }
function _v_log_ok { print -P "$(_v_color_fg green "$(_v_fmt_s "   $1 ") $2")" }
function _v_log_warn { print -P "$(_v_color_fg yellow "$(_v_fmt_s "   $1 ") $2")" }
function _v_log_q { print -P "$(_v_color_fg magenta "$(_v_fmt_s "   $1 ") $2")" }

function _v_q { print -P "  $1? $(_v_color_fg green y) / $(_v_color_fg red N) $(_v_color_fg green $(_v_fmt_b ⟩)) " }

function _v_confirm_proceed {
    local __reply
    vared -p "$(print -P "$(_v_log_q $__context "Proceed?") $(_v_color_fg green y)es | $(_v_color_fg yellow N)o | $(_v_color_fg red q)uit $(_v_color_fg green $(_v_fmt_b ⟩)) "
    )" -c __reply
    if [[ $__reply =~ ^[Yy]$ ]]; then
        __proceed=true
    elif [[ $__reply == "" || $__reply =~ ^[Nn]$ ]]; then
        __proceed=false
    elif [[ $__reply =~ ^[Qq]$ ]]; then
        _v_log_error "QUIT" "Exiting..."
        exit 0
    else
        _v_log_error "ERROR" "Invalid input. Exiting..."
        exit 1
    fi
}

# From https://github.com/ohmyzsh/ohmyzsh/blob/d82669199b5d900b50fd06dd3518c277f0def869/lib/cli.zsh#L668-L676
function _v_reload {
    _v_log_warn " ZSH" "Reloading Zsh..."
    # Delete current completion cache
    (command rm -f $_comp_dumpfile $ZSH_COMPDUMP) 2> /dev/null

    # Old zsh versions don't have ZSH_ARGZERO
    local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}"

    # Check whether to run a login shell
    [[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
}

function _v_print_help {
    function _v_arg {
        printf "$(_v_color_fg green $1), $(_v_color_fg green $2)"
    }

    _v_log_info " HELP" "Bootstraps macOS with minusfive's configuration and software (https://github.com/minusfive/dot)"
    printf "\nUsage: $(_v_color_fg green "$ZSH_ARGZERO [options]")\n"
    printf "\nOptions:\n"
    printf " $(_v_arg "-b" "--brew")        Install Homebrew and managed software\n"
    printf " $(_v_arg "-h" "--help")        Show this help message\n"
    printf " $(_v_arg "-l" "--link")        Symlink dotfiles\n"
    printf " $(_v_arg "-m" "--mise")        Install mise dev tools\n"
    printf " $(_v_arg "-o" "--os")          Configure OS settings\n"
    printf " $(_v_arg "-p" "--profile")     Valid profiles: $(_v_color_fg yellow "'work'") (default, safest), or $(_v_color_fg yellow "'personal'"). e.g. \`$(_v_color_fg green "$ZSH_ARGZERO -p personal")\`\n"
    printf " $(_v_arg "-z" "--zsh")         Install Zsh plugins and themes\n"
}
