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
function _v_log_q { print -P "$(_v_color_fg white "$(_v_fmt_s "   $1 ") $2")" }

# From https://github.com/ohmyzsh/ohmyzsh/blob/d82669199b5d900b50fd06dd3518c277f0def869/lib/cli.zsh#L668-L676
function _v_reload {
    _v_log_warn " ZSH" "Reloading Zsh. Bye  "
    # Delete current completion cache
    (command rm -f $_comp_dumpfile $ZSH_COMPDUMP) 2> /dev/null

    # Old zsh versions don't have ZSH_ARGZERO
    local zsh="${ZSH_ARGZERO:-${functrace[-1]%:*}}"

    # Check whether to run a login shell
    [[ "$zsh" = -* || -o login ]] && exec -l "${zsh#-}" || exec "$zsh"
}
