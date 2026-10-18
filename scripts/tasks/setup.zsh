#!/usr/bin/env zsh
#MISE description="Set up the development environment"

set -euo pipefail

mise install
bun install
hk install --mise
