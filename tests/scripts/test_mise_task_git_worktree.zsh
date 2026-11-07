#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing git:worktree stale cleanup..."

local __fixture_dir
__fixture_dir="$(test_fixture_dir git-worktree)" || exit 1
local __bin_dir="$__fixture_dir/bin"
local __repository="$__fixture_dir/repository"
local __task="$__root_dir/home/.config/mise/tasks/git/worktree.ts"
local __real_git="$(command -v git)"
local __git_log="$__fixture_dir/git.log"
local __git_path_log="$__fixture_dir/git-path.log"
local __prune_log="$__fixture_dir/prune.log"
local __task_cwd_log="$__fixture_dir/task-cwd.log"
local __fzf_log="$__fixture_dir/fzf.log"
local __fzf_preview_log="$__fixture_dir/fzf-preview.log"
local __gh_log="$__fixture_dir/gh.log"
local __pitchfork_log="$__fixture_dir/pitchfork.log"
trap 'rm -rf -- "$__fixture_dir"' EXIT

mkdir -p "$__bin_dir" "$__repository"
"$__real_git" -C "$__repository" init -q
"$__real_git" -C "$__repository" config user.email test@example.com
"$__real_git" -C "$__repository" config user.name test
"$__real_git" -C "$__repository" config commit.gpgsign false
"$__real_git" -C "$__repository" remote add origin https://github.com/minusfive/dot.git
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.trustedGitHubHost github.com
"$__real_git" -C "$__repository" commit --allow-empty -qm init

