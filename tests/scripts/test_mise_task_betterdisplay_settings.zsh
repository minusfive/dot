#!/usr/bin/env zsh

set -euo pipefail

fail() {
    print -u2 -- "FAIL: $1"
    exit 1
}

local __test_dir="$(cd "$(dirname "$0")" && pwd -P)"
local __root_dir="$(cd "$__test_dir/../.." && pwd -P)"
local __work_dir="$__root_dir/.agents/test-runs/betterdisplay-$$"
local __fixture="$__work_dir/repo"
local __bin="$__work_dir/bin"
local __home="$__work_dir/home"
local __zdotdir="$__work_dir/zsh"
local __source="$__fixture/home/.config/BetterDisplay/config.plist"
local __export_task="$__fixture/home/.config/mise/tasks/betterdisplay/settings/export.zsh"
local __import_task="$__fixture/home/.config/mise/tasks/betterdisplay/settings/import.zsh"
local __source_export_task="$__root_dir/home/.config/mise/tasks/betterdisplay/settings/export.zsh"
local __source_import_task="$__root_dir/home/.config/mise/tasks/betterdisplay/settings/import.zsh"

cleanup() {
    rm -rf "$__work_dir"
}
trap cleanup EXIT

mkdir -p "$__fixture/.git" "$__fixture/home/.config/BetterDisplay" "$__fixture/home/.config/mise/tasks/betterdisplay/settings" "$__fixture/scripts/utils" "$__bin" "$__home/Applications/BetterDisplay.app" "$__zdotdir"
cp "$__root_dir/home/.config/BetterDisplay/config.plist" "$__source"
cp "$__root_dir/scripts/utils/betterdisplay.zsh" "$__fixture/scripts/utils/betterdisplay.zsh"
cp "$__root_dir/scripts/utils/betterdisplay_atomic_swap.c" "$__fixture/scripts/utils/betterdisplay_atomic_swap.c"
cp "$__source_export_task" "$__export_task"
cp "$__source_import_task" "$__import_task"

cat > "$__bin/defaults" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail
print -r -- "$*" >> "$BD_COMMAND_LOG"
if [[ "$1" == export ]]; then
    if [[ "${BD_FAIL_EXPORT:-false}" == true ]]; then
        exit 1
    fi
    if [[ -n "${BD_BACKUP_MARKER:-}" ]]; then
        : > "$BD_BACKUP_MARKER"
    fi
    if [[ "${BD_MUTATE_SOURCE:-false}" == true ]]; then
        print -r -- "mutated" > "$BD_SOURCE"
    fi
    cp "$BD_EXPORT_SOURCE" "$3"
elif [[ "$1" == import ]]; then
    print -r -- "$*" >> "$BD_IMPORT_LOG"
    if [[ "${BD_LAUNCH_DURING_IMPORT:-false}" == true && "$3" == "$BD_SOURCE" ]]; then
        : > "$BD_RUNNING_MARKER"
    fi
fi
EOF
cat > "$__bin/pgrep" <<'EOF'
#!/usr/bin/env zsh
if [[ -n "${BD_RUNNING_MARKER:-}" && -f "$BD_RUNNING_MARKER" ]]; then
    exit 0
fi
if [[ "${BD_RELAUNCH_AFTER_BACKUP:-false}" == true &&
    -n "${BD_BACKUP_MARKER:-}" && -f "$BD_BACKUP_MARKER" ]]; then
    exit 0
fi
[[ "${BD_RUNNING:-false}" == true ]]
EOF
cat > "$__bin/git" <<'EOF'
#!/usr/bin/env zsh
if [[ -n "${BD_GIT_ROOT:-}" ]]; then
    print -r -- "$BD_GIT_ROOT"
    exit 0
fi
print -r -- "$*" >> "$BD_GIT_LOG"
exit 1
EOF
cat > "$__bin/mv" <<'EOF'
#!/usr/bin/env zsh
print -r -- "mv $*" >> "$BD_COMMAND_LOG"
/bin/mv "$@"
EOF
chmod +x "$__bin/defaults" "$__bin/pgrep" "$__bin/git" "$__bin/mv"

