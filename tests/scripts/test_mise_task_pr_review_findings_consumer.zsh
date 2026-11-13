#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

local __root="$__root_dir"
local __evidence="$__root/.agents/projects.local/orchestration-and-worktree-reliability/evidence/orch-115"
local __fixture_dir="$__evidence/fixture-runtime"
local __source="$__root/.agents/projects.local/orchestration-and-worktree-reliability/evidence/orch-121/repair-v2/review-findings.v1.json"
local __schema_ledger="$__root/home/.config/mise/tasks/pr/review-findings-ledger.v1.schema.json"
local __schema_ack="$__root/home/.config/mise/tasks/pr/review-findings-ack.v1.schema.json"
local __validator="$__root/home/.config/mise/tasks/pr/review-findings-validate.ts"
local __envelope="$__fixture_dir/envelope.json"
local __state="$__fixture_dir/ledger.json"
local __ack="$__fixture_dir/ack.json"
local __error="$__fixture_dir/error"

rm -rf "$__fixture_dir"
mkdir -p "$__fixture_dir"
cleanup() {
    rm -rf "$__fixture_dir"
}
trap cleanup EXIT

cp "$__source" "$__envelope"

run_consumer() {
    local __envelope_path="$1"
    local __state_path="$2"
    local __evidence_path="${3:-}"
    if [[ -n "$__evidence_path" ]]; then
        mise run pr:review-findings-consumer -- acknowledge \
            --envelope "$__envelope_path" --state "$__state_path" --evidence "$__evidence_path"
    else
        mise run pr:review-findings-consumer -- acknowledge \
            --envelope "$__envelope_path" --state "$__state_path"
    fi
}

validate_ledger() {
    mise run pr:review-findings-validate -- ledger --input "$1" >/dev/null
}

validate_ack() {
    mise run pr:review-findings-validate -- ack --input "$1" >/dev/null
}

validate_schema() {
    local __schema_path="$1"
    local __input_path="$2"
    local __refs="${3:-}"
    bun -e '
      import Ajv2020 from "ajv/dist/2020.js";
      import { readFileSync } from "node:fs";
      const [schemaPath, inputPath, refsPath] = process.argv.slice(1);
      const ajv = new Ajv2020({ allErrors: true, allowUnionTypes: true });
      if (refsPath) ajv.addSchema(JSON.parse(readFileSync(refsPath, "utf8")));
      const validate = ajv.compile(JSON.parse(readFileSync(schemaPath, "utf8")));
      const value = JSON.parse(readFileSync(inputPath, "utf8"));
      if (!validate(value)) {
          console.error(JSON.stringify(validate.errors));
          process.exit(1);
      }
    ' "$__schema_path" "$__input_path" "$__refs"
}

assert_rejected_without_state_change() {
    local __name="$1"
    local __input_path="$2"
    local __state_path="$3"
    local __before_hash="$4"
    rm -f "$__fixture_dir/output" "$__error"
    if run_consumer "$__input_path" "$__state_path" > "$__fixture_dir/output" 2> "$__error"; then
        fail "$__name unexpectedly succeeded"
    fi
    [[ ! -s "$__fixture_dir/output" ]] || fail "$__name emitted success output"
    if [[ -e "$__state_path" ]]; then
        [[ "$(shasum -a 256 "$__state_path" | cut -d' ' -f1)" == "$__before_hash" ]] ||
            fail "$__name changed ledger bytes"
    fi
}

bun -e '
  import Ajv2020 from "ajv/dist/2020.js";
  import { readFileSync } from "node:fs";
  const [producerPath, envelopePath] = process.argv.slice(1);
  const ajv = new Ajv2020({ allErrors: true });
  const schema = JSON.parse(readFileSync(producerPath, "utf8"));
  const validate = ajv.compile(schema);
  if (!validate(JSON.parse(readFileSync(envelopePath, "utf8")))) {
    console.error(JSON.stringify(validate.errors));
    process.exit(1);
  }
' "$__root/home/.config/mise/tasks/pr/review-findings.v1.schema.json" "$__envelope" ||
    fail "producer envelope failed its JSON Schema"

run_consumer "$__envelope" "$__state" "$__ack" > "$__fixture_dir/first.json"
jq -e '
    .status == "acknowledged" and
    .ack.exact == true and
    .ack.durable == true and
    .ack.no_op == false and
    .ledger.persisted_before_ack == true and
    .cursor.advanced == true
' "$__fixture_dir/first.json" >/dev/null || fail "new acknowledgement did not prove durable persistence"
validate_ledger "$__state" || fail "ledger failed semantic validation"
validate_ack "$__ack" || fail "acknowledgement failed semantic validation"
validate_schema "$__schema_ledger" "$__state" || fail "ledger failed JSON Schema validation"
validate_schema "$__schema_ack" "$__ack" "$__schema_ledger" ||
    fail "acknowledgement failed JSON Schema validation"