cat > "$__bin_dir/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
__command_log="\${*//\$'\\n'/\\\\n}"
printf '%s\t%s\\n' "\$PWD" "\$__command_log" >> "$__git_log"
printf 'cwd\\t%s\\n' "\$PWD" >> "$__git_path_log"
if [[ "\$PWD" != "$__fixture_dir" && "\$PWD" != "$__fixture_dir"/* ]]; then
    printf 'git working directory escaped fixture: %s\\n' "\$PWD" >&2
    exit 97
fi
for __arg in "\$@"; do
    case "\$__arg" in
        /*|./*|../*)
            if [[ -e "\$__arg" ]]; then
                __path="\$(realpath "\$__arg")"
            else
                __path="\$(cd "\$(dirname "\$__arg")" && pwd -P)/\$(basename "\$__arg")"
            fi
            __path_log="\${__path//\$'\\n'/\\\\n}"
            printf 'path\\t%s\\n' "\$__path_log" >> "$__git_path_log"
            if [[ "\$__path" != "$__fixture_dir" && "\$__path" != "$__fixture_dir"/* ]]; then
                printf 'git path escaped fixture: %s\\n' "\$__path" >&2
                exit 97
            fi
            ;;
    esac
done
if [[ "\${WORKTREE_LIST_MODE:-}" == empty && "\$*" == "worktree list --porcelain -z" ]]; then
    exit 0
fi
if [[ "\${WORKTREE_LIST_MODE:-}" == empty && "\$*" == config\ --local\ --null\ --get-regexp* ]]; then
    exit 1
fi
if [[ "\$*" == "worktree prune"* ]]; then
    printf '%s\\n' prune >> "$__prune_log"
fi
if [[ "\${1:-}" == "worktree" && "\${2:-}" == "remove" &&
    -f "$__fixture_dir/fail-remove-path" &&
    "\${3:-}" == "\$(cat "$__fixture_dir/fail-remove-path")" ]]; then
    printf '%s\\n' 'forced fixture removal failure' >&2
    exit 1
fi
if [[ -f "$__fixture_dir/fail-release-write" &&
    "\$*" == "config --local --replace-all"* ]]; then
    printf '%s\\n' 'forced fixture release write failure' >&2
    exit 1
fi
if [[ -f "$__fixture_dir/fail-release-field" &&
    "\$*" == "config --local --replace-all"* ]]; then
    __failed_field="\$(cat "$__fixture_dir/fail-release-field")"
    if [[ "\$*" == *"\$__failed_field"* ]]; then
        printf '%s\\n' "forced fixture failure for \$__failed_field" >&2
        exit 1
    fi
fi
exec "$__real_git" "\$@"
EOF
chmod +x "$__bin_dir/git"

cat > "$__bin_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${GH_LOG:?}"
if [[ "$*" == *" --slurp "* && "$*" == *" --jq "* ]]; then
    printf '%s\n' 'gh api does not support --slurp with --jq' >&2
    exit 2
fi
case "${GH_MODE:-normal}:$*" in
    unavailable:*) exit 1 ;;
    malformed:*) printf '%s\n' 'not-json' ;;
    empty:*) printf '%s\n' '[]' ;;
    *--paginate*state=open*) printf '%s\n' \
        '{"number":10,"title":"open","head":{"ref":"open-branch"}}' ;;
    *--paginate*state=closed*) printf '%s\n' \
        '{"number":11,"title":"closed","head":{"ref":"closed-branch"}}' \
        '{"number":12,"title":"closed release failure","head":{"ref":"closed-release"}}' \
        '{"number":13,"title":"closed name mismatch","head":{"ref":"closed-name-mismatch"}}' ;;
    *state=open*) printf '%s\n' '[{"number":10,"title":"open","head":{"ref":"open-branch"}}]' ;;
    *state=closed*) printf '%s\n' '[{"number":11,"title":"closed","head":{"ref":"closed-branch"}},{"number":12,"title":"closed release failure","head":{"ref":"closed-release"}},{"number":13,"title":"closed name mismatch","head":{"ref":"closed-name-mismatch"}}]' ;;
    *) printf '%s\n' '[]' ;;
esac
EOF
chmod +x "$__bin_dir/gh"

cat > "$__bin_dir/fzf" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
preview_command=""
while (($#)); do
    if [[ "$1" == "--preview" && $# -ge 2 ]]; then
        preview_command="$2"
        shift 2
    else
        shift
    fi
done
printf '%s\n' "${FZF_MODE:-first}" >> "$FZF_LOG"
printf '%s\n' "$input" >> "$FZF_LOG"
printf '%s\n' "$preview_command" >> "$FZF_PREVIEW_LOG"
shell_quote() {
    printf "'%s'" "${1//\'/\'\\\'\'}"
}
expand_preview() {
    local command="$1"
    local selected="$2"
    local label path id ref reason
    IFS=$'\t' read -r label path id ref reason <<< "$selected"
    command="${command//\{1\}/$(shell_quote "$label")}"
    command="${command//\{2\}/$(shell_quote "$path")}"
    command="${command//\{s2\}/$(shell_quote "$path")}"
    command="${command//\{3\}/$(shell_quote "$id")}"
    command="${command//\{4\}/$(shell_quote "$ref")}"
    command="${command//\{5\}/$(shell_quote "$reason")}"
    printf '%s' "$command"
}
case "${FZF_MODE:-first}" in
    cancel)
        exit 130
        ;;
    sentinel)
        printf '%s\n' $'ALL_STALE_WORKTREES\tALL_STALE_WORKTREES\t\t\tall eligible stale worktrees'
        ;;
    default-stale)
        printf '%s\n' $'All stale worktrees\tALL_STALE_WORKTREES\t'
        ;;
    closed-sentinel)
        printf '%s\n' $'All closed PRs\tALL_CLOSED_PRS\t'
        ;;
    release-failure)
        printf '%s\n' "$input" | awk -F '\t' '$1 == "ELIGIBLE" && $2 ~ /\/release-failure$/ { print; exit }'
        ;;
    closed-release-failure)
        printf '%s\n' "$input" | awk -F '\t' '$1 == "ELIGIBLE" && $2 ~ /\/closed-release$/ { print; exit }'
        ;;
    lossless-default)
        printf '%s\n' "$input" | awk -F '\t' '$2 ~ /default-lossless $/ { print; exit }'
        ;;
    all)
        printf '%s\n' "$input" | awk -F '\t' '$1 == "ELIGIBLE"'
        ;;
    mutate-dirty)
        selected="$(printf '%s\n' "$input" | awk -F '\t' '$1 == "ELIGIBLE" { print; exit }')"
        path="$(printf '%s\n' "$selected" | cut -f2)"
        printf '%s\n' dirty > "$path/toctou.txt"
        printf '%s\n' "$selected"
        ;;
    preview-metachar)
        selected="$(printf '%s\n' "$input" | awk -F '\t' '$2 ~ /preview; touch fzf-pwned$/ { print; exit }')"
        expanded="$(expand_preview "$preview_command" "$selected")"
        printf '%s\n' "$expanded" >> "$FZF_PREVIEW_LOG"
        bash -c "$expanded" >/dev/null 2>&1 || true
        printf '%s\n' "$selected"
        ;;
    *)
        printf '%s\n' "$input" | awk -F '\t' '$1 == "ELIGIBLE" { print; exit }'
        ;;
esac
EOF
chmod +x "$__bin_dir/fzf"

cat > "$__bin_dir/pitchfork" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\t%s\\n' "\$PWD" "\$*" >> "$__pitchfork_log"
EOF
chmod +x "$__bin_dir/pitchfork"

run_task_from() {
    local __cwd="$1"
    local __name="${2:-}"
    local __delete="${3:-false}"
    local __stale="${4:-false}"
    local __release="${5:-}"
    local __worktree_list_mode="${6:-}"
    local __closed="${7:-false}"
    (
        cd "$__cwd"
        printf '%s\n' "$PWD" >> "$__task_cwd_log"
        env \
            PATH="$__bin_dir:$PATH" \
            GH_MODE="${GH_MODE:-}" \
            GH_LOG="$__gh_log" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
            MISE_ENV_CONF_D=true \
            WORKTREE_LIST_MODE="$__worktree_list_mode" \
            usage_name="$__name" \
            usage_delete="$__delete" \
            usage_stale="$__stale" \
            usage_release="$__release" \
            usage_pull_request="" \
            usage_closed_prs="$__closed" \
            bun "$__task"
    )
}

run_task() {
    local __name="${1:-}"
    local __delete="${2:-false}"
    local __stale="${3:-false}"
    local __release="${4:-}"
    local __worktree_list_mode="${5:-}"
    local __closed="${6:-false}"
    run_task_from "$__repository" "$__name" "$__delete" "$__stale" "$__release" "$__worktree_list_mode" "$__closed"
}

run_pull_request() {
    local __pull_request="$1"
    (
        cd "$__repository"
        env \
            PATH="$__bin_dir:$PATH" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
            MISE_ENV_CONF_D=true \
            usage_name="" \
            usage_delete=false \
            usage_stale=false \
            usage_release="" \
            usage_pull_request="$__pull_request" \
            usage_closed_prs=false \
            GH_LOG="$__gh_log" \
            bun "$__task"
    )
}

run_task_tty() {
    local __input="${1:-}"
    local __mode="${2:-first}"
    local __fail_remove="${3:-}"
    local __stale="${4:-true}"
    local __closed="${5:-false}"
    local __log="$__fixture_dir/tty.log"
    local __status_file="$__fixture_dir/tty.status"
    shift
    shift
    (($#)) && shift
    (($#)) && shift
    (($#)) && shift
    rm -f "$__status_file"
    if [[ -n "$__fail_remove" ]]; then
        printf '%s\n' "$__fail_remove" > "$__fixture_dir/fail-remove-path"
    else
        rm -f "$__fixture_dir/fail-remove-path"
    fi
    (
        cd "$__repository"
        printf '%s\n' "$PWD" >> "$__task_cwd_log"
        local __script_status=0
        if { printf '%s\n' "$__input"; sleep 1; } | script -q -e "$__log" env \
                PATH="$__bin_dir:$PATH" \
                MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
                MISE_ENV_CONF_D=true \
                usage_name="" \
                usage_delete=true \
                usage_stale="$__stale" \
                usage_release="" \
                usage_pull_request="" \
                usage_closed_prs="$__closed" \
                GH_LOG="$__gh_log" \
                FZF_MODE="$__mode" \
                FZF_LOG="$__fzf_log" \
                FZF_PREVIEW_LOG="$__fzf_preview_log" \
                TEST_STATUS_FILE="$__status_file" \
                bash -c 'bun "$1" "${@:2}"; __status=$?; printf "%s\n" "$__status" > "$TEST_STATUS_FILE"; exit "$__status"' \
                bash "$__task" "$@" >/dev/null
        then
            :
        else
            __script_status=$?
        fi
        [[ -f "$__status_file" ]] || printf '%s\n' "$__script_status" > "$__status_file"
    )
    local __status="$(cat "$__status_file")"
    return "$__status"
}

run_usage_conflict() {
    local __name="${1:-}"
    local __stale="${2:-false}"
    local __release="${3:-}"
    local __pull_request="${4:-}"
    (
        cd "$__repository"
        env \
            PATH="$__bin_dir:$PATH" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" \
            MISE_ENV_CONF_D=true \
            usage_name="$__name" \
            usage_delete=false \
            usage_stale="$__stale" \
            usage_release="$__release" \
            usage_pull_request="$__pull_request" \
            usage_closed_prs=true \
            GH_LOG="$__gh_log" \
            FZF_LOG="$__fzf_log" \
            bun "$__task"
    )
}

worktree_id() {
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
}

age_worktree() {
    age_worktree_at "$__repository" "$1"
}

age_worktree_at() {
    local __repository_path="$1"
    local __path="$2"
    local __id="$(worktree_id "$__path")"
    for __field in registeredAt lastSeenAt leaseUntil; do
        "$__real_git" -C "$__repository_path" config --local \
            "worktree.cleanup.v1.$__id.$__field" 2020-01-01T00:00:00.000Z
    done
}

create_registered() {
    run_task "$1" >/dev/null
    age_worktree "$__fixture_dir/$1"
}

create_registered eligible
create_registered dirty
print -r -- dirty > "$__fixture_dir/dirty/dirty.txt"
create_registered locked
"$__real_git" -C "$__repository" worktree lock "$__fixture_dir/locked"
create_registered protected
create_registered open-branch
create_registered closed-branch
create_registered closed-release
create_registered malformed
create_registered invalid-ref
create_registered invalid-head
create_registered released

local __name_mismatch_path="$__fixture_dir/pr-10"
"$__real_git" -C "$__repository" worktree add -q "$__name_mismatch_path" -b closed-name-mismatch
local __name_mismatch_id="$(worktree_id "$__name_mismatch_path")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.path" "$__name_mismatch_path"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.registeredAt" 2020-01-01T00:00:00.000Z
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.lastSeenAt" 2020-01-01T00:00:00.000Z
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.leaseUntil" 2020-01-01T00:00:00.000Z
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.releasedAt" ""
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.ref" refs/heads/closed-name-mismatch
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.head" "$("$__real_git" -C "$__name_mismatch_path" rev-parse HEAD)"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__name_mismatch_id.state" active

local __preview_path="$__fixture_dir/preview; touch fzf-pwned"
"$__real_git" -C "$__repository" worktree add -q "$__preview_path" -b preview-label
local __preview_id="$(worktree_id "$__preview_path")"
local __preview_head="$("$__real_git" -C "$__preview_path" rev-parse HEAD)"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__preview_id.path" "$__preview_path"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__preview_id.ref" refs/heads/preview-label
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__preview_id.head" "$__preview_head"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__preview_id.releasedAt" ""
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__preview_id.state" active
age_worktree "$__preview_path"

local __newline_path="$__fixture_dir/newline"$'\n'"path"
"$__real_git" -C "$__repository" worktree add -q "$__newline_path" -b newline-branch
local __newline_id="$(worktree_id "$__newline_path")"
local __newline_head="$("$__real_git" -C "$__newline_path" rev-parse HEAD)"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__newline_id.path" "$__newline_path"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__newline_id.ref" refs/heads/newline-branch
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__newline_id.head" "$__newline_head"
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__newline_id.releasedAt" ""
"$__real_git" -C "$__repository" config --local "worktree.cleanup.v1.$__newline_id.state" active
age_worktree "$__newline_path"
run_task "" false false "$__newline_path" >/dev/null
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__newline_id.state")" == "released" ]] ||
    fail "newline worktree path did not survive release matching"
"$__real_git" -C "$__repository" worktree remove "$__newline_path" >/dev/null

local __detached="$__fixture_dir/detached"
"$__real_git" -C "$__repository" worktree add -q --detach "$__detached"

local __missing="$__fixture_dir/missing"
"$__real_git" -C "$__repository" worktree add -q "$__missing" -b missing-branch
age_worktree "$__fixture_dir/missing"

local __malformed_id="$(worktree_id "$__fixture_dir/malformed")"
"$__real_git" -C "$__repository" config --local --add \
    "worktree.cleanup.v1.$__malformed_id.registeredAt" 2020-01-01T00:00:00.000Z
local __invalid_ref_id="$(worktree_id "$__fixture_dir/invalid-ref")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__invalid_ref_id.ref" ""
local __invalid_head_id="$(worktree_id "$__fixture_dir/invalid-head")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__invalid_head_id.head" malformed
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.protectedRef refs/heads/protected
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.staleAfterDays ""
local __empty_stale_config_status=0
set +e
run_task "" false true >"$__fixture_dir/empty-stale.out" 2>&1
__empty_stale_config_status=$?
set -e
[[ "$__empty_stale_config_status" -eq 0 ]] ||
    fail "empty staleAfterDays config caused a hard failure"
grep -qF "invalid staleAfterDays configuration" "$__fixture_dir/empty-stale.out" ||
    fail "empty staleAfterDays config was not rejected"
"$__real_git" -C "$__repository" config --local --unset-all worktree.cleanup.staleAfterDays
"$__real_git" -C "$__repository" config --local worktree.cleanup.staleAfterDays 1

assert_closed_conflict() {
    local __label="$1"
    shift
    : > "$__fzf_log"
    : > "$__gh_log"
    rm -f "$__prune_log"
    local __status=0
    set +e
    run_usage_conflict "$@" >"$__fixture_dir/$__label.out" 2>&1
    __status=$?
    set -e
    [[ "$__status" -eq 2 ]] ||
        fail "$__label conflict exited with $__status instead of 2: $(cat "$__fixture_dir/$__label.out")"
    [[ ! -s "$__fzf_log" ]] || fail "$__label conflict invoked FZF"
    [[ ! -s "$__gh_log" ]] || fail "$__label conflict queried GitHub"
    [[ ! -e "$__prune_log" ]] || fail "$__label conflict invoked git worktree prune"
}

assert_closed_conflict stale "" true "" ""
assert_closed_conflict release "" false "$__fixture_dir/released" ""
assert_closed_conflict positional worktree-name false "" ""
assert_closed_conflict pull-request "" false "" "123"

local __linked="$__fixture_dir/linked"
"$__real_git" -C "$__repository" worktree add -q "$__linked" -b linked-branch
local __nested="$__linked/nested"
"$__real_git" -C "$__repository" worktree add -q "$__nested" -b nested-branch

local __report
__report="$(run_task "" false true)"
print -r -- "$__report"
[[ -d "$__fixture_dir/eligible" ]] || fail "report-only stale mode removed a worktree"
if ! print -r -- "$__report" | awk -F '\t' '{ print $2 "\t" $3 "\t" $1 }' | LC_ALL=C sort -c >/dev/null; then
    fail "stale report rows were not deterministically sorted"
fi
print -r -- "$__report" | grep -q $'^ELIGIBLE\t.*/eligible\t' ||
    fail "clean stale worktree was not eligible"
print -r -- "$__report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/dirty"$'\t' ||
    fail "dirty worktree was not quarantined"
print -r -- "$__report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/locked"$'\t' ||
    fail "locked worktree was not quarantined"
print -r -- "$__report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/protected"$'\t' ||
    fail "protected worktree was not quarantined"
print -r -- "$__report" | grep -qF $'\trefs/heads/open-branch\topen pull request' ||
    fail "open pull request was not protected"
print -r -- "$__report" | grep -qF $'ELIGIBLE\t'"$__fixture_dir/closed-branch"$'\t' ||
    fail "closed pull request worktree was not eligible"
if ! print -r -- "$__report" | awk -F '\t' -v path="$__name_mismatch_path" \
    '$1 == "QUARANTINE" && $2 == path && $5 == "open pull request for worktree name" { found = 1 }
    END { exit found ? 0 : 1 }'; then
    fail "stale mode did not quarantine open PR name mismatch"
fi
[[ -d "$__name_mismatch_path" ]] || fail "stale mode removed open PR name mismatch worktree"
print -r -- "$__report" | grep -qF $'UNKNOWN\t'"$__fixture_dir/missing"$'\t' ||
    fail "missing metadata was not unknown"
print -r -- "$__report" | grep -qF $'UNKNOWN\t'"$__fixture_dir/malformed"$'\t' ||
    fail "malformed metadata was not unknown"
print -r -- "$__report" | grep -qF $'UNKNOWN\t'"$__fixture_dir/invalid-ref"$'\t' ||
    fail "invalid ref metadata was not unknown"
print -r -- "$__report" | grep -qF $'UNKNOWN\t'"$__fixture_dir/invalid-head"$'\t' ||
    fail "invalid HEAD metadata was not unknown"
print -r -- "$__report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/detached"$'\t' ||
    fail "detached worktree was not quarantined"

local __closed_report="$(run_task "" false false "" "" true)"
print -r -- "$__closed_report" | grep -qF $'ELIGIBLE\t'"$__fixture_dir/closed-branch"$'\t' ||
    fail "closed-PR report did not include the closed branch"
[[ -d "$__fixture_dir/closed-branch" ]] || fail "closed-PR report removed a worktree"
print -r -- "$__closed_report" | grep -qF $'ELIGIBLE\t'"$__name_mismatch_path"$'\t' &&
    fail "open PR name mismatch was eligible for closed-PR cleanup"
if ! print -r -- "$__closed_report" | awk -F '\t' -v path="$__name_mismatch_path" \
    '$1 == "QUARANTINE" && $2 == path && $5 == "open pull request for worktree name" { found = 1 }
    END { exit found ? 0 : 1 }'; then
    fail "open PR name mismatch was not quarantined by worktree name"
fi
[[ -d "$__name_mismatch_path" ]] || fail "open PR name mismatch worktree was removed"
"$__real_git" -C "$__repository" worktree remove "$__name_mismatch_path" >/dev/null

local __closed_protected_report
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.protectedRef refs/heads/closed-branch
__closed_protected_report="$(run_task "" false false "" "" true)"
print -r -- "$__closed_protected_report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/closed-branch"$'\t' ||
    fail "closed-PR report did not quarantine a protected ref"
"$__real_git" -C "$__repository" config --local --unset-all worktree.cleanup.protectedRef
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.protectedRef refs/heads/protected

local __closed_apply_output="$__fixture_dir/closed-apply.out"
set +e
run_task "" true false "" "" true >"$__closed_apply_output" 2>&1
local __closed_apply_status=$?
set -e
[[ "$__closed_apply_status" -eq 2 ]] ||
    fail "non-TTY closed-PR apply exited with $__closed_apply_status instead of 2"
[[ -d "$__fixture_dir/closed-branch" ]] || fail "non-TTY closed-PR apply removed a worktree"

local __closed_decline_status=0
set +e
run_task_tty n closed-sentinel "" false true >/dev/null 2>&1
__closed_decline_status=$?
set -e
[[ "$__closed_decline_status" -eq 0 ]] ||
    fail "declined closed-PR confirmation exited with $__closed_decline_status"
[[ -d "$__fixture_dir/closed-branch" ]] || fail "declined closed-PR confirmation removed a worktree"

local __closed_toctou_status=0
set +e
run_task_tty y mutate-dirty "" false true >/dev/null 2>&1
__closed_toctou_status=$?
set -e
[[ "$__closed_toctou_status" -eq 0 ]] ||
    fail "closed-PR TOCTOU revalidation exited with $__closed_toctou_status"
[[ -d "$__fixture_dir/closed-branch" ]] || fail "closed-PR TOCTOU revalidation removed a changed worktree"
rm -f "$__fixture_dir/closed-branch/toctou.txt"

local __bare_seed="$__fixture_dir/bare-seed"
local __bare_repository="$__fixture_dir/bare.git"
local __bare_linked="$__fixture_dir/bare-linked"
local __bare_current="$__fixture_dir/bare-current"
"$__real_git" -C "$__fixture_dir" init -q bare-seed
"$__real_git" -C "$__bare_seed" config user.email test@example.com
"$__real_git" -C "$__bare_seed" config user.name test
"$__real_git" -C "$__bare_seed" config commit.gpgsign false
"$__real_git" -C "$__bare_seed" commit --allow-empty -qm init
"$__real_git" clone -q --bare "$__bare_seed" "$__bare_repository"
"$__real_git" --git-dir="$__bare_repository" config remote.origin.url https://github.com/minusfive/dot.git
"$__real_git" --git-dir="$__bare_repository" config --local --add worktree.cleanup.trustedGitHubHost github.com
"$__real_git" --git-dir="$__bare_repository" worktree add -q "$__bare_linked" -b bare-linked
"$__real_git" --git-dir="$__bare_repository" worktree add -q "$__bare_current" -b bare-current
local __bare_linked_id="$(worktree_id "$__bare_linked")"
local __bare_linked_head="$("$__real_git" -C "$__bare_linked" rev-parse HEAD)"
"$__real_git" --git-dir="$__bare_repository" config --local "worktree.cleanup.v1.$__bare_linked_id.path" "$__bare_linked"
"$__real_git" --git-dir="$__bare_repository" config --local "worktree.cleanup.v1.$__bare_linked_id.ref" refs/heads/bare-linked
"$__real_git" --git-dir="$__bare_repository" config --local "worktree.cleanup.v1.$__bare_linked_id.head" "$__bare_linked_head"
"$__real_git" --git-dir="$__bare_repository" config --local "worktree.cleanup.v1.$__bare_linked_id.releasedAt" ""
"$__real_git" --git-dir="$__bare_repository" config --local "worktree.cleanup.v1.$__bare_linked_id.state" active
for __field in registeredAt lastSeenAt leaseUntil; do
    "$__real_git" --git-dir="$__bare_repository" config --local \
        "worktree.cleanup.v1.$__bare_linked_id.$__field" 2020-01-01T00:00:00.000Z
done
local __bare_report="$(run_task_from "$__bare_current" "" false true)"
print -r -- "$__bare_report" | grep -qF $'\t'"$__bare_repository"$'\t' ||
    fail "bare repository root was not listed"
print -r -- "$__bare_report" | grep -qF $'ELIGIBLE\t'"$__bare_repository"$'\t' &&
    fail "bare repository root was eligible for cleanup"
print -r -- "$__bare_report" | grep -qF $'ELIGIBLE\t'"$__bare_linked"$'\t' ||
    fail "linked worktree was incorrectly protected as the bare repository root"

touch "$__fixture_dir/fail-release-write"
local __closed_release_failure_status=0
set +e
run_task_tty y closed-release-failure "" false true >/dev/null 2>&1
__closed_release_failure_status=$?
set -e
[[ "$__closed_release_failure_status" -eq 1 ]] ||
    fail "closed-PR release-write failure exited with $__closed_release_failure_status"
[[ ! -d "$__fixture_dir/closed-release" ]] ||
    fail "closed-PR release-write failure did not preserve the successful Git removal"
grep -qF "Failed to release metadata." "$__fixture_dir/tty.log" ||
    fail "closed-PR release-write failure did not report the metadata failure"
local __closed_release_failure_id="$(worktree_id "$__fixture_dir/closed-release")"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__closed_release_failure_id.state")" == "active" ]] ||
    fail "closed-PR release-write failure claimed released metadata"
