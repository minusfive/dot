#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

local __fixture_dir=""
local __system_temp_dir=""
__fixture_dir="$(mktemp -d)" || exit 1
[[ -n "$__fixture_dir" ]] || exit 1
__fixture_dir="$(realpath "$__fixture_dir")" || exit 1
[[ -n "${TMPDIR:-}" ]] || exit 1
__system_temp_dir="$(realpath "$TMPDIR")" || exit 1
[[ -n "$__system_temp_dir" && -d "$__system_temp_dir" &&
    "$__fixture_dir" == "$__system_temp_dir"/* &&
    "$__fixture_dir" != "$__system_temp_dir" ]] || exit 1
local __bin_dir="$__fixture_dir/bin"
local __shadow_bin_dir="$__fixture_dir/shadow-bin"
local __osascript_executable="$__bin_dir/osascript"
local __state_home="$__fixture_dir/state"
local __log_file="$__fixture_dir/commands.log"
local __process_state="$__fixture_dir/process.state"
local __backup_complete_marker="$__fixture_dir/backup-complete"
local __source_mutation_marker="$__fixture_dir/source-mutation"
local __task_export="$__fixture_dir/scripts/tasks/betterdisplay/settings/export.zsh"
local __task_import="$__fixture_dir/scripts/tasks/betterdisplay/settings/import.zsh"
local __tracked_plist="$__fixture_dir/home/.config/BetterDisplay/config.plist"
local __mise_bin="$(command -v mise)"

__fixture_cleanup_is_safe() {
    local __canonical_fixture_dir=""
    [[ -n "$__fixture_dir" && -n "$__system_temp_dir" ]] || return 1
    [[ -d "$__fixture_dir" ]] || return 1
    __canonical_fixture_dir="$(realpath "$__fixture_dir")" || return 1
    [[ "$__canonical_fixture_dir" == "$__fixture_dir" ]] || return 1
    [[ "$__fixture_dir" == "$__system_temp_dir"/* &&
        "$__fixture_dir" != "$__system_temp_dir" ]]
}

__fixture_temp_plist_exists() {
    [[ -d "$__fixture_dir/home/.config/BetterDisplay" ]] &&
        find "$__fixture_dir/home/.config/BetterDisplay" \
            -maxdepth 1 -name '.config.plist.*' -type f -print -quit |
        grep -q .
}

__fixture_backup_file_exists() {
    [[ -d "$__state_home/minusfive" ]] &&
        find "$__state_home/minusfive" -type f -print -quit |
        grep -q .
}

__fixture_marker_exists() {
    [[ -e "$__backup_complete_marker" ||
        -e "$__source_mutation_marker" ||
        -e "$__fixture_dir/osascript.pid" ]]
}

__fixture_osascript_pid_matches() {
    local __pid="$1"
    local __command=""
    __command="$(/bin/ps -p "$__pid" -o command= 2>/dev/null)" || return 1
    [[ "$__command" == "$__osascript_executable" ||
        "$__command" == "$__osascript_executable "* ||
        "$__command" == *" $__osascript_executable" ||
        "$__command" == *" $__osascript_executable "* ]]
}

__cleanup_fixture() {
    local __pid=""
    local __cleanup_status=0
    __fixture_cleanup_is_safe || return 0
    if [[ -r "$__fixture_dir/osascript.pid" ]]; then
        __pid="$(<"$__fixture_dir/osascript.pid")"
        if [[ "$__pid" == <-> ]]; then
            if __fixture_osascript_pid_matches "$__pid"; then
                if kill -0 "$__pid" 2>/dev/null; then
                    kill -TERM "$__pid" 2>/dev/null || true
                    wait "$__pid" 2>/dev/null || true
                fi
                if kill -0 "$__pid" 2>/dev/null; then
                    kill -KILL "$__pid" 2>/dev/null || true
                    wait "$__pid" 2>/dev/null || true
                fi
                if kill -0 "$__pid" 2>/dev/null; then
                    print -u2 -- "FAIL: fixture osascript PID remained after cleanup: $__pid"
                    __cleanup_status=1
                fi
            else
                print -u2 -- "WARN: stale fixture osascript PID not signaled: $__pid"
            fi
        fi
    fi
    if __fixture_temp_plist_exists; then
        print -u2 -- "FAIL: fixture export temporary file remained after cleanup"
        __cleanup_status=1
    fi
    if __fixture_backup_file_exists; then
        print -u2 -- "FAIL: fixture backup or state file remained after cleanup"
        __cleanup_status=1
    fi
    if __fixture_marker_exists; then
        print -u2 -- "FAIL: fixture task marker remained after cleanup"
        __cleanup_status=1
    fi
    if [[ -d "$__fixture_dir/home/.config/BetterDisplay" ]]; then
        find "$__fixture_dir/home/.config/BetterDisplay" \
            -maxdepth 1 -name '.config.plist.*' -type f -delete ||
            __cleanup_status=1
    fi
    if [[ -d "$__state_home/minusfive" ]]; then
        rm -rf -- "$__state_home/minusfive" || __cleanup_status=1
    fi
    rm -f -- \
        "$__backup_complete_marker" \
        "$__source_mutation_marker" || __cleanup_status=1
    __fixture_cleanup_is_safe || return "$__cleanup_status"
    rm -rf -- "$__fixture_dir"
    return "$__cleanup_status"
}

trap __cleanup_fixture EXIT

mkdir -p \
    "$__bin_dir" \
    "$__shadow_bin_dir" \
    "$__fixture_dir/empty" \
    "$__state_home" \
    "$__fixture_dir/scripts/tasks/betterdisplay/settings" \
    "$__fixture_dir/scripts/utils" \
    "$__fixture_dir/home/.config/BetterDisplay" \
    "$__fixture_dir/.mise/conf.d"
cp scripts/utils/filesystem.zsh "$__fixture_dir/scripts/utils/filesystem.zsh"
cp scripts/utils/application.zsh "$__fixture_dir/scripts/utils/application.zsh"
cp scripts/tasks/betterdisplay/settings/export.zsh "$__task_export"
cp scripts/tasks/betterdisplay/settings/import.zsh "$__task_import"
cp .mise/conf.d/tasks.toml "$__fixture_dir/.mise/conf.d/tasks.toml"
print -r -- "valid" >| "$__tracked_plist"
: >| "$__log_file"

cat > "$__bin_dir/defaults" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "$*" >> "$BETTERDISPLAY_COMMAND_LOG"
case "$1" in
    export)
        if [[ "${BETTERDISPLAY_ASSERT_STOPPED_COMMANDS:-no}" == "yes" ]]; then
            local __process_state_snapshot="$(<"$BETTERDISPLAY_PROCESS_STATE")"
            print -r -- "backup export observed $__process_state_snapshot" >> "$BETTERDISPLAY_COMMAND_LOG"
            [[ "$__process_state_snapshot" == "stopped" ]] || exit 1
        fi
        print -r -- "${BETTERDISPLAY_EXPORT_CONTENT:-backup}" >| "$3"
        if [[ ! -e "${BETTERDISPLAY_SOURCE_MUTATION_MARKER:-}" &&
            "${BETTERDISPLAY_STAT_FLIP:-no}" == "yes" ]]; then
            print -r -- "mutated" >| "$BETTERDISPLAY_TRACKED_PLIST"
            : >| "$BETTERDISPLAY_SOURCE_MUTATION_MARKER"
            print -r -- "source mutation" >> "$BETTERDISPLAY_COMMAND_LOG"
        fi
        [[ "${BETTERDISPLAY_EXPORT_STATUS:-ok}" == "ok" ]] || exit 1
        ;;
    import)
        if [[ "${BETTERDISPLAY_ASSERT_STOPPED_COMMANDS:-no}" == "yes" ]]; then
            local __process_state_snapshot="$(<"$BETTERDISPLAY_PROCESS_STATE")"
            print -r -- "import observed $__process_state_snapshot" >> "$BETTERDISPLAY_COMMAND_LOG"
            [[ "$__process_state_snapshot" == "stopped" ]] || exit 1
        fi
        [[ "${BETTERDISPLAY_IMPORT_STATUS:-ok}" == "ok" ]] || exit 1
        ;;
esac
EOF

cat > "$__bin_dir/plutil" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

[[ "${BETTERDISPLAY_PLUTIL_STATUS:-ok}" == "ok" ]] || exit 1
local __plist="$2"
[[ -f "$__plist" ]] || exit 1
if grep -qF invalid "$__plist"; then
    exit 1
fi
if [[ "$__plist" == "$BETTERDISPLAY_BACKUP_DIR"/BetterDisplay-live.plist.* &&
    "${BETTERDISPLAY_EXPORT_STATUS:-ok}" == "ok" ]]; then
    print -r -- "backup validated" >> "$BETTERDISPLAY_COMMAND_LOG"
    : >| "$BETTERDISPLAY_BACKUP_COMPLETE_MARKER"
    print -r -- "backup complete" >> "$BETTERDISPLAY_COMMAND_LOG"
    if [[ ! -e "${BETTERDISPLAY_SOURCE_MUTATION_MARKER:-}" &&
        "${BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP:-no}" == "yes" ]]; then
        print -r -- "mutated" >| "$BETTERDISPLAY_TRACKED_PLIST"
        : >| "$BETTERDISPLAY_SOURCE_MUTATION_MARKER"
        print -r -- "source mutation" >> "$BETTERDISPLAY_COMMAND_LOG"
    fi
fi
exit 0
EOF

cat > "$__bin_dir/cmp" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

if [[ "${BETTERDISPLAY_CMP_STATUS:-ok}" == "error" ]]; then
    exit 2
fi

exec /usr/bin/cmp "$@"
EOF

cat > "$__bin_dir/mktemp" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

local __template="$1"
local __file="${__template//XXXXXX/fixture.$$}"
print -r -- "$__template" >> "$BETTERDISPLAY_COMMAND_LOG"
: >| "$__file"
print -r -- "$__file"
[[ "${BETTERDISPLAY_MKTEMP_STATUS:-ok}" == "ok" ]] || exit 1
EOF

cat > "$__bin_dir/mv" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "mv $*" >> "$BETTERDISPLAY_COMMAND_LOG"
exec /bin/mv "$@"
EOF

cat > "$__bin_dir/pgrep" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

[[ "$(cat "$BETTERDISPLAY_PROCESS_STATE")" == "running" ]]
EOF

cat > "$__bin_dir/osascript" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "osascript $*" >> "$BETTERDISPLAY_COMMAND_LOG"
print -r -- "osascript quit requested" >> "$BETTERDISPLAY_COMMAND_LOG"
if [[ "${BETTERDISPLAY_OSASCRIPT_STATUS:-ok}" != "ok" ]]; then
    if [[ "${BETTERDISPLAY_OSASCRIPT_EXIT_BEFORE_ERROR:-no}" == "yes" ]]; then
        print -r -- "stopped" >| "$BETTERDISPLAY_PROCESS_STATE"
        print -r -- "process stopped" >> "$BETTERDISPLAY_COMMAND_LOG"
    fi
    exit 1
fi
if [[ "${BETTERDISPLAY_OSASCRIPT_HANG:-no}" == "yes" ]]; then
    print -r -- "$$" >| "$BETTERDISPLAY_OSASCRIPT_PID_FILE"
    trap '' TERM
    while true; do :; done
fi
[[ "${BETTERDISPLAY_OSASCRIPT_KEEP_RUNNING:-no}" == "yes" ]] ||
    {
        print -r -- "stopped" >| "$BETTERDISPLAY_PROCESS_STATE"
        print -r -- "process stopped" >> "$BETTERDISPLAY_COMMAND_LOG"
    }
EOF

cat > "$__bin_dir/open" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "open $*" >> "$BETTERDISPLAY_COMMAND_LOG"
[[ "${BETTERDISPLAY_OPEN_STATUS:-ok}" == "ok" ]] || exit 1
[[ "${BETTERDISPLAY_OPEN_LEAVE_STOPPED:-no}" == "yes" ]] ||
    print -r -- "running" >| "$BETTERDISPLAY_PROCESS_STATE"
EOF

cat > "$__bin_dir/sleep" <<'EOF'
#!/usr/bin/env zsh
exit 0
EOF

cat > "$__bin_dir/stat" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

local __count_file="${BETTERDISPLAY_STAT_COUNT_FILE}"
local __count=0
if [[ -f "$__count_file" ]]; then
    __count="$(<"$__count_file")"
fi
(( __count += 1 ))
print -r -- "$__count" >| "$__count_file"
local __flip_after="${BETTERDISPLAY_STAT_FLIP_AFTER:-1}"
if [[ ! -e "${BETTERDISPLAY_SOURCE_MUTATION_MARKER:-}" &&
    ( ( -e "${BETTERDISPLAY_BACKUP_COMPLETE_MARKER:-}" &&
        "${BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP:-no}" == "yes" ) ||
        ( "${BETTERDISPLAY_STAT_FLIP:-no}" == "yes" && "$__count" -gt "$__flip_after" ) ) ]]; then
    print -r -- "mutated" >| "$BETTERDISPLAY_TRACKED_PLIST"
    : >| "$BETTERDISPLAY_SOURCE_MUTATION_MARKER"
    print -r -- "source mutation" >> "$BETTERDISPLAY_COMMAND_LOG"
fi
exec /usr/bin/stat "$@"
EOF

cat > "$__shadow_bin_dir/stat" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "shadow stat invoked" >> "$BETTERDISPLAY_STAT_SHADOW_LOG"
exit 97
EOF

cat > "$__bin_dir/git" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "$*" >> "$BETTERDISPLAY_GIT_LOG"
exit 99
EOF

chmod +x "$__bin_dir"/*
chmod +x "$__shadow_bin_dir/stat"

run_task() {
    local __task="$1"
    shift
    local __path="${BETTERDISPLAY_TEST_PATH:-$__bin_dir:/usr/bin:/bin}"
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_TASK_NAME \
        HOME="$__fixture_dir/home" \
        ZDOTDIR="$__fixture_dir/empty" \
        PATH="$__path" \
        MISE_PROJECT_ROOT="$__fixture_dir" \
        XDG_STATE_HOME="$__state_home" \
        BETTERDISPLAY_COMMAND_LOG="$__log_file" \
        BETTERDISPLAY_GIT_LOG="$__fixture_dir/git.log" \
        BETTERDISPLAY_PROCESS_STATE="$__process_state" \
        BETTERDISPLAY_BACKUP_COMPLETE_MARKER="$__backup_complete_marker" \
        BETTERDISPLAY_SOURCE_MUTATION_MARKER="$__source_mutation_marker" \
        BETTERDISPLAY_BACKUP_DIR="$__state_home/minusfive/BetterDisplay/backups" \
        BETTERDISPLAY_TRACKED_PLIST="$__tracked_plist" \
        BETTERDISPLAY_ASSERT_STOPPED_COMMANDS="${BETTERDISPLAY_ASSERT_STOPPED_COMMANDS:-no}" \
        BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP="${BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP:-no}" \
        BETTERDISPLAY_STAT_COUNT_FILE="$__fixture_dir/stat.count" \
        BETTERDISPLAY_STAT_SHADOW_LOG="$__fixture_dir/stat-shadow.log" \
        BETTERDISPLAY_OSASCRIPT_PID_FILE="$__fixture_dir/osascript.pid" \
        "$@" /bin/zsh "$__task"
}

run_mise_task() {
    local __task="$1"
    shift
    local __path="${BETTERDISPLAY_TEST_PATH:-$__bin_dir:/usr/bin:/bin}"
    env -u MISE_ENV -u MISE_AUTO_ENV -u MISE_TASK_NAME \
        HOME="$__fixture_dir/home" \
        ZDOTDIR="$__fixture_dir/empty" \
        PATH="$__path" \
        MISE_PROJECT_ROOT="$__fixture_dir" \
        MISE_CONFIG_DIR="$__fixture_dir/mise-config" \
        MISE_ENV_CONF_D=true \
        XDG_STATE_HOME="$__state_home" \
        BETTERDISPLAY_COMMAND_LOG="$__log_file" \
        BETTERDISPLAY_GIT_LOG="$__fixture_dir/git.log" \
        BETTERDISPLAY_PROCESS_STATE="$__process_state" \
        BETTERDISPLAY_BACKUP_COMPLETE_MARKER="$__backup_complete_marker" \
        BETTERDISPLAY_SOURCE_MUTATION_MARKER="$__source_mutation_marker" \
        BETTERDISPLAY_BACKUP_DIR="$__state_home/minusfive/BetterDisplay/backups" \
        BETTERDISPLAY_TRACKED_PLIST="$__tracked_plist" \
        BETTERDISPLAY_ASSERT_STOPPED_COMMANDS="${BETTERDISPLAY_ASSERT_STOPPED_COMMANDS:-no}" \
        BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP="${BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP:-no}" \
        BETTERDISPLAY_STAT_COUNT_FILE="$__fixture_dir/stat.count" \
        BETTERDISPLAY_STAT_SHADOW_LOG="$__fixture_dir/stat-shadow.log" \
        BETTERDISPLAY_OSASCRIPT_PID_FILE="$__fixture_dir/osascript.pid" \
        "$@" "$__mise_bin" -C "$__fixture_dir" run --yes "$__task"
}

reset_fixture() {
    local __recorded_pid=""
    local __had_temp_plist=0
    local __had_backup_file=0
    local __had_marker=0
    if [[ -r "$__fixture_dir/osascript.pid" ]]; then
        __recorded_pid="$(<"$__fixture_dir/osascript.pid")"
        if [[ "$__recorded_pid" == <-> ]]; then
            if __fixture_osascript_pid_matches "$__recorded_pid"; then
                if kill -0 "$__recorded_pid" 2>/dev/null; then
                    fail "fixture osascript PID remained before reset: $__recorded_pid"
                fi
            else
                print -u2 -- "WARN: stale fixture osascript PID ignored before reset: $__recorded_pid"
            fi
        fi
    fi
    if __fixture_temp_plist_exists; then
        __had_temp_plist=1
    fi
    if __fixture_backup_file_exists; then
        __had_backup_file=1
    fi
    if __fixture_marker_exists; then
        __had_marker=1
    fi
    print -r -- "valid" >| "$__tracked_plist"
    print -r -- "stopped" >| "$__process_state"
    : >| "$__log_file"
    rm -f \
        "$__backup_complete_marker" \
        "$__source_mutation_marker" \
        "$__fixture_dir/stat.count" \
        "$__fixture_dir/git.log" \
        "$__fixture_dir/osascript.pid"
    if [[ -d "$__fixture_dir/home/.config/BetterDisplay" ]]; then
        find "$__fixture_dir/home/.config/BetterDisplay" \
            -maxdepth 1 -name '.config.plist.*' -type f -delete
    fi
    if [[ -d "$__state_home/minusfive" ]]; then
        rm -rf -- "$__state_home/minusfive"
    fi
    if (( __had_temp_plist )) && __fixture_temp_plist_exists; then
        fail "fixture export temporary file remained after reset"
    fi
    if (( __had_backup_file )) && __fixture_backup_file_exists; then
        fail "fixture backup or state file remained after reset"
    fi
    if (( __had_marker )) && __fixture_marker_exists; then
        fail "fixture task marker remained after reset"
    fi
}

reset_fixture
run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=valid >| "$__fixture_dir/output"
grep -qF "unchanged" "$__fixture_dir/output" || fail "unchanged export was not reported"
[[ "$(cat "$__tracked_plist")" == "valid" ]] || fail "unchanged export changed the tracked plist"
if grep -q '^mv ' "$__log_file"; then
    fail "unchanged export replaced the tracked plist"
fi

reset_fixture
run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output"
[[ "$(cat "$__tracked_plist")" == "changed" ]] || fail "changed export did not replace the tracked plist"
grep -qF "mv " "$__log_file" || fail "changed export did not move the temporary plist"
grep -qF "$__fixture_dir/home/.config/BetterDisplay/.config.plist." "$__log_file" ||
    fail "export temporary file was not beside the tracked plist"

reset_fixture
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=invalid >| "$__fixture_dir/output" 2>&1; then
    fail "invalid export output was accepted"
fi
[[ "$(cat "$__tracked_plist")" == "valid" ]] || fail "invalid export changed the tracked plist"

reset_fixture
if run_task "$__task_export" \
    BETTERDISPLAY_CMP_STATUS=error \
    BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "comparison command failure was accepted"
fi
[[ "$(cat "$__tracked_plist")" == "valid" ]] || fail "comparison command failure changed the tracked plist"
if grep -q '^mv ' "$__log_file"; then
    fail "comparison command failure replaced the tracked plist"
fi
if find "$__fixture_dir/home/.config/BetterDisplay" -name '.config.plist.*' -print -quit | grep -q .; then
    fail "comparison command failure retained the temporary plist"
fi
grep -qF "Could not compare exported BetterDisplay settings." "$__fixture_dir/output" ||
    fail "comparison command failure was not reported"

reset_fixture
if run_task "$__task_export" \
    BETTERDISPLAY_EXPORT_CONTENT=changed \
    BETTERDISPLAY_STAT_FLIP=yes >| "$__fixture_dir/output" 2>&1; then
    fail "tracked-source identity change was accepted"
fi
[[ "$(cat "$__tracked_plist")" == "mutated" ]] ||
    fail "tracked-source identity change did not record the real mutation"
if grep -q '^mv ' "$__log_file"; then
    fail "tracked-source identity change replaced the tracked plist"
fi
if find "$__fixture_dir/home/.config/BetterDisplay" -name '.config.plist.*' -print -quit | grep -q .; then
    fail "tracked-source identity change retained the temporary plist"
fi
grep -qF "Tracked BetterDisplay plist changed during export." "$__fixture_dir/output" ||
    fail "tracked-source identity change was not reported"

reset_fixture
print -r -- invalid >| "$__tracked_plist"
if run_task "$__task_import" >| "$__fixture_dir/output" 2>&1; then
    fail "invalid tracked source was accepted"
fi
if grep -qE 'osascript|defaults' "$__log_file"; then
    fail "invalid tracked source reached BetterDisplay commands"
fi

reset_fixture
mv "$__fixture_dir/scripts/utils/filesystem.zsh" \
    "$__fixture_dir/scripts/utils/filesystem.real.zsh"
ln -s filesystem.real.zsh "$__fixture_dir/scripts/utils/filesystem.zsh"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "export accepted a symlinked filesystem utility"
fi
if grep -qE 'defaults|osascript' "$__log_file"; then
    fail "export accessed BetterDisplay after a symlinked filesystem utility"
fi
rm "$__fixture_dir/scripts/utils/filesystem.zsh"
mv "$__fixture_dir/scripts/utils/filesystem.real.zsh" \
    "$__fixture_dir/scripts/utils/filesystem.zsh"

reset_fixture
mv "$__fixture_dir/scripts/utils" "$__fixture_dir/scripts/utils.real"
ln -s utils.real "$__fixture_dir/scripts/utils"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "export accepted a symlinked filesystem utility parent"
fi
if grep -qE 'defaults|osascript' "$__log_file"; then
    fail "export accessed BetterDisplay after a symlinked filesystem utility parent"
fi
rm "$__fixture_dir/scripts/utils"
mv "$__fixture_dir/scripts/utils.real" "$__fixture_dir/scripts/utils"

reset_fixture
mv "$__tracked_plist" "$__fixture_dir/home/.config/BetterDisplay/config.real.plist"
ln -s config.real.plist "$__tracked_plist"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "symlinked tracked plist was accepted"
fi
rm "$__tracked_plist"
mv "$__fixture_dir/home/.config/BetterDisplay/config.real.plist" "$__tracked_plist"

reset_fixture
mv "$__fixture_dir/scripts/utils/application.zsh" \
    "$__fixture_dir/scripts/utils/application.real.zsh"
ln -s application.real.zsh "$__fixture_dir/scripts/utils/application.zsh"
if run_task "$__task_import" >| "$__fixture_dir/output" 2>&1; then
    fail "import accepted a symlinked application utility"
fi
if grep -qE 'osascript|defaults' "$__log_file"; then
    fail "import accessed BetterDisplay after a symlinked application utility"
fi
rm "$__fixture_dir/scripts/utils/application.zsh"
mv "$__fixture_dir/scripts/utils/application.real.zsh" \
    "$__fixture_dir/scripts/utils/application.zsh"

reset_fixture
print -r -- "running" >| "$__process_state"
run_task "$__task_import" \
    BETTERDISPLAY_ASSERT_STOPPED_COMMANDS=yes \
    BETTERDISPLAY_EXPORT_CONTENT=backup
[[ "$(cat "$__process_state")" == "running" ]] || fail "running application was not restarted"
local __backup_file="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__backup_file" ]] || fail "live backup was not saved"
[[ -e "$__backup_complete_marker" ]] || fail "backup completion marker was not written"
local __stop_marker='osascript -e with timeout of 10 seconds -e tell application "BetterDisplay" to quit -e end timeout'
local __export_marker="export pro.betterdisplay.BetterDisplay $__backup_file"
local __import_marker="import pro.betterdisplay.BetterDisplay $__tracked_plist"
local __open_marker="open -a BetterDisplay"
local __stop_line="$(grep -nF -- "$__stop_marker" "$__log_file" | cut -d: -f1 || true)"
local __quit_requested_line="$(grep -nF -- "osascript quit requested" "$__log_file" | cut -d: -f1 || true)"
local __process_stopped_line="$(grep -nF -- "process stopped" "$__log_file" | cut -d: -f1 || true)"
local __export_line="$(grep -nF -- "$__export_marker" "$__log_file" | cut -d: -f1 || true)"
local __export_observed_line="$(grep -nF -- "backup export observed stopped" "$__log_file" | cut -d: -f1 || true)"
local __backup_validated_line="$(grep -nF -- "backup validated" "$__log_file" | cut -d: -f1 || true)"
local __backup_complete_line="$(grep -nF -- "backup complete" "$__log_file" | cut -d: -f1 || true)"
local __import_line="$(grep -nF -- "$__import_marker" "$__log_file" | cut -d: -f1 || true)"
local __import_observed_line="$(grep -nF -- "import observed stopped" "$__log_file" | cut -d: -f1 || true)"
local __open_line="$(grep -nF -- "$__open_marker" "$__log_file" | cut -d: -f1 || true)"
[[ "$__quit_requested_line" == <-> ]] || fail "BetterDisplay quit request was not logged"
[[ "$__stop_line" == <-> ]] || fail "BetterDisplay stop was not logged with the bounded osascript command"
[[ "$__process_stopped_line" == <-> ]] || fail "BetterDisplay stopped state transition was not logged"
[[ "$__export_line" == <-> ]] || fail "live backup export was not logged exactly"
[[ "$__export_observed_line" == <-> ]] || fail "backup export did not observe the stopped state"
[[ "$__backup_validated_line" == <-> ]] || fail "live backup validation was not logged"
[[ "$__backup_complete_line" == <-> ]] || fail "backup completion was not logged"
[[ "$__import_line" == <-> ]] || fail "tracked settings import was not logged exactly"
[[ "$__import_observed_line" == <-> ]] || fail "import did not observe the stopped state"
[[ "$__open_line" == <-> ]] || fail "running application restart was not logged exactly"
if ! (( __stop_line < __quit_requested_line &&
    __quit_requested_line < __process_stopped_line &&
    __process_stopped_line < __export_line &&
    __export_line < __export_observed_line &&
    __export_observed_line < __backup_validated_line &&
    __backup_validated_line < __backup_complete_line &&
    __backup_complete_line < __import_line &&
    __import_line < __import_observed_line &&
    __import_observed_line < __open_line )); then
    fail "BetterDisplay quit, stop, backup, import, and restart events were logged out of order"
fi

reset_fixture
BETTERDISPLAY_TEST_PATH="$__shadow_bin_dir:$__bin_dir:/usr/bin:/bin" \
    run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=valid >| "$__fixture_dir/output"
grep -qF "unchanged" "$__fixture_dir/output" ||
    fail "export did not pass with a failing shadow stat earlier in PATH"
[[ ! -e "$__fixture_dir/stat-shadow.log" ]] ||
    fail "export used the shadow stat instead of /usr/bin/stat"

reset_fixture
BETTERDISPLAY_TEST_PATH="$__shadow_bin_dir:$__bin_dir:/usr/bin:/bin" \
    run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=backup >| "$__fixture_dir/output"
grep -qF "settings imported" "$__fixture_dir/output" ||
    fail "import did not pass with a failing shadow stat earlier in PATH"
[[ ! -e "$__fixture_dir/stat-shadow.log" ]] ||
    fail "import used the shadow stat instead of /usr/bin/stat"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" \
    BETTERDISPLAY_ASSERT_STOPPED_COMMANDS=yes \
    BETTERDISPLAY_IDENTITY_CHANGES_AFTER_BACKUP=yes >| "$__fixture_dir/output" 2>&1; then
    fail "identity change after stop and backup was accepted"
fi
[[ "$(cat "$__process_state")" == "running" ]] ||
    fail "identity-change recovery did not restore the previously running application"
local __identity_backup_file="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__identity_backup_file" ]] ||
    fail "identity-change scenario did not create a live backup"
[[ -e "$__backup_complete_marker" ]] ||
    fail "identity-change scenario did not write the backup completion marker"
[[ -e "$__source_mutation_marker" ]] ||
    fail "identity-change scenario did not write the source mutation marker"
[[ "$(cat "$__tracked_plist")" == "mutated" ]] ||
    fail "identity-change scenario did not mutate the tracked plist"
[[ "$(grep -cF "source mutation" "$__log_file")" == 1 ]] ||
    fail "identity-change scenario recorded more than one source mutation"
grep -qF "Backup: $__identity_backup_file" "$__fixture_dir/output" ||
    fail "identity-change backup path was not reported"
grep -qF "BetterDisplay was restarted." "$__fixture_dir/output" ||
    fail "identity-change recovery did not report the restored running state"
if grep -qF "import pro.betterdisplay.BetterDisplay " "$__log_file"; then
    fail "identity-change scenario imported settings after the source changed"
fi
local __identity_quit_requested_line="$(grep -nF -- "osascript quit requested" "$__log_file" | cut -d: -f1 || true)"
local __identity_stop_line="$(grep -nF -- "$__stop_marker" "$__log_file" | cut -d: -f1 || true)"
local __identity_process_stopped_line="$(grep -nF -- "process stopped" "$__log_file" | cut -d: -f1 || true)"
local __identity_export_marker="export pro.betterdisplay.BetterDisplay $__identity_backup_file"
local __identity_export_line="$(grep -nF -- "$__identity_export_marker" "$__log_file" | cut -d: -f1 || true)"
local __identity_export_observed_line="$(grep -nF -- "backup export observed stopped" "$__log_file" | cut -d: -f1 || true)"
local __identity_backup_validated_line="$(grep -nF -- "backup validated" "$__log_file" | cut -d: -f1 || true)"
local __identity_backup_complete_line="$(grep -nF -- "backup complete" "$__log_file" | cut -d: -f1 || true)"
local __identity_source_mutation_line="$(grep -nF -- "source mutation" "$__log_file" | cut -d: -f1 || true)"
local __identity_open_line="$(grep -nF -- "$__open_marker" "$__log_file" | cut -d: -f1 || true)"
[[ "$__identity_quit_requested_line" == <-> ]] || fail "identity-change scenario did not request BetterDisplay stop"
[[ "$__identity_stop_line" == <-> ]] || fail "identity-change scenario did not log the bounded stop command"
[[ "$__identity_process_stopped_line" == <-> ]] || fail "identity-change scenario did not stop BetterDisplay"
[[ "$__identity_export_line" == <-> ]] || fail "identity-change scenario did not log the live backup export"
[[ "$__identity_export_observed_line" == <-> ]] || fail "identity-change backup did not observe the stopped state"
[[ "$__identity_backup_validated_line" == <-> ]] || fail "identity-change backup validation was not logged"
[[ "$__identity_backup_complete_line" == <-> ]] || fail "identity-change scenario did not complete the live backup"
[[ "$__identity_source_mutation_line" == <-> ]] || fail "identity-change scenario did not record source mutation"
[[ "$__identity_open_line" == <-> ]] || fail "identity-change scenario did not log recovery restart"
if ! (( __identity_stop_line < __identity_quit_requested_line &&
    __identity_quit_requested_line < __identity_process_stopped_line &&
    __identity_process_stopped_line < __identity_export_line &&
    __identity_export_line < __identity_export_observed_line &&
    __identity_export_observed_line < __identity_backup_validated_line &&
    __identity_backup_validated_line < __identity_backup_complete_line &&
    __identity_backup_complete_line < __identity_source_mutation_line &&
    __identity_source_mutation_line < __identity_open_line )); then
    fail "identity-change stop, backup, source mutation, and recovery restart were logged out of order"
fi

reset_fixture
run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=backup
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "stopped application was started after successful import"
if grep -qF "open " "$__log_file"; then
    fail "stopped application was restarted"
fi

reset_fixture
local __mise_import_output=""
if ! __mise_import_output="$(
    run_mise_task betterdisplay:settings:import BETTERDISPLAY_EXPORT_CONTENT=backup 2>&1
)"; then
    print -u2 -- "$__mise_import_output"
    fail "successful mise import was rejected"
fi
grep -qF "BetterDisplay settings imported." <<< "$__mise_import_output" ||
    fail "mise import did not execute the task body"
local __mise_backup_file="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__mise_backup_file" ]] || fail "mise import did not create a live backup"
[[ -e "$__backup_complete_marker" ]] ||
    fail "mise import did not validate the live backup"
grep -qF "import pro.betterdisplay.BetterDisplay $__tracked_plist" "$__log_file" ||
    fail "mise import did not import the tracked settings"
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "mise import changed the stopped fixture state"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" \
    BETTERDISPLAY_EXPORT_STATUS=fail \
    BETTERDISPLAY_EXPORT_CONTENT=invalid >| "$__fixture_dir/output" 2>&1; then
    fail "backup failure was accepted"
fi
[[ "$(cat "$__process_state")" == "running" ]] || fail "backup failure did not restore the running application"
if grep -qF "import" "$__log_file"; then
    fail "import ran after backup failure"
fi
if find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit 2>/dev/null | grep -q .; then
    fail "failed invalid backup was not removed"
fi
[[ ! -e "$__backup_complete_marker" ]] ||
    fail "invalid backup incorrectly recorded completion"

reset_fixture
if run_task "$__task_import" \
    BETTERDISPLAY_EXPORT_STATUS=fail \
    BETTERDISPLAY_EXPORT_CONTENT=invalid >| "$__fixture_dir/output" 2>&1; then
    fail "stopped-app backup failure was accepted"
fi
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "stopped application changed state after backup failure"
if grep -qF "open " "$__log_file"; then
    fail "stopped application was restarted after backup failure"
fi
[[ ! -e "$__backup_complete_marker" ]] ||
    fail "stopped invalid backup incorrectly recorded completion"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" \
    BETTERDISPLAY_EXPORT_STATUS=fail \
    BETTERDISPLAY_EXPORT_CONTENT=backup >| "$__fixture_dir/output" 2>&1; then
    fail "failed backup with valid output was accepted"
fi
local __retained_backup="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__retained_backup" ]] || fail "valid backup from a failed export was removed"
[[ ! -e "$__backup_complete_marker" ]] ||
    fail "failed export incorrectly recorded backup completion"
grep -qF "$__retained_backup" "$__fixture_dir/output" ||
    fail "retained valid backup path was not reported"
if grep -qF "import" "$__log_file"; then
    fail "import ran after failed backup with valid output"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_MKTEMP_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "partial backup creation was accepted"
fi
if find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit 2>/dev/null | grep -q .; then
    fail "partial backup file was not removed"
fi
[[ ! -e "$__backup_complete_marker" ]] ||
    fail "failed mktemp incorrectly recorded backup completion"
if grep -qF "import" "$__log_file"; then
    fail "import ran after partial backup creation"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_OSASCRIPT_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "stop failure was accepted"
fi
if grep -qF "export" "$__log_file"; then
    fail "backup ran after stop failure"
fi
if grep -qF "BetterDisplay was restarted." "$__fixture_dir/output"; then
    fail "stop failure falsely reported a restart"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" \
    BETTERDISPLAY_OSASCRIPT_STATUS=fail \
    BETTERDISPLAY_OSASCRIPT_EXIT_BEFORE_ERROR=yes \
    BETTERDISPLAY_OPEN_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "stop failure after exit was accepted"
fi
[[ "$(cat "$__process_state")" == "stopped" ]] || fail "failed recovery changed the exited application state"
grep -qF "Could not stop BetterDisplay before import." "$__fixture_dir/output" ||
    fail "stop failure was not reported"
grep -qF "Could not restore the running BetterDisplay state." "$__fixture_dir/output" ||
    fail "recovery failure after stop failure was not reported"
if grep -qF "export" "$__log_file"; then
    fail "backup ran after stop failure and recovery"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_OSASCRIPT_KEEP_RUNNING=yes >| "$__fixture_dir/output" 2>&1; then
    fail "stop wait failure was accepted"
fi
if grep -qF "export" "$__log_file"; then
    fail "backup ran after stop wait failure"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
local __hang_start=$SECONDS
local __task_pid
run_task "$__task_import" BETTERDISPLAY_OSASCRIPT_HANG=yes >| "$__fixture_dir/output" 2>&1 &
__task_pid=$!
local __task_deadline=$(( SECONDS + 18 ))
while kill -0 "$__task_pid" 2>/dev/null; do
    if (( SECONDS >= __task_deadline )); then
        kill -TERM "$__task_pid" 2>/dev/null || true
        kill -KILL "$__task_pid" 2>/dev/null || true
        fail "hung osascript task exceeded the bounded test window"
    fi
    sleep 1
done
local __task_status=0
wait "$__task_pid" || __task_status=$?
if (( __task_status == 0 )); then
    fail "hung osascript was accepted"
fi
(( SECONDS - __hang_start < 20 )) ||
    fail "hung osascript exceeded the bounded test window"
local __osascript_pid="$(<"$__fixture_dir/osascript.pid")"
[[ "$__osascript_pid" == <-> ]] || fail "hung osascript PID was not recorded"
wait "$__osascript_pid" 2>/dev/null || true
if kill -0 "$__osascript_pid" 2>/dev/null; then
    fail "hung osascript child remained alive after timeout"
fi
grep -qF "Could not stop BetterDisplay before import." "$__fixture_dir/output" ||
    fail "hung osascript failure was not reported"

reset_fixture
if run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=invalid >| "$__fixture_dir/output" 2>&1; then
    fail "invalid live backup was accepted"
fi
if grep -qF "import" "$__log_file"; then
    fail "import ran after invalid live backup"
fi
[[ ! -e "$__backup_complete_marker" ]] ||
    fail "invalid live backup incorrectly recorded completion"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_IMPORT_STATUS=fail BETTERDISPLAY_OPEN_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "import and restart failure was accepted"
fi
grep -qiF "could not restore" "$__fixture_dir/output" ||
    fail "combined import and restart failure was not reported"
grep -qF "Backup:" "$__fixture_dir/output" ||
    fail "backup path was not reported after import failure"

reset_fixture
if run_task "$__task_import" \
    BETTERDISPLAY_ASSERT_STOPPED_COMMANDS=yes \
    BETTERDISPLAY_IMPORT_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "stopped-state import failure was accepted"
fi
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "stopped-state import failure changed the final process state"
if grep -qF "open " "$__log_file"; then
    fail "stopped-state import failure attempted to restart BetterDisplay"
fi
local __stopped_import_backup="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__stopped_import_backup" ]] ||
    fail "stopped-state import failure did not create a backup"
grep -qF "import observed stopped" "$__log_file" ||
    fail "stopped-state import failure did not observe the stopped state"
grep -qF "Backup: $__stopped_import_backup" "$__fixture_dir/output" ||
    fail "stopped-state import failure did not report the backup path"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_OPEN_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "successful import followed by restart failure was accepted"
fi
grep -qF "settings imported, but the app could not be started." "$__fixture_dir/output" ||
    fail "restart failure after successful import was not reported"
grep -qiF "could not restore" "$__fixture_dir/output" ||
    fail "restart failure recovery was not reported"
grep -qF "import" "$__log_file" ||
    fail "successful import did not run before restart failure"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" \
    BETTERDISPLAY_OPEN_LEAVE_STOPPED=yes >| "$__fixture_dir/output" 2>&1; then
    fail "unconfirmed restart was accepted"
fi
grep -qF "settings imported, but the app restart could not be confirmed within 10 seconds." \
    "$__fixture_dir/output" ||
    fail "unconfirmed restart was not reported accurately"
if grep -qF "could not be started" "$__fixture_dir/output"; then
    fail "unconfirmed restart was reported as a start failure"
fi
grep -qF "Backup:" "$__fixture_dir/output" ||
    fail "backup path was not reported after unconfirmed restart"
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "unconfirmed restart changed the stopped fixture state"

reset_fixture
if run_task "$__task_import" BETTERDISPLAY_STAT_FLIP=yes >| "$__fixture_dir/output" 2>&1; then
    fail "source identity change was accepted"
fi
if grep -qF "import" "$__log_file"; then
    fail "import ran after source identity changed"
fi
[[ "$(cat "$__tracked_plist")" == "mutated" ]] ||
    fail "source identity change did not mutate the tracked plist"
[[ -e "$__source_mutation_marker" ]] ||
    fail "source identity change did not record the source mutation"
[[ "$(cat "$__process_state")" == "stopped" ]] ||
    fail "stopped application changed state after source identity failure"

grep -qF '#MISE confirm={message="Import tracked BetterDisplay settings and overwrite live settings?", default="no"}' "$__task_import" ||
    fail "mise confirmation directive is missing"
if grep -Eq '(^|[[:space:]])(read|vared)[[:space:]]' "$__task_import"; then
    fail "import task contains a shell confirmation prompt"
fi
[[ ! -e "$__fixture_dir/git.log" ]] || fail "BetterDisplay task invoked Git"

reset_fixture
local __confirmation_output
__confirmation_output="$(
    print -r -- "n" | env -u MISE_ENV -u MISE_AUTO_ENV \
        HOME="$__fixture_dir/home" \
        ZDOTDIR="$__fixture_dir/empty" \
        PATH="$__bin_dir:/usr/bin:/bin" \
        MISE_PROJECT_ROOT="$__fixture_dir" \
        MISE_CONFIG_DIR="$__fixture_dir/mise-config" \
        MISE_ENV_CONF_D=true \
        XDG_STATE_HOME="$__state_home" \
        BETTERDISPLAY_COMMAND_LOG="$__log_file" \
        BETTERDISPLAY_GIT_LOG="$__fixture_dir/git.log" \
        BETTERDISPLAY_PROCESS_STATE="$__process_state" \
        BETTERDISPLAY_STAT_COUNT_FILE="$__fixture_dir/stat.count" \
        "$__mise_bin" -C "$__fixture_dir" run betterdisplay:settings:import 2>&1
)" || true
grep -qF "requires confirmation" <<< "$__confirmation_output" ||
    fail "mise confirmation was not enforced"
if grep -qF "import" "$__log_file"; then
    fail "cancelled mise confirmation ran the import"
fi

echo "BetterDisplay settings task tests passed."