local __valid_export="$__work_dir/export.plist"
cp "$__source" "$__valid_export"
local __command_log="$__work_dir/commands.log"
local __import_log="$__work_dir/import.log"
local __git_log="$__work_dir/git.log"
touch "$__command_log" "$__import_log" "$__git_log"
export PATH="$__bin:$PATH"
export HOME="$__home"
export ZDOTDIR="$__zdotdir"
export MISE_PROJECT_ROOT="$__fixture"
export XDG_STATE_HOME="$__work_dir/state"
export BD_SOURCE="$__source" BD_EXPORT_SOURCE="$__valid_export"
export BD_COMMAND_LOG="$__command_log" BD_IMPORT_LOG="$__import_log" BD_GIT_LOG="$__git_log"
local __running_marker="$__work_dir/running"
export BD_RUNNING_MARKER="$__running_marker"

local __lock_state="$__work_dir/lock-state"
local __lock_dir="$__lock_state/minusfive/BetterDisplay/lock"
local __dead_pid=999999
while kill -0 "$__dead_pid" 2>/dev/null; do
    (( __dead_pid++ ))
done
mkdir -p "$__lock_dir"
{
    print -r -- "pid=$__dead_pid"
    print -r -- "token=stale"
} > "$__lock_dir/owner"
touch -t 200001010000 "$__lock_dir" "$__lock_dir/owner"
env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f <<'EOF'
source "$BETTERDISPLAY_UTIL"
betterdisplay_acquire_lock
[[ "$(sed -n 's/^pid=//p' "$BETTERDISPLAY_LOCK_DIR/owner")" == "$$" ]]
betterdisplay_release_lock
[[ ! -e "${XDG_STATE_HOME}/minusfive/BetterDisplay/lock" ]]
EOF
[[ ! -e "$__lock_dir" ]] || fail "dead BetterDisplay lock was not recovered and released"

mkdir -p "$__lock_dir"
print -r -- interrupted > "$__lock_dir/.owner.interrupted"
if env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f -c 'source "$BETTERDISPLAY_UTIL"; betterdisplay_acquire_lock' 2>/dev/null; then
    fail "fresh hidden BetterDisplay lock was incorrectly recovered"
fi
[[ -e "$__lock_dir" ]] || fail "freshly created hidden BetterDisplay lock was removed"
touch -t 200001010000 "$__lock_dir"
env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f <<'EOF'
source "$BETTERDISPLAY_UTIL"
betterdisplay_acquire_lock
betterdisplay_release_lock
EOF
[[ ! -e "$__lock_dir" ]] || fail "stale hidden BetterDisplay lock was not recovered"

local __candidate_dir="$__lock_state/minusfive/BetterDisplay/.lock.999.1.1"
mkdir -p "$__candidate_dir"
touch -t 200001010000 "$__candidate_dir"
env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f <<'EOF'
source "$BETTERDISPLAY_UTIL"
betterdisplay_acquire_lock
betterdisplay_release_lock
EOF
[[ ! -e "$__candidate_dir" ]] || fail "stale incomplete lock candidate was not recovered"

local __reclaim_dir="$__lock_state/minusfive/BetterDisplay/.lock.reclaim.$__dead_pid.1.1"
mkdir -p "$__reclaim_dir" "$__lock_dir"
{
    print -r -- "pid=$__dead_pid"
    print -r -- "start=stale"
    print -r -- "token=stale"
} > "$__reclaim_dir/owner"
touch -t 200001010000 "$__reclaim_dir" "$__reclaim_dir/owner"
{
    print -r -- "pid=$$"
    print -r -- "start=$(ps -p $$ -o lstart= | sed 's/^[[:space:]]*//')"
    print -r -- "token=live"
} > "$__lock_dir/owner"
print -r -- "sentinel" > "$__lock_dir/sentinel"
if env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f -c 'source "$BETTERDISPLAY_UTIL"; betterdisplay_acquire_lock' 2>/dev/null; then
    fail "acquisition unexpectedly succeeded with a live BetterDisplay lock"
