# Use deduplicated (unique) path entries to maintain performance
typeset -aU path
typeset -aU fpath
typeset -aU manpath

[[ -r "$ZDOTDIR/.zshrc-zone-0.zsh" ]] && source "$ZDOTDIR/.zshrc-zone-0.zsh"
[[ -r "$ZDOTDIR/.zshrc-zone-1.zsh" ]] && source "$ZDOTDIR/.zshrc-zone-1.zsh"
[[ -r "$ZDOTDIR/.zshrc-zone-2.zsh" ]] && source "$ZDOTDIR/.zshrc-zone-2.zsh"
[[ -r "$ZDOTDIR/.zshrc-zone-3.zsh" ]] && source "$ZDOTDIR/.zshrc-zone-3.zsh"
