# wezterm shell integration
if [[ "$TERM" == "wezterm" && -f $XDG_CONFIG_HOME/wezterm/shell-integration.sh ]]; then
    source $XDG_CONFIG_HOME/wezterm/shell-integration.sh
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "$XDG_CACHE_HOME/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation.
export ZSH="$XDG_CONFIG_HOME/oh-my-zsh"

# Oh My Zsh cache
export ZSH_CACHE_DIR="$XDG_CACHE_HOME/omz"
export ZSH_COMPDUMP="$ZSH_CACHE_DIR/.zcompdump"


# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

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
# under VCS as dirty. This makes repository status check for large repositories
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

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
    # vi-mode
    zsh-vi-mode
    colored-man-pages
    docker
    fast-syntax-highlighting
    git
    terraform
    virtualenv
    # yarn # Keyboard commands conflict with Yazi's CLI
    zoxide
    # zsh-autocomplete # Too noisy
    zsh-autosuggestions
    # per-directory-history # Not used to this yet
    fzf
    fzf-tab
    fzf-tab-source
    ohmyzsh-full-autoupdate
)

source $ZSH/oh-my-zsh.sh

# User configuration

# Remove ESC delay
KEYTIMEOUT=1

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Use deduplicated (unique) path entries to maintain performance
typeset -U path
typeset -U fpath
typeset -U manpath

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
    export EDITOR='vim'
else
    export EDITOR='nvim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

path=(
    # Coreutils
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

export PATH
export FPATH
export MANPATH

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

# Load Aliases File
if [[ -f "$ZDOTDIR/.aliases" ]]; then
    source "$ZDOTDIR/.aliases"
fi


[[ -f "$HOME/.docker/init-zsh.sh" ]] && source "$HOME/.docker/init-zsh.sh" || true # Added by Docker Desktop

# Configure Powerlevel10k
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
if [[ -f "$ZDOTDIR/.p10k.zsh" ]]; then
    source "$ZDOTDIR/.p10k.zsh"
fi

# Wezterm CLI auto-complete
if [[ -f "$XDG_CONFIG_HOME/wezterm/shell-completion.zsh" ]]; then
    source "$XDG_CONFIG_HOME/wezterm/shell-completion.zsh"
fi

# Multiplexers
export ZELLIJ_CONFIG_DIR="$XDG_CONFIG_HOME/zellij"

# Lazygit
export LG_CONFIG_FILE="$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/theme.yml"

# ripgrep config
export RIPGREP_CONFIG_PATH="$XDG_CONFIG_HOME/ripgrep/.ripgreprc"


# FZF configuration

# wrapped in immediately executed anonymous function to contain var scope
function {
    # Eza + Fzf: preview directories contents with eza when completing cd and zoxide
    local __eza_fzf_cmd='eza --tree --level=2 --color=always --icons=auto --classify=auto --group-directories-first --header --time-style=long-iso';
    export FZF_COMPLETION_DIR_OPTS="--preview='$__eza_fzf_cmd {}'"
    export FZF_DEFAULT_OPTS_FILE="$XDG_CONFIG_HOME/fzf/fzf.conf"
    export FZF_CTRL_R_OPTS="--no-preview --layout=reverse"
    export FZF_ALT_C_OPTS="$FZF_COMPLETION_DIR_OPTS"

    # fzf-tab
    # set list-colors to enable filename colorizing
    zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
    # force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
    zstyle ':completion:*' menu no
    # switch group using `<` and `>`
    zstyle ':fzf-tab:*' switch-group '<' '>'
    # custom fzf flags
    # NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
    zstyle ':fzf-tab:*' fzf-flags --bind=tab:accept
    # To make fzf-tab follow FZF_DEFAULT_OPTS.
    # NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
    zstyle ':fzf-tab:*' use-fzf-default-opts yes
    enable-fzf-tab

    # Eza + fzf-tab
    zstyle ':fzf-tab:complete:cd:*' fzf-preview "$__eza_fzf_cmd \$realpath"
    zstyle ':fzf-tab:complete:z:*' fzf-preview "$__eza_fzf_cmd \$realpath"
    zstyle ':fzf-tab:complete:zoxide:*' fzf-preview "$__eza_fzf_cmd \$realpath"
}

# Colorize LS
export LS_COLORS="$(vivid generate catppuccin-mocha)"

# Yazi - Change directory when exiting
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp" > /dev/null
}

# zsh-autosuggestions
ZSH_AUTOSUGGEST_STRATEGY=(history)
# Fix https://github.com/romkatv/powerlevel10k/issues/1554
unset ZSH_AUTOSUGGEST_USE_ASYNC
bindkey '^y' autosuggest-accept

# Use 1Password SSH agent
export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

# mise
eval "$(mise activate zsh)"

