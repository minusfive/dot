#!/usr/bin/env bash
#MISE description="Install all global packages"
#MISE alias="gi"
#MISE quiet=true

set -euo pipefail

mise run global-install-packages-npm
mise run global-install-packages-python
mise run global-install-packages-ruby
