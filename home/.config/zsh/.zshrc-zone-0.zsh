# Load custom functions
source "$ZDOTDIR/custom_functions.zsh"

# Shared profile persisted by init.zsh for cross-tool config decisions.
export DOT_PROFILE="$(read_dot_profile)"

path=(
    $path
    /usr/local/bin
    /usr/local/sbin
    $HOME/.local/bin
)

export PATH
export FPATH
export MANPATH

# vi-mode plugin settings
# VI_MODE_RESET_PROMPT_ON_MODE_CHANGE=true
# VI_MODE_SET_CURSOR=true
# VI_MODE_CURSOR_NORMAL=1
# VI_MODE_CURSOR_VISUAL=0
# VI_MODE_CURSOR_INSERT=5
# VI_MODE_CURSOR_OPPEND=0

# zsh-vi-mode config
if [[ -f $XDG_CONFIG_HOME/zsh/plugins/zsh-vi-mode/config.zsh ]]; then
    source $XDG_CONFIG_HOME/zsh/plugins/zsh-vi-mode/config.zsh
fi
