#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

main() {
    unset GH_CONFIG_DIR GH_HOST
    local fixture="$__root_dir/.agents/projects.local/orchestration-and-worktree-reliability/evidence/orch-108/repair/test-fixtures-$$"
    local task="$__root_dir/home/.config/mise/tasks/gh/project.ts"
    local plan="$fixture/plan.json"
    local authorization="$fixture/retry-authorization.json"
    local state="$fixture/state.json"
    local output
    mkdir -p "$fixture"
    trap "rm -rf -- '$fixture'" EXIT

    cat >"$plan" <<'JSON'
{
  "schema_version": "gh-project-plan.v20",
  "target": {
    "host": "github.com",
    "owner": "minusfive",
    "repository": "dot",
    "title": "orchestration-and-worktree-reliability",
    "key": "minusfive/dot:orchestration-and-worktree-reliability"
  },
  "lanes": ["Blocked", "Todo", "Research", "Implement", "Validate", "Critique", "Done"],
  "issues": [
    {"number": 108, "key": "ORCH-108", "labels": ["ORCH-108"]},
    {"number": 121, "key": "ORCH-121", "labels": ["ORCH-121"]},
    {"number": 115, "key": "ORCH-115", "labels": ["ORCH-115"]},
    {"number": 122, "key": "WT-122", "labels": ["WT-122"]}
  ],
  "dependencies": [
    {"source": 108, "target": 121, "kind": "blocked_by"},
    {"source": 121, "target": 115, "kind": "blocked_by"}
  ],
  "required_labels": ["ORCH-108", "ORCH-121", "ORCH-115", "WT-122"]
}
JSON

    local plan_digest
    plan_digest="$(bun -e 'const v=JSON.parse(await Bun.file(Bun.argv[1]).text()); const c=(x)=>Array.isArray(x)?x.map(c):x&&typeof x==="object"?Object.fromEntries(Object.keys(x).sort().map(k=>[k,c(x[k])])):x; console.log((await import("node:crypto")).createHash("sha256").update(JSON.stringify(c(v))).digest("hex"))' "$plan")"
    cat >"$authorization" <<JSON
{"schema_version":"retry-authorization.v1","authorized":true,"current_turn_only":true,"owner":"external orchestrator","expires":"end of current turn","plan_digest":"$plan_digest"}
JSON

    cat >"$state" <<'JSON'
{
  "capabilities": {"project": true, "repo": true},
  "host": "github.com",
  "owner": {"type": "User", "login": "minusfive", "id": "fixture-owner"},
  "repository": {"name": "dot", "nameWithOwner": "minusfive/dot", "id": "fixture-repo"},
  "inventory": {
    "open_pages": 1,
    "closed_pages": 1,
    "open_complete": true,
    "closed_complete": true,
    "open_cursors": ["<start>"],
    "closed_cursors": ["<start>"],
    "open_termination": {"has_next_page": false, "end_cursor": null},
    "closed_termination": {"has_next_page": false, "end_cursor": null}
  },
  "projects": []
}
JSON

    mise run gh:project-validate -- \
        --schema plan-v20 --input "$plan" >/dev/null ||
        fail "plan validator rejected the accepted fixture plan"
    cat "$plan" | mise run gh:project-validate -- \
        --schema plan-v20 --input - >/dev/null ||
        fail "plan validator did not accept typed stdin input"
    jq -e '."$comment" | contains("canonical semantic validator") and contains("target-key equality")' \
        "$__root_dir/home/.config/mise/tasks/gh/project-result.v20.schema.json" >/dev/null ||
        fail "result schema did not document the canonical semantic validator boundary"
    jq -e '.properties.target."$comment" | contains("canonical semantic validator") and contains("cross-field equality")' \
        "$__root_dir/home/.config/mise/tasks/gh/project-plan.v20.schema.json" >/dev/null ||
        fail "plan target schema did not document the canonical semantic validator boundary"
    jq -e '.properties.dependencies."$comment" | contains("canonical semantic validator") and contains("endpoints")' \
        "$__root_dir/home/.config/mise/tasks/gh/project-plan.v20.schema.json" >/dev/null ||
        fail "plan dependency schema did not document the canonical semantic validator boundary"
    jq '.target = {}' "$plan" >"$fixture/malformed-plan.json"
    if mise run gh:project-validate -- \
        --schema plan-v20 --input "$fixture/malformed-plan.json" >/dev/null 2>&1; then
        fail "plan validator accepted malformed nested target identity"
    fi
    jq '.target.key = "wrong-key"' "$plan" >"$fixture/schema-target-key.json"
    if ! bun -e 'const Ajv=(await import("ajv/dist/2020.js")).default;
        const schema=JSON.parse(await Bun.file(Bun.argv[1]).text());
        const value=JSON.parse(await Bun.file(Bun.argv[2]).text());
        if (!new Ajv({strict:false}).compile(schema)(value)) process.exit(1);' \
        "$__root_dir/home/.config/mise/tasks/gh/project-plan.v20.schema.json" \
        "$fixture/schema-target-key.json"; then
        fail "plan schema rejected a semantic target-key negative corpus case"
    fi
    if mise run gh:project-validate -- \
        --schema plan-v20 --input "$fixture/schema-target-key.json" >/dev/null 2>&1; then
        fail "plan validator accepted the target-key semantic negative corpus case"
    fi
    jq '.dependencies[0].target = 999' "$plan" >"$fixture/schema-dependency-reference.json"
    if ! bun -e 'const Ajv=(await import("ajv/dist/2020.js")).default;
        const schema=JSON.parse(await Bun.file(Bun.argv[1]).text());
        const value=JSON.parse(await Bun.file(Bun.argv[2]).text());
        if (!new Ajv({strict:false}).compile(schema)(value)) process.exit(1);' \
        "$__root_dir/home/.config/mise/tasks/gh/project-plan.v20.schema.json" \
        "$fixture/schema-dependency-reference.json"; then
        fail "plan schema rejected a semantic dependency-reference negative corpus case"
    fi
    if mise run gh:project-validate -- \
        --schema plan-v20 --input "$fixture/schema-dependency-reference.json" >/dev/null 2>&1; then
        fail "plan validator accepted the dependency-reference semantic negative corpus case"
    fi
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$state" --dry-run)"
    [[ "$(jq -r '.status' <<<"$output")" == bootstrap_required ]] ||
        fail "empty fixture did not classify as bootstrap_required"
    [[ "$(jq -r '.mutation_authorized' <<<"$output")" == false ]] ||
        fail "dry run authorized mutation"
    [[ "$(jq '.projects | length' "$state")" == 0 ]] ||
        fail "dry run changed fixture state"

    output="$(GH_HOST=enterprise.example mise run gh:project -- \
        --plan "$plan" --dry-run 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "live mode did not fail closed for a non-GitHub runtime host"
    jq -e '.failures[] | contains("GH_HOST")' <<<"$output" >/dev/null ||
        fail "non-GitHub runtime host failure was not recorded"
    output="$(GH_CONFIG_DIR="$fixture/alternate-gh-config" \
        usage_plan="$plan" usage_fixture="" usage_evidence_dir="" usage_dry_run=true \
        usage_confirm="" usage_retry=0 usage_retry_authorization="" \
        bun "$task" 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "live mode did not fail closed for an alternate gh configuration directory"
    jq -e '.failures[] | contains("GH_CONFIG_DIR")' <<<"$output" >/dev/null ||
        fail "alternate gh configuration failure was not recorded"
    grep -qF -- '--hostname' "$__root_dir/home/.config/mise/tasks/gh/project.ts" ||
        fail "live gh calls do not pin the GitHub hostname explicitly"
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$state" --dry-run --retry 0 \
        --retry-authorization "$authorization")"
    [[ "$(jq -r '.retry_authorized' <<<"$output")" == false &&
        "$(jq -r '.retry_authorization' <<<"$output")" == null ]] ||
        fail "zero retry did not produce unauthorized retry evidence"
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$state" --dry-run --retry 0 \
        --retry-authorization "$fixture/missing-authorization.json")"
    [[ "$(jq -r '.retry_authorized' <<<"$output")" == false &&
        "$(jq -r '.retry_authorization' <<<"$output")" == null ]] ||
        fail "zero retry treated invalid authorization as effective"

    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$state" --confirm APPLY \
        --evidence-dir "$fixture/evidence")"
    [[ "$(jq -r '.status' <<<"$output")" == ready ]] ||
        fail "fixture bootstrap did not report the converged status"
    [[ "$(jq -r '.second_read.converged' <<<"$output")" == true ]] ||
        fail "fixture bootstrap did not converge after second read"
    [[ "$(jq -r '.live_vs_fixture' <<<"$output")" == fixture ]] ||
        fail "fixture result was not classified as fixture"
    [[ -f "$fixture/evidence/create-response-identity.v1.json" ]] ||
        fail "fixture bootstrap did not persist durable create identity"
    [[ "$(jq -r '.durable_create_identity.project_node_id' <<<"$output")" == fixture-project-1 ]] ||
        fail "fixture result did not propagate durable create identity"
    mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/evidence/project-result.v1.json" >/dev/null ||
        fail "result validator rejected the fixture result"
    jq '.second_read = {"classification":"ready"}' \
        "$fixture/evidence/project-result.v1.json" >"$fixture/malformed-result.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/malformed-result.json" >/dev/null 2>&1; then
        fail "result validator accepted malformed nested second_read"
    fi
    jq '.partial_project_ids = [{"id":"fixture-project-1"}]' \
        "$fixture/evidence/project-result.v1.json" >"$fixture/missing-partial-number.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/missing-partial-number.json" >/dev/null 2>&1; then
        fail "result validator accepted partial_project_ids without number"
    fi
    jq '.partial_project_ids = [{"id":"fixture-project-1","number":1},{"id":"fixture-project-1","number":1}]' \
        "$fixture/evidence/project-result.v1.json" >"$fixture/duplicate-partial-identity.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/duplicate-partial-identity.json" >/dev/null 2>&1; then
        fail "result validator accepted duplicate partial Project identities"
    fi
    jq '.accepted_plan = {"path":"plan.json","sha256":("'"$(printf '%064d' 0)"'")} |
        .authorization = {"path":"authorization.json","authorized":true,"expires":"end of current turn","delivery_authorized":false} |
        .branch_worktree_state = {"branch":"fixture","dirty_paths_preserved":[],"excluded_files_unchanged":true} |
        .live_vs_fixture_classification = {"live":"blocked","fixture":"ready"} |
        .retry_authorized = false |
        .retry_authorization = null |
        .lane_state = "ready" |
        .secret_status = "clean" |
        .redaction_status = "clean" |
        .second_read_consistency = true |
        .inventory = {"open_pages":1,"closed_pages":1,"open_complete":true,"closed_complete":true,"open_cursors":["<start>"],"closed_cursors":["<start>"],"open_termination":{"has_next_page":false,"end_cursor":null},"closed_termination":{"has_next_page":false,"end_cursor":null}}' \
        "$fixture/evidence/project-result.v1.json" >"$fixture/complete-result.json"
    mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/complete-result.json" >/dev/null ||
        fail "result validator rejected complete nested result contract"
    jq '.target.key = "wrong-key"' "$fixture/complete-result.json" >"$fixture/schema-result-target-key.json"
    if ! bun -e 'const Ajv=(await import("ajv/dist/2020.js")).default;
        const schema=JSON.parse(await Bun.file(Bun.argv[1]).text());
        const value=JSON.parse(await Bun.file(Bun.argv[2]).text());
        if (!new Ajv({strict:false}).compile(schema)(value)) process.exit(1);' \
        "$__root_dir/home/.config/mise/tasks/gh/project-result.v20.schema.json" \
        "$fixture/schema-result-target-key.json"; then
        fail "result schema rejected a semantic target-key negative corpus case"
    fi
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/schema-result-target-key.json" >/dev/null 2>&1; then
        fail "result validator accepted the target-key semantic negative corpus case"
    fi
    jq '.retry_authorized = true | .retry_authorization = null' \
        "$fixture/complete-result.json" >"$fixture/schema-only-invalid-retry.json"
    if bun -e 'const Ajv=(await import("ajv/dist/2020.js")).default;
        const schema=JSON.parse(await Bun.file(Bun.argv[1]).text());
        const value=JSON.parse(await Bun.file(Bun.argv[2]).text());
        if (new Ajv({strict:false}).compile(schema)(value)) process.exit(0);
        process.exit(1);' \
        "$__root_dir/home/.config/mise/tasks/gh/project-result.v20.schema.json" \
        "$fixture/schema-only-invalid-retry.json"; then
        fail "JSON Schema accepted retry authorization mismatch"
    fi
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/schema-only-invalid-retry.json" >/dev/null 2>&1; then
        fail "result validator accepted zero retry with retry authorization"
    fi
    jq '.accepted_plan.extra = true' "$fixture/complete-result.json" >"$fixture/extra-evidence-key.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/extra-evidence-key.json" >/dev/null 2>&1; then
        fail "result validator accepted an unexpected nested evidence key"
    fi
    jq 'del(.retry_authorized)' "$fixture/evidence/project-result.v1.json" >"$fixture/missing-retry-evidence.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/missing-retry-evidence.json" >/dev/null 2>&1; then
        fail "result validator accepted missing retry authorization evidence"
    fi
    jq 'del(.secret_status)' "$fixture/evidence/project-result.v1.json" >"$fixture/missing-secret-evidence.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/missing-secret-evidence.json" >/dev/null 2>&1; then
        fail "result validator accepted missing secret status evidence"
    fi
    jq 'del(.secret_redaction_status)' "$fixture/evidence/project-result.v1.json" >"$fixture/missing-secret-redaction-evidence.json"
    if mise run gh:project-validate -- \
        --schema result-v20 --input "$fixture/missing-secret-redaction-evidence.json" >/dev/null 2>&1; then
        fail "result validator accepted missing secret redaction evidence"
    fi
    jq '.issues[0].extra = true' "$plan" >"$fixture/extra-plan-key.json"
    if mise run gh:project-validate -- \
        --schema plan-v20 --input "$fixture/extra-plan-key.json" >/dev/null 2>&1; then
        fail "plan validator accepted an unexpected nested issue key"
    fi
    jq '.lanes = (.lanes | reverse)' "$plan" >"$fixture/reordered-lanes.json"
    if mise run gh:project-validate -- \
        --schema plan-v20 --input "$fixture/reordered-lanes.json" >/dev/null 2>&1; then
        fail "plan validator accepted reordered status lanes"
    fi
    [[ "$(jq '.projects | length' "$state")" == 1 ]] ||
        fail "fixture bootstrap did not create one Project"
    jq '.projects[0].id = "wrong-project-id"' "$state" >"$fixture/wrong-persisted-identity.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/wrong-persisted-identity.json" \
        --dry-run --evidence-dir "$fixture/evidence" >/dev/null 2>&1; then
        fail "persisted create identity mismatch was accepted"
    fi

    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$state" --confirm APPLY --evidence-dir "$fixture/evidence")"
    [[ "$(jq -r '.status' <<<"$output")" == ready ]] ||
        fail "repeated fixture run did not converge to ready"
    [[ "$(jq -r '.journal_entries' <<<"$output")" == 1 ]] ||
        fail "ready run performed unexpected mutations"

    jq '.issues[0].node_id = "fixture-issue-108" |
        .issues[0].label_node_ids = {"ORCH-108":"fixture-label-1"}' \
        "$plan" >"$fixture/identity-plan.json"
    jq '.projects[0].items[0].issue.id = "wrong-issue-node"' \
        "$state" >"$fixture/wrong-issue-node.json"
    if mise run gh:project -- \
        --plan "$fixture/identity-plan.json" --fixture "$fixture/wrong-issue-node.json" --dry-run >/dev/null 2>&1; then
        fail "wrong issue node identity was accepted"
    fi
    jq '.projects[0].labels[0].id = "wrong-label-node"' \
        "$state" >"$fixture/wrong-label-node.json"
    if mise run gh:project -- \
        --plan "$fixture/identity-plan.json" --fixture "$fixture/wrong-label-node.json" --dry-run >/dev/null 2>&1; then
        fail "wrong label node identity was accepted"
    fi

    jq '.projects[0].fields[0].options |= .[0:-1]' \
        "$state" >"$fixture/missing-lane.json"
    output="$(mise run gh:project -- --plan "$plan" --fixture "$fixture/missing-lane.json" --dry-run)"
    [[ "$(jq -r '.status' <<<"$output")" == bootstrap_required ]] ||
        fail "missing status lane was not classified as bootstrap_required"
    jq '.projects[0].fields[0].options += [{"id":"extra-lane","name":"Unexpected"}]' \
        "$state" >"$fixture/extra-lane.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/extra-lane.json" --dry-run >/dev/null 2>&1; then
        fail "extra status lane was accepted"
    fi
    jq '.projects[0].fields[0].options[0].name = .projects[0].fields[0].options[1].name' \
        "$state" >"$fixture/duplicate-lane.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/duplicate-lane.json" --dry-run >/dev/null 2>&1; then
        fail "duplicate status lane was accepted"
    fi
    jq '.projects[0].fields[0].type = "TEXT"' \
        "$state" >"$fixture/wrong-status-type.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/wrong-status-type.json" --dry-run >/dev/null 2>&1; then
        fail "wrong Status field data type was accepted"
    fi
    jq '.projects[0].fields[0].__typename = "ProjectV2TextField"' \
        "$state" >"$fixture/wrong-status-typename.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/wrong-status-typename.json" --dry-run >/dev/null 2>&1; then
        fail "wrong Status field __typename was accepted"
    fi
    jq 'del(.projects[0].fields[0].options[0].id)' \
        "$state" >"$fixture/missing-option-id.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/missing-option-id.json" --dry-run >/dev/null 2>&1; then
        fail "missing Status option identity was accepted"
    fi
    jq '.projects[0].fields[0].options[0].color = ""' \
        "$state" >"$fixture/missing-option-metadata.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/missing-option-metadata.json" --dry-run >/dev/null 2>&1; then
        fail "missing Status option metadata was accepted"
    fi
    jq '.projects[0].fields[0].options += [.projects[0].fields[0].options[0]]' \
        "$state" >"$fixture/duplicate-option.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/duplicate-option.json" --dry-run >/dev/null 2>&1; then
        fail "duplicate Status option was accepted"
    fi
    jq '.projects[0].items += [{"id":"extra-item","issue":{"id":"extra-issue","number":999,"repository":"minusfive/dot","labels":[]}}]' \
        "$state" >"$fixture/unexpected-item.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/unexpected-item.json" --dry-run >/dev/null 2>&1; then
        fail "unexpected Project item was accepted"
    fi
    jq '.projects[0].labels += [{"id":"extra-label","name":"EXTRA","repository":"minusfive/dot","issue_numbers":[]}]' \
        "$state" >"$fixture/unexpected-label.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/unexpected-label.json" --dry-run >/dev/null 2>&1; then
        fail "unexpected Project label was accepted"
    fi
    jq '.projects[0].dependencies += [{"id":"extra-edge","source":999,"target":998,"kind":"blocked_by"}]' \
        "$state" >"$fixture/unexpected-dependency.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/unexpected-dependency.json" --dry-run >/dev/null 2>&1; then
        fail "unexpected dependency edge was accepted"
    fi

    jq '.projects[0].repository = {"name":"other","nameWithOwner":"minusfive/other"}' \
        "$state" >"$fixture/wrong-linkage.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/wrong-linkage.json" --dry-run >/dev/null 2>&1; then
        fail "wrong repository linkage was accepted"
    fi

    jq '.projects += [.projects[0]]' "$state" >"$fixture/duplicate.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/duplicate.json" --dry-run >/dev/null 2>&1; then
        fail "duplicate Project identity was accepted"
    fi

    jq '.capabilities.project = false' "$state" >"$fixture/no-capability.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/no-capability.json" --dry-run >/dev/null 2>&1; then
        fail "missing Project capability was accepted"
    fi

    jq '.host = "ghe.example"' "$state" >"$fixture/wrong-host.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/wrong-host.json" --dry-run >/dev/null 2>&1; then
        fail "wrong host was accepted"
    fi

    jq 'del(.projects)' "$state" >"$fixture/malformed.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/malformed.json" --dry-run >/dev/null 2>&1; then
        fail "malformed fixture data was accepted"
    fi
    jq '.projects[0].items[0].issue = {}' "$state" >"$fixture/malformed-nested.json"
    if mise run gh:project -- --plan "$plan" --fixture "$fixture/malformed-nested.json" --dry-run >/dev/null 2>&1; then
        fail "malformed nested fixture data was accepted"
    fi

    local fake_bin="$fixture/bin"
    mkdir -p "$fake_bin"
    cat >"$fake_bin/gh" <<'ZSH'
#!/usr/bin/env zsh
mode="${GH_MODE:-dependency_error}"
state="${GH_STATE:-}"
log="${GH_LOG:-}"
title="${GH_PROJECT_TITLE:-orchestration-and-worktree-reliability}"
if [[ "$mode" == "live_like" ]]; then
    state="${0:A:h:h}/live-state"
    log="${0:A:h:h}/live-gh.log"
    mkdir -p "$state"
fi
[[ -n "$log" ]] && print -r -- "$*" >>"$log"
if [[ "$1" == "api" && "$2" == "graphql" && "$*" == *"--input -"* ]]; then
    input="$(cat)"
    [[ -n "$log" ]] && print -r -- "$input" >>"$log.body"
    if [[ "$input" == *"updateProjectV2Field"* ]]; then
        if [[ "$mode" == "malformed_mutation" ]]; then
            print '{"data":{}}'
        else
            : >"$state/status"
            print '{"data":{"updateProjectV2Field":{"projectV2Field":{"id":"status","name":"Status","dataType":"SINGLE_SELECT","options":[{"id":"1","name":"Blocked","color":"BLUE","description":"Execution lane: Blocked"},{"id":"2","name":"Todo","color":"GRAY","description":"Execution lane: Todo"},{"id":"3","name":"Research","color":"GREEN","description":"Execution lane: Research"},{"id":"4","name":"Implement","color":"YELLOW","description":"Execution lane: Implement"},{"id":"5","name":"Validate","color":"ORANGE","description":"Execution lane: Validate"},{"id":"6","name":"Critique","color":"RED","description":"Execution lane: Critique"},{"id":"7","name":"Done","color":"PURPLE","description":"Execution lane: Done"}]}}}}'
        fi
    elif [[ "$input" == *"projectsV2(first:100"* ]]; then
        if [[ "$mode" == "pagination_ambiguous" ]]; then
            print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[],\"pageInfo\":{\"hasNextPage\":true,\"endCursor\":null}}}}}"
        elif [[ "$mode" == "graphql_missing" ]]; then
            print '{"data":{}}'
        elif [[ "$mode" == "create_incomplete" ]]; then
            print '{"data":{"user":{"projectsV2":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "paginated" && "$input" == *'"after":null'* ]]; then
            if [[ "$input" == *'"query":"is:closed"'* ]]; then
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":3,\"id\":\"P3\",\"title\":\"other-closed\",\"closed\":true,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo3\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":true,\"endCursor\":\"cursor-closed\"}}}}}"
            else
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\",\"closed\":false,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":true,\"endCursor\":\"cursor-open\"}}}}}"
            fi
        elif [[ "$mode" == "paginated" ]]; then
            if [[ "$input" == *'"query":"is:closed"'* ]]; then
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":4,\"id\":\"P4\",\"title\":\"other-closed-2\",\"closed\":true,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo4\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            else
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":2,\"id\":\"P2\",\"title\":\"other\",\"closed\":false,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo2\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            fi
        elif [[ "$mode" == "closed_duplicate" ]]; then
            if [[ "$input" == *'"query":"is:closed"'* ]]; then
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":2,\"id\":\"P2\",\"title\":\"$title\",\"closed\":true,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo2\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            else
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\",\"closed\":false,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            fi
        else
            if [[ "$input" == *'"query":"is:closed"'* ]]; then
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":2,\"id\":\"P2\",\"title\":\"other\",\"closed\":true,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo2\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            else
                print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\",\"closed\":false,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo\",\"nameWithOwner\":\"minusfive/dot\"}]}}],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
            fi
        fi
    elif [[ "$input" == *"items(first:100"* ]]; then
        if [[ "$mode" == "wrong_item_identity" ]]; then
            print '{"data":{"node":{"items":{"nodes":[{"id":"item-108","content":{"id":"issue-999","number":108,"repository":{"nameWithOwner":"minusfive/dot"}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "missing_items" ]]; then
            print '{"data":{"node":{}}}'
        elif [[ "$mode" == "malformed_mutation" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "create_incomplete" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "paginated" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "items_paginated" && "$input" == *'"after":null'* ]]; then
            print '{"data":{"node":{"items":{"nodes":[{"id":"item-108","content":{"id":"issue-108","number":108,"repository":{"nameWithOwner":"minusfive/dot"}}}],"pageInfo":{"hasNextPage":true,"endCursor":"item-cursor-1"}}}}}'
        elif [[ "$mode" == "items_paginated" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "pagination_ambiguous" || "$mode" == "graphql_missing" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        elif [[ "$mode" == "closed_duplicate" ]]; then
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        else
        if [[ "$mode" == "live_like" && -f "$state/item" ]] || [[ "$mode" != "live_like" ]]; then
            print '{"data":{"node":{"items":{"nodes":[{"id":"item-108","content":{"id":"issue-108","number":108,"repository":{"nameWithOwner":"minusfive/dot"}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        else
            print '{"data":{"node":{"items":{"nodes":[],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}'
        fi
        fi
    else
        print '{"data":{}}'
    fi
elif [[ "$mode" == "create_incomplete" && "$1" == "project" && "$2" == "create" ]]; then
    print '{"number":2,"id":"P2"}'
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "list" ]]; then
    if [[ "$*" == *" --closed "* ]]; then
        [[ "$mode" == "closed_duplicate" ]] && print "{\"projects\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\"}]}" || print '{"projects":[]}'
    else
        print "{\"projects\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\"}]}"
    fi
elif [[ "$mode" == "live_like" && "$1" == "api" && "$2" == "graphql" && "$*" == *"--input -"* ]]; then
    input="$(cat)"
    [[ "$input" == *"updateProjectV2Field"* ]] || exit 1
    : >"$state/status"
elif [[ "$mode" == "live_like" && "$1" == "api" && "$2" == "graphql" ]]; then
    print "{\"data\":{\"user\":{\"projectsV2\":{\"nodes\":[{\"number\":1,\"id\":\"P1\",\"title\":\"$title\",\"closed\":false,\"owner\":{\"__typename\":\"User\",\"login\":\"minusfive\",\"id\":\"owner\"},\"repositories\":{\"nodes\":[{\"id\":\"repo\",\"nameWithOwner\":\"minusfive/dot\"}]} }],\"pageInfo\":{\"hasNextPage\":false,\"endCursor\":null}}}}}"
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "field-list" ]]; then
    if [[ -f "$state/status" ]]; then
        print '{"fields":[{"id":"status","name":"Status","type":"SINGLE_SELECT","options":[{"id":"1","name":"Blocked","color":"BLUE","description":"Execution lane: Blocked"},{"id":"2","name":"Todo","color":"GRAY","description":"Execution lane: Todo"},{"id":"3","name":"Research","color":"GREEN","description":"Execution lane: Research"},{"id":"4","name":"Implement","color":"YELLOW","description":"Execution lane: Implement"},{"id":"5","name":"Validate","color":"ORANGE","description":"Execution lane: Validate"},{"id":"6","name":"Critique","color":"RED","description":"Execution lane: Critique"},{"id":"7","name":"Done","color":"PURPLE","description":"Execution lane: Done"}]}]}'
    else
        print '{"fields":[{"id":"status","name":"Status","type":"SINGLE_SELECT","options":[{"id":"1","name":"Blocked","color":"BLUE","description":"Execution lane: Blocked"}]}]}'
    fi
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "item-list" ]]; then
    if [[ -f "$state/item" ]]; then
        print '{"items":[{"id":"item-108","content":{"id":"issue-108","number":108,"repository":"minusfive/dot"}}]}'
    else
        print '{"items":[]}'
    fi