jq -e '
    .schema_version == "review-findings-ledger.v1" and
    (.findings | length == 4) and
    (.acknowledged_batches | length == 1) and
    (.pending == null) and
    (.cursor.seen.reviews == ["3101@rev-31"]) and
    (.cursor.seen.inline_comments == ["pulls:3103@rev-31"]) and
    (.cursor.seen.issue_comments == ["issues:3104"])
' "$__state" >/dev/null || fail "ledger did not persist every finding before advancing seen state"

for __kind in review inline_comment issue_comment nested_comment; do
    local __wrong_source="$__fixture_dir/wrong-source-${__kind}.json"
    local __wrong_state="$__fixture_dir/wrong-source-${__kind}-ledger.json"
    jq --arg kind "$__kind" '
        (.findings[] | select(.kind == $kind) | .provenance.source) = "wrong-source"
    ' "$__envelope" > "$__wrong_source"
    local __missing_hash="missing"
    assert_rejected_without_state_change "wrong source ${__kind}" "$__wrong_source" "$__wrong_state" "$__missing_hash"
    [[ ! -e "$__wrong_state" ]] || fail "wrong source ${__kind} created a ledger"
done

jq '(.findings[0].provenance.source = "wrong-source")' "$__state" > "$__fixture_dir/wrong-source-ledger.json"
if validate_schema "$__schema_ledger" "$__fixture_dir/wrong-source-ledger.json"; then
    fail "ledger schema accepted a wrong provenance source"
fi

local __before_hash="$(shasum -a 256 "$__state" | cut -d' ' -f1)"
run_consumer "$__envelope" "$__state" > "$__fixture_dir/duplicate.json"
jq -e '.status == "duplicate" and .ack.no_op == true and .cursor.advanced == false' \
    "$__fixture_dir/duplicate.json" >/dev/null || fail "exact duplicate acknowledgement was not a no-op"
[[ "$(shasum -a 256 "$__state" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "exact duplicate acknowledgement changed ledger bytes"

jq '(.findings[0].body = "tampered committed envelope")' "$__envelope" > "$__fixture_dir/tampered-envelope.json"
assert_rejected_without_state_change \
    "tampered committed envelope" "$__fixture_dir/tampered-envelope.json" "$__state" "$__before_hash"

for __tamper in finding-envelope-digest finding-payload-digest finding-findings-digest batch-envelope-digest batch-payload-digest batch-findings-digest batch-finding-ids cursor-batch cursor-seen ledger-identity batch-identity; do
    local __tampered_state="$__fixture_dir/tampered-${__tamper}.json"
    case "$__tamper" in
        finding-envelope-digest)
            jq '(.findings[0].digest.envelope_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        finding-payload-digest)
            jq '(.findings[0].digest.payload_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        finding-findings-digest)
            jq '(.findings[0].digest.findings_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        batch-envelope-digest)
            jq '(.acknowledged_batches[0].envelope_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        batch-payload-digest)
            jq '(.acknowledged_batches[0].payload_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        batch-findings-digest)
            jq '(.acknowledged_batches[0].findings_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
                "$__state" > "$__tampered_state"
            ;;
        batch-finding-ids)
            jq '(.acknowledged_batches[0].finding_ids = .acknowledged_batches[0].finding_ids[0:3])' \
                "$__state" > "$__tampered_state"
            ;;
        cursor-batch)
            jq '(.cursor.last_acknowledged_batch_id = "foreign-batch")' "$__state" > "$__tampered_state"
            ;;
        cursor-seen)
            jq '(.cursor.seen.reviews += ["foreign-review"])' "$__state" > "$__tampered_state"
            ;;
        ledger-identity)
            jq '(.identity.candidate_id = "foreign-candidate")' "$__state" > "$__tampered_state"
            ;;
        batch-identity)
            jq '(.acknowledged_batches[0].identity.candidate_id = "foreign-candidate")' "$__state" > "$__tampered_state"
            ;;
    esac
    if validate_ledger "$__tampered_state"; then
        fail "tampered ${__tamper} ledger unexpectedly validated"
    fi
    local __tampered_before="$(shasum -a 256 "$__tampered_state" | cut -d' ' -f1)"
    assert_rejected_without_state_change "tampered ${__tamper}" "$__envelope" "$__tampered_state" "$__tampered_before"
done

jq '(.identity.candidate_id = "foreign-candidate") |
    (.findings[].identity.candidate_id = "foreign-candidate")' \
    "$__envelope" > "$__fixture_dir/mismatch.json"
__before_hash="$(shasum -a 256 "$__state" | cut -d' ' -f1)"
if run_consumer "$__fixture_dir/mismatch.json" "$__state" > "$__fixture_dir/output" 2> "$__error"; then
    fail "mismatched identity unexpectedly acknowledged"
