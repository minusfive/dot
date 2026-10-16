#!/usr/bin/env bash
#MISE description="Install global Python packages"
#MISE alias="gip"
#MISE quiet=true

set -euo pipefail

uv tool install --upgrade pynvim