fi
[[ ! -e "$__reclaim_dir" ]] || fail "orphaned BetterDisplay quarantine was not cleaned"
[[ -f "$__lock_dir/owner" && -f "$__lock_dir/sentinel" ]] ||
    fail "orphaned quarantine cleanup removed the live BetterDisplay lock"
rm -rf "$__lock_dir"

mkdir -p "$__lock_dir"
{
    print -r -- "pid=$__dead_pid"
    print -r -- "start=stale"
    print -r -- "token=stale"
} > "$__lock_dir/owner"
touch -t 200001010000 "$__lock_dir" "$__lock_dir/owner"
local __reclaimer_script="$__work_dir/reclaimer.zsh"
local __winner_log="$__work_dir/reclaimer-winners"
: > "$__winner_log"
export BD_WINNER_LOG="$__winner_log"
cat > "$__reclaimer_script" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail
source "$BETTERDISPLAY_UTIL"
if betterdisplay_acquire_lock; then
    print -r -- "$$" >> "$BD_WINNER_LOG"
    sleep 2
    betterdisplay_release_lock
else
    exit 1
fi
EOF
chmod +x "$__reclaimer_script"
local -a __reclaimer_pids
local __reclaimer_index __reclaimer_successes=0
for __reclaimer_index in {1..6}; do
    env \
        XDG_STATE_HOME="$__lock_state" \
        BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
        zsh -f "$__reclaimer_script" >"$__work_dir/reclaimer.$__reclaimer_index.log" 2>&1 &
    __reclaimer_pids+=("$!")
done
for __reclaimer_index in "${__reclaimer_pids[@]}"; do
    if wait "$__reclaimer_index"; then
        __reclaimer_successes=$(( __reclaimer_successes + 1 ))
    fi
done
[[ "$__reclaimer_successes" == 1 ]] || fail "concurrent stale reclaimers did not elect exactly one owner"
[[ "$(wc -l < "$__winner_log" | tr -d ' ')" == 1 ]] ||
    fail "concurrent stale reclaimers recorded multiple owners"
[[ ! -e "$__lock_dir" ]] || fail "concurrent stale reclaimer left the lock installed"
if find "$__lock_state/minusfive/BetterDisplay" -maxdepth 1 -name '.lock.reclaim.*' -print -quit | grep -q .; then
    fail "concurrent stale reclaimer left a quarantine directory"
fi
unset BD_WINNER_LOG

mkdir -p "$__lock_dir"
{
    print -r -- "pid=$$"
    print -r -- "start=$(ps -p $$ -o lstart= | sed 's/^[[:space:]]*//')"
    print -r -- "token=live"
} > "$__lock_dir/owner"
print -r -- "sentinel" > "$__lock_dir/sentinel"
if env \
    XDG_STATE_HOME="$__lock_state" \
    BETTERDISPLAY_UTIL="$__root_dir/scripts/utils/betterdisplay.zsh" \
    zsh -f -c 'source "$BETTERDISPLAY_UTIL"; betterdisplay_acquire_lock' 2>/dev/null; then
    fail "live BetterDisplay lock was stolen"
fi
[[ -f "$__lock_dir/owner" && -f "$__lock_dir/sentinel" ]] ||
    fail "live BetterDisplay lock contents were deleted"
rm -rf "$__lock_state"

[[ "$("$__export_task" 2>&1)" == *"unchanged"* ]] || fail "unchanged export was not reported"
[[ ! -s "$__git_log" ]] || fail "export invoked Git"
local __deployed_task="$__work_dir/deployed/.config/mise/tasks/betterdisplay/settings/export.zsh"
mkdir -p "${__deployed_task:h}"
ln -s "$__export_task" "$__deployed_task"
[[ "$("$__deployed_task" 2>&1)" == *"unchanged"* ]] || fail "deployed task symlink was not resolved to its trusted source"

