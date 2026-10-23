#!/usr/bin/env zsh
#MISE description="Refresh mise tools after bootstrap"
#MISE quiet=true

set -euo pipefail

mise upgrade --prune
mise reshim -f
