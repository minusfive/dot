#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise:cleanup task..."

local __task="home/.config/mise/tasks/mise/cleanup.zsh"
local __fixture_dir="$(mktemp -d)"
local __fixture_home="$__fixture_dir/home"
local __fixture_root="$__fixture_dir/repository"
local __source_dir="$__fixture_root/home"
local __target_dir="$__fixture_home/.config/mise"
local __output="$__fixture_dir/output"
local __failure_output="$__fixture_dir/failure-output"
local __block_failure_output="$__fixture_dir/block-failure-output"
trap 'rm -rf "$__fixture_dir"' EXIT

[[ -x "$__task" ]] || fail "cleanup task is not executable"
grep -qF '"~/.config/mise/tasks/mise/cleanup.zsh"' \
    home/.config/mise/conf.d/module.mise.toml ||
    fail "cleanup task is not deployed by the mise control plane"

mkdir -p \
    "$__source_dir/.config/mise/conf.d" \
    "$__source_dir/.config/mise/active" \
    "$__source_dir/.config/zsh" \
    "$__source_dir/.local/state/mise" \
    "$__target_dir/conf.d" \
    "$__target_dir/active" \
    "$__target_dir/conf.d/old" \
    "$__fixture_home/.config/zsh" \
    "$__fixture_home/.local/state/mise/tracked-configs"
cat > "$__source_dir/.config/mise/conf.d/module.fixture.toml" <<'EOF'
[dotfiles]
"~/.config/zsh/.zshrc/active" = { block = '''
active
''' }
EOF
printf 'external\n' > "$__fixture_dir/external"
cat > "$__source_dir/.config/mise/cleanup.paths" <<'EOF'
# fixture inventory
.config/mise
.config/zsh
.local/state/mise
EOF
printf '# Relative target paths and block IDs that historically belonged to this repository.\n' \
    > "$__source_dir/.config/mise/cleanup.blocks"
printf '%s\t%s\n' '.config/zsh/.zshrc' active >> "$__source_dir/.config/mise/cleanup.blocks"
printf '%s\t%s\n' '.config/zsh/.zshrc' removed >> "$__source_dir/.config/mise/cleanup.blocks"
cat > "$__fixture_home/.config/zsh/.zshrc" <<'EOF'
header
# >>> mise:active >>> managed by mise — do not edit between markers
active
# <<< mise:active <<<
# >>> mise:removed >>> managed by mise — do not edit between markers
removed
# <<< mise:removed <<<
# >>> mise:foreign >>> managed by mise — do not edit between markers
foreign
# <<< mise:foreign <<<
EOF
printf 'active\n' > "$__source_dir/.config/mise/conf.d/active.toml"
printf 'active\n' > "$__source_dir/.config/mise/active/current"

ln -s "$__source_dir/.config/mise/conf.d/active.toml" \
    "$__target_dir/conf.d/active.toml"
ln -s "$__source_dir/.config/mise/conf.d/direct-removed.toml" \
    "$__target_dir/conf.d/direct-removed.toml"
ln -s "$__source_dir/.config/mise/conf.d/removed.toml" \
    "$__target_dir/conf.d/removed.toml"
ln -s "$__source_dir/.config/mise/conf.d/old/removed.toml" \
    "$__target_dir/conf.d/old/removed.toml"
ln -s "$__source_dir/.config/mise/active/current" \
    "$__target_dir/active/current"
ln -s "$__source_dir/.config/mise/active/removed" \
    "$__target_dir/active/removed"
ln -s "$__source_dir/.config/zsh/removed.zsh" \
    "$__fixture_home/.config/zsh/removed.zsh"
ln -s "$__source_dir/.config/zsh/tracked-config.zsh" \
    "$__fixture_home/.local/state/mise/tracked-configs/config"
ln -s "$__fixture_dir/missing-external" "$__fixture_home/external-broken"
ln -s "$__fixture_dir/external" "$__target_dir/external"

