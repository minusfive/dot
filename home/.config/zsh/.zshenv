export EDITOR=nvim
export PAGER=less

# use standard XDG directories
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# read zsh config files from XDG dir
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# Disable Next.js telemetry
# https://nextjs.org/telemetry
export NEXT_TELEMETRY_DISABLED=1

# Use the repository mise configuration by default. Preserve caller-provided
# values; set DOT_DISABLE_REPOSITORY_MISE_CONFIG=1 for isolated tests/tools.
if [[ "${DOT_DISABLE_REPOSITORY_MISE_CONFIG:-}" != 1 &&
    -d "$HOME/dev/personal/dot/home/.config/mise" ]]; then
    [[ -n "${MISE_CONFIG_DIR+x}" ]] ||
        export MISE_CONFIG_DIR="$HOME/dev/personal/dot/home/.config/mise"
    [[ -n "${MISE_ENV_CONF_D+x}" ]] ||
        export MISE_ENV_CONF_D=true
fi
