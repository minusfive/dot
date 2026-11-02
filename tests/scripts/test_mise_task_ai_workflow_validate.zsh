#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    local fixture valid_file delivery_file historical_file future now output
    local contract_schema ledger_schema
    export MISE_CONFIG_DIR="$__root_dir/home/.config/mise"
    export TMPDIR="$HOME/.cache"

    fixture="$(test_fixture_dir workflow-validate)"
    trap "rm -rf -- '$fixture'" EXIT

    contract_schema="$__root_dir/home/.config/mise/tasks/ai/workflow/contract.schema.json"
    ledger_schema="$__root_dir/home/.config/mise/tasks/ai/workflow/ledger.schema.json"
    now="$(date -u "+%Y-%m-%dT%H:%M:%SZ")"
    future="2099-01-01T00:00:00Z"
    valid_file="$fixture/valid.json"

    jq -n --arg now "$now" --arg future "$future" '{
        version: 1,
        workflow_id: "workflow-1",
        contracts: [{
            workflow_id: "workflow-1",
            candidate_id: "candidate-1",
            lane_id: "lane-1",
            artifact_id: "artifact-1",
            state_owner: "workflow-policy",
            worktree: {
                path: "opaque://worktree/workflow-1",
                ref: "refs/heads/chore/workflow-guardrails"
            },
            owned_paths: ["home/.config/mise/tasks/ai/workflow"],
            excluded_paths: ["home/.agents/skills"],
            authorization: {
                record_id: "auth-1",
                source: "external_attestation",
                reference: "attestation://authorization-1",
                scope: "edit-owned-paths",
                owned_paths: ["home/.config/mise/tasks/ai/workflow"],
                expires_at: $future
            },
            budget: {
                mode: "advisory",
                wall_clock_minutes: 30,
                tool_calls: 25,
                expires_at: $future
            },
            checkpoint: {
                initial_at: $now,
                last_at: $now,
                next_due_at: $future,
                status: "pending"
            },
            dependencies: [],
            acceptance: ["owned paths and evidence are recorded"],
            evidence_refs: ["artifact://workflow-1/checkpoint-1"],
            redaction_status: "clean",
            terminal_state: null,
            state: "validate"
        }],
        records: []
    }' >"$valid_file"

    jq empty "$contract_schema" >/dev/null ||
        fail "contract schema is not valid JSON"
    jq empty "$ledger_schema" >/dev/null ||
        fail "ledger schema is not valid JSON"
    jq -e '
        .properties.worktree.properties.path.pattern ==
            "^(worktree://[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*|opaque://worktree/[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*)$" and
        .properties.budget.properties.mode.const == "advisory" and
        ."$schema" == "https://json-schema.org/draft/2020-12/schema"
    ' "$contract_schema" >/dev/null ||
        fail "contract schema does not define the advisory trust boundary"
    jq -e '
        .properties.contracts.items."$ref" ==
            "https://minusfive.dev/schemas/mise-workflow-contract.json" and
        .properties.records.items.allOf[0]."$ref" ==
            "https://minusfive.dev/schemas/mise-workflow-contract.json" and
        (.description | contains("External orchestration owns"))
    ' "$ledger_schema" >/dev/null ||
        fail "ledger schema does not describe external enforcement"

    mise tasks --no-header | grep -qF "ai:workflow:validate" ||
        fail "workflow validator task is not discoverable"
    mise run ai:workflow:validate --help | grep -qF -- "--file" ||
        fail "workflow validator help does not describe --file"
    if mise run ai:workflow:validate --help |
        grep -qE -- "--(authorization|runtime)-interface-fd"; then
        fail "workflow validator still exposes caller-controlled interfaces"
    fi
    if mise run ai:workflow:validate -- \
        --file "$valid_file" --authorization-interface-fd 3 >/dev/null 2>&1; then
        fail "validator accepted a caller-controlled authorization interface"
    fi
    mise run ai:workflow:validate -- --file "$valid_file" >/dev/null ||
        fail "validator rejected a valid advisory contract"
    mise run ai:workflow:validate -- --dry-run --file "$valid_file" |
        grep -qF "dry run" ||
        fail "validator did not report dry-run mode"

    jq '.contracts[0].budget.expires_at = "2020-01-01T00:00:00Z" |
        .contracts[0].authorization.expires_at = "2020-01-01T00:00:00Z"' \
        "$valid_file" >"$fixture/expired-advisory.json"
    mise run ai:workflow:validate -- --file "$fixture/expired-advisory.json" >/dev/null ||
        fail "validator treated advisory expiry as runtime enforcement"

    jq '.contracts[0].budget.mode = "runtime_enforced"' \
        "$valid_file" >"$fixture/trusted-budget-mode.json"
    if mise run ai:workflow:validate -- --file "$fixture/trusted-budget-mode.json" >/dev/null 2>&1; then
        fail "validator accepted a trusted budget mode"
    fi

    jq '.contracts[0].verified = true' "$valid_file" >"$fixture/trusted-key.json"
    if mise run ai:workflow:validate -- --file "$fixture/trusted-key.json" >/dev/null 2>&1; then
        fail "validator accepted a trusted-status key"
    fi
    jq '.contracts[0].state = "runtime_verified"' \
        "$valid_file" >"$fixture/trusted-value.json"
    if mise run ai:workflow:validate -- --file "$fixture/trusted-value.json" >/dev/null 2>&1; then
        fail "validator accepted a trusted-status value"
    fi

    jq '.contracts[0].worktree.path = "~/dev/personal/dot"' \
        "$valid_file" >"$fixture/tilde-worktree.json"
    if mise run ai:workflow:validate -- --file "$fixture/tilde-worktree.json" >/dev/null 2>&1; then
        fail "validator accepted a tilde worktree path"
    fi
    jq '.contracts[0].worktree.path = "/Users/villalj/dev/personal/dot"' \
        "$valid_file" >"$fixture/absolute-worktree.json"
    if mise run ai:workflow:validate -- --file "$fixture/absolute-worktree.json" >/dev/null 2>&1; then
        fail "validator accepted an absolute worktree path"
    fi
    jq '.contracts[0].worktree.path = "worktree://workflow-1"' \
        "$valid_file" >"$fixture/worktree-reference.json"
    mise run ai:workflow:validate -- --file "$fixture/worktree-reference.json" >/dev/null ||
        fail "validator rejected an approved worktree reference"
    jq '.contracts[0].worktree.path = "opaque://worktree/workflow-1/lane-1"' \
        "$valid_file" >"$fixture/hierarchical-worktree-reference.json"
    mise run ai:workflow:validate -- \
        --file "$fixture/hierarchical-worktree-reference.json" >/dev/null ||
        fail "validator rejected an approved hierarchical worktree reference"
    jq '.contracts[0].worktree.path = "opaque://worktree/../workflow-1"' \
        "$valid_file" >"$fixture/worktree-traversal.json"
    if mise run ai:workflow:validate -- --file "$fixture/worktree-traversal.json" >/dev/null 2>&1; then
        fail "validator accepted worktree traversal"
    fi

    for claim_path in \
        "./home/file" \
        "home//file" \
        "home/../file" \
        "home/café" \
        "home%2Ffile" \
        "home\\file"; do
        jq --arg path "$claim_path" \
            '.contracts[0].owned_paths = [$path] |
             .contracts[0].authorization.owned_paths = [$path]' \
            "$valid_file" >"$fixture/path-invalid-${claim_path//\//-}.json"
        if mise run ai:workflow:validate -- \
            --file "$fixture/path-invalid-${claim_path//\//-}.json" >/dev/null 2>&1; then
            fail "validator accepted an ambiguous path alias: $claim_path"
        fi
    done

    jq '.contracts[0].owned_paths = ["Docs/File", "docs/file"] |
        .contracts[0].authorization.owned_paths = ["Docs/File", "docs/file"]' \
        "$valid_file" >"$fixture/case-colliding-owned-paths.json"
    if mise run ai:workflow:validate -- \
        --file "$fixture/case-colliding-owned-paths.json" >/dev/null 2>&1; then
        fail "validator accepted case-colliding owned paths"
    fi
    jq '.contracts[0].owned_paths = ["Docs/File"] |
        .contracts[0].excluded_paths = ["docs/file"] |
        .contracts[0].authorization.owned_paths = ["Docs/File"]' \
        "$valid_file" >"$fixture/case-colliding-claims.json"
    if mise run ai:workflow:validate -- \
        --file "$fixture/case-colliding-claims.json" >/dev/null 2>&1; then
        fail "validator accepted case-colliding ownership claims"
    fi

    for sensitive_path in \
        ".GIT/config" \
        ".github/WORKFLOWS/release.yml" \
        "ssh/config" \
        "infra/DEPLOYMENT" \
        "service/Auth/config" \
        "secrets/API_KEY" \
        "certs/server.PEM" \
        "keys/private-key" \
        "ssh/id_rsa" \
        "data/credentials.json" \
        "data/secret.txt" \
        "data/auth.json" \
        "data/ci"; do
        jq --arg path "$sensitive_path" \
            '.contracts[0].owned_paths = [$path] |
             .contracts[0].authorization.owned_paths = [$path]' \
            "$valid_file" >"$fixture/sensitive-${sensitive_path//\//-}.json"
        if mise run ai:workflow:validate -- \
            --file "$fixture/sensitive-${sensitive_path//\//-}.json" >/dev/null 2>&1; then
            fail "validator accepted sensitive path: $sensitive_path"
        fi
    done

    delivery_file="$fixture/delivery.json"
    jq '.records = [
        (.contracts[0] + {
            record_id: "review-1",
            record_type: "review",
            record_status: "historical",
            state: "critique",
            transition: {from: "validate", to: "critique"}
        }),
        (.contracts[0] + {
            record_id: "delivery-1",
            record_type: "delivery",
            record_status: "active",
            state: "done",
            transition: {from: "critique", to: "done"}
        })
    ]' "$valid_file" >"$delivery_file"
    output="$(mise run ai:workflow:validate -- --file "$delivery_file" 2>&1)" && {
        fail "validator accepted delivery without external gates"
    }
    print -- "$output" | grep -qF "status=valid_structure" ||
        fail "validator did not report structural validation"
    print -- "$output" | grep -qF "status=requires_external_authorization" ||
        fail "validator did not report the external authorization requirement"
    print -- "$output" | grep -qF "status=requires_external_runtime" ||
        fail "validator did not report the external runtime requirement"
    if print -- "$output" | grep -qE "status=(authorized|runtime_verified)"; then
        fail "validator reported a trusted status"
    fi

    historical_file="$fixture/historical-runtime.json"
    jq '.records = [
        (.contracts[0] + {
            record_id: "review-1",
            record_type: "review",
            record_status: "historical",
            state: "critique",
            transition: {from: "validate", to: "critique"},
            evidence: {
                recorded_at: "2020-01-03T00:00:00Z",
                reason: "historical runtime measurement",
                runtime: {
                    attestation_ref: "attestation://runtime-1",
                    measured_start_at: "2020-01-01T00:00:00Z",
                    measured_end_at: "2020-01-02T00:00:00Z",
                    measured_tool_calls: 40,
                    measured_wall_clock_minutes: 45,
                    budget_tool_calls: 25,
                    budget_wall_clock_minutes: 30,
                    within_tool_call_budget: false,
                    within_wall_clock_budget: false,
                    checkpoint_event_ids: ["checkpoint://workflow-1/event-1"],
                    cancellation_status: "not_cancelled",
                    stop_status: "completed"
                }
            }
        })
    ]' "$valid_file" >"$historical_file"
    mise run ai:workflow:validate -- --file "$historical_file" >/dev/null ||
        fail "validator rejected advisory historical evidence"

    print "Workflow validator tests passed."
}

main "$@"
