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
local __valid_export="$__work_dir/export.plist"
local __command_log="$__work_dir/commands.log"
local __git_log="$__work_dir/git.log"
local __running_marker="$__work_dir/running"

cleanup() {
    [[ -n "${__lock_holder_pid:-}" ]] && kill "$__lock_holder_pid" 2>/dev/null || true
    rm -rf "$__work_dir"
}
trap cleanup EXIT

mkdir -p "$__fixture/.git" "$__fixture/home/.config/BetterDisplay" \
    "$__fixture/home/.config/mise/tasks/betterdisplay/settings" "$__fixture/scripts/utils" \
    "$__bin" "$__home/Applications/BetterDisplay.app" "$__zdotdir"
cp "$__root_dir/home/.config/BetterDisplay/config.plist" "$__source"
cp "$__root_dir/scripts/utils/betterdisplay.zsh" "$__fixture/scripts/utils/betterdisplay.zsh"
cp "$__root_dir/home/.config/mise/tasks/betterdisplay/settings/export.zsh" "$__export_task"
cp "$__root_dir/home/.config/mise/tasks/betterdisplay/settings/import.zsh" "$__import_task"
cp "$__source" "$__valid_export"
touch "$__command_log" "$__git_log"

cat > "$__bin/defaults" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail
print -r -- "$*" >> "$BD_COMMAND_LOG"
if [[ "$1" == export ]]; then
    [[ "${BD_FAIL_EXPORT:-false}" != true ]] || exit 1
    [[ "${BD_MUTATE_SOURCE:-false}" != true ]] || print -r -- "mutated" > "$BD_SOURCE"
    [[ -z "${BD_BACKUP_MARKER:-}" ]] || : > "$BD_BACKUP_MARKER"
    cp "$BD_EXPORT_SOURCE" "$3"
elif [[ "$1" == import ]]; then
    [[ "${BD_FAIL_IMPORT:-false}" != true ]] || exit 1
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
print -r -- "$*" >> "$BD_GIT_LOG"
exit 97
EOF
chmod +x "$__bin/defaults" "$__bin/pgrep" "$__bin/git"

export PATH="$__bin:$PATH"
export HOME="$__home"
export ZDOTDIR="$__zdotdir"
export XDG_STATE_HOME="$__work_dir/state"
export BD_SOURCE="$__source" BD_EXPORT_SOURCE="$__valid_export"
export BD_COMMAND_LOG="$__command_log" BD_GIT_LOG="$__git_log"
export BD_RUNNING_MARKER="$__running_marker"

grep -qF '#MISE description="Export BetterDisplay settings to the tracked plist"' "$__export_task" ||
    fail "export task description is missing"
grep -qF '#MISE description="Import the tracked plist into BetterDisplay"' "$__import_task" ||
    fail "import task description is missing"
grep -qF '#MISE dir="{{cwd}}"' "$__export_task" || fail "export task directory directive is missing"
grep -qF '#MISE dir="{{cwd}}"' "$__import_task" || fail "import task directory directive is missing"
[[ "$(zsh -f "$__export_task" 2>&1)" == *"unchanged"* ]] || fail "unchanged export was not reported"
[[ ! -s "$__git_log" ]] || fail "export invoked Git"

local __deployed_task="$__work_dir/deployed/.config/mise/tasks/betterdisplay/settings/export.zsh"
mkdir -p "${__deployed_task:h}"
ln -s "$__export_task" "$__deployed_task"
[[ "$(zsh -f "$__deployed_task" 2>&1)" == *"unchanged"* ]] || fail "deployed task symlink was not resolved"
[[ -L "$__deployed_task" ]] || fail "deployed task symlink was replaced"

print -r -- '<?xml version="1.0"?><plist version="1.0"><dict><key>Changed</key><true/></dict></plist>' > "$__valid_export"
zsh -f "$__deployed_task" >/dev/null
cmp -s "$__valid_export" "$__source" || fail "export did not update the tracked source"
[[ -L "$__deployed_task" ]] || fail "export wrote through the deployed task symlink"
[[ ! -s "$__git_log" ]] || fail "changed export invoked Git"

local __before="$(cat "$__source")"
print -r -- "not a plist" > "$__valid_export"
if zsh -f "$__export_task" >/dev/null 2>&1; then
    fail "invalid export output was accepted"
fi
[[ "$(cat "$__source")" == "$__before" ]] || fail "invalid export changed the source"
cp "$__source" "$__valid_export"

export BD_MUTATE_SOURCE=true
if zsh -f "$__export_task" > "$__work_dir/conflict-output" 2>&1; then
    fail "source mutation during export was accepted"
fi
export BD_MUTATE_SOURCE=false
grep -qF "recovery copy retained" "$__work_dir/conflict-output" ||
    fail "export conflict recovery was not reported"
