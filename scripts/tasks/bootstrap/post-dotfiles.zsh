#!/usr/bin/env zsh
#MISE description="Run repository cleanup and fixes after dotfiles bootstrap"
#MISE quiet=true

set -euo pipefail

mise run bootstrap:post-dotfiles:cleanup:inventory
mise run bootstrap:post-dotfiles:cleanup
mise fix
