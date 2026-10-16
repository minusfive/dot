function p10k-on-pre-prompt() {
    if (( $+functions[set_terminal_title] )); then
        set_terminal_title
    fi
}
