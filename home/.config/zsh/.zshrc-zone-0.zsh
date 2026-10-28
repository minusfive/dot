# Load custom functions
source "$ZDOTDIR/custom_functions.zsh"

# Shared profile persisted by native mise bootstrap for cross-tool config decisions.
export DOT_PROFILE="$(read_dot_profile)"

path=(
    /usr/local/bin
    /usr/local/sbin
    $HOME/.local/bin
    $path
)

export PATH
export FPATH
export MANPATH
