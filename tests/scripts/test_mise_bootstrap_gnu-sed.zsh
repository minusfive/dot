#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing GNU sed package bootstrap configuration..."
assert_module_package gnu-sed brew:gnu-sed

local __config="home/.config/mise/conf.d/module.gnu-sed.toml"
local __source="home/.config/gnu-sed/zshrc.zsh"
local __control_plane="home/.config/mise/conf.d/module.mise.toml"
[[ -f "$__source" ]] || fail "missing GNU sed Zsh source"
zsh -n "$__source" || fail "GNU sed Zsh source has syntax errors"
grep -qF '[bootstrap.packages]' "$__config" ||
    fail "GNU sed package declaration is missing"
grep -qF '"brew:gnu-sed" = "latest"' "$__config" ||
    fail "GNU sed package declaration is incorrect"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/gnu-sed" = { source = "~/dev/personal/dot/home/.config/gnu-sed/zshrc.zsh", template = "tera" }' "$__config" ||
    fail "GNU sed Zone 0 template declaration is missing"
grep -qF '"~/.config/mise/conf.d/module.gnu-sed.toml"' "$__control_plane" ||
    fail "mise control-plane module does not deploy module.gnu-sed.toml"
if grep -qF '"~/.config/gnu-sed"' "$__config"; then
    fail "GNU sed module must not manage a standalone runtime target"
fi
if find home/.config/gnu-sed -type f ! -name zshrc.zsh | grep -q .; then
    fail "GNU sed source tree contains runtime files"
fi

mkdir -p "$__root_dir/.test-fixtures"
local __fixture="$(mktemp -d "$__root_dir/.test-fixtures/gnu-sed.XXXXXX")"
local __fake_bin="$__fixture/bin"
local __fake_prefix="$__fixture/homebrew/opt/gnu-sed"
local __fallback_bin="$__fixture/fallback-bin"
trap 'rm -rf -- "$__fixture"' EXIT
mkdir -p "$__fake_bin" "$__fake_prefix/libexec/gnubin" "$__fallback_bin"

cat > "$__fake_bin/brew" <<'EOF'
#!/bin/sh
if [ "$#" -eq 2 ] && [ "$1" = "--prefix" ] && [ "$2" = "gnu-sed" ]; then
    printf '%s\n' "$FAKE_BREW_PREFIX"
    exit 0
fi
exit 1
EOF
cat > "$__fake_prefix/libexec/gnubin/sed" <<'EOF'
#!/bin/sh
printf '%s\n' 'GNU sed'
EOF
cat > "$__fallback_bin/sed" <<'EOF'
#!/bin/sh
printf '%s\n' 'fallback sed'
EOF
chmod +x "$__fake_bin/brew" "$__fake_prefix/libexec/gnubin/sed" "$__fallback_bin/sed"

local __before="$(
    env -u FAKE_BREW_PREFIX \
        PATH="$__fallback_bin:$__fake_bin:$PATH" \
        zsh -fc 'command -v sed; sed --sentinel'
)"
[[ "${__before%%$'\n'*}" == "$__fallback_bin/sed" ]] ||
    fail "fallback sed does not resolve before the GNU sed source loads"
[[ "${__before##*$'\n'}" == "fallback sed" ]] ||
    fail "fallback sed behavior changed before the GNU sed source loads"

local __after="$(
    env FAKE_BREW_PREFIX="$__fake_prefix" \
        PATH="$__fake_bin:$__fallback_bin:$PATH" \
        zsh -fc 'source "$1"; command -v sed; sed --sentinel' \
        -- "$__root_dir/$__source"
)"
[[ "${__after%%$'\n'*}" == "$__fake_prefix/libexec/gnubin/sed" ]] ||
    fail "GNU sed does not resolve as sed after the source loads"
[[ "${__after##*$'\n'}" == "GNU sed" ]] ||
    fail "GNU sed behavior is not exposed as sed after the source loads"

echo "GNU sed package bootstrap configuration passed."
