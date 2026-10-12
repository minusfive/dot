# Wezterm shell completion
if [[ $(command -v wezterm) != "" ]]; then
  eval "$(wezterm shell-completion --shell zsh)"
fi