rm -f "$__fixture_dir/fail-release-write"

local __linked_report="$(run_task_from "$__linked" "" false true)"
print -r -- "$__linked_report" | grep -qF $'QUARANTINE\t'"$__repository"$'\t' ||
    fail "linked invocation did not protect the common repository root"
print -r -- "$__linked_report" | grep -qF $'QUARANTINE\t'"$__linked"$'\t' ||
    fail "linked invocation did not protect its current worktree root"

local __nested_report="$(run_task_from "$__nested" "" false true)"
print -r -- "$__nested_report" | grep -qF $'QUARANTINE\t'"$__repository"$'\t' ||
    fail "nested invocation did not protect the common repository root"
print -r -- "$__nested_report" | grep -qF $'QUARANTINE\t'"$__nested"$'\t' ||
    fail "nested invocation did not protect its current worktree root"
local __guard_report="$(GH_MODE=unavailable run_task_from "$__nested" "" false true)"
print -r -- "$__guard_report" | grep -qF "No eligible stale worktrees found:" ||
    fail "quarantine/unknown-only report did not print a summary"
print -r -- "$__guard_report" | grep -qF "quarantine, " ||
    fail "quarantine/unknown-only report did not print counts"
print -r -- "$__guard_report" | grep -qF "repository root" ||
    fail "quarantine/unknown-only report did not print reasons"

