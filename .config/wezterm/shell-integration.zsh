# Wezterm shell integration
if [[ "$TERM" == "wezterm" && -f "$(dirname $WEZTERM_EXECUTABLE_DIR)/Resources/wezterm.sh" ]]; then
    source "$(dirname $WEZTERM_EXECUTABLE_DIR)/Resources/wezterm.sh"
fi
