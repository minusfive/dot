#!/usr/bin/env zsh
#MISE description="Run all checks"
#MISE quiet=true

set -euo pipefail

hk run check "$@"