create_registered internal-host
: > "$__gh_log"
"$__real_git" -C "$__repository" remote set-url origin https://attacker.internal/minusfive/dot.git
local __internal_report="$(run_task "" false true)"
print -r -- "$__internal_report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/internal-host"$'\t' ||
    fail "unsupported remote host did not quarantine stale cleanup"
print -r -- "$__internal_report" | grep -qF "unavailable pull request" ||
    fail "unsupported remote host did not report unavailable pull request state"
[[ ! -s "$__gh_log" ]] || fail "unsupported remote host reached the GitHub API stub"
[[ -d "$__fixture_dir/internal-host" ]] || fail "unsupported remote host changed report-only cleanup"
"$__real_git" -C "$__repository" remote set-url origin https://github.com/minusfive/dot.git
"$__real_git" -C "$__repository" config --local --unset-all worktree.cleanup.trustedGitHubHost
: > "$__gh_log"
local __untrusted_default_report="$(run_task "" false true)"
print -r -- "$__untrusted_default_report" | grep -qF "unavailable pull request" ||
    fail "github.com was trusted without an explicit allowlist"
[[ ! -s "$__gh_log" ]] || fail "default GitHub host reached the API without trust"
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.trustedGitHubHost "github.com/path"
: > "$__gh_log"
local __invalid_trusted_report="$(run_task "" false true)"
print -r -- "$__invalid_trusted_report" | grep -qF "unavailable pull request" ||
    fail "invalid trusted-host configuration was accepted"
