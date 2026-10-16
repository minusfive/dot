[[ -f "$HOME/.docker/init-zsh.sh" ]] && source "$HOME/.docker/init-zsh.sh" || true # Added by Docker Desktop

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=("$HOME/.docker/completions" $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