env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    MISE_PROJECT_ROOT="$__fixture_root" \
    usage_dry_run=true \
    zsh "$__task" > "$__output"

grep -qF "would remove stale mise link" "$__output" ||
    fail "dry run did not report stale links"
grep -qF "would remove stale mise block" "$__output" ||
    fail "dry run did not report stale blocks"
[[ -L "$__target_dir/conf.d/removed.toml" ]] || fail "dry run removed a stale link"
grep -qF 'mise:removed' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "dry run removed a stale block"
[[ -L "$__fixture_home/.config/zsh/removed.zsh" ]] ||
    fail "dry run removed a stale link outside mise"
[[ -L "$__fixture_home/.local/state/mise/tracked-configs/config" ]] ||
    fail "dry run removed a tracked-config link"
[[ -L "$__fixture_home/external-broken" ]] || fail "dry run removed an external link"

env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    MISE_PROJECT_ROOT="$__fixture_root" \
    zsh "$__task" > "$__output"

[[ -L "$__target_dir/conf.d/active.toml" ]] || fail "active managed link was removed"
[[ ! -L "$__target_dir/conf.d/direct-removed.toml" ]] ||
    fail "broken direct repository link remains"
[[ ! -L "$__target_dir/conf.d/removed.toml" ]] || fail "stale managed link remains"
[[ ! -L "$__target_dir/conf.d/old/removed.toml" ]] ||
    fail "stale link with a missing source directory remains"
[[ -L "$__target_dir/active/current" ]] || fail "active symlink-each link was removed"
[[ ! -L "$__target_dir/active/removed" ]] || fail "stale symlink-each link remains"
grep -qF 'mise:active' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "active mise block was removed"
if grep -qF 'mise:removed' "$__fixture_home/.config/zsh/.zshrc"; then
    fail "stale mise block remains"
fi
grep -qF 'mise:foreign' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "unlisted mise block was removed"
[[ ! -L "$__fixture_home/.config/zsh/removed.zsh" ]] ||
    fail "stale link outside the mise directory remains"
[[ -L "$__fixture_home/.local/state/mise/tracked-configs/config" ]] ||
    fail "tracked-config link was removed"
[[ -L "$__fixture_home/external-broken" ]] || fail "external broken link was removed"

local __blocks_backup="$__fixture_dir/cleanup.blocks.backup"
cp "$__source_dir/.config/mise/cleanup.blocks" "$__blocks_backup"
printf '%s\t%s\n' '../outside' removed >> "$__source_dir/.config/mise/cleanup.blocks"
if env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    MISE_PROJECT_ROOT="$__fixture_root" \
    zsh "$__task" > "$__block_failure_output" 2>&1; then
    fail "cleanup accepted a block target outside HOME"
fi
grep -qF "outside HOME" "$__block_failure_output" ||
    fail "cleanup did not explain the block path containment refusal"
mv "$__blocks_backup" "$__source_dir/.config/mise/cleanup.blocks"


[[ -L "$__target_dir/external" ]] || fail "external link was removed"

mkdir -p "$__fixture_dir/external-source"
ln -s "$__fixture_dir/external-source" "$__source_dir/alias"
ln -s "$__source_dir/alias/missing" "$__fixture_home/.config/zsh/physical-bypass"
if env \
    HOME="$__fixture_home" \
    XDG_CONFIG_HOME="$__fixture_home/.config" \
    MISE_PROJECT_ROOT="$__fixture_root" \
    zsh "$__task" > "$__failure_output" 2>&1; then
    fail "cleanup removed a link whose physical source is outside the repository"
fi
grep -qF "outside this repository" "$__failure_output" ||
    fail "cleanup did not explain the physical containment refusal"
[[ -L "$__fixture_home/.config/zsh/physical-bypass" ]] ||
    fail "cleanup removed the physically external link"

echo "mise:cleanup task passed."
