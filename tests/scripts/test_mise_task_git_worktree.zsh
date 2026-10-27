#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing git:worktree closed PR cleanup..."

local __fixture_dir
__fixture_dir="$(test_fixture_dir git-worktree)" || exit 1
local __bin_dir="$__fixture_dir/bin"
local __repository="$__fixture_dir/repository"
local __task="$__root_dir/home/.config/mise/tasks/git/worktree.ts"
trap 'rm -rf -- "$__fixture_dir"' EXIT

mkdir -p "$__bin_dir" "$__repository"
git -C "$__repository" init -q
git -C "$__repository" remote add origin https://github.com/minusfive/dot.git

cat > "$__bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

has_jq=false
for arg in "$@"; do
    [[ "$arg" == "--jq" ]] && has_jq=true
done

if [[ "$*" == *"state=closed"* ]]; then
    if [[ "$has_jq" == true ]]; then
        printf '%s\n' '[{"number":1,"title":"closed","head":{"ref":"closed-branch"}}]'
    else
        python3 - <<'PY'
import json

print(json.dumps([
    {"number": index, "title": "closed", "head": {"ref": f"closed-{index}"}, "body": "x" * 100}
    for index in range(10000)
]))
PY
    fi
    exit 0
fi

if [[ "$*" == *"state=open"* ]]; then
    printf '%s\n' '[]'
    exit 0
fi

printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$__bin_dir/gh"

(
    cd "$__repository"
    env \
        PATH="$__bin_dir:$PATH" \
        usage_delete=true \
        usage_name=ALL_CLOSED_PRS \
        bun "$__task"
) | grep -qF "No worktrees found for closed pull requests."

echo "git:worktree closed PR cleanup passed."
