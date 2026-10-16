# Load user aliases after shell plugins so they override plugin aliases.
if [[ -f "$ZDOTDIR/.aliases" ]]; then
    source "$ZDOTDIR/.aliases"
fi
