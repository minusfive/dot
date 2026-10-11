#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing agents bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.agents.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/AGENTS.md" ]] || fail "missing shared global instructions"
[[ -d "home/.agents/skills" ]] || fail "missing tracked agent skills"
[[ -d "home/.agents/eval-workspaces" ]] || fail "missing durable evaluation metadata"

grep -qF '"~/AGENTS.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "AGENTS.md source is missing"
grep -qF '"~/CLAUDE.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "CLAUDE.md source is missing"
grep -qF 'exclude = ["skills/**/evals/**/outputs/**", "eval-workspaces/**/outputs/**"]' "$__config" ||
    fail "generated evaluation output exclusions are missing"
for __target in '"~/AGENTS.md"' '"~/CLAUDE.md"' '"~/.agents"'; do
    if grep -qF "$__target" home/.config/mise/conf.d/bootstrap-ai.toml; then
        fail "legacy AI declaration still owns $__target"
    fi
done
grep -qF '"~/.config/mise/conf.d/module.agents.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.agents.toml"

mise run lint-skill-index >/dev/null || fail "root skill index validation failed"
mise run lint-skill-index --base-path home >/dev/null || fail "home skill index validation failed"

[[ -L "$HOME/AGENTS.md" ]] || fail "global AGENTS.md target is not a symlink"
[[ -L "$HOME/CLAUDE.md" ]] || fail "global CLAUDE.md target is not a symlink"
[[ "$(realpath "$HOME/AGENTS.md")" == "$(realpath home/AGENTS.md)" ]] ||
    fail "global AGENTS.md target resolves to the wrong source"
[[ "$(realpath "$HOME/CLAUDE.md")" == "$(realpath home/AGENTS.md)" ]] ||
    fail "global CLAUDE.md target resolves to the wrong source"
[[ -d "$HOME/.agents" && ! -L "$HOME/.agents" ]] || fail "agents target must be a physical directory"

local __absolute_link
while IFS= read -r __absolute_link; do
    case "$(readlink "$__absolute_link")" in
        /*) fail "absolute agents link: $__absolute_link" ;;
    esac
done < <(find "$HOME/.agents" -type l -print)

if find "$HOME/.agents" -type l \( -path '*/evals/*/outputs/*' -o -path '*/eval-workspaces/*/outputs/*' \) | grep -q .; then
    fail "generated evaluation output is still linked into ~/.agents"
fi
[[ -L "$HOME/.agents/skills/agentic-projects/evals/evals.json" ]] ||
    fail "tracked skill evaluation definition is missing"
[[ -L "$HOME/.agents/eval-workspaces/agent-instructions-evaluation/iteration-1/benchmark.json" ]] ||
    fail "durable evaluation metadata is missing"

echo "Agents bootstrap configuration passed."
