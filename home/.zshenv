export EDITOR=nvim
export PAGER=less

# use standard XDG directories
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# read zsh config files from XDG dir
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Disable Next.js telemetry
# https://nextjs.org/telemetry
export NEXT_TELEMETRY_DISABLED=1
