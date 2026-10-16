# wezterm shell integration
if [[ "$TERM" == "wezterm" && -f $XDG_CONFIG_HOME/wezterm/shell-integration.zsh ]]; then
    source $XDG_CONFIG_HOME/wezterm/shell-integration.zsh
fi

# Wezterm CLI auto-complete
if [[ -f "$XDG_CONFIG_HOME/wezterm/shell-completion.zsh" ]]; then
    source "$XDG_CONFIG_HOME/wezterm/shell-completion.zsh"
fi