[[ ! -s "$__gh_log" ]] || fail "invalid trusted-host configuration reached the API"
"$__real_git" -C "$__repository" config --local --unset-all worktree.cleanup.trustedGitHubHost
"$__real_git" -C "$__repository" config --local --add worktree.cleanup.trustedGitHubHost " GitHub.com. "

local __eligible_id="$(worktree_id "$__fixture_dir/eligible")"
local __registered_count="$("$__real_git" -C "$__repository" config --local --get-all \
    "worktree.cleanup.v1.$__eligible_id.registeredAt" | wc -l | tr -d ' ')"
[[ "$__registered_count" == "1" ]] || fail "registration was not idempotent"

local __reuse_path="$__fixture_dir/pr-10"
"$__real_git" -C "$__repository" worktree add -q "$__reuse_path" -b pr-10
run_pull_request 10 >/dev/null
local __known_registered_at=2020-01-01T00:00:00.000Z
local __known_last_seen_at=2020-01-02T00:00:00.000Z
local __known_lease_until=2030-01-01T00:00:00.000Z
local __reuse_id="$(worktree_id "$__reuse_path")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.registeredAt" "$__known_registered_at"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.lastSeenAt" "$__known_last_seen_at"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.leaseUntil" "$__known_lease_until"
run_pull_request 10 >/dev/null
[[ "$("$__real_git" -C "$__repository" config --local --get-all \
    "worktree.cleanup.v1.$__reuse_id.registeredAt" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "reuse duplicated registeredAt metadata"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.registeredAt")" == "$__known_registered_at" ]] ||
    fail "reuse changed registeredAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.leaseUntil")" == "$__known_lease_until" ]] ||
    fail "reuse changed leaseUntil"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.lastSeenAt")" != "$__known_last_seen_at" ]] ||
    fail "reuse did not update lastSeenAt"

local __recovery_pending_at=2020-01-03T00:00:00.000Z
local __recovery_failed=manual-recovery-required
local __captured_registered_at="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.registeredAt")"
local __captured_last_seen_at="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.lastSeenAt")"
local __captured_lease_until="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.leaseUntil")"
local __captured_released_at="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasedAt")"
local __captured_ref="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.ref")"
local __captured_head="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.head")"
local __captured_state="$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.state")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasePendingAt" "$__recovery_pending_at"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releaseRecoveryFailed" "$__recovery_failed"
: > "$__gh_log"
local __reuse_recovery_output="$__fixture_dir/reuse-recovery.out"
local __reuse_recovery_status=0
set +e
run_pull_request 10 >"$__reuse_recovery_output" 2>&1
__reuse_recovery_status=$?
set -e
[[ "$__reuse_recovery_status" -eq 1 ]] ||
    fail "release recovery reuse refusal exited with $__reuse_recovery_status"
grep -qF "release metadata recovery required" "$__reuse_recovery_output" ||
    fail "release recovery reuse refusal did not report the recovery guard"
! grep -qF "pr checkout" "$__gh_log" ||
    fail "release recovery reuse refusal reached PR checkout"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasePendingAt")" == "$__recovery_pending_at" ]] ||
    fail "release recovery reuse refusal changed releasePendingAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releaseRecoveryFailed")" == "$__recovery_failed" ]] ||
    fail "release recovery reuse refusal changed releaseRecoveryFailed"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.registeredAt")" == "$__captured_registered_at" ]] ||
    fail "release recovery reuse refusal changed registeredAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.lastSeenAt")" == "$__captured_last_seen_at" ]] ||
    fail "release recovery reuse refusal changed lastSeenAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.leaseUntil")" == "$__captured_lease_until" ]] ||
    fail "release recovery reuse refusal changed leaseUntil"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasedAt")" == "$__captured_released_at" ]] ||
    fail "release recovery reuse refusal changed releasedAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.ref")" == "$__captured_ref" ]] ||
    fail "release recovery reuse refusal changed ref"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.head")" == "$__captured_head" ]] ||
    fail "release recovery reuse refusal changed HEAD"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.state")" == "$__captured_state" ]] ||
    fail "release recovery reuse refusal changed state"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__reuse_id.releasePendingAt"
: > "$__gh_log"
local __failed_recovery_output="$__fixture_dir/failed-recovery.out"
local __failed_recovery_status=0
set +e
run_pull_request 10 >"$__failed_recovery_output" 2>&1
__failed_recovery_status=$?
set -e
[[ "$__failed_recovery_status" -eq 1 ]] ||
    fail "failed release recovery reuse refusal exited with $__failed_recovery_status"
grep -qF "release metadata recovery required" "$__failed_recovery_output" ||
    fail "failed release recovery reuse refusal did not report the recovery guard"
! grep -qF "pr checkout" "$__gh_log" ||
    fail "failed release recovery reuse refusal reached PR checkout"
