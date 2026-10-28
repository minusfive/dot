#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing agents bootstrap configuration..."

local __config="home/.config/mise/conf.d/agents.toml"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/AGENTS.md" ]] || fail "missing shared global instructions"
[[ -d "home/.agents/skills" ]] || fail "missing tracked agent skills"
[[ -f "home/.agents/agents/orchestrator.md" ]] || fail "missing shared orchestrator profile"
grep -qF "You are an orchestrator for multi-step work" home/.agents/agents/orchestrator.md ||
    fail "orchestrator profile does not state its role"
[[ -d ".agents/eval-workspaces" ]] || fail "missing repository-local evaluation workspace"

grep -qF '"~/AGENTS.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "AGENTS.md source is missing"
grep -qF '"~/CLAUDE.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "CLAUDE.md source is missing"
grep -qF 'exclude = ["skills/**/evals/**", "eval-workspaces/**"]' "$__config" ||
    fail "evaluation artifact exclusions are missing"
for __target in '"~/AGENTS.md"' '"~/CLAUDE.md"' '"~/.agents"'; do
    if [[ -f home/.config/mise/conf.d/bootstrap-ai.toml ]] &&
        grep -qF "$__target" home/.config/mise/conf.d/bootstrap-ai.toml; then
        fail "legacy AI declaration still owns $__target"
    fi
done
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

if find "$HOME/.agents" \( -path '*/skills/*/evals' -o -path '*/skills/*/evals/*' -o -path '*/eval-workspaces' -o -path '*/eval-workspaces/*' \) -print | grep -q .; then
    fail "evaluation artifacts are still deployed into ~/.agents"
fi
[[ ! -e "$HOME/.agents/skills/agentic-projects/evals/evals.json" ]] ||
    fail "tracked skill evaluation definition must remain repository-local"
[[ ! -e "$HOME/.agents/eval-workspaces" ]] ||
    fail "repository evaluation workspace must remain local"

echo "Agents bootstrap configuration passed."
