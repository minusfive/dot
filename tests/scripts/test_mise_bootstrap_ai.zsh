#!/usr/bin/env zsh
# Test the AI bootstrap configuration.

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing AI bootstrap configuration..."

local __config=".config/mise/conf.d/bootstrap-ai.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/AGENTS.md" ]] || fail "missing shared global instructions"
[[ ! -e "AGENTS.md" ]] || fail "repository AGENTS.md source should move under home"
[[ ! -e "CLAUDE.md" ]] || fail "redundant repository CLAUDE.md source should be removed"
[[ -d "home/.agents/skills" ]] || fail "missing global agent skills"
[[ -f "home/.claude/settings.json" ]] || fail "missing Claude settings"
[[ -f "home/.claude/statusline-command.sh" ]] || fail "missing Claude statusline"
[[ -f "home/.copilot/copilot-instructions.md" ]] || fail "missing Copilot instructions"
[[ -f "home/.copilot/statusline-context.sh" ]] || fail "missing Copilot statusline"
[[ -f "home/.config/opencode/opencode.jsonc" ]] || fail "missing OpenCode config"
[[ -f "home/.config/opencode/plugin/env-protection.ts" ]] || fail "missing OpenCode plugin"
[[ -f "home/.config/opencode/tui.json" ]] || fail "missing OpenCode TUI config"
[[ ! -e ".config/opencode" ]] || fail "OpenCode source directory should be removed"
[[ ! -e ".config/mcphub/servers.json" ]] || fail "obsolete McpHub source should be removed"

grep -qF '"~/AGENTS.md" = { source = "../../../home/AGENTS.md", mode = "symlink" }' "$__config" || fail "AGENTS.md source is missing"
grep -qF '"~/CLAUDE.md" = { source = "../../../home/AGENTS.md", mode = "symlink" }' "$__config" || fail "CLAUDE.md source is missing"
grep -qF '"~/.agents" = { source = "../../../home/.agents", mode = "symlink-each" }' "$__config" || fail "global agents source is missing"
grep -qF '"~/.claude" = { source = "../../../home/.claude", mode = "symlink-each" }' "$__config" || fail "Claude source is missing"
grep -qF '"~/.copilot" = { source = "../../../home/.copilot", mode = "symlink-each" }' "$__config" || fail "Copilot source is missing"
grep -qF '"~/.config/opencode" = { source = "../../../home/.config/opencode", mode = "symlink-each" }' "$__config" || fail "OpenCode source is missing"
grep -qF '"~/.config/opencode/package.json"' "$__config" && fail "OpenCode runtime manifest must not be managed"
grep -qF '"~/.config/opencode/bun.lock"' "$__config" && fail "OpenCode lockfile must not be managed"
grep -qF 'statusline-command.sh' home/.claude/settings.json || fail "Claude statusline reference is missing"

for __pattern in '^/\.agents' '^/\.claude' '^/\.copilot' '^/home'; do
    grep -qF "$__pattern" .stow-local-ignore || fail "missing Stow boundary: $__pattern"
done

echo "AI bootstrap configuration passed."