! "$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasePendingAt" >/dev/null 2>&1 ||
    fail "failed release recovery reuse refusal restored releasePendingAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.registeredAt")" == "$__captured_registered_at" ]] ||
    fail "failed release recovery reuse refusal changed registeredAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.lastSeenAt")" == "$__captured_last_seen_at" ]] ||
    fail "failed release recovery reuse refusal changed lastSeenAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.leaseUntil")" == "$__captured_lease_until" ]] ||
    fail "failed release recovery reuse refusal changed leaseUntil"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releasedAt")" == "$__captured_released_at" ]] ||
    fail "failed release recovery reuse refusal changed releasedAt"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.ref")" == "$__captured_ref" ]] ||
    fail "failed release recovery reuse refusal changed ref"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.head")" == "$__captured_head" ]] ||
    fail "failed release recovery reuse refusal changed HEAD"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.state")" == "$__captured_state" ]] ||
    fail "failed release recovery reuse refusal changed state"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__reuse_id.releaseRecoveryFailed")" == "$__recovery_failed" ]] ||
    fail "failed release recovery reuse refusal changed releaseRecoveryFailed"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__reuse_id.releaseRecoveryFailed"

age_worktree "$__reuse_path"
local __mismatched_pr_report="$(run_task "" false true)"
print -r -- "$__mismatched_pr_report" | grep -qF $'QUARANTINE\t'"$__reuse_path"$'\t' ||
    fail "open PR basename match with a mismatched branch was not quarantined"
print -r -- "$__mismatched_pr_report" | grep -qF $'QUARANTINE\t'"$__reuse_path"$'\t'"$__reuse_id"$'\trefs/heads/pr-10\topen pull request for worktree name' ||
    fail "open PR basename match did not report the quarantine reason"
[[ -d "$__reuse_path" ]] || fail "open PR basename quarantine removed the worktree"
"$__real_git" -C "$__repository" worktree remove "$__reuse_path" >/dev/null

local __register_guard_path="$__fixture_dir/register-guard"
local __register_guard_id="$(worktree_id "$__register_guard_path")"
local __register_guard_head="$("$__real_git" -C "$__repository" rev-parse HEAD)"
for __field_value in \
    "path=$__register_guard_path" \
    "registeredAt=2020-01-01T00:00:00.000Z" \
    "lastSeenAt=2020-01-01T00:00:00.000Z" \
    "leaseUntil=2020-01-01T00:00:00.000Z" \
    "releasedAt=" \
    "ref=refs/heads/register-guard" \
    "head=$__register_guard_head" \
    "state=active"; do
    local __field="${__field_value%%=*}"
    local __value="${__field_value#*=}"
    "$__real_git" -C "$__repository" config --local \
        "worktree.cleanup.v1.$__register_guard_id.$__field" "$__value"
done
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__register_guard_id.releaseRecoveryFailed" "$__recovery_failed"
local __register_guard_output="$__fixture_dir/register-guard.out"
local __register_guard_status=0
set +e
run_task register-guard >"$__register_guard_output" 2>&1
__register_guard_status=$?
set -e
[[ "$__register_guard_status" -eq 1 ]] ||
    fail "registration recovery guard exited with $__register_guard_status"
grep -qF "release metadata recovery required" "$__register_guard_output" ||
    fail "registration recovery guard did not report the recovery guard"
[[ ! -d "$__register_guard_path" ]] ||
    fail "registration recovery guard created a worktree"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__register_guard_id.releaseRecoveryFailed")" == "$__recovery_failed" ]] ||
    fail "registration recovery guard changed releaseRecoveryFailed"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__register_guard_id.ref")" == "refs/heads/register-guard" ]] ||
    fail "registration recovery guard changed the captured ref"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__register_guard_id.releaseRecoveryFailed"
for __field in path registeredAt lastSeenAt leaseUntil releasedAt ref head state; do
    "$__real_git" -C "$__repository" config --local \
        --unset-all "worktree.cleanup.v1.$__register_guard_id.$__field"
done

local __physical_parent="$__fixture_dir/physical-parent"
local __symlink_parent="$__fixture_dir/symlink-parent"
local __symlinked_target="$__physical_parent/missing-target"
mkdir -p "$__physical_parent"
ln -s "$__physical_parent" "$__symlink_parent"
local __symlinked_target_id="$(worktree_id "$__symlinked_target")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__symlinked_target_id.path" "$__symlinked_target"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__symlinked_target_id.releaseRecoveryFailed" "$__recovery_failed"
local __symlink_recovery_output="$__fixture_dir/symlink-recovery.out"
local __symlink_recovery_status=0
set +e
run_task "symlink-parent/missing-target" >"$__symlink_recovery_output" 2>&1
__symlink_recovery_status=$?
set -e
[[ "$__symlink_recovery_status" -eq 1 ]] ||
    fail "symlinked-parent recovery guard exited with $__symlink_recovery_status"
grep -qF "release metadata recovery required" "$__symlink_recovery_output" ||
    fail "symlinked-parent recovery guard did not report the recovery guard"
[[ ! -e "$__symlinked_target" ]] ||
    fail "symlinked-parent recovery guard created the missing worktree"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__symlinked_target_id.path")" == "$__symlinked_target" ]] ||
    fail "symlinked-parent recovery guard changed the path metadata"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__symlinked_target_id.releaseRecoveryFailed")" == "$__recovery_failed" ]] ||
    fail "symlinked-parent recovery guard changed releaseRecoveryFailed"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__symlinked_target_id.path"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__symlinked_target_id.releaseRecoveryFailed"

local __pull_recovery_path="$__fixture_dir/pr-10"
local __pull_recovery_id="$(worktree_id "$__pull_recovery_path")"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__pull_recovery_id.path" "$__pull_recovery_path"
"$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__pull_recovery_id.releaseRecoveryFailed" "$__recovery_failed"
: > "$__gh_log"
: > "$__git_log"
local __pull_recovery_output="$__fixture_dir/pull-recovery.out"
local __pull_recovery_status=0
set +e
run_pull_request 10 >"$__pull_recovery_output" 2>&1
__pull_recovery_status=$?
set -e
[[ "$__pull_recovery_status" -eq 1 ]] ||
    fail "pull-request recovery guard exited with $__pull_recovery_status"
grep -qF "release metadata recovery required" "$__pull_recovery_output" ||
    fail "pull-request recovery guard did not report the recovery guard"
! grep -qF "pr checkout" "$__gh_log" ||
    fail "pull-request recovery guard reached PR checkout"
! grep -qF "worktree add" "$__git_log" ||
    fail "pull-request recovery guard created a worktree"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__pull_recovery_id.path")" == "$__pull_recovery_path" ]] ||
    fail "pull-request recovery guard changed the path metadata"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__pull_recovery_id.releaseRecoveryFailed")" == "$__recovery_failed" ]] ||
    fail "pull-request recovery guard changed releaseRecoveryFailed"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__pull_recovery_id.path"
"$__real_git" -C "$__repository" config --local \
    --unset-all "worktree.cleanup.v1.$__pull_recovery_id.releaseRecoveryFailed"

run_task "" false false "$__fixture_dir/released" >/dev/null
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$(worktree_id "$__fixture_dir/released").state")" == "released" ]] ||
    fail "release did not write released state"
[[ -d "$__fixture_dir/released" ]] || fail "release removed the worktree"