local __untrusted_root="$__work_dir/untrusted-root"
local __untrusted_marker="$__work_dir/untrusted-sourced"
mkdir -p "$__untrusted_root/.git" "$__untrusted_root/home/.config/BetterDisplay" "$__untrusted_root/home/.config/mise/tasks/betterdisplay/settings" "$__untrusted_root/scripts/utils"
cp "$__source" "$__untrusted_root/home/.config/BetterDisplay/config.plist"
cp "$__source_export_task" "$__untrusted_root/home/.config/mise/tasks/betterdisplay/settings/export.zsh"
cp "$__source_import_task" "$__untrusted_root/home/.config/mise/tasks/betterdisplay/settings/import.zsh"
cat > "$__untrusted_root/scripts/utils/betterdisplay.zsh" <<'EOF'
#!/usr/bin/env zsh
: > "$BD_UNTRUSTED_MARKER"
EOF
export MISE_PROJECT_ROOT="" MISE_ORIGINAL_CWD="$__untrusted_root"
export BD_GIT_ROOT="$__untrusted_root" BD_UNTRUSTED_MARKER="$__untrusted_marker"
if "$__export_task" >"$__work_dir/untrusted-output" 2>&1; then
    fail "export accepted an untrusted fallback repository"
fi
[[ ! -e "$__untrusted_marker" ]] || fail "untrusted fallback helper was sourced"
grep -qF "refusing untrusted dotfiles repository" "$__work_dir/untrusted-output" ||
    fail "untrusted fallback repository was not rejected"
if "$__import_task" >"$__work_dir/untrusted-import-output" 2>&1; then
    fail "import accepted an untrusted fallback repository"
fi
[[ ! -e "$__untrusted_marker" ]] || fail "untrusted import fallback helper was sourced"
grep -qF "refusing untrusted dotfiles repository" "$__work_dir/untrusted-import-output" ||
    fail "untrusted import fallback repository was not rejected"

local __valid_fallback_root="$__work_dir/valid-fallback-root"
local __valid_export_task="$__valid_fallback_root/home/.config/mise/tasks/betterdisplay/settings/export.zsh"
local __valid_import_task="$__valid_fallback_root/home/.config/mise/tasks/betterdisplay/settings/import.zsh"
mkdir -p "$__valid_fallback_root/.git" "$__valid_fallback_root/home/.config/BetterDisplay" "$__valid_fallback_root/home/.config/mise/tasks/betterdisplay/settings" "$__valid_fallback_root/scripts/utils"
cp "$__source" "$__valid_fallback_root/home/.config/BetterDisplay/config.plist"
cp "$__root_dir/scripts/utils/betterdisplay.zsh" "$__valid_fallback_root/scripts/utils/betterdisplay.zsh"
cp "$__source_export_task" "$__valid_export_task"
cp "$__source_import_task" "$__valid_import_task"
export MISE_ORIGINAL_CWD="$__valid_fallback_root" BD_GIT_ROOT="$__valid_fallback_root"
export BD_EXPORT_SOURCE="$__valid_fallback_root/home/.config/BetterDisplay/config.plist"
[[ "$("$__valid_export_task" 2>&1)" == *"unchanged"* ]] || fail "valid fallback repository was rejected"
print -r -- n | "$__valid_import_task" >"$__work_dir/valid-import-output"
grep -qF "Import cancelled" "$__work_dir/valid-import-output" ||
    fail "valid import fallback repository was rejected"
export MISE_PROJECT_ROOT="$__fixture" MISE_ORIGINAL_CWD="$__root_dir"
export BD_GIT_ROOT="" BD_UNTRUSTED_MARKER=""
export BD_EXPORT_SOURCE="$__valid_export"

print -r -- '<?xml version="1.0"?><plist version="1.0"><dict><key>Changed</key><true/></dict></plist>' > "$__valid_export"
"$__export_task" >/dev/null
cmp -s "$__valid_export" "$__source" || fail "export did not update the tracked source"
grep -qF 'export pro.betterdisplay.BetterDisplay' "$__command_log" || fail "defaults export was not invoked"
[[ -x "$XDG_STATE_HOME/minusfive/BetterDisplay/tools/betterdisplay_atomic_swap" ]] ||
    fail "export did not use the native atomic replacement helper"

local __before="$(cat "$__source")"
print -r -- 'not a plist' > "$__valid_export"
if "$__export_task" >/dev/null 2>&1; then
    fail "invalid export output was accepted"
