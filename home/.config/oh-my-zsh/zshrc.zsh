# Path to your oh-my-zsh installation.
export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"

# Oh My Zsh cache
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/omz"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    # vi-mode
    git
    zsh-vi-mode
    # terraform
    # virtualenv
    # yarn # Keyboard commands conflict with Yazi's CLI
    zoxide
    # per-directory-history # Not used to this yet
    fzf
    fzf-tab
    fzf-tab-source
    # zsh-autocomplete # Too noisy
    zsh-autosuggestions
    fast-syntax-highlighting
    colored-man-pages
    ohmyzsh-full-autoupdate
    mise
    bun
)

source $ZSH/oh-my-zsh.sh

# Configure Powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -f "$ZDOTDIR/.p10k.zsh" ]]; then
    source "$ZDOTDIR/.p10k.zsh"
fi

# zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history)
# Fix https://github.com/romkatv/powerlevel10k/issues/1554
unset ZSH_AUTOSUGGEST_USE_ASYNC
bindkey '^y' autosuggest-accept
