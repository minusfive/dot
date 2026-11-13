#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

local __task="$__root_dir/home/.config/mise/tasks/pr/review-watch.ts"
local __fixture_dir
__fixture_dir="$(test_fixture_dir pr-review-watch)" || exit 1
cleanup() {
    chflags -R nouchg "$__fixture_dir" 2>/dev/null || true
    rm -rf "$__fixture_dir"
}
trap cleanup EXIT
local __bin_dir="$__fixture_dir/bin"
local __state_file="$__fixture_dir/watch.json"
local __log_file="$__fixture_dir/gh.log"
local __poll_output="$__fixture_dir/poll.json"
local __schema="$__root_dir/home/.config/mise/tasks/pr/review-findings.v1.schema.json"
local __repository="$(
    env \
        usage_action=list \
        usage_state_file="$__state_file" \
        usage_format=json \
        bun "$__task" | jq -r '.repository'
)"

mkdir -p "$__bin_dir"

cat > "$__bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GH_REVIEW_WATCH_LOG"
if [[ "$1" == api && "$*" == *" --paginate --slurp "* ]]; then
    [[ "$2" == "--hostname" && "$3" == "github.com" ]] ||
        { printf 'unexpected REST hostname argv: %s\n' "$*" >&2; exit 1; }
    [[ "$4" == "--method" && "$5" == "GET" ]] ||
        { printf 'REST pagination request did not use GET: %s\n' "$*" >&2; exit 1; }
    [[ "$6" == "--paginate" && "$7" == "--slurp" ]] ||
        { printf 'REST pagination flags changed: %s\n' "$*" >&2; exit 1; }
    [[ "$#" -eq 8 ]] ||
        { printf 'REST pagination argv shape changed: %s\n' "$*" >&2; exit 1; }
    [[ "$8" == repos/*"?per_page=100" ]] ||
        { printf 'REST page size was not encoded in the GET URL: %s\n' "$*" >&2; exit 1; }
    [[ "$*" != *" -f "* && "$*" != *" -F "* && "$*" != *" --input "* && "$*" != *" POST "* ]] ||
        { printf 'REST pagination request included a form or POST body argument: %s\n' "$*" >&2; exit 1; }
    {
        printf 'REST_ARGV'
        printf ' %s' "$@"
        printf '\n'
    } >> "$GH_REVIEW_WATCH_LOG"
fi
if [[ -n "${GH_REVIEW_WATCH_DELAY:-}" ]]; then
    sleep "$GH_REVIEW_WATCH_DELAY"
fi
if [[ "${GH_REVIEW_WATCH_FAIL_PR:-}" == "6" && "$*" == *"pr view 6"* ]]; then
    printf 'simulated PR failure\n' >&2
    exit 1
fi
if [[ "$1" == pr && "$2" == view ]]; then
    number="$3"
    if [[ "${GH_REVIEW_WATCH_FAIL_PR:-}" == "$number" ]]; then
        printf 'simulated PR failure\n' >&2
        exit 1
    fi
    cat "$GH_REVIEW_WATCH_FIXTURES/pr-$number.json"
    exit 0
fi
if [[ "$1" == api ]]; then
    if [[ "$*" == *" graphql "* || "$*" == *" graphql" ]]; then
        if [[ "${GH_REVIEW_WATCH_GRAPHQL_FAIL:-}" == "1" ]]; then
            printf 'simulated GraphQL failure\n' >&2
            exit 1
        fi
        if [[ "${GH_REVIEW_WATCH_GRAPHQL_REJECT_LEGACY:-}" == "1" && "$*" == *"pullRequestReviewThread"* ]]; then
            printf 'simulated unsupported GraphQL field\n' >&2
            exit 1
        fi
        if [[ -n "${GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE:-}" && "$*" == *"PullRequestReviewThread"* ]]; then
            if [[ -n "${GH_REVIEW_WATCH_GRAPHQL_INNER_PAGE_FIXTURE:-}" && "$*" == *"cursor=inner-next"* ]]; then
                cat "$GH_REVIEW_WATCH_GRAPHQL_INNER_PAGE_FIXTURE"
            else
                cat "$GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE"
            fi
        elif [[ -n "${GH_REVIEW_WATCH_GRAPHQL_FIXTURE:-}" ]]; then
            if [[ -n "${GH_REVIEW_WATCH_GRAPHQL_PAGE_FIXTURE:-}" && "$*" == *"cursor=outer-next"* ]]; then
                cat "$GH_REVIEW_WATCH_GRAPHQL_PAGE_FIXTURE"
            else
                cat "$GH_REVIEW_WATCH_GRAPHQL_FIXTURE"
            fi
        else
            printf '{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"isResolved":false,"comments":{"nodes":[{"id":"RC_201","fullDatabaseId":"201"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}\n'
        fi
        exit 0
    fi
    path="${@: -1}"
    request_path="${path%%\?*}"
    kind="$(printf '%s' "$request_path" | cut -d/ -f4)"
    number="$(printf '%s' "$request_path" | cut -d/ -f5)"
    if [[ "$request_path" == */reviews ]]; then
        if [[ "${GH_REVIEW_WATCH_REST_RAW:-}" == "1" ]]; then
            jq -c '[.reviews // []]' "$GH_REVIEW_WATCH_FIXTURES/pr-$number.json"
        else
            jq -c '[[ (.reviews // [])[] | if has("submittedAt") then .submitted_at = .submittedAt | del(.submittedAt) else . end ]]' \
                "$GH_REVIEW_WATCH_FIXTURES/pr-$number.json"
        fi
        exit 0
    fi
    if [[ "${GH_REVIEW_WATCH_FAIL_ENDPOINT:-}" == "$request_path" ]]; then
        printf 'simulated API failure\n' >&2
        exit 1
    fi
    if [[ "${GH_REVIEW_WATCH_RENAME_FAIL:-}" == "1" ]]; then
        chflags uchg "$GH_REVIEW_WATCH_STATE"
    fi
    cat "$GH_REVIEW_WATCH_FIXTURES/$kind-$number.json"
    exit 0
fi
printf 'unexpected gh invocation: %s\n' "$*" >&2
exit 1
EOF
chmod +x "$__bin_dir/gh"

