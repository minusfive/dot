#!/usr/bin/env zsh
#MISE description="Run pre-commit hooks"
#MISE quiet=true

set -euo pipefail

hk run pre-commit "$@"
