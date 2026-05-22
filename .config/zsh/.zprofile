# Use deduplicated (unique) path entries to maintain performance
typeset -U path
typeset -U fpath
typeset -U manpath

eval "$(/opt/homebrew/bin/brew shellenv)"

path=(
    # UUtils
    $(brew --prefix coreutils)/libexec/gnubin

    # git diff-highlight
    $(brew --prefix git)/share/git-core/contrib/diff-highlight

    # curl
    $(brew --prefix curl)/bin

    # yarn
    $HOME/.yarn/bin
    $XDG_CONFIG_HOME/yarn/global/node_modules/.bin

    # local
    /usr/local/bin
    /usr/local/sbin
    $HOME/.local/bin

    # default
    $path
)

eval "$(mise activate zsh --shims)"
