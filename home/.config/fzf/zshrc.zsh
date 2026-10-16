# FZF configuration

# wrapped in immediately executed anonymous function to contain var scope
function {
    # Eza + Fzf: preview directories contents with eza when completing cd and zoxide
    local __eza_fzf_cmd='eza --tree --level=2 --color=always --icons=auto --classify=auto --group-directories-first --header --time-style=long-iso';
    export FZF_COMPLETION_DIR_OPTS="--preview='$__eza_fzf_cmd {}'"
    export FZF_DEFAULT_OPTS_FILE="$XDG_CONFIG_HOME/fzf/fzf.conf"
    export FZF_CTRL_R_OPTS="--no-preview --layout=reverse"
    export FZF_ALT_C_OPTS="$FZF_COMPLETION_DIR_OPTS"

    # fzf-tab
    # set list-colors to enable filename colorizing
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
    zstyle ':completion:*' menu no
    # switch group using `<` and `>`
    zstyle ':fzf-tab:*' switch-group '<' '>'
    # custom fzf flags
    # NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
    zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept
    # To make fzf-tab follow FZF_DEFAULT_OPTS.
    # NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    enable-fzf-tab

    # Eza + fzf-tab
    zstyle ':fzf-tab:complete:cd:*' fzf-preview "$__eza_fzf_cmd \$realpath"
    zstyle ':fzf-tab:complete:z:*' fzf-preview "$__eza_fzf_cmd \$realpath"
    zstyle ':fzf-tab:complete:zoxide:*' fzf-preview "$__eza_fzf_cmd \$realpath"
}
