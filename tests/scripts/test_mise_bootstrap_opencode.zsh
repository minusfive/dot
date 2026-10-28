#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing OpenCode bootstrap configuration..."

local __config="home/.config/mise/conf.d/opencode.personal.toml"
[[ -f "$__config" ]] || fail "missing $__config"
assert_personal_module_package opencode brew:opencode
git ls-files --error-unmatch \
    home/.config/opencode/opencode.jsonc \
    home/.config/opencode/tui.json \
    home/.config/opencode/plugin/env-protection.ts >/dev/null ||
    fail "tracked OpenCode source files are missing"

grep -qF '"opencode/config/opencode" = { source = "~/dev/personal/dot/home/.config/opencode", mode = "symlink-each", variants = [{ default = true, target = "{{ xdg_config_home }}/opencode" }] }' "$__config" ||
    fail "OpenCode module declaration is incorrect"
if grep -qF '[tools]' "$__config"; then
    fail "OpenCode must use the Homebrew package manager"
fi
if grep -qF 'package.json' "$__config" || grep -qF 'bun.lock' "$__config" || grep -qF 'node_modules' "$__config"; then
    fail "OpenCode runtime dependencies must remain unmanaged"
fi
if [[ -f home/.config/mise/conf.d/bootstrap-ai.toml ]] &&
    grep -qF '"opencode/config/opencode"' home/.config/mise/conf.d/bootstrap-ai.toml; then
    fail "legacy AI declaration still owns the OpenCode target"
fi
if git grep -IlE 'BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|(^|[^[:alnum:]])(token|password|secret|api[-_]?key)[[:space:]]*[:=]' -- home/.config/opencode >/dev/null; then
    fail "credential-like content found in tracked OpenCode sources"
fi

[[ -d "$HOME/.config/opencode" && ! -L "$HOME/.config/opencode" ]] ||
    fail "OpenCode target must be a physical directory"
for __path in \
    "$HOME/.config/opencode/opencode.jsonc" \
    "$HOME/.config/opencode/tui.json" \
    "$HOME/.config/opencode/plugin/env-protection.ts"; do
    [[ -L "$__path" ]] || fail "OpenCode managed target is not a symlink: $__path"
    case "$(readlink "$__path")" in
        /*) fail "OpenCode managed link is absolute: $__path" ;;
    esac
done
[[ -f "$HOME/.config/opencode/package.json" ]] || fail "OpenCode package manifest was not preserved"
[[ -f "$HOME/.config/opencode/bun.lock" ]] || fail "OpenCode lockfile was not preserved"
[[ -d "$HOME/.config/opencode/node_modules" ]] || fail "OpenCode dependencies were not preserved"
if find "$HOME/.config/opencode" -maxdepth 1 -type l \( -name 'package.json' -o -name 'bun.lock' -o -name 'node_modules' \) | grep -q .; then
    fail "OpenCode runtime dependency became managed"
fi

echo "OpenCode bootstrap configuration passed."
