#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise:cleanup:inventory task..."

local __task="home/.config/mise/tasks/mise/cleanup/inventory.zsh"
local __fixture_dir="$(mktemp -d)"
local __fixture_root="$__fixture_dir/repository"
local __manifest="$__fixture_root/home/.config/mise/cleanup.paths"
local __blocks_manifest="$__fixture_root/home/.config/mise/cleanup.blocks"
trap 'rm -rf "$__fixture_dir"' EXIT

[[ -x "$__task" ]] || fail "cleanup inventory task is not executable"
grep -qF '"~/.config/mise/tasks/mise/cleanup/inventory.zsh"' \
    home/.config/mise/conf.d/module-mise.toml ||
    fail "cleanup inventory task is not deployed by the mise control plane"

mkdir -p "$__fixture_root/home/.config/mise/conf.d"
cat > "$__fixture_root/home/.config/mise/conf.d/module-example.toml" <<'EOF'
[dotfiles]
"~/.config/example" = { source = "~/dev/personal/dot/home/.config/example", mode = "symlink-each" }
"~/.config/example/config.toml/old" = { block = '''
old
''' }
EOF
mkdir -p "$__fixture_root/home/.config/example"
printf '# Relative paths under $HOME that historically contained repository-managed targets.\nlegacy/managed\n' \
    > "$__manifest"

git -C "$__fixture_root" init -q
git -C "$__fixture_root" config user.email test@example.com
git -C "$__fixture_root" config user.name "Cleanup Test"
git -C "$__fixture_root" add home
git -C "$__fixture_root" -c commit.gpgsign=false commit -q -m "seed cleanup inventory fixture"

env MISE_PROJECT_ROOT="$__fixture_root" zsh "$__task"

grep -qF 'legacy/managed' "$__manifest" ||
    fail "inventory removed an existing historical path"
grep -qF '.config/example' "$__manifest" ||
    fail "inventory omitted a current module path"
grep -qF $'.config/example/config.toml\told' "$__blocks_manifest" ||
    fail "inventory omitted a current block"
if grep -qF '"' "$__manifest"; then
    fail "cleanup inventory contains quoted paths"
fi

echo "mise:cleanup:inventory task passed."
