#!/usr/bin/env zsh

function {
    emulate -L zsh
    setopt errexit nounset pipefail

    path=("$HOME/.local/bin" $path)
    export PATH
    rehash
} "$@"
