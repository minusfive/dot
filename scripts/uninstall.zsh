#!/usr/bin/env zsh

# Exit immediately if a command fails and treat unset vars as error
set -eu

# Guardrail
echo <<-EOM
%F{yellow}WARNING!%f
This may be dangerous! Open this script and uncomment accordingly if really desired
EOM
exit 0

# TODO: stow -D .
# TODO: uninstall OMZ
# TODO: uninstall homebrew and all apps
# TODO: uninstall mise and all tools