local __apply_output="$__fixture_dir/apply.out"
set +e
run_task "" true true >"$__apply_output" 2>&1
local __apply_status=$?
set -e
[[ "$__apply_status" -eq 2 ]] || fail "non-TTY apply exited with $__apply_status instead of 2"
[[ -d "$__fixture_dir/eligible" ]] || fail "non-TTY apply removed a worktree"
[[ ! -e "$__prune_log" ]] || fail "stale cleanup invoked git worktree prune"

__report="$(GH_MODE=unavailable run_task "" false true)"
print -r -- "$__report" | grep -qF "unavailable pull request" ||
    fail "unavailable pull request was not protected"

__report="$(GH_MODE=malformed run_task "" false true)"
print -r -- "$__report" | grep -qF "unavailable pull request" ||
    fail "malformed pull request output was not protected"

create_registered declined
create_registered toctou
create_registered first
create_registered second

local __cancel_status=0
local __cancel_output="$__fixture_dir/cancel.out"
set +e
run_task_tty "" cancel >"$__cancel_output" 2>&1
__cancel_status=$?
set -e
[[ "$__cancel_status" -eq 130 ]] ||
    fail "FZF cancellation exited with $__cancel_status instead of 130: $(cat "$__cancel_output")"
grep -qF "Cancelled; no worktrees removed." "$__cancel_output" ||
    grep -qF "Cancelled; no worktrees removed." "$__fixture_dir/tty.log" ||
    fail "FZF cancellation did not report a cancellation"

local __decline_status=0
set +e
run_task_tty n first >/dev/null 2>&1
__decline_status=$?
set -e
[[ "$__decline_status" -eq 0 ]] ||
    fail "declined confirmation exited with $__decline_status instead of 0; fzf=$(tail -10 "$__fzf_log"); tty=$(tail -10 "$__fixture_dir/tty.log")"
[[ -d "$__fixture_dir/declined" ]] || fail "declined confirmation removed a worktree"
grep -qF "Apply removal to " "$__fixture_dir/tty.log" ||
    fail "apply did not print the confirmation prompt"

local __toctou_status=0
set +e
run_task_tty y mutate-dirty >/dev/null 2>&1
__toctou_status=$?
set -e
[[ "$__toctou_status" -eq 0 ]] || fail "TOCTOU revalidation exited with $__toctou_status instead of 0"
[[ -d "$__fixture_dir/toctou" ]] || fail "TOCTOU revalidation removed a changed worktree"

local __preview_status=0
set +e
run_task_tty y preview-metachar >/dev/null 2>&1
__preview_status=$?
set -e
[[ "$__preview_status" -eq 0 ]] || fail "metacharacter preview selection exited with $__preview_status"
[[ ! -e "$__repository/fzf-pwned" ]] ||
    fail "metacharacter worktree path executed as preview shell syntax"
grep -qF "$__preview_path" "$__fzf_log" ||
    fail "preview stub did not receive the metacharacter worktree path"
grep -qF "printf '%bX' {s2}" "$__fzf_preview_log" ||
    fail "stale preview did not request lossless path placeholder expansion"

local __partial_status=0
set +e
run_task_tty y all "$__fixture_dir/second" >/dev/null 2>&1
__partial_status=$?
set -e
[[ "$__partial_status" -eq 1 ]] ||
    fail "partial failure exited with $__partial_status instead of 1; fail=$(cat "$__fixture_dir/fail-remove-path" 2>/dev/null || true); log=$(tail -20 "$__git_log"); tty=$(tail -20 "$__fixture_dir/tty.log")"
[[ ! -d "$__fixture_dir/first" ]] || fail "partial apply did not remove the successful worktree"
[[ -d "$__fixture_dir/second" ]] || fail "partial apply removed the failed worktree"
grep -qF "Failed:" "$__fixture_dir/tty.log" ||
    fail "partial apply did not report the failed removal"

rm -f "$__fixture_dir/fail-remove-path"
run_task_tty y sentinel >/dev/null 2>&1
[[ ! -d "$__fixture_dir/eligible" ]] || fail "sentinel selection did not remove an eligible worktree"
[[ -d "$__fixture_dir/dirty" ]] || fail "sentinel selection removed a quarantined worktree"
grep -qF $'ALL_STALE_WORKTREES\tALL_STALE_WORKTREES\t\t\tall eligible stale worktrees' "$__fzf_log" ||
    fail "FZF input did not contain the exact stale sentinel row"

: > "$__pitchfork_log"
create_registered release-failure
touch "$__fixture_dir/fail-release-write"
local __release_failure_status=0
set +e
run_task_tty y release-failure >/dev/null 2>&1
__release_failure_status=$?
set -e
[[ "$__release_failure_status" -eq 1 ]] ||
    fail "release-write failure exited with $__release_failure_status"
[[ ! -d "$__fixture_dir/release-failure" ]] ||
    fail "release-write failure did not preserve the successful Git removal"
grep -qF "Removed: $__fixture_dir/release-failure" "$__fixture_dir/tty.log" ||
    fail "release-write failure did not report the successful Git removal"
grep -qF "Failed to release metadata." "$__fixture_dir/tty.log" ||
    fail "release-write failure did not report the metadata failure"
grep -qF "failed to process 1 of 1 selected worktree(s); 1 release metadata update(s) failed." \
    "$__fixture_dir/tty.log" ||
    fail "release-write failure did not preserve partial-failure reporting"
local __release_failure_id="$(worktree_id "$__fixture_dir/release-failure")"
[[ "$("$__real_git" -C "$__repository" config --local \
    "worktree.cleanup.v1.$__release_failure_id.state")" == "active" ]] ||
    fail "release-write failure claimed released metadata"
[[ -z "$("$__real_git" -C "$__repository" config --local \
    --get "worktree.cleanup.v1.$__release_failure_id.releasedAt" 2>/dev/null || true)" ]] ||
    fail "release-write failure wrote a release timestamp"
grep -qF "clean --prune" "$__pitchfork_log" ||
    fail "release-write failure skipped Pitchfork cleanup after Git removal"
rm -f "$__fixture_dir/fail-release-write"

create_registered release-recovery
printf '%s\n' '.state' > "$__fixture_dir/fail-release-field"
local __release_recovery_status=0
set +e
run_task "" false false "$__fixture_dir/release-recovery" >"$__fixture_dir/release-recovery.out" 2>&1
__release_recovery_status=$?
set -e
[[ "$__release_recovery_status" -eq 1 ]] ||
    fail "failed release restore exited with $__release_recovery_status"
rm -f "$__fixture_dir/fail-release-field"
local __release_recovery_report="$(run_task "" false true)"
print -r -- "$__release_recovery_report" | grep -qF $'QUARANTINE\t'"$__fixture_dir/release-recovery"$'\t' ||
    fail "failed release restore was not quarantined"
print -r -- "$__release_recovery_report" | grep -qF "release metadata recovery required" ||
    fail "failed release restore did not report recovery"

local __noop_report="$(run_task "" false true "" empty)"
print -r -- "$__noop_report" | grep -qF "No stale worktrees found." ||
    fail "stale cleanup no-op did not report no stale worktrees"