fi
grep -qF "envelope identity does not match the ledger identity" "$__error" ||
    fail "mismatched identity error was not actionable"
[[ "$(shasum -a 256 "$__state" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "mismatched identity changed prior ledger bytes"
[[ ! -s "$__fixture_dir/output" ]] || fail "mismatched identity emitted success output"

jq '.schema_version = "review-findings.v2"' "$__envelope" > "$__fixture_dir/unknown-version.json"
__before_hash="$(shasum -a 256 "$__state" | cut -d' ' -f1)"
if run_consumer "$__fixture_dir/unknown-version.json" "$__state" > "$__fixture_dir/output" 2> "$__error"; then
    fail "unknown envelope version unexpectedly acknowledged"
fi
grep -qF "unknown review findings schema version" "$__error" ||
    fail "unknown-version error was not actionable"
[[ "$(shasum -a 256 "$__state" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "unknown-version input changed prior ledger bytes"

jq -n '{
    schema_version: "review-findings-ledger.v1",
    protocol: "persist-before-ack-v1",
    identity: null,
    findings: [],
    acknowledged_batches: [],
    cursor: {
        last_acknowledged_batch_id: null,
        seen: {reviews: [], inline_comments: [], issue_comments: []}
    },
    pending: null
}' > "$__fixture_dir/interrupted-ledger.json"
if REVIEW_FINDINGS_CONSUMER_INTERRUPT_AFTER_STAGE=1 \
    run_consumer "$__envelope" "$__fixture_dir/interrupted-ledger.json" > "$__fixture_dir/output" 2> "$__error"; then
    fail "interrupted acknowledgement unexpectedly succeeded"
fi
jq --rawfile raw "$__envelope" -e '
    .pending.envelope_bytes == $raw and
    .pending.batch_id == "orch-121-repair-v2-fixture-batch" and
    (.findings | length == 4) and
    (.cursor.seen.reviews | length == 0) and
    (.cursor.seen.inline_comments | length == 0) and
    (.cursor.seen.issue_comments | length == 0)
' "$__fixture_dir/interrupted-ledger.json" >/dev/null ||
    fail "interruption did not preserve pending bytes and prior cursor state"
validate_ledger "$__fixture_dir/interrupted-ledger.json" || fail "interrupted pending ledger failed validation"
cp "$__fixture_dir/interrupted-ledger.json" "$__fixture_dir/tampered-pending.json"
jq '(.pending.next_seen.reviews += ["foreign-review"])' "$__fixture_dir/tampered-pending.json" > "$__fixture_dir/tampered-pending.tmp"
mv "$__fixture_dir/tampered-pending.tmp" "$__fixture_dir/tampered-pending.json"
if validate_ledger "$__fixture_dir/tampered-pending.json"; then
    fail "tampered pending cursor unexpectedly validated"
fi
jq '(.pending.envelope_sha256 = "0000000000000000000000000000000000000000000000000000000000000000")' \
    "$__fixture_dir/interrupted-ledger.json" > "$__fixture_dir/tampered-pending-envelope.json"
if validate_ledger "$__fixture_dir/tampered-pending-envelope.json"; then
    fail "tampered pending envelope digest unexpectedly validated"
fi
run_consumer "$__envelope" "$__fixture_dir/interrupted-ledger.json" > "$__fixture_dir/recovered.json"
jq -e '.status == "acknowledged" and .cursor.advanced == true' "$__fixture_dir/recovered.json" >/dev/null ||
    fail "retry did not acknowledge the exact pending batch"

jq -n '{
    schema_version: "review-findings-ledger.v1",
    protocol: "persist-before-ack-v1",
    identity: null,
    findings: [],
    acknowledged_batches: [],
    cursor: {
        last_acknowledged_batch_id: null,
        seen: {reviews: [], inline_comments: [], issue_comments: []}
    },
    pending: null
}' > "$__fixture_dir/failing-ledger.json"
__before_hash="$(shasum -a 256 "$__fixture_dir/failing-ledger.json" | cut -d' ' -f1)"
if REVIEW_FINDINGS_CONSUMER_FAIL_PERSIST=stage \
    run_consumer "$__envelope" "$__fixture_dir/failing-ledger.json" > "$__fixture_dir/output" 2> "$__error"; then
    fail "persistence-failing acknowledgement unexpectedly succeeded"
fi
[[ "$(shasum -a 256 "$__fixture_dir/failing-ledger.json" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "persistence failure changed the prior ledger bytes"
jq -e '.pending == null and (.findings | length == 0)' "$__fixture_dir/failing-ledger.json" >/dev/null ||
    fail "persistence failure did not preserve the prior ledger"

echo "review-findings consumer fixture test passed"
