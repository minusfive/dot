#!/usr/bin/env zsh
#MISE description="Validate workflow structure and advisory evidence"
#MISE quiet=true
#MISE dir="{{cwd}}"
#USAGE flag "--file <path>" help="Ledger JSON file to validate"
#USAGE flag "--initialize" help="Allow a clean empty ledger during initialization"
#USAGE flag "--dry-run" help="Validate without treating an empty ledger as active"

set -euo pipefail

die() {
    print -u2 -- "error: $1"
    exit 1
}

validate_schema_artifacts() {
    local contract_schema="$1"
    local ledger_schema="$2"

    jq -e '
        ."$schema" == "https://json-schema.org/draft/2020-12/schema" and
        ."$id" == "https://minusfive.dev/schemas/mise-workflow-contract.json" and
        .unevaluatedProperties == false and
        (.required | index("authorization")) != null and
        .properties.worktree.properties.path.pattern ==
            "^(worktree://[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*|opaque://worktree/[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*)$" and
        .properties.budget.properties.mode.const == "advisory" and
        .properties.authorization.properties.source.const == "external_attestation" and
        .properties.authorization.properties.reference.pattern ==
            "^attestation://[A-Za-z0-9][A-Za-z0-9._:/~@+-]{0,191}$"
    ' "$contract_schema" >/dev/null ||
        die "invalid contract schema artifact"

    jq -e '
        ."$schema" == "https://json-schema.org/draft/2020-12/schema" and
        ."$id" == "https://minusfive.dev/schemas/mise-workflow-ledger.json" and
        .additionalProperties == false and
        .properties.contracts.items."$ref" ==
            "https://minusfive.dev/schemas/mise-workflow-contract.json" and
        .properties.records.items.allOf[0]."$ref" ==
            "https://minusfive.dev/schemas/mise-workflow-contract.json" and
        .properties.records.items.allOf[2].if.properties.record_type.const == "delivery" and
        (.description | contains("External orchestration owns"))
    ' "$ledger_schema" >/dev/null ||
        die "invalid ledger schema artifact"
}