write_fixture() {
    local __number="$1"
    local __state="${2:-OPEN}"
    local __merged="${3:-null}"
    local __closed="${4:-null}"
    cat > "$__fixture_dir/pr-$__number.json" <<EOF
{"number":$__number,"state":"$__state","mergedAt":$__merged,"closedAt":$__closed,"headRefName":"review-$__number","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[{"name":"build","status":"COMPLETED","conclusion":"SUCCESS"}]}
EOF
}

write_state() {
    local __contents="$1"
    printf '%s\n' "$__contents" > "$__state_file"
}

run_poll() {
    env \
        PATH="$__bin_dir:$PATH" \
        GH_REVIEW_WATCH_FIXTURES="$__fixture_dir" \
        GH_REVIEW_WATCH_LOG="$__log_file" \
        GH_REVIEW_WATCH_STATE="$__state_file" \
        usage_action=poll \
        usage_state_file="$__state_file" \
        usage_format=json \
        bun "$__task"
}

run_action() {
    local __action="$1"
    local __pull_requests="${2:-}"
    local __format="${3:-json}"
    env \
        PATH="$__bin_dir:$PATH" \
        GH_REVIEW_WATCH_FIXTURES="$__fixture_dir" \
        GH_REVIEW_WATCH_LOG="$__log_file" \
        GH_REVIEW_WATCH_STATE="$__state_file" \
        usage_action="$__action" \
        usage_pull_requests="$__pull_requests" \
        usage_state_file="$__state_file" \
        usage_format="$__format" \
        bun "$__task"
}

validate_findings_schema() {
    bun -e '
      import Ajv2020 from "ajv/dist/2020.js";
      import { readFileSync } from "node:fs";
      const schema = JSON.parse(readFileSync(process.argv[1], "utf8"));
      const output = JSON.parse(readFileSync(process.argv[2], "utf8"));
      const validate = new Ajv2020({ allErrors: true }).compile(schema);
      if (!validate(output.review_findings)) {
          console.error(JSON.stringify(validate.errors));
          process.exit(1);
      }
    ' "$__schema" "$1"
}

write_fixture 10
cat > "$__fixture_dir/pr-10.json" <<'EOF'
{"number":10,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-10","reviewDecision":"CHANGES_REQUESTED","reviews":[{"id":101,"node_id":"R_101","author":{"login":"reviewer"},"submittedAt":"2024-01-02T00:00:00Z","state":"CHANGES_REQUESTED","body":"First line\nFull review body","url":"https://example.test/review/101"}],"statusCheckRollup":[{"name":"build","status":"COMPLETED","conclusion":"SUCCESS"}]}
EOF
cat > "$__fixture_dir/pulls-10.json" <<'EOF'
[[{"id":201,"node_id":"RC_201","pull_request_review_id":101,"in_reply_to_id":200,"user":{"login":"reviewer"},"created_at":"2024-01-03T00:00:00Z","body":"Full inline thread body","path":"src/main.ts","line":9,"start_line":8,"start_side":"LEFT","side":"RIGHT","html_url":"https://example.test/inline/201"}]]
EOF
cat > "$__fixture_dir/issues-10.json" <<'EOF'
[[{"id":301,"node_id":"IC_301","user":{"login":"commenter"},"created_at":"2024-01-04T00:00:00Z","body":"Full issue comment body","html_url":"https://example.test/issue/301"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
run_action add 10 > "$__poll_output"
jq -e '
  .reconciliation[0].reviews[0].body == "First line\nFull review body" and
  .reconciliation[0].reviews[0].id == 101 and
  .reconciliation[0].reviews[0].url == "https://example.test/review/101" and
  .reconciliation[0].inline_comments[0].body == "Full inline thread body" and
  .reconciliation[0].inline_comments[0].pull_request_review_id == 101 and
  .reconciliation[0].inline_comments[0].in_reply_to_id == 200 and
  .reconciliation[0].issue_comments[0].body == "Full issue comment body" and
  .reconciliation[0].checks[0].conclusion == "SUCCESS" and
  .reconciliation[0].action_required == true
' "$__poll_output" >/dev/null || fail "add did not reconcile complete pre-watch activity"
jq -e '
  .pull_requests[0].seen.reviews == ["101"] and
  .pull_requests[0].seen.inline_comments == ["pulls:201"] and
  .pull_requests[0].seen.issue_comments == ["issues:301"]
' "$__state_file" >/dev/null || fail "pre-watch reconciliation identifiers were not persisted"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
: > "$__log_file"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 10 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "interrupted add unexpectedly succeeded"
fi
[[ ! -s "$__poll_output" ]] || fail "interrupted add emitted reconciliation before acknowledgement"
jq -e '
  .pending_add.payload.reconciliation[0].reviews[0].body == "First line\nFull review body" and
  .pending_add.payload.reconciliation[0].inline_comments[0].body == "Full inline thread body" and
  .pending_add.payload.reconciliation[0].issue_comments[0].body == "Full issue comment body" and
  .pending_add.next_pull_requests[0].seen.reviews == ["101"] and
  (.pull_requests | length == 0)
' "$__state_file" >/dev/null || fail "interrupted add did not durably stage the complete reconciliation"
run_action list > "$__poll_output"
jq -e '
  .pending_acknowledgment.action == "add" and
  .pending_acknowledgment.requested_numbers == [10] and
  .watch_empty == false and
  .pull_requests[0].number == 10
' "$__poll_output" >/dev/null || fail "list hid the staged add acknowledgment"
cp "$__state_file" "$__fixture_dir/staged-add-backup.json"
jq '.pending_add.payload.pull_requests = []' "$__state_file" > "$__fixture_dir/staged-add-rewritten.json"
mv "$__fixture_dir/staged-add-rewritten.json" "$__state_file"
run_action list > "$__poll_output"
jq -e '
  .pending_acknowledgment == null and
  .watch_empty == true and
  (.warnings | any(contains("quarantined pending-add")))
' "$__poll_output" >/dev/null || fail "staged-add payload omission was not quarantined"
jq -e '
  (.pending_add | not) and
  (.quarantine | any(.kind == "pending-add" and .raw.payload.pull_requests == []))
' "$__state_file" >/dev/null || fail "staged-add quarantine did not preserve the malformed payload"
mv "$__fixture_dir/staged-add-backup.json" "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_action add > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "empty staged-add acknowledgment unexpectedly succeeded"
fi
grep -qF 'a staged add must be acknowledged before changing watch state' "$__fixture_dir/error" ||
    fail "empty staged-add acknowledgment error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "invalid staged-add acknowledgment emitted output"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "invalid staged-add acknowledgment changed state bytes"
: > "$__log_file"
run_action add 10 > "$__poll_output"
jq -e '
  .reconciliation[0].reviews[0].body == "First line\nFull review body" and
  .reconciliation[0].reviews[0].id == 101 and
  .reconciliation[0].inline_comments[0].body == "Full inline thread body" and
  .reconciliation[0].inline_comments[0].pull_request_review_id == 101 and
  .reconciliation[0].inline_comments[0].in_reply_to_id == 200 and
  .reconciliation[0].issue_comments[0].body == "Full issue comment body" and
  .reconciliation[0].checks[0].conclusion == "SUCCESS" and
  .reconciliation[0].action_required == true
' "$__poll_output" >/dev/null || fail "next add did not recover the complete staged reconciliation"
if grep -q '^pr view\|^api ' "$__log_file"; then
    fail "staged add recovery fetched new activity instead of acknowledging the staged result"
fi
jq -e '
  (.pending_add | not) and
  .pull_requests[0].seen.reviews == ["101"] and
  .pull_requests[0].seen.inline_comments == ["pulls:201"] and
  .pull_requests[0].seen.issue_comments == ["issues:301"]
' "$__state_file" >/dev/null ||
    fail "staged add recovery did not activate the candidate cursor"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 10 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "staged add for unrelated-state validation unexpectedly succeeded"
fi
jq '.pull_requests = [{"number":99,"addedAt":"2024-01-01T00:00:00Z"}]' "$__state_file" > "$__fixture_dir/unrelated-staged-add.json"
mv "$__fixture_dir/unrelated-staged-add.json" "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action add 10 > "$__poll_output"
jq -e '
  (.warnings | any(contains("quarantined pending-add"))) and
  (.pull_requests | map(.number) | sort == [10,99])
' "$__poll_output" >/dev/null || fail "unrelated staged state was not quarantined before add"
jq -e '
  (.quarantine | any(.kind == "pending-add")) and
  (.pull_requests | map(.number) | sort == [10,99])
' "$__state_file" >/dev/null || fail "unrelated staged state quarantine did not preserve the valid watch"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
: > "$__log_file"
if PR_REVIEW_WATCH_TEST_CRASH_AFTER_STAGE=1 run_action add 10 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "crashed add unexpectedly succeeded"
fi
[[ -d "$__state_file.lock" ]] || fail "crashed add did not leave its lock"
jq -e '
  .pending_add.payload.reconciliation[0].reviews[0].body == "First line\nFull review body" and
  .pending_add.payload.reconciliation[0].inline_comments[0].body == "Full inline thread body" and
  .pending_add.payload.reconciliation[0].issue_comments[0].body == "Full issue comment body"
' "$__state_file" >/dev/null || fail "crashed add did not preserve the complete staged findings"
: > "$__log_file"
run_action add 10 > "$__poll_output"
jq -e '
  .reconciliation[0].reviews[0].body == "First line\nFull review body" and
  .reconciliation[0].inline_comments[0].body == "Full inline thread body" and
  .reconciliation[0].issue_comments[0].body == "Full issue comment body"
' "$__poll_output" >/dev/null || fail "stale-lock recovery lost staged findings"
if grep -q '^pr view\|^api ' "$__log_file"; then
    fail "stale-lock recovery fetched new activity instead of replaying pending_add"
fi
jq -e '(.pending_add | not) and .pull_requests[0].seen.reviews == ["101"]' "$__state_file" >/dev/null ||
    fail "stale-lock recovery did not activate the staged cursor"

write_fixture 1
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[{"user":{"login":"old-inline"},"created_at":"2023-12-31T23:59:59Z","body":"old"}],[{"user":{"login":"reviewer"},"created_at":"2024-01-02T00:00:00Z","body":"new","path":"src/index.ts","line":12,"html_url":"https://example.test/inline"}]]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[[{"user":{"login":"commenter"},"created_at":"2024-01-03T00:00:00Z","body":"issue","html_url":"https://example.test/issue"}]]
EOF
cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[{"author":{"login":"reviewer"},"submittedAt":"2024-01-02T00:00:00Z","state":"COMMENTED","body":"Looks good"}],"statusCheckRollup":[{"name":"build","status":"COMPLETED","conclusion":"SUCCESS"}]}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
: > "$__log_file"
run_poll > "$__poll_output"
jq -e '
  .action == "poll" and
  .repository == $repo and
  (.warnings | type == "array") and
  (.pull_requests | length == 1) and
  .pull_requests[0].has_new_activity == true and
  .pull_requests[0].has_failed_checks == false and
  .pull_requests[0].action_required == true and
  .pull_requests[0].pagination_contract == "gh-api-paginate-slurp-v1" and
  .pull_requests[0].review_metadata_contract == "gh-pr-view-reviews-v1" and
  .pull_requests[0].inline_comments_pages == 2 and
  .pull_requests[0].issue_comments_pages == 1 and
  .pull_requests[0].inline_comments_page_lengths == [1,1] and
  .pull_requests[0].issue_comments_page_lengths == [1] and
  .pull_requests[0].inline_comments_pagination_complete == true and
  .pull_requests[0].issue_comments_pagination_complete == true and
  .pull_requests[0].inline_comments_pagination_termination == "short-final-page" and
  .pull_requests[0].issue_comments_pagination_termination == "short-final-page" and
  (.pull_requests[0].new_inline_comments | length == 1) and
  (.pull_requests[0].new_issue_comments | length == 1) and
  (.pull_requests[0].new_reviews | length == 1) and
  (.review_findings.findings | map(.kind) | sort == ["inline_comment","issue_comment","review"])
' --arg repo "$__repository" "$__poll_output" >/dev/null || fail "multi-page poll output shape or cutoff is incorrect"
validate_findings_schema "$__poll_output" || fail "poll findings envelope failed JSON Schema validation"

cat > "$__fixture_dir/pr-2.json" <<'EOF'
{"number":2,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-2","headRefOid":"head-2","reviewDecision":"CHANGES_REQUESTED","reviews":[{"id":201,"author":{"login":"reviewer-2"},"submittedAt":"2024-01-03T00:00:00Z","state":"CHANGES_REQUESTED","body":"second PR"}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-2.json" <<'EOF'
[[{"id":202,"created_at":"2024-01-03T00:01:00Z","body":"second inline","path":"src/second.ts","position":4}]]
EOF
cat > "$__fixture_dir/issues-2.json" <<'EOF'
[[{"id":203,"created_at":"2024-01-03T00:02:00Z","body":"second issue"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\"},{\"number\":2,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
run_poll > "$__poll_output"
jq -e '
  (.pull_requests | length == 2) and
  (.review_findings.counts.pull_requests == 2) and
  ([.review_findings.findings[].identity.pull_request] | unique | sort == [1,2])
' "$__poll_output" >/dev/null || fail "multi-PR poll findings lost per-PR identities"
validate_findings_schema "$__poll_output" || fail "multi-PR findings envelope failed JSON Schema validation"
if grep -q -- '--jq' "$__log_file"; then
    fail "review-watch combined --slurp with incompatible --jq"
fi
grep -q -- '--paginate --slurp' "$__log_file" || fail "review-watch did not use gh api pagination"
grep -qE '^REST_ARGV api --hostname github.com --method GET --paginate --slurp repos/[^ ]+\\?per_page=100$' "$__log_file" ||
    fail "review-watch did not use the exact GET URL query argv"
if grep -qF 'REST_ARGV' "$__log_file" && grep -qE 'REST_ARGV.*( -f | -F |--input| POST )' "$__log_file"; then
    fail "review-watch emitted a REST form or POST body argument"
fi
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "successful poll left a temporary file"
[[ ! -d "$__state_file.lock" ]] || fail "successful poll left the lock"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-02T00:00:00Z\"}]}"
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[{"user":{"login":"equal"},"created_at":"2024-01-02T00:00:00Z","body":"equal"}],[{"user":{"login":"later"},"created_at":"2024-01-02T00:00:01Z","body":"later"}]]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[[]]
EOF
run_poll > "$__poll_output"
jq -e '.pull_requests[0].new_inline_comments | length == 1 and .[0].author == "later"' "$__poll_output" >/dev/null ||
    fail "subsequent poll did not use strict lastSeenAt cutoff"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-02T00:00:00Z\",\"seen\":{\"reviews\":[],\"inline_comments\":[\"pulls:401\"],\"issue_comments\":[]}}]}"
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[{"id":401,"user":{"login":"already-seen"},"created_at":"2024-01-04T00:00:00Z","body":"duplicate"}]]
EOF
run_poll > "$__poll_output"
jq -e '.pull_requests[0].new_inline_comments | length == 0' "$__poll_output" >/dev/null ||
    fail "already-seen activity was emitted again after the cutoff"

write_fixture 12
cat > "$__fixture_dir/pr-12.json" <<'EOF'
{"number":12,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-12","reviewDecision":"APPROVED","reviews":[{"id":1201,"state":"PENDING","submittedAt":null,"body":"draft review with null timestamp"},{"id":1202,"state":"PENDING","submittedAt":"","body":"draft review with empty timestamp"},{"id":1203,"state":"PENDING","body":"draft review with missing timestamp"},{"id":1204,"state":"COMMENTED","submittedAt":"2024-01-02T00:00:00Z","body":"submitted"}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-12.json" <<'EOF'
[[{"id":1203,"isResolved":false,"created_at":"2024-01-02T00:00:00Z","body":"unresolved","html_url":"https://example.test/inline/1203"}]]
EOF
cat > "$__fixture_dir/issues-12.json" <<'EOF'
[[{"id":1204,"created_at":"2024-01-02T00:00:00Z","body":"unknown resolution"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":12,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"seen\":{\"reviews\":[\"1204\"],\"inline_comments\":[\"pulls:1203\"],\"issue_comments\":[\"issues:1204\"]},\"graceChecks\":3}]}"
run_poll > "$__poll_output"
jq -e '
  (.pull_requests[0].new_reviews | length == 0) and
  (.pull_requests[0].new_inline_comments | length == 0) and
  (.pull_requests[0].new_issue_comments | length == 0) and
  .pull_requests[0].has_unresolved_activity == true and
  .pull_requests[0].action_required == true and
  .pull_requests[0].grace_checks == 0
' "$__poll_output" >/dev/null || fail "unresolved prior activity was treated as clean"

write_fixture 14
cat > "$__fixture_dir/pulls-14.json" <<'EOF'
[[{"id":1401,"isResolved":true,"created_at":"2024-01-02T00:00:00Z","body":"resolved thread"}]]
EOF
cat > "$__fixture_dir/issues-14.json" <<'EOF'
[[{"id":1402,"created_at":"2024-01-02T00:00:00Z","body":"historical issue comment"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":14,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"seen\":{\"reviews\":[],\"inline_comments\":[\"pulls:1401\"],\"issue_comments\":[\"issues:1402\"]},\"graceChecks\":3}]}"
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].has_unresolved_activity == false and
  .pull_requests[0].action_required == false and
  .pull_requests[0].grace_checks == 4
' "$__poll_output" >/dev/null || fail "issue-comment resolution state blocked a clean review thread"

write_fixture 13
cat > "$__fixture_dir/pulls-13.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-13.json" <<'EOF'
[[{"created_at":"2024-01-04T00:00:00Z","body":"unknown resolution"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
run_action add 13 > "$__poll_output"
jq -e '.reconciliation[0].issue_comments[0].is_resolved == null' "$__poll_output" >/dev/null ||
    fail "unknown comment resolution was not emitted explicitly as null"

write_fixture 15
cat > "$__fixture_dir/pulls-15.json" <<'EOF'
[[{"id":1501,"node_id":"RC_1501","created_at":"2024-01-04T00:00:00Z","body":"lookup failure"}]]
EOF
cat > "$__fixture_dir/issues-15.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FAIL=1
run_action add 15 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FAIL
jq -e '
  (.warnings | any(test("review thread .* resolution lookup failed"))) and
  (.reconciliation[0].resolution_warnings | length == 1) and
  .reconciliation[0].inline_comments[0].is_resolved == null
' "$__poll_output" >/dev/null || fail "GraphQL resolution failure was hidden"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[]
EOF
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].inline_comments_pages == 0 and
  .pull_requests[0].issue_comments_pages == 0 and
  (.pull_requests[0].new_inline_comments | length == 0) and
  (.pull_requests[0].new_issue_comments | length == 0)
' "$__poll_output" >/dev/null || fail "true zero-page comment responses were not preserved for both endpoints"

cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[{"context":"lint","state":"FAILURE"},{"context":"deploy","state":"ERROR"},{"context":"integration","state":"PENDING"}]}
EOF
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].has_failed_checks == true and
  .pull_requests[0].action_required == true and
  .pull_requests[0].checks == [
    {"name":"lint","status":"FAILURE"},
    {"name":"deploy","status":"ERROR"},
    {"name":"integration","status":"PENDING"}
  ]
' "$__poll_output" >/dev/null || fail "StatusContext failures, errors, or pending checks were not normalized"

cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[{"context":"integration","state":"PENDING"}]}
EOF
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].has_failed_checks == false and
  .pull_requests[0].action_required == true
' "$__poll_output" >/dev/null || fail "pending StatusContext did not require action without reporting a failure"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[]
EOF
cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[{"author":{"login":"bad"},"submittedAt":"not-a-timestamp","body":"bad"},{"author":{"login":"missing"},"body":"missing"},{"author":{"login":"reviewer"},"submittedAt":"2024-01-02T00:00:00Z","state":"COMMENTED","body":"valid"}],"statusCheckRollup":[]}
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed review timestamps unexpectedly succeeded"
fi
grep -qF 'PR #1 review 1 has a missing or malformed submittedAt timestamp' "$__fixture_dir/error" ||
    fail "malformed review error was not actionable"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "malformed review changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "malformed review left the lock"

write_fixture 3
cat > "$__fixture_dir/pulls-3.json" <<'EOF'
[]
EOF
cat > "$__fixture_dir/issues-3.json" <<'EOF'
[]
EOF
cat > "$__fixture_dir/pr-3.json" <<'EOF'
{"number":3,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-3","reviewDecision":"APPROVED","reviews":[{"author":{"login":"pending"},"state":"PENDING","submittedAt":"not-a-timestamp","body":"malformed pending review"}],"statusCheckRollup":[]}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":3,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed pending review timestamp unexpectedly succeeded"
fi
grep -qF 'PR #3 review 1 has a missing or malformed submittedAt timestamp' "$__fixture_dir/error" ||
    fail "malformed pending review error was not actionable"
[[ ! -d "$__state_file.lock" ]] || fail "malformed pending review left the lock"

printf '{\n  "version": 1,\n  "repository": "%s",\n  "pull_requests": [{"number": 1, "addedAt": "2024-01-01T00:00:00Z"}]\n}\n' \
    "$__repository" > "$__state_file"
local __before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[{"created_at":"2024-01-02T00:00:00Z"}],{"not":"a page"}]
EOF
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed page unexpectedly succeeded"
fi
grep -qF 'pulls/1/comments' "$__fixture_dir/error" || fail "malformed page error omitted endpoint and PR"
grep -qF 'page 2' "$__fixture_dir/error" || fail "malformed page error omitted page number"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "failed poll changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "malformed poll left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "malformed poll left a temporary file"

cat > "$__state_file" <<EOF
{
  "version": 1,
  "repository": "$__repository",
  "pull_requests": [{"number": 1, "addedAt": "2024-01-01T00:00:00Z", "lastSeenAt": "2024-01-02T00:00:00Z"}],
  "pending_poll": {
    "payload": {
      "action": "poll",
      "repository": "$__repository",
      "state_file": "$__state_file",
      "watch_empty": false,
      "scheduler_should_stop": false,
      "warnings": [],
      "pull_requests": [{
        "number": 1,
        "identity": {"repository": "$__repository", "coordinator_id": "review-watch:$__repository", "scheduler_id": "review-watch-scheduler:$__repository", "assignment_id": "review-assignment:$__repository", "scope_id": "review-scope:$__repository", "candidate_id": "candidate:$__repository#1", "pull_request": 1, "head": "review-1"},
        "state": "OPEN",
        "head": "review-1",
        "new_reviews": [{"body": "recover me", "submitted_at": "2024-01-02T00:00:00Z"}],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "reviews_pages": 0,
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
        "reviews_page_lengths": [],
        "inline_comments_page_lengths": [],
        "issue_comments_page_lengths": [],
        "reviews_pagination_complete": true,
        "inline_comments_pagination_complete": true,
        "issue_comments_pagination_complete": true,
        "reviews_pagination_termination": "empty-result",
        "inline_comments_pagination_termination": "empty-result",
        "issue_comments_pagination_termination": "empty-result",
        "reviews_page_size": 100,
        "inline_comments_page_size": 100,
        "issue_comments_page_size": 100,
        "pagination_contract": "gh-api-paginate-slurp-v1",
        "review_metadata_contract": "gh-pr-view-reviews-v1",
        "has_new_activity": true,
        "has_failed_checks": false,
        "has_pending_checks": false,
        "action_required": true
      }]
    },
    "next_pull_requests": [{"number": 1, "addedAt": "2024-01-01T00:00:00Z", "lastSeenAt": "2024-01-03T00:00:00Z", "graceChecks": 1, "graceComplete": false}]
  }
}
EOF
: > "$__log_file"
run_poll > "$__poll_output"
jq -e '.pull_requests[0].new_reviews[0].body == "recover me"' "$__poll_output" >/dev/null ||
    fail "interrupted poll did not replay the staged activity payload"
if grep -q '^pr view\|^api ' "$__log_file"; then
    fail "pending poll recovery fetched new activity instead of acknowledging staged results"
fi
jq -e '(.pending_poll | not) and (.pull_requests[0].lastSeenAt != null)' "$__state_file" >/dev/null ||
    fail "interrupted poll did not advance state after replay"

cat > "$__state_file" <<EOF
{
  "version": 1,
  "repository": "$__repository",
  "pull_requests": [{"number": 11, "addedAt": "2024-01-01T00:00:00Z", "head": "review-11-new"}],
  "pending_poll": {
    "payload": {
      "action": "not-poll",
      "repository": "$__repository",
      "state_file": "$__state_file",
      "watch_empty": true,
      "scheduler_should_stop": false,
      "warnings": [],
      "pull_requests": []
    },
    "next_pull_requests": []
  }
}
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action list > "$__poll_output"
jq -e '
  (.warnings | any(contains("quarantined pending-poll"))) and
  (.pull_requests | map(.number) == [11])
' "$__poll_output" >/dev/null || fail "invalid pending poll was not quarantined"
jq -e '
  (.pending_poll | not) and
  (.quarantine | any(.kind == "pending-poll" and .raw.payload.action == "not-poll"))
' "$__state_file" >/dev/null || fail "invalid pending poll quarantine did not preserve raw evidence"

write_fixture 7 UNKNOWN
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":7,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "unknown pull request state unexpectedly succeeded"
fi
grep -qF 'pull request #7 metadata: response has an invalid state' "$__fixture_dir/error" ||
    fail "unknown pull request state error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "invalid pull request state emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "invalid pull request state changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "invalid pull request state left the lock"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":8,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
cat > "$__fixture_dir/pr-8.json" <<'EOF'
{"number":8,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-8","reviewDecision":"APPROVED","statusCheckRollup":[]}
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "missing reviews unexpectedly succeeded"
fi
grep -qF 'pull request #8 metadata: reviews is not an array' "$__fixture_dir/error" ||
    fail "missing reviews error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "missing reviews emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "missing reviews changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "missing reviews left the lock"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":9,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
cat > "$__fixture_dir/pr-9.json" <<'EOF'
{"number":9,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-9","reviewDecision":"APPROVED","reviews":[]}
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "missing statusCheckRollup unexpectedly succeeded"
fi
grep -qF 'pull request #9 metadata: statusCheckRollup is not an array' "$__fixture_dir/error" ||
    fail "missing statusCheckRollup error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "missing statusCheckRollup emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "missing statusCheckRollup changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "missing statusCheckRollup left the lock"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[null]}"
run_action list > "$__poll_output"
jq -e '
  (.warnings | any(contains("quarantined watch-entry"))) and
  (.pull_requests | length == 0)
' "$__poll_output" >/dev/null || fail "malformed watch entry was not quarantined"
jq -e '
  (.quarantine | any(.kind == "watch-entry" and .raw == null))
' "$__state_file" >/dev/null || fail "malformed watch entry quarantine did not preserve raw evidence"
[[ ! -d "$__state_file.lock" ]] || fail "malformed watch entry left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "malformed watch entry left a temporary file"

write_fixture 2
cat > "$__fixture_dir/pulls-2.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-2.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
chflags uchg "$__state_file"
if run_action add 2 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "forced add atomic rename failure unexpectedly succeeded"
fi
[[ ! -s "$__poll_output" ]] || fail "failed add emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "failed add changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "failed add left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "failed add left a temporary file"
chflags nouchg "$__state_file"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":2,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
chflags uchg "$__state_file"
if run_action remove 2 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "forced remove atomic rename failure unexpectedly succeeded"
fi
[[ ! -s "$__poll_output" ]] || fail "failed remove emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "failed remove changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "failed remove left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "failed remove left a temporary file"
chflags nouchg "$__state_file"

__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_action remove 2 invalid > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "unsupported output format unexpectedly succeeded"
fi
grep -qF 'unsupported --format value: invalid' "$__fixture_dir/error" ||
    fail "unsupported output format error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "unsupported output format emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "unsupported output format changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "unsupported output format left the lock"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":1,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
cat > "$__fixture_dir/pr-1.json" <<'EOF'
{"number":1,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-1","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[[]]
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if GH_REVIEW_WATCH_RENAME_FAIL=1 run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "forced atomic rename failure unexpectedly succeeded"
fi
grep -qE 'EPERM:.*rename' "$__fixture_dir/error" || fail "forced atomic failure did not fail during rename"
[[ ! -s "$__poll_output" ]] || fail "failed poll emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "atomic rename failure changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "atomic rename failure left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "atomic rename failure left a temporary file"
chflags nouchg "$__state_file"

write_fixture 11
cat > "$__fixture_dir/pulls-11.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-11.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":11,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
local __grace_poll=0
while (( __grace_poll < 4 )); do
    __grace_poll=$((__grace_poll + 1))
    run_poll > "$__poll_output"
    if (( __grace_poll < 4 )); then
        jq -e '.scheduler_should_stop == false and .pull_requests[0].keep_watching == true' "$__poll_output" >/dev/null ||
            fail "scheduler stopped before the four-check clean grace period"
    fi
done
jq -e '
  .watch_empty == false and
  .scheduler_should_stop == true and
  .pull_requests[0].grace_checks == 4 and
  .pull_requests[0].grace_complete == true and
  .pull_requests[0].keep_watching == false
' "$__poll_output" >/dev/null || fail "clean grace period did not complete after four checks"
jq -e '.pull_requests | length == 1 and .[0].number == 11' "$__state_file" >/dev/null ||
    fail "grace-complete open PR was removed from watch state"

cat > "$__fixture_dir/pr-11.json" <<'EOF'
{"number":11,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-11-new","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].head_changed == true and
  .pull_requests[0].grace_checks == 0 and
  .pull_requests[0].action_required == true
' "$__poll_output" >/dev/null || fail "head changes did not reset the grace period"

cat > "$__state_file" <<EOF
{
  "version": 1,
  "repository": "$__repository",
  "pull_requests": [{"number": 11, "addedAt": "2024-01-01T00:00:00Z", "head": "review-11-new"}],
  "pending_poll": {
    "payload": {
      "action": "poll",
      "repository": "$__repository",
      "state_file": "$__state_file",
      "watch_empty": false,
      "scheduler_should_stop": true,
      "warnings": [],
      "pull_requests": [{
        "number": 11,
        "identity": {"repository": "$__repository", "coordinator_id": "review-watch:$__repository", "scheduler_id": "review-watch-scheduler:$__repository", "assignment_id": "review-assignment:$__repository", "scope_id": "review-scope:$__repository", "candidate_id": "candidate:$__repository#11", "pull_request": 11, "head": "review-11-new"},
        "state": "OPEN",
        "head": "review-11-new",
        "new_reviews": [],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "reviews_pages": 0,
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
        "reviews_page_lengths": [],
        "inline_comments_page_lengths": [],
        "issue_comments_page_lengths": [],
        "reviews_pagination_complete": true,
        "inline_comments_pagination_complete": true,
        "issue_comments_pagination_complete": true,
        "reviews_pagination_termination": "empty-result",
        "inline_comments_pagination_termination": "empty-result",
        "issue_comments_pagination_termination": "empty-result",
        "reviews_page_size": 100,
        "inline_comments_page_size": 100,
        "issue_comments_page_size": 100,
        "pagination_contract": "gh-api-paginate-slurp-v1",
        "review_metadata_contract": "gh-pr-view-reviews-v1",
        "has_new_activity": false,
        "has_failed_checks": false,
        "has_pending_checks": false,
        "action_required": false,
        "grace_checks": 4,
        "grace_complete": true,
        "keep_watching": false
      }]
    },
    "next_pull_requests": [{
      "number": 11,
      "addedAt": "2024-01-01T00:00:00Z",
      "head": "review-11-new",
      "graceChecks": 4,
      "graceComplete": true,
      "seen": {"reviews": [], "inline_comments": [], "issue_comments": []}
    }]
  }
}
EOF
run_poll > "$__poll_output"
jq -e '.scheduler_should_stop == false and (.warnings | any(. == "replayed poll cannot safely stop the scheduler"))' "$__poll_output" >/dev/null ||
    fail "replayed stop decision was not conservative"

write_fixture 4 CLOSED null '"2024-01-04T00:00:00Z"'
write_fixture 5 MERGED '"2024-01-05T00:00:00Z"'
cat > "$__fixture_dir/pulls-4.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-4.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/pulls-5.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-5.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":4,\"addedAt\":\"2024-01-01T00:00:00Z\"},{\"number\":5,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
: > "$__log_file"
run_poll > "$__poll_output"
jq -e '
  .watch_empty == true and
  .pull_requests[0].removed == true and .pull_requests[0].reason == "closed" and
  .pull_requests[1].removed == true and .pull_requests[1].reason == "merged"
' "$__poll_output" >/dev/null || fail "merged/closed cleanup output is incorrect"
if grep -q '^api ' "$__log_file"; then
    fail "closed and merged PRs queried comment endpoints"
fi

write_fixture 6
cat > "$__fixture_dir/pulls-1.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-1.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/pulls-6.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-6.json" <<'EOF'
[[]]
EOF
printf '{\n  "version": 1,\n  "repository": "%s",\n  "pull_requests": [\n    {"number": 1, "addedAt": "2024-01-01T00:00:00Z"},\n    {"number": 6, "addedAt": "2024-01-01T00:00:00Z"}\n  ]\n}\n' "$__repository" > "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if GH_REVIEW_WATCH_FAIL_PR=6 run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "mid-poll failure unexpectedly succeeded"
fi
grep -qF 'pull request #6 metadata failed' "$__fixture_dir/error" || fail "mid-poll failure did not reach the second PR"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "mid-poll failure changed state bytes"
[[ ! -d "$__state_file.lock" ]] || fail "mid-poll failure left the lock"
[[ -z "$(find "$__fixture_dir" -name '*.tmp.*' -print -quit)" ]] || fail "mid-poll failure left a temporary file"

mkdir "$__state_file.lock"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "lock contention unexpectedly succeeded"
fi
grep -qF 'watch state is locked' "$__fixture_dir/error" || fail "lock contention error was not actionable"
[[ -d "$__state_file.lock" ]] || fail "lock contention removed the existing lock"
rm -rf "$__state_file.lock"

mkdir "$__state_file.lock"
printf '{"pid":%s,"identity":"legacy-locale-timezone-identity"}\n' "$$" > "$__state_file.lock/owner"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "live lock contention unexpectedly succeeded"
fi
grep -qF 'watch state is locked' "$__fixture_dir/error" || fail "live lock contention error was not actionable"
[[ -d "$__state_file.lock" ]] || fail "live lock contention removed the live owner lock"
rm -rf "$__state_file.lock"

local __real_ps="$(command -v ps)"
export GH_REVIEW_WATCH_REAL_PS="$__real_ps"
cat > "$__bin_dir/ps" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "-p" && "${2:-}" == "999999" ]]; then
    if [[ -n "${GH_REVIEW_WATCH_BARRIER_DIR:-}" ]]; then
        touch "$GH_REVIEW_WATCH_BARRIER_DIR/$$"
        __barrier_attempt=0
        while (( __barrier_attempt < 200 )); do
            __barrier_attempt=$((__barrier_attempt + 1))
            (( $(find "$GH_REVIEW_WATCH_BARRIER_DIR" -type f | wc -l) >= 2 )) && break
            sleep 0.01
        done
    fi
    exit 1
fi
exec "$GH_REVIEW_WATCH_REAL_PS" "$@"
EOF
chmod +x "$__bin_dir/ps"
write_fixture 2
cat > "$__fixture_dir/pulls-2.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-2.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":2,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
mkdir "$__state_file.lock"
printf '{"pid":999999,"identity":"stale"}\n' > "$__state_file.lock/owner"

local __contender_one="$__fixture_dir/contender-one"
local __contender_two="$__fixture_dir/contender-two"
local __status_one="$__fixture_dir/status-one"
local __status_two="$__fixture_dir/status-two"
local __barrier_dir="$__fixture_dir/barrier"
mkdir "$__barrier_dir"
export GH_REVIEW_WATCH_BARRIER_DIR="$__barrier_dir"
(
    if GH_REVIEW_WATCH_DELAY=1 run_poll > "$__contender_one.out" 2> "$__contender_one.err"; then
        print -r -- 0 > "$__status_one"
    else
        print -r -- "$?" > "$__status_one"
    fi
) &
local __pid_one="$!"
(
    if GH_REVIEW_WATCH_DELAY=1 run_poll > "$__contender_two.out" 2> "$__contender_two.err"; then
        print -r -- 0 > "$__status_two"
    else
        print -r -- "$?" > "$__status_two"
    fi
) &
local __pid_two="$!"
wait "$__pid_one"
wait "$__pid_two"
[[ "$(find "$__barrier_dir" -type f | wc -l | tr -d ' ')" -ge 2 ]] ||
    fail "concurrent stale-lock contenders did not reach the overlap barrier"
local __result_one="$(<"$__status_one")"
local __result_two="$(<"$__status_two")"
(( (__result_one == 0) + (__result_two == 0) == 1 )) ||
    fail "concurrent stale-lock recovery did not produce exactly one winner"
if (( __result_one != 0 )); then
    grep -qF 'watch state is locked' "$__contender_one.err" ||
        fail "losing stale-lock contender did not observe contention"
fi
if (( __result_two != 0 )); then
    grep -qF 'watch state is locked' "$__contender_two.err" ||
        fail "losing stale-lock contender did not observe contention"
fi
[[ ! -d "$__state_file.lock" ]] || fail "concurrent stale-lock recovery left the lock behind"
unset GH_REVIEW_WATCH_BARRIER_DIR

cat > "$__fixture_dir/pr-16.json" <<'EOF'
{"number":16,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-16","headRefOid":"oid-16","reviewDecision":"APPROVED","reviews":[{"id":1601,"author":{"login":"reviewer"},"submittedAt":"2024-01-01T00:00:00Z","state":"CHANGES_REQUESTED","body":"old request"},{"id":1602,"author":{"login":"reviewer"},"submittedAt":"2024-01-02T00:00:00Z","state":"APPROVED","body":"superseded request"}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-16.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-16.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":16,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"head\":\"review-16\",\"seen\":{\"reviews\":[\"1601\",\"1602\"],\"inline_comments\":[],\"issue_comments\":[]},\"graceChecks\":3}]}"
export GH_REVIEW_WATCH_GRAPHQL_REJECT_LEGACY=1
run_poll > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_REJECT_LEGACY
jq -e '
  .pull_requests[0].head_changed == true and
  .pull_requests[0].has_unresolved_activity == false and
  .pull_requests[0].action_required == true and
  .pull_requests[0].grace_checks == 0 and
  .pull_requests[0].head == "review-16" and
  .pull_requests[0].head_oid == "oid-16"
' "$__poll_output" >/dev/null || fail "legacy head migration did not detect the new fetched OID"
jq -e '.pull_requests[0].head == "oid-16"' "$__state_file" >/dev/null ||
    fail "legacy head name was not migrated to the fetched head OID"

cat > "$__fixture_dir/pr-23.json" <<'EOF'
{"number":23,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-23","headRefOid":"oid-23","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-23.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-23.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":23,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"head\":\"oid-23-old\",\"seen\":{\"reviews\":[],\"inline_comments\":[],\"issue_comments\":[]},\"graceChecks\":3}]}"
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].head_changed == true and
  .pull_requests[0].action_required == true and
  .pull_requests[0].grace_checks == 0
' "$__poll_output" >/dev/null || fail "OID-native head changes did not reset the grace period"

cat > "$__fixture_dir/pr-26.json" <<'EOF'
{"number":26,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-26","headRefOid":"oid-26","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-26.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-26.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":26,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"head\":\"oid-26\",\"seen\":{\"reviews\":[],\"inline_comments\":[],\"issue_comments\":[]},\"graceChecks\":3}]}"
run_poll > "$__poll_output"
jq -e '
  .pull_requests[0].head_changed == false and
  .pull_requests[0].action_required == false and
  .pull_requests[0].grace_checks == 4
' "$__poll_output" >/dev/null || fail "OID-native unchanged heads did not preserve the grace period"

cat > "$__fixture_dir/pr-17.json" <<'EOF'
{"number":17,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-17","headRefOid":"oid-17","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-17.json" <<'EOF'
[[{"id":1701,"node_id":"RC_1701","created_at":"2024-01-04T00:00:00Z","body":"supported resolution","html_url":"https://example.test/inline/1701"}]]
EOF
cat > "$__fixture_dir/issues-17.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-valid-17.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_1701","isResolved":true,"comments":{"nodes":[{"id":"RC_1701","fullDatabaseId":"1701"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-valid-17.json"
export GH_REVIEW_WATCH_GRAPHQL_REJECT_LEGACY=1
run_action add 17 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE GH_REVIEW_WATCH_GRAPHQL_REJECT_LEGACY
jq -e '
  .reconciliation[0].inline_comments[0].is_resolved == true and
  (.reconciliation[0].resolution_warnings | length == 0)
' "$__poll_output" >/dev/null || fail "supported review-thread GraphQL resolution was not used"

cat > "$__fixture_dir/pr-18.json" <<'EOF'
{"number":18,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-18","headRefOid":"oid-18","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-18.json" <<'EOF'
[[{"id":1801,"node_id":"RC_1801","created_at":"2024-01-04T00:00:00Z","body":"invalid response","html_url":"https://example.test/inline/1801"}]]
EOF
cat > "$__fixture_dir/issues-18.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-invalid-18.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":null}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-invalid-18.json"
run_action add 18 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq -e '
  .reconciliation[0].inline_comments[0].is_resolved == null and
  (.reconciliation[0].resolution_warnings | any(test("returned an invalid response")))
' "$__poll_output" >/dev/null || fail "invalid GraphQL resolution response was not reported"

cat > "$__fixture_dir/pr-19.json" <<'EOF'
{"number":19,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-19","headRefOid":"oid-19","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
jq -n '[range(1901;1934) | {id:.,node_id:("RC_"+tostring),created_at:"2024-01-04T00:00:00Z",body:("comment "+tostring),html_url:("https://example.test/inline/"+tostring)}]' |
    jq -s '.' > "$__fixture_dir/pulls-19.json"
cat > "$__fixture_dir/issues-19.json" <<'EOF'
[[]]
EOF
jq -n '
  {data:{repository:{pullRequest:{reviewThreads:{
    nodes:[{id:"RT_19",isResolved:false,comments:{nodes:[range(1901;1934) | {id:("RC_"+tostring),fullDatabaseId:(tostring)}],pageInfo:{hasNextPage:false,endCursor:null}}}],
    pageInfo:{hasNextPage:false,endCursor:null}
  }}}}}
' > "$__fixture_dir/graphql-many-19.json"
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-many-19.json"
run_action add 19 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq -e '
  (.reconciliation[0].inline_comments | length == 33) and
  (.reconciliation[0].inline_comments | all(.is_resolved == false)) and
  (.reconciliation[0].resolution_warnings | length == 0)
' "$__poll_output" >/dev/null || fail "more than 32 inline comments were not fully resolved"

cat > "$__fixture_dir/pr-27.json" <<'EOF'
{"number":27,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-27","headRefOid":"oid-27","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-27.json" <<'EOF'
[[{"id":2701,"node_id":"RC_2701","created_at":"2024-01-04T00:00:00Z","body":"first outer page comment","html_url":"https://example.test/inline/2701"},{"id":2702,"node_id":"RC_2702","created_at":"2024-01-04T00:00:00Z","body":"later outer page comment","html_url":"https://example.test/inline/2702"}]]
EOF
cat > "$__fixture_dir/issues-27.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-paginated-outer-27.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_2701","isResolved":false,"comments":{"nodes":[{"id":"RC_2701","fullDatabaseId":"2701"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":true,"endCursor":"outer-next"}}}}}}
EOF
cat > "$__fixture_dir/graphql-paginated-outer-page-27.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_2702","isResolved":true,"comments":{"nodes":[{"id":"RC_2702","fullDatabaseId":"2702"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
: > "$__log_file"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-paginated-outer-27.json"
export GH_REVIEW_WATCH_GRAPHQL_PAGE_FIXTURE="$__fixture_dir/graphql-paginated-outer-page-27.json"
run_action add 27 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE GH_REVIEW_WATCH_GRAPHQL_PAGE_FIXTURE
jq -e '
  (.reconciliation[0].inline_comments | length == 2) and
  (.reconciliation[0].inline_comments | any(.id == 2701 and .is_resolved == false)) and
  (.reconciliation[0].inline_comments | any(.id == 2702 and .is_resolved == true)) and
  (.reconciliation[0].resolution_warnings | length == 0)
' "$__poll_output" >/dev/null || fail "valid outer review-thread later page was not mapped"
grep -qF 'cursor=outer-next' "$__log_file" ||
    fail "outer review-thread pagination did not request the distinct later cursor"

cat > "$__fixture_dir/pr-28.json" <<'EOF'
{"number":28,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-28","headRefOid":"oid-28","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-28.json" <<'EOF'
[[{"id":2801,"node_id":"RC_2801","created_at":"2024-01-04T00:00:00Z","body":"first inner page comment","html_url":"https://example.test/inline/2801"},{"id":2802,"node_id":"RC_2802","created_at":"2024-01-04T00:00:00Z","body":"later inner page comment","html_url":"https://example.test/inline/2802"}]]
EOF
cat > "$__fixture_dir/issues-28.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-paginated-inner-28.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_2801","isResolved":false,"comments":{"nodes":[{"id":"RC_2801","fullDatabaseId":"2801"}],"pageInfo":{"hasNextPage":true,"endCursor":"inner-next"}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
cat > "$__fixture_dir/graphql-paginated-inner-page-28.json" <<'EOF'
{"data":{"node":{"isResolved":true,"comments":{"nodes":[{"id":"RC_2802","fullDatabaseId":"2802"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
: > "$__log_file"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-paginated-inner-28.json"
export GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE="$__fixture_dir/graphql-paginated-inner-28.json"
export GH_REVIEW_WATCH_GRAPHQL_INNER_PAGE_FIXTURE="$__fixture_dir/graphql-paginated-inner-page-28.json"
run_action add 28 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE GH_REVIEW_WATCH_GRAPHQL_INNER_PAGE_FIXTURE
jq -e '
  (.reconciliation[0].inline_comments | length == 2) and
  (.reconciliation[0].inline_comments | any(.id == 2801 and .is_resolved == true)) and
  (.reconciliation[0].inline_comments | any(.id == 2802 and .is_resolved == true)) and
  (.reconciliation[0].resolution_warnings | length == 0)
' "$__poll_output" >/dev/null || fail "distinct inner review-thread comment later page was not mapped"
grep -qF 'cursor=inner-next' "$__log_file" ||
    fail "inner review-thread comment pagination did not request the distinct later cursor"

cat > "$__fixture_dir/pr-24.json" <<'EOF'
{"number":24,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-24","headRefOid":"oid-24","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-24.json" <<'EOF'
[[{"id":2401,"node_id":"RC_2401","created_at":"2024-01-04T00:00:00Z","body":"outer cursor repeat","html_url":"https://example.test/inline/2401"}]]
EOF
cat > "$__fixture_dir/issues-24.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-repeat-outer-24.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[],"pageInfo":{"hasNextPage":true,"endCursor":"outer-repeat"}}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-repeat-outer-24.json"
run_action add 24 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq -e '
  (.reconciliation[0].resolution_warnings | any(test("review thread resolution pagination repeated a cursor"))) and
  .reconciliation[0].inline_comments[0].is_resolved == null
' "$__poll_output" >/dev/null || fail "repeated outer review-thread cursor was not stopped conservatively"

cat > "$__fixture_dir/pr-25.json" <<'EOF'
{"number":25,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-25","headRefOid":"oid-25","reviewDecision":"APPROVED","reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-25.json" <<'EOF'
[[{"id":2501,"node_id":"RC_2501","created_at":"2024-01-04T00:00:00Z","body":"inner cursor repeat","html_url":"https://example.test/inline/2501"}]]
EOF
cat > "$__fixture_dir/issues-25.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/graphql-repeat-inner-25.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_2501","isResolved":true,"comments":{"nodes":[{"id":"RC_2501","fullDatabaseId":"2501"}],"pageInfo":{"hasNextPage":true,"endCursor":"inner-repeat"}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
cat > "$__fixture_dir/graphql-repeat-inner-page-25.json" <<'EOF'
{"data":{"node":{"isResolved":true,"comments":{"nodes":[{"id":"RC_2501","fullDatabaseId":"2501"}],"pageInfo":{"hasNextPage":true,"endCursor":"inner-repeat"}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-repeat-inner-25.json"
export GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE="$__fixture_dir/graphql-repeat-inner-page-25.json"
run_action add 25 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE GH_REVIEW_WATCH_GRAPHQL_INNER_FIXTURE
jq -e '
  (.reconciliation[0].resolution_warnings | any(test("review thread comment pagination repeated a cursor"))) and
  .reconciliation[0].inline_comments[0].is_resolved == true
' "$__poll_output" >/dev/null || fail "repeated inner thread-comment cursor was not stopped conservatively"

cat > "$__state_file" <<EOF
{
  "version": 1,
  "repository": "$__repository",
  "pull_requests": [
    {"number": 20, "addedAt": "2024-01-01T00:00:00Z"},
    {"number": 21, "addedAt": "2024-01-01T00:00:00Z"}
  ],
  "pending_poll": {
    "payload": {
      "action": "poll",
      "repository": "$__repository",
      "state_file": "$__state_file",
      "watch_empty": false,
      "scheduler_should_stop": false,
      "warnings": [],
      "pull_requests": [{
        "number": 20,
        "identity": {"repository": "$__repository", "coordinator_id": "review-watch:$__repository", "scheduler_id": "review-watch-scheduler:$__repository", "assignment_id": "review-assignment:$__repository", "scope_id": "review-scope:$__repository", "candidate_id": "candidate:$__repository#20", "pull_request": 20, "head": "review-20"},
        "state": "OPEN",
        "head": "review-20",
        "new_reviews": [],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "reviews_pages": 0,
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
        "reviews_page_lengths": [],
        "inline_comments_page_lengths": [],
        "issue_comments_page_lengths": [],
        "reviews_pagination_complete": true,
        "inline_comments_pagination_complete": true,
        "issue_comments_pagination_complete": true,
        "reviews_pagination_termination": "empty-result",
        "inline_comments_pagination_termination": "empty-result",
        "issue_comments_pagination_termination": "empty-result",
        "reviews_page_size": 100,
        "inline_comments_page_size": 100,
        "issue_comments_page_size": 100,
        "pagination_contract": "gh-api-paginate-slurp-v1",
        "review_metadata_contract": "gh-pr-view-reviews-v1",
        "has_new_activity": false,
        "has_failed_checks": false,
        "has_pending_checks": false,
        "action_required": false
      }]
    },
    "next_pull_requests": [{
      "number": 20,
      "addedAt": "2024-01-01T00:00:00Z",
      "graceChecks": 1,
      "graceComplete": false,
      "seen": {"reviews": [], "inline_comments": [], "issue_comments": []}
    }]
  }
}
EOF
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action list > "$__poll_output"
jq -e '
  (.warnings | any(contains("quarantined pending-poll"))) and
  (.pending_acknowledgment == null)
' "$__poll_output" >/dev/null || fail "staged poll omission was not quarantined"
jq -e '
  (.pending_poll | not) and
  (.quarantine | any(.kind == "pending-poll"))
' "$__state_file" >/dev/null || fail "staged poll omission quarantine did not preserve raw evidence"

cat > "$__state_file" <<EOF
{
  "version": 1,
  "repository": "$__repository",
  "pull_requests": [{"number": 22, "addedAt": "2024-01-01T00:00:00Z"}],
  "pending_poll": {
    "payload": {
      "action": "poll",
      "repository": "$__repository",
      "state_file": "$__state_file",
      "watch_empty": true,
      "scheduler_should_stop": true,
      "warnings": [],
      "pull_requests": [{
        "number": 22,
        "identity": {"repository": "$__repository", "coordinator_id": "review-watch:$__repository", "scheduler_id": "review-watch-scheduler:$__repository", "assignment_id": "review-assignment:$__repository", "scope_id": "review-scope:$__repository", "candidate_id": "candidate:$__repository#22", "pull_request": 22, "head": "review-22"},
        "state": "MERGED",
        "head": "review-22",
        "new_reviews": [],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "reviews_pages": 0,
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
        "reviews_page_lengths": [],
        "inline_comments_page_lengths": [],
        "issue_comments_page_lengths": [],
        "reviews_pagination_complete": true,
        "inline_comments_pagination_complete": true,
        "issue_comments_pagination_complete": true,
        "reviews_pagination_termination": "empty-result",
        "inline_comments_pagination_termination": "empty-result",
        "issue_comments_pagination_termination": "empty-result",
        "reviews_page_size": 100,
        "inline_comments_page_size": 100,
        "issue_comments_page_size": 100,
        "pagination_contract": "gh-api-paginate-slurp-v1",
        "review_metadata_contract": "gh-pr-view-reviews-v1",
        "has_new_activity": false,
        "has_failed_checks": false,
        "has_pending_checks": false,
        "action_required": false,
        "removed": true,
        "reason": "merged"
      }]
    },
    "next_pull_requests": []
  }
}
EOF
run_poll > "$__poll_output"
jq -e '.pull_requests[0].number == 22 and .pull_requests[0].removed == true' "$__poll_output" >/dev/null ||
    fail "explicit staged removal result did not replay"
jq -e '(.pull_requests | length == 0) and (.pending_poll | not)' "$__state_file" >/dev/null ||
    fail "staged removal replay did not clear the active watch"

export PR_REVIEW_WATCH_COORDINATOR_ID="coord-test"
export PR_REVIEW_WATCH_SCHEDULER_ID="scheduler-test"
export PR_REVIEW_WATCH_ASSIGNMENT_ID="assignment-test"
export PR_REVIEW_WATCH_SCOPE_ID="scope-test"
export PR_REVIEW_WATCH_CANDIDATE_ID="candidate-test"
write_fixture 31
cat > "$__fixture_dir/pr-31.json" <<'EOF'
{"number":31,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-31","headRefOid":"head-31","reviewDecision":"CHANGES_REQUESTED","reviews":[{"id":3101,"author":{"login":"reviewer"},"submittedAt":"2024-01-05T00:00:00Z","state":"CHANGES_REQUESTED","body":"body-only review","commit_id":"rev-31","comments":[{"id":3102,"created_at":"2024-01-05T00:01:00Z","body":"nested detail","path":"src/main.ts","position":12,"thread_id":"thread-31","in_reply_to_id":3099,"commit_id":"rev-31"}]}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-31.json" <<'EOF'
[[{"id":3103,"node_id":"RC_3103","pull_request_review_id":3101,"in_reply_to_id":3100,"created_at":"2024-01-05T00:02:00Z","body":"reply outside diff","path":null,"position":null,"commit_id":"rev-31"}]]
EOF
cat > "$__fixture_dir/issues-31.json" <<'EOF'
[[{"id":3104,"created_at":"2024-01-05T00:03:00Z","body":"pathless issue finding"}]]
EOF
cat > "$__fixture_dir/graphql-31.json" <<'EOF'
{"data":{"repository":{"pullRequest":{"reviewThreads":{"nodes":[{"id":"RT_3103","isResolved":false,"comments":{"nodes":[{"id":"RC_3103","fullDatabaseId":"3103"}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}],"pageInfo":{"hasNextPage":false,"endCursor":null}}}}}}
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-31.json"
run_action add 31 > "$__poll_output"
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq -e '
  .review_findings.schema_version == "review-findings.v1" and
  .review_findings.identity.coordinator_id == "coord-test" and
  (.review_findings.findings | any(.kind == "nested_comment" and .result_number == 31 and .source_batch_id != "")) and
  (.review_findings.findings | any(.provenance.reply_to == 3100)) and
  (.review_findings.findings | any(.provenance.location == "diff" and .provenance.outside_diff == false and .provenance.thread_id == "thread-31" and .provenance.revision_id == "rev-31")) and
  (.review_findings.findings | any(.kind == "inline_comment" and .provenance.location == "pathless" and .provenance.outside_diff == true))
' "$__poll_output" >/dev/null || fail "identity-bound nested review envelope was incomplete"
validate_findings_schema "$__poll_output" || fail "nested review findings envelope failed JSON Schema validation"
jq -e '
  .identity.coordinator_id == "coord-test" and
  .pull_requests[0].identity.pull_request == 31 and
  .pull_requests[0].identity.head == "head-31"
' "$__state_file" >/dev/null || fail "identity-bound watch state was not persisted"

write_fixture 33
cat > "$__fixture_dir/pr-33.json" <<'EOF'
{"number":33,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-33","headRefOid":"head-33","reviewDecision":"APPROVED","reviews":[{"id":3301,"author":{"login":"reviewer"},"submittedAt":"2024-01-06T00:00:00Z","state":"COMMENTED","body":"malformed nested","comments":[{"id":3302,"created_at":"2024-01-06T00:01:00Z","body":5}]}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-33.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-33.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_action add 33 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed nested review unexpectedly succeeded"
fi
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "malformed nested review advanced state"

write_fixture 34
cat > "$__fixture_dir/pulls-34.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-34.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 34 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "identity-mismatch staging unexpectedly succeeded"
fi
cp "$__state_file" "$__fixture_dir/identity-stage-backup.json"
jq '.pending_add.payload.reconciliation[0].identity.head = "foreign-head"' "$__state_file" > "$__fixture_dir/identity-stage-rewritten.json"
mv "$__fixture_dir/identity-stage-rewritten.json" "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action list > "$__poll_output"
jq -e '(.warnings | any(contains("quarantined pending-add"))) and (.pending_acknowledgment == null)' \
    "$__poll_output" >/dev/null || fail "foreign per-result identity was not quarantined"
jq -e '(.quarantine | any(.kind == "pending-add"))' "$__state_file" >/dev/null ||
    fail "foreign per-result identity quarantine was not persisted"
mv "$__fixture_dir/identity-stage-backup.json" "$__state_file"

write_fixture 32
cat > "$__fixture_dir/pr-32.json" <<'EOF'
{"number":32,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-32","headRefOid":"head-32","reviewDecision":"APPROVED","reviewCount":1,"reviews":[],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-32.json" <<'EOF'
[[{"id":3201,"created_at":"2024-01-05T00:00:00Z","body":"count mismatch"}]]
EOF
cat > "$__fixture_dir/issues-32.json" <<'EOF'
[[]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_action add 32 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "review count mismatch unexpectedly succeeded"
fi
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "count mismatch advanced state"

cat > "$__fixture_dir/pulls-32.json" <<'EOF'
[{"items":[],"complete":false}]
EOF
if run_action add 32 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "incomplete pagination unexpectedly succeeded"
fi
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "incomplete pagination advanced state"

jq -n '[[range(0;100) | {"id": (3200 + .), "created_at": "2024-01-05T00:00:00Z", "body": "full page"}]]' \
    > "$__fixture_dir/pulls-32.json"
cat > "$__fixture_dir/issues-32.json" <<'EOF'
[[]]
EOF
if run_action add 32 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "full terminal pagination page unexpectedly succeeded"
fi
grep -qF 'pagination has no short terminal page' "$__fixture_dir/error" ||
    fail "full terminal pagination error was not actionable"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "full terminal pagination advanced state"

cat > "$__fixture_dir/pulls-32.json" <<'EOF'
[[]]
EOF
jq -n '[[range(0;100) | {"id": (3300 + .), "created_at": "2024-01-05T00:00:00Z", "body": "full issue page"}]]' \
    > "$__fixture_dir/issues-32.json"
if run_action add 32 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "full terminal issue-comment page unexpectedly succeeded"
fi
grep -qF 'pagination has no short terminal page' "$__fixture_dir/error" ||
    fail "full terminal issue-comment error was not actionable"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "full terminal issue-comment pagination advanced state"

cat > "$__fixture_dir/pulls-35.json" <<'EOF'
[[]]
EOF
cat > "$__fixture_dir/issues-35.json" <<'EOF'
[[]]
EOF
jq -n '{number:35,state:"OPEN",mergedAt:null,closedAt:null,headRefName:"review-35",headRefOid:"head-35",reviewDecision:"APPROVED",reviews:[range(0;100) | {id:(3500 + .),submittedAt:"2024-01-05T00:00:00Z",state:"COMMENTED",body:"full review page"}],statusCheckRollup:[]}' \
    > "$__fixture_dir/pr-35.json"
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_action add 35 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "full terminal review page unexpectedly succeeded"
fi
grep -qF 'reviews for PR #35' "$__fixture_dir/error" ||
    fail "full terminal review error omitted PR identity"
grep -qF 'pagination has no short terminal page' "$__fixture_dir/error" ||
    fail "full terminal review error was not actionable"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "full terminal review pagination advanced state"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-31.json"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 31 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "review source-binding staging unexpectedly succeeded"
fi
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq '(.pending_add.payload.review_findings.findings |= map(if .kind == "review" then .provenance.review_id = "foreign-review" else . end))' \
    "$__state_file" > "$__fixture_dir/foreign-review.json"
mv "$__fixture_dir/foreign-review.json" "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action list > "$__poll_output"
jq -e '(.warnings | any(contains("quarantined pending-add"))) and (.pending_acknowledgment == null)' \
    "$__poll_output" >/dev/null || fail "foreign review provenance was not quarantined"
jq -e '(.quarantine | any(.kind == "pending-add"))' "$__state_file" >/dev/null ||
    fail "foreign review provenance quarantine was not persisted"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
export GH_REVIEW_WATCH_GRAPHQL_FIXTURE="$__fixture_dir/graphql-31.json"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 31 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "comment source-binding staging unexpectedly succeeded"
fi
unset GH_REVIEW_WATCH_GRAPHQL_FIXTURE
jq '(.pending_add.payload.review_findings.findings |= map(if .kind == "inline_comment" then .provenance.comment_id = "foreign-comment" else . end))' \
    "$__state_file" > "$__fixture_dir/foreign-comment.json"
mv "$__fixture_dir/foreign-comment.json" "$__state_file"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
run_action list > "$__poll_output"
jq -e '(.warnings | any(contains("quarantined pending-add"))) and (.pending_acknowledgment == null)' \
    "$__poll_output" >/dev/null || fail "foreign comment provenance was not quarantined"
jq -e '(.quarantine | any(.kind == "pending-add"))' "$__state_file" >/dev/null ||
    fail "foreign comment provenance quarantine was not persisted"

write_state '{"version":2,"repository":"'"$__repository"'","identity":{"repository":"'"$__repository"'","coordinator_id":"coord-test","scheduler_id":"scheduler-test","assignment_id":"assignment-test","scope_id":"scope-test","candidate_id":"candidate-test"},"pull_requests":[]}'
export PR_REVIEW_WATCH_COORDINATOR_ID="different-coordinator"
if run_action list > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "cross-coordinator replay unexpectedly succeeded"
fi
unset PR_REVIEW_WATCH_COORDINATOR_ID PR_REVIEW_WATCH_SCHEDULER_ID PR_REVIEW_WATCH_ASSIGNMENT_ID \
    PR_REVIEW_WATCH_SCOPE_ID PR_REVIEW_WATCH_CANDIDATE_ID

write_fixture 41
cat > "$__fixture_dir/pr-41.json" <<'EOF'
{"number":41,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-41","reviewDecision":"APPROVED","reviews":[{"id":4101,"author":{"login":"rest-reviewer"},"submittedAt":"2024-01-07T00:00:00Z","state":"COMMENTED","body":"REST timestamp"}],"statusCheckRollup":[]}
EOF
printf '[[]]\n' > "$__fixture_dir/pulls-41.json"
printf '[[]]\n' > "$__fixture_dir/issues-41.json"
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
run_action add 41 > "$__poll_output"
jq -e '
  .reconciliation[0].reviews[0].submitted_at == "2024-01-07T00:00:00Z" and
  (.reconciliation[0].reviews[0] | has("submittedAt") | not) and
  ([.. | objects | keys[]] | any(. == "submittedAt") | not)
' "$__poll_output" >/dev/null || fail "REST submitted_at was not normalized to the canonical review output"
if grep -qE 'submittedAt[^a-z_]|submitted_at' "$__state_file"; then
    fail "raw provider timestamp fields were persisted in watch state"
fi

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
if PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE=1 run_action add 41 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed staged review unexpectedly succeeded"
fi
jq '.pending_add.payload.reconciliation[0].reviews[0].submitted_at = "not-a-timestamp"' "$__state_file" \
    > "$__fixture_dir/malformed-staged-review.json"
mv "$__fixture_dir/malformed-staged-review.json" "$__state_file"
run_action list > "$__poll_output"
jq -e '(.warnings | any(contains("quarantined pending-add"))) and (.pending_acknowledgment == null)' \
    "$__poll_output" >/dev/null || fail "malformed staged review was not quarantined"
jq -e '
  (.quarantine | any(.kind == "pending-add" and .raw.pending_add == null and
    .raw.payload.reconciliation[0].reviews[0].submitted_at == "not-a-timestamp"))
' "$__state_file" >/dev/null || fail "malformed staged review quarantine lost raw evidence"

write_fixture 42
cat > "$__fixture_dir/pr-42.json" <<'EOF'
{"number":42,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-42","reviewDecision":"APPROVED","reviews":[{"id":4201,"author":{"login":"conflict"},"submittedAt":"2024-01-07T00:00:00Z","submitted_at":"2024-01-08T00:00:00Z","state":"COMMENTED","body":"conflict"}],"statusCheckRollup":[]}
EOF
printf '[[]]\n' > "$__fixture_dir/pulls-42.json"
printf '[[]]\n' > "$__fixture_dir/issues-42.json"
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if GH_REVIEW_WATCH_REST_RAW=1 run_action add 42 > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "conflicting REST and GraphQL review timestamps unexpectedly succeeded"
fi
grep -qF 'submittedAt and submitted_at conflict' "$__fixture_dir/error" ||
    fail "conflicting provider timestamp error was not actionable"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "conflicting provider timestamp changed state"

write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":118,\"addedAt\":\"2024-01-01T00:00:00Z\"},{\"number\":113}]}"
run_action list > "$__poll_output"
jq -e '
  (.pull_requests | map(.number) == [118]) and
  (.warnings | any(contains("quarantined watch-entry for PR #113")))
' "$__poll_output" >/dev/null || fail "malformed watch entry was not quarantined without hiding valid watches"
jq -e '
  (.pull_requests | map(.number) == [118]) and
  (.quarantine | length == 1) and
  .quarantine[0].kind == "watch-entry" and
  .quarantine[0].number == 113 and
  .quarantine[0].raw.number == 113 and
  (.quarantine[0].digest | test("^[a-f0-9]{64}$"))
' "$__state_file" >/dev/null || fail "quarantine did not preserve malformed raw evidence"

write_fixture 113
cat > "$__fixture_dir/pr-113.json" <<'EOF'
{"number":113,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-113","reviewDecision":"APPROVED","reviews":[{"id":11301,"author":{"login":"bad"},"submittedAt":"not-a-timestamp","state":"COMMENTED","body":"bad metadata"}],"statusCheckRollup":[]}
EOF
write_fixture 124
cat > "$__fixture_dir/pr-124.json" <<'EOF'
{"number":124,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-124","reviewDecision":"APPROVED","reviews":[{"id":12401,"author":{"login":"good"},"submittedAt":"2024-01-07T00:00:00Z","state":"COMMENTED","body":"valid metadata"}],"statusCheckRollup":[]}
EOF
printf '[[]]\n' > "$__fixture_dir/pulls-113.json"
printf '[[]]\n' > "$__fixture_dir/issues-113.json"
printf '[[]]\n' > "$__fixture_dir/pulls-124.json"
printf '[[]]\n' > "$__fixture_dir/issues-124.json"
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":113,\"addedAt\":\"2024-01-01T00:00:00Z\"},{\"number\":124,\"addedAt\":\"2024-01-01T00:00:00Z\"}]}"
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "isolated malformed watch poll unexpectedly succeeded"
fi
grep -qF 'PR #113 poll failed' "$__fixture_dir/error" ||
    fail "isolated poll did not report the malformed watch"
grep -qF 'pr view 124' "$__log_file" ||
    fail "malformed PR #113 blocked polling of valid PR #124"
jq -e '
  ([.pull_requests[].number] | sort == [113,124]) and
  (.pull_requests[] | select(.number == 113) | .poll_failed == true) and
  (.pull_requests[] | select(.number == 124) | .new_reviews[0].submitted_at == "2024-01-07T00:00:00Z")
' "$__poll_output" >/dev/null || fail "isolated poll did not emit the valid watch result"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "failed isolated poll persisted state changes"

echo "pr:review-watch task passed."
