#!/usr/bin/env zsh
#MISE description="Fix all (fixable) issues"

set -euo pipefail

hk run fix "$@"