validate_schema_shape() {
    local ledger="$1"

    jq -e '
        def printable($max):
            type == "string" and length > 0 and length <= $max and
            (explode | all(. >= 32 and . != 127));
        def identifier:
            printable(128) and test("^[A-Za-z0-9][A-Za-z0-9._:-]*$");
        def scope:
            printable(128) and test("^[a-z][a-z0-9._:-]*$");
        def ref:
            printable(192) and
            test("^(artifact|checkpoint|run|file|event)://[A-Za-z0-9][A-Za-z0-9._:/~@+-]*$");
        def timestamp_text:
            printable(64) and length >= 20;
        def safe_array(f):
            type == "array" and all(.[]; f);
        def exact_keys($allowed):
            (keys - $allowed | length) == 0;
        def valid_transition:
            type == "object" and exact_keys(["from", "to"]) and
            (.from | IN("blocked", "todo", "research", "implement", "validate", "critique", "done")) and
            (.to | IN("blocked", "todo", "research", "implement", "validate", "critique", "done"));
        def valid_worktree:
            type == "object" and exact_keys(["path", "ref", "branch"]) and
            (.path | printable(512) and
                test("^(worktree://[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*|opaque://worktree/[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*)$")) and
            (.ref | printable(192) and test("^(refs/)?[A-Za-z0-9][A-Za-z0-9._/@+-]*$")) and
            ((.branch? // null) == null or (.branch | printable(192) and
                test("^[A-Za-z0-9][A-Za-z0-9._/@+-]*$")));
        def valid_authorization($owned):
            type == "object" and
            exact_keys(["record_id", "source", "reference", "scope", "owned_paths", "expires_at"]) and
            (.record_id | identifier) and
            (.source == "external_attestation") and
            (.reference | printable(192) and
                test("^attestation://[A-Za-z0-9][A-Za-z0-9._:/~@+-]*$")) and
            (.scope | scope) and
            (.owned_paths | (safe_array(printable(512)) and length > 0)) and
            (.owned_paths | (sort == ($owned | sort))) and
            (.expires_at | timestamp_text);
        def valid_budget:
            type == "object" and
            exact_keys(["mode", "wall_clock_minutes", "tool_calls", "expires_at"]) and
            (.mode == "advisory") and
            (.wall_clock_minutes | type == "number" and isfinite and . > 0) and
            (.tool_calls | type == "number" and floor == . and . > 0) and
            (.expires_at | timestamp_text);
        def valid_checkpoint:
            type == "object" and exact_keys(["initial_at", "last_at", "next_due_at", "status"]) and
            (.initial_at | timestamp_text) and (.last_at | timestamp_text) and
            (.next_due_at | timestamp_text) and (.status | IN("pending", "received"));
        def valid_runtime:
            type == "object" and
            (keys - ["attestation_ref", "measured_start_at", "measured_end_at", "measured_tool_calls",
                "measured_wall_clock_minutes", "budget_tool_calls",
                "budget_wall_clock_minutes", "within_tool_call_budget",
                "within_wall_clock_budget", "checkpoint_event_ids",
                "cancellation_status", "stop_status"] | length == 0) and
            ((.attestation_ref? // null) == null or
                (.attestation_ref | printable(192) and
                    test("^attestation://[A-Za-z0-9][A-Za-z0-9._:/~@+-]*$"))) and
            (.measured_start_at | timestamp_text) and (.measured_end_at | timestamp_text) and
            (.measured_tool_calls | type == "number" and floor == . and . >= 0) and
            (.measured_wall_clock_minutes | type == "number" and isfinite and . >= 0) and
            (.budget_tool_calls | type == "number" and floor == . and . > 0) and
            (.budget_wall_clock_minutes | type == "number" and isfinite and . > 0) and
            (.within_tool_call_budget | type == "boolean") and
            (.within_wall_clock_budget | type == "boolean") and
            (.checkpoint_event_ids | (safe_array(ref) and length > 0)) and
            (.cancellation_status | IN("not_cancelled", "cancelled")) and
            (.stop_status | IN("completed", "stopped", "cancelled"));
        def valid_evidence:
            type == "object" and
            exact_keys(["recorded_at", "reason", "unblock_condition", "resumed_from", "resumed_to", "runtime"]) and
            (.recorded_at | timestamp_text) and
            (.reason | printable(512)) and
            ((.unblock_condition? // null) == null or (.unblock_condition | printable(512))) and
            ((.resumed_from? // null) == null or
                (.resumed_from | IN("blocked", "todo", "research", "implement", "validate", "critique", "done"))) and
            ((.resumed_to? // null) == null or
                (.resumed_to | IN("blocked", "todo", "research", "implement", "validate", "critique", "done"))) and
            ((.runtime? // null) == null or (.runtime | valid_runtime));
        def valid_paths:
            safe_array(printable(512));
        def valid_contract($record):
            (.owned_paths) as $owned |
            type == "object" and
            (if $record then
                exact_keys(["workflow_id", "candidate_id", "lane_id", "artifact_id", "state_owner",
                    "worktree", "owned_paths", "excluded_paths", "authorization", "budget",
                    "checkpoint", "dependencies", "acceptance", "evidence_refs", "redaction_status",
                    "terminal_state", "state", "record_id", "record_type", "record_status",
                    "evidence", "transition"])
            else
                exact_keys(["workflow_id", "candidate_id", "lane_id", "artifact_id", "state_owner",
                    "worktree", "owned_paths", "excluded_paths", "authorization", "budget",
                    "checkpoint", "dependencies", "acceptance", "evidence_refs",
                    "redaction_status", "terminal_state", "state"])
            end) and
            (.workflow_id | identifier) and (.candidate_id | identifier) and
            (.lane_id | identifier) and (.artifact_id | identifier) and
            (.state_owner | identifier) and (.worktree | valid_worktree) and
            (.owned_paths | ((type == "array" and length > 0) and (valid_paths))) and
            (.excluded_paths | valid_paths) and
            (.authorization | valid_authorization($owned)) and
            (.budget | valid_budget) and (.checkpoint | valid_checkpoint) and
            (.dependencies | safe_array(identifier)) and
            (.acceptance | (safe_array(printable(512)) and length > 0)) and
            (.evidence_refs | (safe_array(ref) and length > 0)) and
            (.redaction_status | IN("clean", "redacted")) and
            (.terminal_state == null or (.terminal_state | IN("closed", "escalated", "deferred"))) and
            (.state | IN("blocked", "todo", "research", "implement", "validate", "critique", "done")) and
            (if $record then
                (.record_id | identifier) and
                (.record_type | IN("checkpoint", "delivery", "finding", "handoff", "review", "frozen", "recovery")) and
                (.record_status | IN("historical", "active")) and
                (if .record_type == "delivery" then .record_status == "active"
                else .record_status == "historical" end) and
                (.transition | valid_transition) and
                ((.evidence? // null) == null or (.evidence | valid_evidence)) and
                (if .record_type == "frozen" then
                    .state == "blocked" and (.evidence.unblock_condition? | printable(512))
                elif .record_type == "recovery" then
                    .transition.from == "blocked" and .transition.to == "research" and
                    .evidence.resumed_from == "blocked" and .evidence.resumed_to == "research"
                else true end) and
                true
            else
                ((has("record_id") or has("record_type") or has("record_status") or
                    has("evidence") or has("transition")) | not)
            end);
        (type == "object") and
        if (type != "object") or (.version != 1) or
            (.contracts | type != "array") or (.records | type != "array") then
            false
        elif ((keys - ["version", "workflow_id", "contracts", "records"]) | length > 0) then
            false
        elif (((.contracts | length > 0) or (.records | length > 0)) and
            ((.workflow_id? // null) | identifier | not)) then
            false
        elif (has("workflow_id") and ((.workflow_id | identifier) | not)) then
            false
        elif ((.contracts | length == 0) and (.records | length == 0)) then
            true
        else
            all(.contracts[]; valid_contract(false)) and
            all(.records[]; valid_contract(true))
        end
    ' "$ledger" >/dev/null || die "ledger does not match the workflow schemas"
}

validate_trusted_claims() {
    local ledger="$1"

    jq -e '
        def trusted_key:
            ascii_downcase |
            test("(^|_)(authorized|verified|trusted|proof|enforced)(_|$)");
        def trusted_value:
            (type == "string") and
            ((ascii_downcase) |
                IN("authorized", "runtime_verified", "trusted", "verified",
                    "runtime_enforced", "budget_enforced"));
        def safe:
            if type == "object" then
                all(to_entries[];
                    (.key | trusted_key | not) and (.value | safe))
            elif type == "array" then
                all(.[]; safe)
            else
                (trusted_value | not)
            end;
        safe
    ' "$ledger" >/dev/null ||
        die "ledger contains a trusted-status claim"
}

validate_timestamps() {
    local ledger="$1"

    jq -e '
        def timestamp:
            if type != "string" then null
            elif test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$") then
                try (
                    capture("^(?<date>[0-9]{4}-[0-9]{2}-[0-9]{2})(T(?<clock>[0-9]{2}:[0-9]{2}:[0-9]{2}))(?<fraction>\\.[0-9]+)?(?<zone>Z|(?<sign>[+-])(?<hour>[0-9]{2}):(?<minute>[0-9]{2}))$") as $parts |
                    (($parts.date + "T" + $parts.clock) | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $base |
                    (($parts.fraction // ".0") |
                        sub("^\\."; "") |
                        sub("0+$"; "") |
                        if . == "" then "0" else . end) as $fraction |
                    if ($parts.zone != "Z" and
                        (($parts.hour | tonumber) > 23 or ($parts.minute | tonumber) > 59)) then null
                    else
                        (if $parts.zone == "Z" then 0
                        else ($parts.hour | tonumber) * 3600 + ($parts.minute | tonumber) * 60
                        end) as $offset |
                        {
                            seconds: (
                                if $parts.zone == "Z" then $base
                                elif $parts.sign == "+" then $base - $offset
                                else $base + $offset
                                end
                            ),
                            fraction: $fraction
                        }
                    end
                ) catch null
            else null end;
        def pad_fraction($fraction; $length):
            $fraction +
                (reduce range(($fraction | length); $length) as $index
                    (""; . + "0"));
        def compare_timestamps($left; $right):
            if $left.seconds < $right.seconds then -1
            elif $left.seconds > $right.seconds then 1
            else
                ([$left.fraction | length, $right.fraction | length] | max) as $length |
                (pad_fraction($left.fraction; $length)) as $left_fraction |
                (pad_fraction($right.fraction; $length)) as $right_fraction |
                if $left_fraction < $right_fraction then -1
                elif $left_fraction > $right_fraction then 1
                else 0
                end
            end;
        def timestamp_le($left; $right):
            compare_timestamps($left; $right) <= 0;
        def timestamp_ge($left; $right):
            compare_timestamps($left; $right) >= 0;
        def valid_runtime:
            (.evidence.runtime? // null) as $runtime |
            if $runtime == null then true
            else
                ($runtime.measured_start_at | timestamp) as $start |
                ($runtime.measured_end_at | timestamp) as $end |
                $start != null and $end != null and timestamp_le($start; $end)
            end;
        def valid_entry($record):
            (.checkpoint.initial_at | timestamp) as $initial |
            (.checkpoint.last_at | timestamp) as $last |
            (.checkpoint.next_due_at | timestamp) as $next |
            ($initial != null and $last != null and $next != null and
                timestamp_le($initial; $last) and timestamp_le($last; $next) and
                valid_runtime);
        def componentwise_ge($current; $previous):
            all(range(0; ($current | length));
                timestamp_ge($current[.]; $previous[.]));
        . as $ledger |
        ([$ledger.contracts[] |
            {
                key: ([.lane_id, .candidate_id] | join("\u0000")),
                value: ([.checkpoint.initial_at, .checkpoint.last_at,
                    .checkpoint.next_due_at] | map(timestamp))
            }
        ] | from_entries) as $initial |
        all($ledger.contracts[]; valid_entry(false)) and
        all($ledger.records[]; valid_entry(true)) and
        (reduce ($ledger.records[]?) as $record
            ({previous: $initial, valid: true};
             ([$record.lane_id, $record.candidate_id] | join("\u0000")) as $key |
             ([$record.checkpoint.initial_at, $record.checkpoint.last_at,
                 $record.checkpoint.next_due_at] | map(timestamp)) as $current |
             . as $state |
             .valid = (.valid and
                 ($state.previous[$key] != null) and
                 componentwise_ge($current; $state.previous[$key])) |
             .previous[$key] = $current
            ) | .valid)
    ' "$ledger" >/dev/null || die "ledger contains invalid or out-of-order timestamps"
}

validate_transitions() {
    local ledger="$1"

    jq -e '
        def valid_transition:
            (.from == "blocked" and .to == "todo") or
            (.from == "blocked" and .to == "research") or
            (.from == "todo" and .to == "blocked") or
            (.from == "research" and .to == "blocked") or
            (.from == "implement" and .to == "blocked") or
            (.from == "validate" and .to == "blocked") or
            (.from == "critique" and .to == "blocked") or
            (.from == "todo" and .to == "research") or
            (.from == "research" and .to == "implement") or
            (.from == "implement" and .to == "validate") or
            (.from == "validate" and .to == "critique") or
            (.from == "critique" and .to == "done") or
            (.from == "critique" and .to == "research");
        . as $ledger |
        ($ledger.contracts | map({key: .candidate_id, value: .state}) | from_entries) as $initial |
        (all($ledger.contracts[]; .transition == null or (.transition.to == .state and
            (.transition | valid_transition)))) and
        (reduce $ledger.records[] as $record
            ({last: {}, valid: true};
             if .last[$record.candidate_id] == null then
                .valid = (.valid and $record.transition.from == $initial[$record.candidate_id] and
                    $record.transition.to == $record.state and ($record.transition | valid_transition)) |
                .last[$record.candidate_id] = $record.state
             else
                .valid = (.valid and $record.transition.from == .last[$record.candidate_id] and
                    $record.transition.to == $record.state and ($record.transition | valid_transition)) |
                .last[$record.candidate_id] = $record.state
             end) | .valid)
    ' "$ledger" >/dev/null || die "invalid or discontinuous state transition"
}

validate_record_identities() {
    local ledger="$1"

    jq -e '
        def identity($historical):
            {
                workflow_id, candidate_id, lane_id, artifact_id, state_owner,
                worktree: {
                    path: .worktree.path,
                    ref: .worktree.ref,
                    branch: (.worktree.branch // null)
                },
                owned_paths: (.owned_paths | sort),
                excluded_paths: (.excluded_paths | sort),
                authorization: {
                    record_id: .authorization.record_id,
                    scope: .authorization.scope,
                    owned_paths: (.authorization.owned_paths | sort)
                },
                budget: (if $historical then
                    {mode: .budget.mode, wall_clock_minutes: .budget.wall_clock_minutes,
                        tool_calls: .budget.tool_calls}
                else
                    {mode: .budget.mode, wall_clock_minutes: .budget.wall_clock_minutes,
                        tool_calls: .budget.tool_calls, expires_at: .budget.expires_at}
                end),
                dependencies: (.dependencies | sort),
                acceptance
            };
        . as $ledger |
        ([.contracts[].candidate_id] | length == (unique | length)) and
        ([.contracts[].lane_id] | length == (unique | length)) and
        ([.contracts[].artifact_id] | length == (unique | length)) and
        ([.records[].record_id] | length == (unique | length)) and
        (all(.contracts[]; .workflow_id == $ledger.workflow_id)) and
        (all(.records[]; .workflow_id == $ledger.workflow_id)) and
        ((.contracts | map({key: .candidate_id, value: .}) | from_entries) as $contracts |
            all(.records[];
                ($contracts[.candidate_id] // null) as $contract |
                . as $record |
                ($record.record_type == "frozen" or $record.record_type == "recovery") as $historical |
                $contract != null and
                ($record | identity($historical)) == ($contract | identity($historical))))
    ' "$ledger" >/dev/null || die "ledger contains missing or inconsistent identities"
}

validate_dependencies() {
    local ledger="$1"

    jq -e '
        . as $ledger |
        [$ledger.contracts[].candidate_id] as $ids |
        ($ledger.contracts | map({key: .candidate_id, value: .dependencies}) | from_entries) as $graph |
        def known($dependency; $owner):
            ($dependency | type == "string" and length > 0) and $dependency != $owner and
            ($ids | index($dependency)) != null;
        def reaches($node; $seen):
            if ($seen | index($node)) != null then true
            else any(($graph[$node] // [])[]; reaches(.; $seen + [$node]))
            end;
        (all($ledger.contracts[]; .candidate_id as $owner |
            all(.dependencies[]; known(.; $owner)))) and
        (all($ledger.records[]; .candidate_id as $owner |
            all(.dependencies[]; known(.; $owner)))) and
        (all($ids[]; (reaches(.; []) | not)))
    ' "$ledger" >/dev/null || die "ledger contains an unresolved, self-referential, or cyclic dependency"
}

validate_paths() {
    local ledger="$1"

    jq -e '
        def repository_path:
            type == "string" and length > 0 and length <= 512 and
            (explode | all(. >= 32 and . <= 127 and . != 127)) and
            test("^[A-Za-z0-9._/@+-]+$") and
            (startswith("/") | not) and (startswith("~") | not) and
            (startswith("./") | not) and (endswith("/") | not) and
            ((split("/") | any(. == "" or . == "." or . == "..")) | not);
        def normalize_path:
            gsub("/+"; "/") | ascii_downcase;
        def opaque_worktree:
            test("^opaque://worktree/[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*$") or
            test("^worktree://[A-Za-z0-9][A-Za-z0-9._~-]*(/[A-Za-z0-9][A-Za-z0-9._~-]*)*$");
        def worktree_path:
            type == "string" and length > 0 and length <= 512 and
            (explode | all(. >= 32 and . <= 127 and . != 127)) and
            opaque_worktree;
        def overlap($left; $right):
            ($left | normalize_path) as $left_normalized |
            ($right | normalize_path) as $right_normalized |
            $left_normalized == $right_normalized or
            ($left_normalized | startswith($right_normalized + "/")) or
            ($right_normalized | startswith($left_normalized + "/"));
        def sensitive:
            normalize_path as $path |
            ($path | split("/")) as $parts |
            ($parts[-1]) as $name |
            ($parts | any(
                . == ".git" or . == ".ssh" or . == "ssh" or
                . == "ci" or . == ".ci" or . == "credentials" or
                . == "credential" or . == "secrets" or . == "secret" or
                . == "deploy" or . == "deployment" or . == "deployments" or
                . == "auth" or . == "authentication" or . == "private-key" or
                . == "private_key" or . == "privatekey" or
                . == "key" or . == "keys" or . == "cert" or
                . == "certificate" or . == "certificates")) or
            ($path == ".github/workflows" or
                ($path | startswith(".github/workflows/")) or
                $path == ".github/actions" or
                ($path | startswith(".github/actions/")) or
                ($path | startswith(".circleci/")) or
                ($path | startswith(".buildkite/")) or
                ($path | startswith(".gitlab/")) or
                $name == ".gitlab-ci.yml" or $name == ".travis.yml" or
                $name == "azure-pipelines.yml" or $name == "jenkinsfile" or
                $name == "config" or $name == "authorized_keys" or
                $name == "known_hosts" or
                $name == "credentials.json" or $name == "secret.txt" or
                $name == "auth.json" or
                ($name | test("(^|[._-])(ssh|key|keys|cert|certificate|private|credential|secret|auth|ci|deploy|deployment)([._-]|$)")) or
                ($name | test("^id_(rsa|dsa|ecdsa|ed25519)(|_sk)$")) or
                ($name | test("\\.(key|pub|pem|crt|cer|der|p12|pfx)$")) or
                ($name | test("^\\.env($|\\.)")));
        def unique_normalized($paths):
            ($paths | map(normalize_path)) as $normalized |
            ($normalized | length == (unique | length));
        def valid_claims:
            (.owned_paths | all(.[]; repository_path and (sensitive | not))) and
            (.excluded_paths | all(.[]; repository_path and (sensitive | not))) and
            unique_normalized(.owned_paths) and unique_normalized(.excluded_paths) and
            (. as $claim |
                all($claim.owned_paths[]; . as $owned |
                    all($claim.excluded_paths[]; . as $excluded |
                        (overlap($owned; $excluded) | not))));
        def claims_for($contract):
            {candidate_id: $contract.candidate_id,
                paths: $contract.owned_paths};
        (all((.contracts[]?, .records[]?); .worktree.path | worktree_path)) and
        (all(.contracts[]; valid_claims)) and (all(.records[]; valid_claims)) and
        ([.contracts[] | claims_for(.)] as $claims |
            all($claims[]; . as $left |
                all($claims[]; . as $right |
                    ($left.candidate_id >= $right.candidate_id) or
                    all($left.paths[]; . as $left_path |
                        all($right.paths[]; . as $right_path |
                            (overlap($left_path; $right_path) | not))))))
    ' "$ledger" >/dev/null || die "ledger contains unsafe, sensitive, non-canonical, or overlapping paths"
}

check_secret_like_values() {
    local ledger="$1"

    jq -e '
        def redaction_token:
            "(<redacted>|\\[redacted\\]|\\{redacted\\}|\\*{3,}|\\bmasked\\b|\\bremoved\\b)";
        def normalized_key:
            tostring | ascii_downcase | gsub("[^a-z0-9]"; "");
        def sensitive_key:
            normalized_key as $key |
            ($key == "sig" or ($key | test(
                "(apikey|apitoken|accesstoken|refreshtoken|clientsecret|oauthtoken|githubtoken|bearertoken|sessiontoken|token|secret|password|credential|cookie|privatekey|signingkey|encryptionkey|sshkey|basicauth|signedurl|signature)"
            )));
        def credential_token:
            (length >= 16 and
                (
                    test("^[a-f0-9]+$") or
                    test("^[A-F0-9]+$") or
                    ([
                        test("^[0-9]+$"),
                        test("^[^A-Za-z0-9]+$")
                    ] | any) or
                    ([
                        test("[A-Z]"), test("[a-z]"), test("[0-9]"),
                        test("[^A-Za-z0-9]")
                    ] | map(select(.)) | length) >= 3
                ));
        def credential_authorization:
            [match("(?i)(?<scheme>bearer|basic)[[:space:]]+" +
                "(?<credential>[A-Za-z0-9+/=_.~-]+)"; "g") |
                (.captures | map({key: .name, value: .string}) | from_entries).credential |
                credential_token] | any;
        def secret_pattern:
            gsub("(?i)" + redaction_token; "") |
            (test("(?i)(ghp_[A-Za-z0-9_]+|github_pat_[A-Za-z0-9_]+|xox[baprs]-[A-Za-z0-9-]+|AKIA[0-9A-Z]{16})") or
             credential_authorization or
             test("-----BEGIN [A-Z ]*PRIVATE KEY-----") or
             test("(?i)(^|[?&[:space:]])(signature|sig|token|access_token|api_key|client_secret|password)=[^&#[:space:]]+") or
             test("(?i)(cookie:|set-cookie:|(^|[;[:space:]])(session|sid|phpsessid|csrftoken|sessionid)=[^;[:space:]]+)") or
             test("(?i)(api[_-]?key|secret[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]]+"));
        def fully_redacted:
            test("(?i)^\\s*" + redaction_token + "\\s*$") or
            test("(?i)^\\s*(bearer|basic)[[:space:]]+" + redaction_token + "\\s*$") or
            test("(?i)^\\s*https?://[^[:space:]]*[?&](signature|sig|token|access_token|api_key|client_secret|password)=" +
                redaction_token + "([&#][^[:space:]]*)?\\s*$");
        def valid_value($sensitive):
            ((. | secret_pattern) | not) and
            (($sensitive | not) or (type == "string" and fully_redacted));
        def walk($sensitive):
            if type == "object" or type == "array" then
                all(to_entries[]; . as $entry |
                    ($entry.key | sensitive_key) as $key_sensitive |
                    ($entry.value | walk($sensitive or $key_sensitive)))
            elif type == "string" then valid_value($sensitive)
            elif $sensitive then false
            else true end;
        walk(false)
    ' "$ledger" >/dev/null || die "ledger contains an unredacted secret-like value"
}

validate_review_delivery() {
    local ledger="$1"

    jq -e '
        def identity:
            {
                workflow_id, candidate_id, lane_id, artifact_id, state_owner,
                worktree, owned_paths, excluded_paths, dependencies, acceptance
            };
        . as $ledger |
        all($ledger.records | to_entries[] | select(.value.record_type == "delivery") |
            . as $delivery |
            any($ledger.records[:$delivery.key][];
                .record_type == "review" and
                ((. | identity) == ($delivery.value | identity))))
    ' "$ledger" >/dev/null || die "delivery has no matching prior review contract"
}

validate_redaction_status() {
    local ledger="$1"

    jq -e '
        def marker:
            type == "string" and
            test("(?i)(<redacted>|\\[redacted\\]|\\{redacted\\}|\\*{3,}|\\bmasked\\b|\\bremoved\\b)");
        all((.contracts[]?, .records[]?);
            . as $entry |
            ([paths(scalars) as $path | getpath($path)] | any(marker)) as $has_marker |
            (($entry.redaction_status == "redacted") == $has_marker))
    ' "$ledger" >/dev/null || die "ledger entry redaction status does not match its content"
}

redaction_status() {
    local ledger="$1"

    jq -r '
        def marker:
            type == "string" and
            test("(?i)(<redacted>|\\[redacted\\]|\\{redacted\\}|\\*{3,}|\\bmasked\\b|\\bremoved\\b)");
        if any([paths(scalars) as $path | getpath($path)][]; marker) then
            "redacted"
        else "clean" end
    ' "$ledger"
}

main() {
    local project_root file task_dir schema_contract schema_ledger redaction
    local initialize="${usage_initialize:-false}"
    local dry_run="${usage_dry_run:-false}"

    project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$project_root" ]] || die "this task must be run inside a git repository"
    file="${usage_file:-}"
    [[ -n "$file" ]] || die "--file is required"
    [[ "$file" == /* ]] || file="${PWD}/${file}"
    [[ -f "$file" && ! -L "$file" ]] || die "ledger file is not a regular file"

    task_dir="${0:A:h}"
    schema_contract="${task_dir}/contract.schema.json"
    schema_ledger="${task_dir}/ledger.schema.json"
    if [[ ! -f "$schema_contract" || ! -f "$schema_ledger" ]]; then
        schema_contract="${project_root}/home/.config/mise/tasks/ai/workflow/contract.schema.json"
        schema_ledger="${project_root}/home/.config/mise/tasks/ai/workflow/ledger.schema.json"
    fi
    [[ -f "$schema_contract" && -f "$schema_ledger" ]] ||
        die "workflow schema files are missing"
    jq empty "$schema_contract" >/dev/null 2>&1 || die "invalid contract schema"
    jq empty "$schema_ledger" >/dev/null 2>&1 || die "invalid ledger schema"
    validate_schema_artifacts "$schema_contract" "$schema_ledger"
    jq empty "$file" >/dev/null 2>&1 || die "malformed JSON"

    validate_trusted_claims "$file"
    validate_schema_shape "$file"
    check_secret_like_values "$file"
    validate_paths "$file"
    validate_record_identities "$file"
    validate_transitions "$file"
    validate_timestamps "$file"
    validate_dependencies "$file"
    validate_review_delivery "$file"
    validate_redaction_status "$file"
    redaction="$(redaction_status "$file")"
    print -- "status=valid_structure redaction=${redaction}"

    if jq -e '.contracts == [] and .records == []' "$file" >/dev/null 2>&1; then
        [[ "$initialize" == true || "$dry_run" == true ]] ||
            die "empty ledger is allowed only with --initialize or --dry-run"
        print -- "Workflow ledger is clean and initialized (redaction: ${redaction})."
        return
    fi

    if jq -e 'any(.records[]?; .record_type == "delivery")' "$file" >/dev/null; then
        print -- "status=requires_external_authorization"
        print -- "status=requires_external_runtime"
        print -u2 -- "error: external orchestration must authorize and measure delivery"
        return 1
    fi

    if [[ "$dry_run" == true ]]; then
        print -- "Workflow ledger is valid (dry run; redaction: ${redaction})."
    else
        print -- "Workflow ledger is valid (redaction: ${redaction})."
    fi
}

main "$@"