elif [[ "$mode" == "live_like" && "$1" == "issue" && "$2" == "view" ]]; then
    if [[ -f "$state/label" ]]; then
        print '{"id":"issue-108","labels":[{"id":"label-108","name":"ORCH-108"}]}'
    else
        print '{"id":"issue-108","labels":[]}'
    fi
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "field-create" ]]; then
    : >"$state/status"
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "item-add" ]]; then
    : >"$state/item"
    print '{"id":"item-108"}'
elif [[ "$mode" == "live_like" && "$1" == "issue" && "$2" == "edit" ]]; then
    : >"$state/label"
elif [[ "$mode" == "live_like" && "$1" == "label" && "$2" == "create" ]]; then
    :
elif [[ "$mode" == "live_like" && "$1" == "api" && "$2" == repos/* ]]; then
    print '[]'
elif [[ "$mode" == "live_like" && "$1" == "project" && "$2" == "link" ]]; then
    :
elif [[ "$mode" != "live_like" && "$1" == "project" && "$2" == "list" ]]; then
    if [[ "$*" == *" --closed "* ]]; then
        [[ "$mode" == "closed_duplicate" ]] && print '{"projects":[{"number":1,"id":"P1","title":"orchestration-and-worktree-reliability"}]}' || print '{"projects":[]}'
    else
        print '{"projects":[{"number":1,"id":"P1","title":"orchestration-and-worktree-reliability"}]}'
    fi
elif [[ "$mode" != "live_like" && "$1" == "api" && "$2" == "graphql" ]]; then
    print '{"data":{"user":{"projectsV2":{"nodes":[{"number":1,"id":"P1","title":"orchestration-and-worktree-reliability","owner":{"login":"minusfive","id":"owner"},"repositories":{"nodes":[{"id":"repo","nameWithOwner":"minusfive/dot"}]}}]}}}}'
elif [[ "$mode" != "live_like" && "$1" == "project" && "$2" == "field-list" ]]; then
    if [[ "$mode" == "malformed_mutation" ]]; then
        print '{"fields":[{"id":"status","name":"Status","type":"SINGLE_SELECT","options":[{"id":"1","name":"Blocked"}]}]}'
    elif [[ "$mode" == "missing_fields" ]]; then
        print '{}'
    else
        print '{"fields":[{"id":"status","name":"Status","type":"SINGLE_SELECT","options":[{"id":"1","name":"Blocked","color":"BLUE","description":"Execution lane: Blocked"},{"id":"2","name":"Todo","color":"GRAY","description":"Execution lane: Todo"},{"id":"3","name":"Research","color":"GREEN","description":"Execution lane: Research"},{"id":"4","name":"Implement","color":"YELLOW","description":"Execution lane: Implement"},{"id":"5","name":"Validate","color":"ORANGE","description":"Execution lane: Validate"},{"id":"6","name":"Critique","color":"RED","description":"Execution lane: Critique"},{"id":"7","name":"Done","color":"PURPLE","description":"Execution lane: Done"}]}]}'
    fi
elif [[ "$mode" != "live_like" && "$1" == "project" && "$2" == "item-list" ]]; then
    print '{"items":[{"id":"item-108","content":{"id":"issue-108","number":108,"repository":"minusfive/dot"}}]}'
elif [[ "$mode" != "live_like" && "$1" == "issue" && "$2" == "view" ]]; then
    print '{"id":"issue-108","labels":[]}'
elif [[ "$mode" != "live_like" && "$1" == "api" && "$2" == repos/* ]]; then
    if [[ "$mode" == "dependency_secret_error" ]]; then
        print -u2 'dependency endpoint failed: Authorization=Bearer fixture-'sensitive-value
        exit 1
    elif [[ "$mode" == "dependency_malformed_json" ]]; then
        print '{"malformed":'
    elif [[ "$mode" == "dependency_missing_identity" ]]; then
        print '[{}]'
    elif [[ "$mode" == "items_paginated" ]]; then
        print '[]'
    else
        print -u2 'dependency endpoint unavailable'
        exit 1
    fi
else
    print -u2 "unexpected gh invocation: $*"
    exit 1
fi
ZSH
    chmod +x "$fake_bin/gh"
    output="$(PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --dry-run 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "dependency read error was not a hard failure"
    jq -e '.failures | any(.[]; startswith("dependency_read_error:"))' <<<"$output" >/dev/null ||
        fail "dependency read error lacked explicit evidence"
    for mode in dependency_malformed_json dependency_missing_identity dependency_secret_error; do
        output="$(GH_MODE="$mode" PATH="$fake_bin:$PATH" mise run gh:project -- \
            --plan "$plan" --dry-run 2>/dev/null || true)"
        [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
            fail "$mode was not a hard failure"
        jq -e '.failures | any(.[]; startswith("dependency_read_"))' <<<"$output" >/dev/null ||
            fail "$mode lacked dependency evidence"
    done
    [[ "$output" != *"fixture-sensitive-value"* ]] ||
        fail "secret-bearing dependency error leaked into result output"
    [[ "$(jq -r '.redaction_status' <<<"$output")" == redacted ]] ||
        fail "secret-bearing dependency error did not record redaction status"
    output="$(GH_MODE=closed_duplicate PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --dry-run 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "closed duplicate Project was not rejected"
    jq '.inventory = {"open_pages":2,"closed_pages":3,"open_complete":true,"closed_complete":true,"open_cursors":["<start>","cursor-open"],"closed_cursors":["<start>","cursor-closed","cursor-closed-2"],"open_termination":{"has_next_page":false,"end_cursor":null},"closed_termination":{"has_next_page":false,"end_cursor":null}}' \
        "$state" >"$fixture/paginated-inventory.json"
    output="$(mise run gh:project -- --plan "$plan" --fixture "$fixture/paginated-inventory.json" --dry-run)"
    [[ "$(jq -r '.inventory.open_pages' <<<"$output")" == 2 ]] ||
        fail "paginated inventory evidence was not preserved"
    jq '.inventory.closed_complete = false' "$fixture/paginated-inventory.json" >"$fixture/incomplete-inventory.json"
    output="$(mise run gh:project -- --plan "$plan" --fixture "$fixture/incomplete-inventory.json" --dry-run 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "incomplete paginated inventory was accepted"
    for mode in graphql_missing pagination_ambiguous missing_fields missing_items wrong_item_identity; do
        output="$(GH_MODE="$mode" PATH="$fake_bin:$PATH" mise run gh:project -- \
            --plan "$plan" --dry-run 2>/dev/null || true)"
        [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
            fail "$mode was not a hard failure"
    done
    output="$(GH_MODE=paginated PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --dry-run)"
    [[ "$(jq -r '.inventory.open_complete' <<<"$output")" == true &&
        "$(jq -r '.inventory.closed_complete' <<<"$output")" == true ]] ||
        fail "paginated GraphQL inventory did not prove termination"
    local item_log="$fixture/items-paginated.log"
    output="$(GH_MODE=items_paginated GH_LOG="$item_log" PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --dry-run)"
    [[ "$(jq -r '.status' <<<"$output")" == bootstrap_required ]] ||
        fail "paginated Project items did not remain a safe incomplete state"
    [[ "$(grep -c 'items(first:100' "$item_log.body")" -ge 2 ]] ||
        fail "Project item pagination did not continue to explicit termination"
    output="$(GH_MODE=malformed_mutation PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --confirm APPLY 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "missing GraphQL mutation data was not a hard failure"
    output="$(GH_MODE=create_incomplete PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --confirm APPLY --retry 0 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "incomplete create identity was not a hard failure"
    output="$(GH_MODE=create_incomplete PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --confirm APPLY --retry 1 --retry-authorization "$authorization" 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "ambiguous create was retried without durable identity"
    local create_evidence="$fixture/create-evidence"
    local create_log="$fixture/create.log"
    output="$(GH_MODE=create_incomplete GH_LOG="$create_log" PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --confirm APPLY --retry 0 --evidence-dir "$create_evidence" 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure && -f "$create_evidence/create-intent.v1.json" ]] ||
        fail "pre-create intent was not persisted before ambiguous create"
    output="$(GH_MODE=create_incomplete GH_LOG="$create_log" PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$plan" --confirm APPLY --retry 1 --retry-authorization "$authorization" \
        --evidence-dir "$create_evidence" 2>/dev/null || true)"
    [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
        fail "persisted ambiguous create did not block a later process"
    [[ "$(grep -c 'project create' "$create_log")" == 1 ]] ||
        fail "ambiguous create was invoked more than once across processes"

    local live_plan="$fixture/live-plan.json"
    local live_state="$fixture/live-state"
    local live_log="$fixture/live-gh.log"
    mkdir -p "$live_state"
    cat >"$live_plan" <<'JSON'
{
  "schema_version": "gh-project-plan.v20",
  "target": {
    "host": "github.com",
    "owner": "minusfive",
    "repository": "dot",
    "title": "live-like-project",
    "key": "minusfive/dot:live-like-project"
  },
  "lanes": ["Blocked", "Todo", "Research", "Implement", "Validate", "Critique", "Done"],
  "issues": [{"number": 108, "key": "ORCH-108", "labels": ["ORCH-108"]}],
  "dependencies": [],
  "required_labels": ["ORCH-108"]
}
JSON
local live_evidence="$fixture/live-evidence"
local live_plan_digest
live_plan_digest="$(bun -e 'const v=JSON.parse(await Bun.file(Bun.argv[1]).text()); const c=(x)=>Array.isArray(x)?x.map(c):x&&typeof x==="object"?Object.fromEntries(Object.keys(x).sort().map(k=>[k,c(x[k])])):x; console.log((await import("node:crypto")).createHash("sha256").update(JSON.stringify(c(v))).digest("hex"))' "$live_plan")"
mkdir -p "$live_evidence"
cat >"$live_evidence/create-intent.v1.json" <<JSON
{"schema_version":"project-create-intent.v1","plan_digest":"$live_plan_digest","target":{"host":"github.com","owner":"minusfive","repository":"dot","title":"live-like-project","key":"minusfive/dot:live-like-project"},"client_mutation_id":"live-create-1","intent_timestamp":"2026-01-01T00:00:00.000Z"}
JSON
cat >"$live_evidence/create-response-identity.v1.json" <<JSON
{"schema_version":"create-response-identity.v1","plan_digest":"$live_plan_digest","client_mutation_id":"live-create-1","intent_timestamp":"2026-01-01T00:00:00.000Z","response_timestamp":"2026-01-01T00:00:01.000Z","provider_request_id":"fixture-request","project_node_id":"P1","project_number":1,"response_digest":"$(printf '%064d' 0)"}
JSON
    output="$(GH_MODE=live_like GH_STATE="$live_state" GH_LOG="$live_log" GH_PROJECT_TITLE=live-like-project \
        PATH="$fake_bin:$PATH" mise run gh:project -- \
    --plan "$live_plan" --confirm APPLY --retry 0 --evidence-dir "$live_evidence")"
    [[ "$(jq -r '.status' <<<"$output")" == ready ]] ||
        fail "live-like command fixture did not converge"
    [[ "$(jq -r '.second_read.converged' <<<"$output")" == true ]] ||
        fail "live-like command fixture did not verify second-read convergence"
    grep -q 'api graphql --input -' "$live_log" ||
        fail "status mutation did not use typed GraphQL input"
    jq -e 'select(.variables.input | type == "object") |
        .variables.input.singleSelectOptions |
        all(.[]; (.id? == null or (.id | type == "string")) and
            (.name | type == "string") and (.color | type == "string") and
            (.description | type == "string"))' "$live_log.body" >/dev/null ||
        fail "status mutation did not serialize typed option objects"
    grep -q 'project item-add' "$live_log" ||
        fail "live-like fixture did not exercise the item mutation group"
    grep -q 'issue edit' "$live_log" ||
        fail "live-like fixture did not exercise the label mutation group"
    [[ "$(grep -c 'project field-list' "$live_log")" -ge 5 ]] ||
        fail "live-like fixture did not perform fresh reads around mutation groups"
    local live_log_lines
    live_log_lines="$(wc -l <"$live_log")"
    output="$(GH_MODE=live_like GH_STATE="$live_state" GH_LOG="$live_log" GH_PROJECT_TITLE=live-like-project \
        PATH="$fake_bin:$PATH" mise run gh:project -- \
        --plan "$live_plan" --confirm APPLY --retry 0 --evidence-dir "$live_evidence")"
    [[ "$(jq -r '.status' <<<"$output")" == ready ]] ||
        fail "repeated live-like command fixture did not remain ready"
    if sed -n "$((live_log_lines + 1)),\$p" "$live_log" | grep -Eq 'field-create|item-add|label create|issue edit|--method POST'; then
        fail "repeated live-like reconciliation re-applied an existing child"
    fi
    jq '.second_read_inconsistent = true' "$state" >"$fixture/inconsistent-second-read.json"
    output="$(mise run gh:project -- --plan "$plan" \
        --fixture "$fixture/inconsistent-second-read.json" --dry-run 2>&1 || true)"
    [[ "$(print -r -- "$output" | grep '^{' | tail -1 | jq -r '.status')" == hard_failure ]] ||
        { print -r -- "$output"; fail "inconsistent second reads were not rejected"; }

    jq '.projects = [] | .fail_operations = ["issue:121"]' "$state" >"$fixture/partial.json"
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$fixture/partial.json" --confirm APPLY --retry 0 \
        --evidence-dir "$fixture/partial-evidence" 2>&1 || true)"
    print -r -- "$output" | grep -q '"status":"incomplete"' ||
        fail "partial fixture failure did not produce an incomplete result"
    print -r -- "$output" | grep '^{' | tail -1 | jq -e '.missing_children | any(.[]; . == "issue:121")' >/dev/null ||
        fail "final missing_children did not include the failed child"
    if print -r -- "$output" | grep '^{' | tail -1 | jq -e '.missing_children | any(.[]; . == "field:Status")' >/dev/null; then
        fail "result retained stale pre-mutation missing_children"
    fi
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$fixture/partial.json" --confirm APPLY --retry 1 2>&1 || true)"
    print -r -- "$output" | grep -q '"status":"hard_failure"' ||
        fail "retry without current-turn authorization was not rejected"
    output="$(mise run gh:project -- \
        --plan "$plan" --fixture "$fixture/partial.json" --confirm APPLY --retry 1 \
        --retry-authorization "$authorization" --evidence-dir "$fixture/partial-evidence")"
    [[ "$(jq -r '.second_read.converged' <<<"$output")" == true ]] ||
        fail "partial fixture retry did not converge"
    for field in owner expires plan_digest; do
        case "$field" in
            owner) jq '.owner = "stale-owner"' "$authorization" >"$fixture/stale-authorization.json" ;;
            expires) jq '.expires = "next turn"' "$authorization" >"$fixture/stale-authorization.json" ;;
            plan_digest) jq '.plan_digest = ("0" * 64)' "$authorization" >"$fixture/stale-authorization.json" ;;
        esac
        output="$(mise run gh:project -- --plan "$plan" --fixture "$state" --dry-run --retry 1 \
            --retry-authorization "$fixture/stale-authorization.json" 2>/dev/null || true)"
        [[ "$(jq -r '.status' <<<"$output")" == hard_failure ]] ||
            fail "invalid retry authorization field $field was accepted"
    done

    echo "GitHub Project task tests passed."
}

main "$@"