if print -r -- "$__noop_report" | grep -qF "No eligible stale worktrees found:"; then
    fail "zero-row stale cleanup printed a quarantine/unknown summary"
fi

create_registered default-stale
: > "$__fzf_log"
local __default_stale_output="$__fixture_dir/default-stale.out"
run_task_tty y default-stale "" false
cp "$__fixture_dir/tty.log" "$__default_stale_output"
grep -qF $'All stale worktrees\tALL_STALE_WORKTREES\t' "$__fzf_log" ||
    fail "default delete menu did not contain the stale sentinel"
grep -qF $'All closed PRs\tALL_CLOSED_PRS\t' "$__fzf_log" ||
    fail "default delete menu dropped the closed-PR sentinel"
grep -qF $'default-stale\t'"$__fixture_dir/default-stale"$'\tdefault-stale' "$__fzf_log" ||
    fail "default delete menu did not contain regular worktree rows"
[[ "$(grep -c '^default-stale$' "$__fzf_log")" -eq 1 ]] ||
    fail "default stale selection opened a second FZF prompt"
local __default_report_line="$(grep -nF $'ELIGIBLE\t'"$__fixture_dir/default-stale"$'\t' "$__default_stale_output" |
    head -1 | cut -d: -f1)"
local __default_confirmation_line="$(grep -nF "Apply removal to 1 eligible worktree(s)?" "$__default_stale_output" |
    head -1 | cut -d: -f1)"
[[ -n "$__default_report_line" && -n "$__default_confirmation_line" &&
    "$__default_report_line" -lt "$__default_confirmation_line" ]] ||
    fail "default stale selection did not report before confirmation"
[[ ! -d "$__fixture_dir/default-stale" ]] ||
    fail "default stale selection did not remove the eligible worktree"
[[ ! -e "$__prune_log" ]] ||
    fail "default stale selection invoked git worktree prune"

local __lossless_alternate="$__fixture_dir/default-lossless"
local __lossless_path="$__fixture_dir/default-lossless "
"$__real_git" -C "$__repository" worktree add -q "$__lossless_alternate" -b default-lossless-alternate
"$__real_git" -C "$__repository" worktree add -q "$__lossless_path" -b default-lossless-space
: > "$__fzf_log"
local __lossless_output="$__fixture_dir/lossless-default.out"
run_task_tty y lossless-default "" false
cp "$__fixture_dir/tty.log" "$__lossless_output"
grep -qF $'default-lossless \t'"$__lossless_path"$'\tdefault-lossless-space' "$__fzf_log" ||
    fail "default deletion menu did not preserve the trailing-space path field"
grep -qF "Removed: $__lossless_path" "$__lossless_output" ||
    fail "default deletion menu did not report the exact trailing-space path"
grep -qF "$__lossless_path" "$__git_log" ||
    fail "default deletion menu did not pass the exact trailing-space path to Git"
[[ ! -d "$__lossless_path" ]] ||
    fail "default deletion menu did not remove the selected trailing-space worktree"
[[ -d "$__lossless_alternate" ]] ||
    fail "default deletion menu targeted the alternate path after trimming"

create_registered direct-stale
local __direct_stale_status=0
set +e
run_task "ALL_STALE_WORKTREES" true false "" "" false >"$__fixture_dir/direct-stale.out" 2>&1
__direct_stale_status=$?
set -e
[[ "$__direct_stale_status" -eq 2 ]] ||
    fail "direct stale sentinel apply exited with $__direct_stale_status instead of 2"
grep -qF "Stale worktree apply requires an interactive TTY." "$__fixture_dir/direct-stale.out" ||
    fail "direct stale sentinel did not use the stale apply flow"
[[ -d "$__fixture_dir/direct-stale" ]] ||
    fail "direct stale sentinel removed a worktree without an interactive TTY"

local __closed_pr_path="$__fixture_dir/closed-branch"
"$__real_git" -C "$__closed_pr_path" clean -fdq
: > "$__fzf_log"
run_task_tty y closed-sentinel "" false
grep -qF $'All stale worktrees\tALL_STALE_WORKTREES\t' "$__fzf_log" ||
    fail "closed-PR delete menu did not retain the stale sentinel"
grep -qF $'All closed PRs\tALL_CLOSED_PRS\t' "$__fzf_log" ||
    fail "closed-PR delete menu did not retain the closed-PR sentinel"
[[ ! -d "$__closed_pr_path" ]] ||
    fail "closed-PR sentinel selection did not remove the matching worktree"
[[ "$(grep -c '^closed-sentinel$' "$__fzf_log")" -eq 1 ]] ||
    fail "closed-PR sentinel selection opened an unexpected second FZF prompt"

local __closed_noop_report="$(GH_MODE=empty run_task "" false false "" "" true)"
print -r -- "$__closed_noop_report" | grep -qF "No closed-PR worktrees found." ||
    fail "closed-PR no-op did not report the required message"

local __closed_unknown="$__fixture_dir/pr-11"
"$__real_git" -C "$__repository" worktree add -q "$__closed_unknown" -b pr-11
local __closed_quarantine_report="$__fixture_dir/closed-discovery-error.out"
local __closed_quarantine_status=0
set +e
GH_MODE=unavailable run_task "" false false "" "" true >"$__closed_quarantine_report" 2>&1
__closed_quarantine_status=$?
set -e
[[ "$__closed_quarantine_status" -eq 1 ]] ||
    fail "closed-PR discovery failure exited with $__closed_quarantine_status"
grep -qF "GitHub pull request discovery failed" "$__closed_quarantine_report" ||
    fail "closed-PR discovery failure was hidden by no-hints handling"

grep -qF "clean --prune" "$__pitchfork_log" ||
    fail "successful stale removal did not clean Pitchfork registrations"
rm -f "$__fixture_dir/fail-remove-path"

while IFS= read -r __task_cwd; do
    [[ "$__task_cwd" == "$__fixture_dir" || "$__task_cwd" == "$__fixture_dir"/* ]] ||
        fail "a task invocation used a non-fixture repository cwd: $__task_cwd"
done < "$__task_cwd_log"
while IFS=$'\t' read -r __logged_git_cwd __git_command __extra; do
    [[ -n "$__logged_git_cwd" && -n "$__git_command" && -z "$__extra" ]] ||
        fail "malformed Git command log entry"
    [[ "$__logged_git_cwd" == "$__fixture_dir" || "$__logged_git_cwd" == "$__fixture_dir"/* ]] ||
        fail "a logged Git working directory escaped the fixture: $__logged_git_cwd"
done < "$__git_log"
[[ -s "$__git_path_log" ]] || fail "git path ownership log is empty"
while IFS=$'\t' read -r __path_kind __logged_path __extra; do
    [[ -n "$__path_kind" && -n "$__logged_path" && -z "$__extra" ]] ||
        fail "malformed git path ownership log entry"
    [[ "$__path_kind" == cwd || "$__path_kind" == path ]] ||
        fail "unknown git path ownership log entry: $__path_kind"
    [[ "$__logged_path" == "$__fixture_dir" || "$__logged_path" == "$__fixture_dir"/* ]] ||
        fail "a logged Git path escaped the fixture: $__logged_path"
done < "$__git_path_log"

echo "git:worktree stale cleanup passed."
