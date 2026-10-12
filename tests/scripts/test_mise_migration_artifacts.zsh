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

    sed '/^key = "opencode"$/,/^$/ s/^status = "done"$/status = "blocked"/' \
        "$__fixture_dir/module-registry.toml" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/module-registry.toml"
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted a roadmap and registry status mismatch."
        exit 1
    fi
    grep -qF -- "Story status mismatch for MIG-MODULE-opencode" "$__output"

    cp "$__project_dir/module-registry.toml" \
        "$__fixture_dir/module-registry.toml"
    sed 's/^- Approval state: `approved`$/- Approval state: `pending`/' \
        "$__fixture_dir/research/inventories/opencode.md" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/research/inventories/opencode.md"
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted an approval and inventory state mismatch."
        exit 1
    fi
    grep -qF -- "Inventory approval state mismatch for MIG-MODULE-opencode" "$__output"

    cp "$__project_dir/research/inventories/opencode.md" \
        "$__fixture_dir/research/inventories/opencode.md"
    sed '/^key = "gh"$/,/^$/ s/^status = "done"$/status = "done"/' \
        "$__fixture_dir/module-registry.toml" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/module-registry.toml"
    sed '/^## 6\. Story `MIG-MODULE-gh`:/,/^## 7\./ s/^- Status: `done`$/- Status: `done`/' \
        "$__fixture_dir/plans/migration-roadmap-v1.md" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/plans/migration-roadmap-v1.md"
    sed 's/^- Approval state: `approved`$/- Approval state: `pending`/; s/^- Final decision: `approved for execution`$/- Final decision: `pending`/' \
        "$__fixture_dir/research/approvals/MIG-MODULE-gh.md" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/research/approvals/MIG-MODULE-gh.md"
    sed 's/^- Approval state: `approved`$/- Approval state: `pending`/' \
        "$__fixture_dir/research/inventories/gh.md" >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/research/inventories/gh.md"
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted a completed story without approved authorization."
        exit 1
    fi
    grep -qF -- "Active or completed story lacks approved authorization: MIG-MODULE-gh" "$__output"

    cp "$__project_dir/module-registry.toml" \
        "$__fixture_dir/module-registry.toml"
    cp "$__project_dir/plans/migration-roadmap-v1.md" \
        "$__fixture_dir/plans/migration-roadmap-v1.md"
    cp "$__project_dir/research/approvals/MIG-MODULE-gh.md" \
        "$__fixture_dir/research/approvals/MIG-MODULE-gh.md"
    cp "$__project_dir/research/inventories/gh.md" \
        "$__fixture_dir/research/inventories/gh.md"
    sed 's/^- Focused test:.*/- Focused test: `not specified in inventory`/' \
        "$__fixture_dir/research/approvals/MIG-MODULE-git.md" \
        >"$__planning_work_tmp"
    mv "$__planning_work_tmp" "$__fixture_dir/research/approvals/MIG-MODULE-git.md"
    if "$__fixture_dir/scripts/validate-artifacts.zsh" >"$__output" 2>&1; then
        print -u2 "Validator accepted an approval focused-test mismatch."
        exit 1
    fi
    grep -qF -- "Focused test mismatch for MIG-MODULE-git" "$__output"

    cp "$__project_dir/research/approvals/MIG-MODULE-git.md" \
        "$__fixture_dir/research/approvals/MIG-MODULE-git.md"
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
