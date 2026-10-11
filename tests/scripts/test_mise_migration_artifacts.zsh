#!/usr/bin/env zsh

set -euo pipefail

typeset -r __test_dir="$(realpath "$(dirname "$0")")"
typeset -r __root_dir="$(dirname "$(dirname "$__test_dir")")"

function main {
    local __project_dir="$__root_dir/.agents/projects/stow-to-mise-migration"
    local __fixture_root="$(mktemp -d)"
    local __fixture_dir="$__fixture_root/stow-to-mise-migration"
    local __output="$__fixture_root/output.log"
    local __planning_work_tmp="$__fixture_root/planning-work.md"

    trap 'rm -rf -- "${__fixture_root:-}"' EXIT
    cp -R "$__project_dir" "$__fixture_dir"

    "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1

    cat >"$__fixture_dir/research/pending-decisions.md" <<'EOF'
# Pending Migration Decisions

## Decision records

1. **Decision key:** `DEC-test`
   **Status:** `resolved`
   **Resolution:** Use the selected behavior.
EOF
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted a resolved pending decision."
        exit 1
    fi
    grep -qF -- "Resolved decisions must be removed" "$__output"

    cp "$__project_dir/research/pending-decisions.md" \
        "$__fixture_dir/research/pending-decisions.md"
    awk '
        /^### `PLAN-03`:/ && !inserted {
            print "  - `DEC-unrecorded`: missing artifact."
            inserted = 1
        }
        { print }
    ' "$__fixture_dir/research/planning-work.md" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/research/planning-work.md"
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted a decision without an authoritative artifact."
        exit 1
    fi
    grep -qF -- "Resolved decision is not encoded" "$__output"

    print "Migration artifact decision checks passed."
}

main "$@"
