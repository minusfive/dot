#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

local __task="$__root_dir/home/.config/mise/tasks/pr/review-watch.ts"
local __fixture_dir="$__root_dir/.agents/projects.local/review-watch-repair/tmp/review-watch-test.$$"
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
cleanup() {
    chflags -R nouchg "$__fixture_dir" 2>/dev/null || true
    rm -rf "$__fixture_dir"
}
trap cleanup EXIT

cat > "$__bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$GH_REVIEW_WATCH_LOG"
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
run_poll > "$__poll_output"
jq -e '
  (.warnings | length == 2) and
  (.warnings | any(.[]; contains("PR #1 review 1"))) and
  (.warnings | any(.[]; contains("PR #1 review 2"))) and
  (.pull_requests[0].new_reviews | length == 1) and
  .pull_requests[0].new_reviews[0].author == "reviewer"
' "$__poll_output" >/dev/null || fail "malformed review timestamps were not ignored with warnings"

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

write_fixture 2
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

echo "pr:review-watch task passed."
