#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing python tool module..."
local __config="home/.config/mise/conf.d/python.toml"
assert_tool_module python 'python = { version = "3.13", postinstall = "mise run global-install-packages-python" }'
grep -qF 'uv = "latest"' "$__config" || fail "uv is missing from the Python module"
grep -qF '"python/config/mise/tasks/global-install-packages-python.sh"' "$__config" ||
    fail "Python package task is not owned by the Python module"
grep -qF 'pipx.uvx = true' "$__config" || fail "pipx setting is missing"
grep -qF 'python.uv_venv_auto = true' "$__config" || fail "Python virtual environment setting is missing"
grep -qF 'python.uv_venv_create_args = ["--seed"]' "$__config" ||
    fail "Python virtual environment arguments are missing"
[[ ! -e "home/.config/mise/conf.d/uv.toml" ]] ||
    fail "standalone uv module remains"
echo "python tool module passed."