find "$XDG_STATE_HOME/minusfive/BetterDisplay/conflicts" -type f -print -quit | grep -q . ||
    fail "export conflict recovery file was not retained"
grep -qF mutated "$__source" || fail "source-change protection did not preserve the changed source"
cp "$__valid_export" "$__source"

local __outside_source="$__work_dir/outside.plist"
cp "$__source" "$__outside_source"
mv "$__source" "$__source.regular"
ln -s "$__outside_source" "$__source"
if zsh -f "$__export_task" >/dev/null 2>&1; then
    fail "export accepted a symlinked tracked source"
fi
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import accepted a symlinked tracked source"
fi
cmp -s "$__outside_source" "$__source.regular" ||
    fail "symlinked-source rejection allowed an outside write"
rm "$__source"
mv "$__source.regular" "$__source"

local __lock_marker="$__work_dir/lock-held"
local __attempt
rm -f "$__lock_marker"
env BETTERDISPLAY_UTIL="$__fixture/scripts/utils/betterdisplay.zsh" \
    BD_LOCK_MARKER="$__lock_marker" zsh -f -c '
        source "$BETTERDISPLAY_UTIL"
        betterdisplay_acquire_lock
        : > "$BD_LOCK_MARKER"
        sleep 2
        betterdisplay_release_lock
    ' &
local __lock_holder_pid="$!"
for (( __attempt = 1; __attempt <= 40; __attempt++ )); do
    [[ -e "$__lock_marker" ]] && break
    sleep 0.05
done
[[ -e "$__lock_marker" ]] || fail "manual lock holder did not start"
if zsh -f "$__export_task" >/dev/null 2>&1; then
    fail "concurrent manual export was accepted"
fi
wait "$__lock_holder_pid"
unset __lock_holder_pid
[[ ! -e "$XDG_STATE_HOME/minusfive/BetterDisplay/lock" ]] ||
    fail "normal lock cleanup failed"

mkdir -p "$XDG_STATE_HOME/minusfive/BetterDisplay/lock"
if zsh -f "$__export_task" >/dev/null 2>&1; then
    fail "stale manual lock was silently replaced"
fi
[[ -d "$XDG_STATE_HOME/minusfive/BetterDisplay/lock" ]] ||
    fail "existing manual lock was removed or reclaimed"
rmdir "$XDG_STATE_HOME/minusfive/BetterDisplay/lock"
if ! zsh -f "$__export_task" >/dev/null; then
    fail "manual lock cleanup did not recover export"
fi

mv "$__source" "$__source.missing"
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import accepted a missing source"
fi
mv "$__source.missing" "$__source"

print -r -- "not a plist" > "$__source"
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import accepted an invalid source"
fi
cp "$__valid_export" "$__source"

: > "$__command_log"
print -r -- n | zsh -f "$__import_task" > "$__work_dir/cancel-output"
if grep -qF "import pro.betterdisplay.BetterDisplay" "$__command_log"; then
    fail "cancelled import invoked defaults import"
fi
grep -qF "Import cancelled" "$__work_dir/cancel-output" || fail "import cancellation was not reported"

print -r -- y | zsh -f "$__import_task" > "$__work_dir/import-output"
grep -qF "export pro.betterdisplay.BetterDisplay" "$__command_log" || fail "import did not back up settings first"
grep -qF "import pro.betterdisplay.BetterDisplay" "$__command_log" || fail "import command was not invoked"
grep -qF "Restart BetterDisplay" "$__work_dir/import-output" || fail "import restart guidance is missing"
find "$XDG_STATE_HOME/minusfive/BetterDisplay/backups" -type f -name '*.plist' -print -quit | grep -q . ||
    fail "import backup was not created"
[[ ! -s "$__git_log" ]] || fail "import invoked Git"

export BD_RUNNING=true
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded while BetterDisplay was running"
fi
export BD_RUNNING=false

: > "$__command_log"
local __relaunch_marker="$__work_dir/relaunched"
rm -f "$__relaunch_marker"
export BD_RELAUNCH_AFTER_BACKUP=true BD_BACKUP_MARKER="$__relaunch_marker"
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded after BetterDisplay relaunched during backup"
fi
if grep -qF "import pro.betterdisplay.BetterDisplay" "$__command_log"; then
    fail "relaunching BetterDisplay still invoked defaults import"
fi
export BD_RELAUNCH_AFTER_BACKUP=false BD_BACKUP_MARKER=""

: > "$__command_log"
export BD_FAIL_EXPORT=true
if print -r -- y | zsh -f "$__import_task" >/dev/null 2>&1; then
    fail "import proceeded after backup failure"
fi
export BD_FAIL_EXPORT=false
if grep -qF "import pro.betterdisplay.BetterDisplay" "$__command_log"; then
    fail "backup failure still invoked defaults import"
fi
[[ ! -s "$__git_log" ]] || fail "manual tasks invoked Git"

print -r -- "BetterDisplay mise task tests passed."
