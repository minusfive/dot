#!/usr/bin/env bash
#MISE description="Install global NPM packages"
#MISE alias="gin"
#MISE quiet=true

set -euo pipefail

npm install -g npm@latest
npm install -g neovim@latest
