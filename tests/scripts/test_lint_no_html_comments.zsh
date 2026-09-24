#!/usr/bin/env zsh
# Regression tests for the Markdown HTML-comment lint task.

set -euo pipefail

local __test_dir="$(realpath "$(dirname "$0")")"
local __root_dir="$(dirname "$(dirname "$__test_dir")")"
local __tmp_dir="$(mktemp -d)"
trap 'rm -rf "$__tmp_dir"' EXIT

fail() {
    echo "FAIL: $1"
    exit 1
}

cd "$__root_dir"

cat >"$__tmp_dir/fenced.md" <<'EOF'
```html
<!-- This example is inside a fenced code block. -->
```

~~~html
<!-- This example uses a tilde fence. -->
~~~
EOF

if ! mise run lint-no-html-comments -- "$__tmp_dir/fenced.md" >/dev/null; then
    fail "fenced HTML comment examples should be ignored"
fi

cat >"$__tmp_dir/real.md" <<'EOF'
# Real comment

<!-- This comment must fail the lint. -->
EOF

local __output
if __output="$(mise run lint-no-html-comments -- "$__tmp_dir/real.md" 2>&1)"; then
    fail "HTML comments outside fenced code blocks should fail the lint"
fi

print -r -- "$__output" | grep -qF "HTML comments are not allowed in Markdown files." ||
    fail "lint failure should explain the rule"
print -r -- "$__output" | grep -qF "$__tmp_dir/real.md:3:" ||
    fail "lint failure should report the real comment line"

echo "Lint regression tests passed."
