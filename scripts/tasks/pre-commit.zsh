#!/usr/bin/env zsh
#MISE description="Run pre-commit hooks"

set -euo pipefail

hk run pre-commit "$@"