fi
[[ "$(cat "$__source")" == "$__before" ]] || fail "invalid export changed the source"

cp "$__source" "$__valid_export"
export BD_MUTATE_SOURCE=true
if "$__export_task" >/dev/null 2>&1; then
    fail "source mutation during export was accepted"
fi
export BD_MUTATE_SOURCE=false
cp "$__valid_export" "$__source"

print -r -- '<?xml version="1.0"?><plist version="1.0"><dict><key>RaceChange</key><true/></dict></plist>' > "$__valid_export"
local __race_helper="$XDG_STATE_HOME/minusfive/BetterDisplay/tools/betterdisplay_atomic_swap"
local __race_marker="$__work_dir/race"
rm -f "$__race_marker"
cat > "$__race_helper" <<'EOF'
#!/usr/bin/env zsh
if [[ ! -e "$BD_RACE_MARKER" ]]; then
    print -r -- concurrent > "$1"
    : > "$BD_RACE_MARKER"
fi
local swap_file="$2.swap"
/bin/mv "$2" "$swap_file"
/bin/mv "$1" "$2"
/bin/mv "$swap_file" "$1"
EOF
chmod +x "$__race_helper"
export BD_RACE_MARKER="$__race_marker"
if "$__export_task" >"$__work_dir/race-output" 2>&1; then
    fail "concurrent replacement was accepted"
fi
[[ "$(cat "$__source")" == concurrent ]] || fail "concurrent source content was not restored"
find "$XDG_STATE_HOME/minusfive/BetterDisplay/conflicts" -type f -print -quit | grep -q . ||
    fail "concurrent export content was not preserved"
rm -f "$__race_helper" "$BD_RACE_MARKER"
unset BD_RACE_MARKER
cp "$__valid_export" "$__source"

cat > "$__race_helper" <<'EOF'
#!/usr/bin/env zsh
local swap_file="$2.swap"
if [[ ! -e "$BD_RACE_MARKER" ]]; then
    : > "$BD_RACE_MARKER"
    /bin/mv "$2" "$swap_file"
    /bin/mv "$1" "$2"
    /bin/mv "$swap_file" "$1"
    print -r -- concurrent > "$1"
    exit 0
fi
/bin/mv "$2" "$swap_file"
/bin/mv "$1" "$2"
/bin/mv "$swap_file" "$1"
EOF
chmod +x "$__race_helper"
export BD_RACE_MARKER="$__race_marker"
local __conflicts_dir="$XDG_STATE_HOME/minusfive/BetterDisplay/conflicts"
rm -rf "$__conflicts_dir"
print -r -- blocked > "$__conflicts_dir"
cp "$__root_dir/home/.config/BetterDisplay/config.plist" "$__source"
print -r -- '<?xml version="1.0"?><plist version="1.0"><dict><key>FailurePath</key><true/></dict></plist>' > "$__valid_export"
if "$__export_task" >"$__work_dir/conflict-copy-output" 2>&1; then
    fail "export accepted a failed conflict-file creation"
fi
grep -qF "displaced tracked content retained at" "$__work_dir/conflict-copy-output" ||
    fail "conflict-file failure did not report the displaced content path"
find "$__fixture/home/.config/BetterDisplay" -name '.betterdisplay.*' -type f -print -quit | grep -q . ||
    fail "conflict-file failure deleted the displaced content"
rm -f "$__race_helper" "$BD_RACE_MARKER"
unset BD_RACE_MARKER
rm -f "$__conflicts_dir"
cp "$__valid_export" "$__source"

cat > "$__race_helper" <<'EOF'
#!/usr/bin/env zsh
local swap_file="$2.swap"
if [[ ! -e "$BD_RACE_MARKER" ]]; then
    : > "$BD_RACE_MARKER"
    /bin/mv "$2" "$swap_file"
    /bin/mv "$1" "$2"
    /bin/mv "$swap_file" "$1"
    print -r -- concurrent > "$1"
    exit 0
fi
exit 1
EOF
chmod +x "$__race_helper"
export BD_RACE_MARKER="$__race_marker"
cp "$__root_dir/home/.config/BetterDisplay/config.plist" "$__source"
if "$__export_task" >"$__work_dir/rollback-output" 2>&1; then
    fail "export accepted a failed rollback"
