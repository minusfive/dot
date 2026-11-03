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
        printf '{"data":{"node":{"pullRequestReviewThread":{"isResolved":false}}}}\n'
        exit 0
    fi
    path="${@: -1}"
    if [[ "${GH_REVIEW_WATCH_FAIL_ENDPOINT:-}" == "$path" ]]; then
        printf 'simulated API failure\n' >&2
        exit 1
    fi
    if [[ "${GH_REVIEW_WATCH_RENAME_FAIL:-}" == "1" ]]; then
        chflags uchg "$GH_REVIEW_WATCH_STATE"
    fi
    kind="$(printf '%s' "$path" | cut -d/ -f4)"
    number="$(printf '%s' "$path" | cut -d/ -f5)"
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
if run_action list > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "staged-add payload omission unexpectedly succeeded"
fi
grep -qF "invalid watch state: $__state_file" "$__fixture_dir/error" ||
    fail "staged-add payload omission error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "staged-add payload omission emitted output"
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
  .pull_requests[0].inline_comments_pages == 2 and
  .pull_requests[0].issue_comments_pages == 1 and
  (.pull_requests[0].new_inline_comments | length == 1) and
  (.pull_requests[0].new_issue_comments | length == 1) and
  (.pull_requests[0].new_reviews | length == 1)
' --arg repo "$__repository" "$__poll_output" >/dev/null || fail "multi-page poll output shape or cutoff is incorrect"
if grep -q -- '--jq' "$__log_file"; then
    fail "review-watch combined --slurp with incompatible --jq"
fi
grep -q -- '--paginate --slurp' "$__log_file" || fail "review-watch did not use gh api pagination"
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
{"number":12,"state":"OPEN","mergedAt":null,"closedAt":null,"headRefName":"review-12","reviewDecision":"APPROVED","reviews":[{"id":1201,"state":"PENDING","body":"draft review"},{"id":1202,"state":"COMMENTED","submittedAt":"2024-01-02T00:00:00Z","body":"submitted"}],"statusCheckRollup":[]}
EOF
cat > "$__fixture_dir/pulls-12.json" <<'EOF'
[[{"id":1203,"isResolved":false,"created_at":"2024-01-02T00:00:00Z","body":"unresolved","html_url":"https://example.test/inline/1203"}]]
EOF
cat > "$__fixture_dir/issues-12.json" <<'EOF'
[[{"id":1204,"created_at":"2024-01-02T00:00:00Z","body":"unknown resolution"}]]
EOF
write_state "{\"version\":1,\"repository\":\"$__repository\",\"pull_requests\":[{\"number\":12,\"addedAt\":\"2024-01-01T00:00:00Z\",\"lastSeenAt\":\"2024-01-03T00:00:00Z\",\"seen\":{\"reviews\":[\"1202\"],\"inline_comments\":[\"pulls:1203\"],\"issue_comments\":[\"issues:1204\"]},\"graceChecks\":3}]}"
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
        "state": "OPEN",
        "new_reviews": [{"body": "recover me"}],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
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
  "pull_requests": [],
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
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "invalid pending poll action unexpectedly succeeded"
fi
grep -qF "invalid watch state: $__state_file" "$__fixture_dir/error" ||
    fail "invalid pending poll error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "invalid pending poll emitted output"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "invalid pending poll changed state bytes"

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
__before_hash="$(shasum -a 256 "$__state_file" | cut -d' ' -f1)"
if run_poll > "$__poll_output" 2> "$__fixture_dir/error"; then
    fail "malformed watch entry unexpectedly succeeded"
fi
grep -qF "invalid watch state: $__state_file" "$__fixture_dir/error" ||
    fail "malformed watch entry error was not actionable"
[[ ! -s "$__poll_output" ]] || fail "malformed watch entry emitted success JSON"
[[ "$(shasum -a 256 "$__state_file" | cut -d' ' -f1)" == "$__before_hash" ]] ||
    fail "malformed watch entry changed state bytes"
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
  "pull_requests": [],
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
        "state": "OPEN",
        "new_reviews": [],
        "new_inline_comments": [],
        "new_issue_comments": [],
        "checks": [],
        "inline_comments_pages": 0,
        "issue_comments_pages": 0,
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

echo "pr:review-watch task passed."
