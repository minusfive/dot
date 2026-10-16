# Run terminal maintenance before each prompt.
autoload -Uz add-zsh-hook
if (( $+functions[_ztfix_repair_terminal_state] )); then
    add-zsh-hook -d precmd _ztfix_repair_terminal_state 2>/dev/null
    add-zsh-hook precmd _ztfix_repair_terminal_state
fi

# User configuration

# Remove ESC delay
KEYTIMEOUT=1

# Compilation flags
# export ARCHFLAGS="-arch x86_64"
