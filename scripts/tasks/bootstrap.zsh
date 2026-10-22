#!/usr/bin/env zsh
#MISE description="Run repository cleanup and fixes after mise bootstrap"
#MISE quiet=true

set -euo pipefail

mise run mise:cleanup:inventory
mise run mise:cleanup
mise fix
