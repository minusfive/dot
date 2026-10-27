#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Claude bootstrap configuration..."

local __config="home/.config/mise/conf.d/claude.toml"
local __agent_profile="home/.agents/agents/orchestrator.md"
[[ -f "$__config" ]] || fail "missing $__config"
assert_module_package claude brew-cask:claude-code
[[ -f "$__agent_profile" ]] || fail "missing shared orchestrator profile"
[[ -f "home/.claude/settings.json" ]] || fail "missing Claude settings"
[[ -x "home/.claude/statusline-command.sh" ]] || fail "missing executable Claude statusline"
[[ -L "home/.claude/skills" ]] || fail "missing repository-only Claude skills alias"

grep -qF '"~/.claude/settings.json" = { source = "~/dev/personal/dot/home/.claude/settings.json", mode = "symlink" }' "$__config" ||
    fail "Claude settings source is missing"
grep -qF '"~/.claude/agents/orchestrator.md" = { source = "~/dev/personal/dot/home/.agents/agents/orchestrator.md", mode = "symlink" }' "$__config" ||
    fail "Claude orchestrator source is missing"
grep -qF '"~/.claude/skills" = { source = "~/dev/personal/dot/home/.agents/skills", mode = "symlink-each", exclude = ["**/evals/**"] }' "$__config" ||
    fail "Claude skills source or exclusion is incorrect"
grep -qF '"~/.claude/statusline-command.sh" = { source = "~/dev/personal/dot/home/.claude/statusline-command.sh", mode = "symlink" }' "$__config" ||
    fail "Claude statusline source is missing"
if grep -qF '"~/.claude"' home/.config/mise/conf.d/bootstrap-ai.toml; then
    fail "legacy AI declaration still owns ~/.claude"
fi
grep -qF '"~/.config/mise/conf.d/claude.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "mise control-plane module does not deploy claude.toml"

bash -n home/.claude/statusline-command.sh || fail "Claude statusline has syntax errors"
test "$(readlink home/.claude/skills)" = "../.agents/skills" ||
    fail "repository-only Claude skills alias changed"
if git grep -IlE 'AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9_]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY' -- home/.claude >/dev/null; then
    fail "credential-like content found in tracked Claude sources"
fi

[[ -d "$HOME/.claude" && ! -L "$HOME/.claude" ]] || fail "Claude target must be a physical directory"
[[ -L "$HOME/.claude/settings.json" ]] || fail "Claude settings target is not a symlink"
[[ -L "$HOME/.claude/statusline-command.sh" ]] || fail "Claude statusline target is not a symlink"
[[ -L "$HOME/.claude/agents/orchestrator.md" ]] || fail "Claude orchestrator target is not a symlink"
[[ "$(realpath "$HOME/.claude/settings.json")" == "$(realpath home/.claude/settings.json)" ]] ||
    fail "Claude settings target resolves to the wrong source"
[[ "$(realpath "$HOME/.claude/statusline-command.sh")" == "$(realpath home/.claude/statusline-command.sh)" ]] ||
    fail "Claude statusline target resolves to the wrong source"
[[ "$(realpath "$HOME/.claude/agents/orchestrator.md")" == "$(realpath "$__agent_profile")" ]] ||
    fail "Claude orchestrator target resolves to the wrong source"
[[ -d "$HOME/.claude/skills" && ! -L "$HOME/.claude/skills" ]] || fail "Claude skills target must be a physical directory"

local __absolute_link
while IFS= read -r __absolute_link; do
    case "$(readlink "$__absolute_link")" in
        /*) fail "absolute Claude link: $__absolute_link" ;;
    esac
done < <(find "$HOME/.claude/skills" -type l -print)
if find "$HOME/.claude/skills" \( -path '*/evals' -o -path '*/evals/*' \) -print | grep -q .; then
    fail "evaluation artifacts are still linked into ~/.claude/skills"
fi
[[ ! -e "$HOME/.claude/skills/agentic-projects/evals" ]] ||
    fail "skill evaluation data must remain repository-local"
[[ -L "$HOME/.claude/skills/agent-instructions-authoring/SKILL.md" ]] ||
    fail "Claude skills target is missing a tracked skill"
[[ "$(realpath "$HOME/.claude/skills/agent-instructions-authoring/SKILL.md")" == "$(realpath home/.agents/skills/agent-instructions-authoring/SKILL.md)" ]] ||
    fail "Claude skills target does not use the canonical agents source"

[[ -e "$HOME/.claude/history.jsonl" ]] || fail "Claude history runtime state was not preserved"
[[ -e "$HOME/.claude/mcp-needs-auth-cache.json" ]] || fail "Claude authentication cache was not preserved"

echo "Claude bootstrap configuration passed."