fi
grep -qF "could not roll back" "$__work_dir/rollback-output" ||
    fail "rollback failure was not reported"
grep -qF "recovery copy retained at" "$__work_dir/rollback-output" ||
    fail "rollback failure did not report its recovery path"
find "$XDG_STATE_HOME/minusfive/BetterDisplay/conflicts" -type f -print -quit | grep -q . ||
    fail "rollback failure did not preserve a recovery copy"
rm -f "$__race_helper" "$BD_RACE_MARKER"
unset BD_RACE_MARKER
cp "$__valid_export" "$__source"

mv "$__source" "$__source.missing"
if print -r -- y | "$__import_task" >/dev/null 2>&1; then
    fail "import accepted a missing source"
fi
mv "$__source.missing" "$__source"

cp "$__source" "$__valid_export"
print -r -- 'not a plist' > "$__source"
if print -r -- y | "$__import_task" >/dev/null 2>&1; then
    fail "import accepted an invalid source"
fi
cp "$__valid_export" "$__source"

cp "$__source" "$__valid_export"
: > "$__command_log"
print -r -- n | "$__import_task" > "$__work_dir/cancel-output"
if grep -qF 'import pro.betterdisplay.BetterDisplay' "$__command_log"; then
    fail "cancelled import invoked defaults import"
fi
print -r -- y | "$__import_task" > "$__work_dir/import-output"
grep -qF 'export pro.betterdisplay.BetterDisplay' "$__command_log" || fail "import did not back up settings first"
grep -qF 'import pro.betterdisplay.BetterDisplay' "$__command_log" || fail "import command was not invoked"
grep -qF 'Restart BetterDisplay' "$__work_dir/import-output" || fail "import restart guidance is missing"
find "$XDG_STATE_HOME/minusfive/BetterDisplay/backups" -type f -name '*.plist' | grep -q . ||
    fail "import backup was not created"

export BD_RUNNING=true
if print -r -- y | "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded while BetterDisplay was running"
fi
export BD_RUNNING=false

: > "$__command_log"
local __relaunch_marker="$__work_dir/relaunched"
rm -f "$__relaunch_marker"
export BD_RELAUNCH_AFTER_BACKUP=true BD_BACKUP_MARKER="$__relaunch_marker"
if print -r -- y | "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded after BetterDisplay relaunched during backup"
fi
if grep -qF 'import pro.betterdisplay.BetterDisplay' "$__command_log"; then
    fail "relaunching BetterDisplay still invoked defaults import"
fi
export BD_RELAUNCH_AFTER_BACKUP=false BD_BACKUP_MARKER=""

: > "$__command_log"
rm -f "$BD_RUNNING_MARKER"
export BD_LAUNCH_DURING_IMPORT=true
if print -r -- y | "$__import_task" > "$__work_dir/import-race-output" 2>&1; then
    fail "import proceeded after BetterDisplay launched during import"
fi
grep -cF 'import pro.betterdisplay.BetterDisplay' "$__command_log" | grep -q '^2$' ||
    fail "import did not attempt the required rollback"
grep -qF 'rollback completed' "$__work_dir/import-race-output" ||
    fail "import launch race did not report rollback"
export BD_LAUNCH_DURING_IMPORT=false
rm -f "$BD_RUNNING_MARKER"

: > "$__command_log"
export BD_FAIL_EXPORT=true
if print -r -- y | "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded after backup failure"
fi
export BD_FAIL_EXPORT=false
if grep -qF 'import pro.betterdisplay.BetterDisplay' "$__command_log"; then
    fail "backup failure still invoked defaults import"
fi

grep -qF '#MISE dir="{{cwd}}"' "$__export_task" || fail "export task directory directive is missing"
grep -qF '#MISE dir="{{cwd}}"' "$__import_task" || fail "import task directory directive is missing"
grep -qF 'tracked BetterDisplay plist changed after replacement' "$__export_task" ||
    fail "export task is missing its post-replacement source-change guard"
print -r -- "BetterDisplay mise task tests passed."
