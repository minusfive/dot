#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

local __fixture_dir="$(mktemp -d)"
trap 'rm -rf -- "$__fixture_dir"' EXIT
__fixture_dir="$(realpath "$__fixture_dir")"
local __bin_dir="$__fixture_dir/bin"
local __state_home="$__fixture_dir/state"
local __log_file="$__fixture_dir/commands.log"
local __process_state="$__fixture_dir/process.state"
local __task_export="$__fixture_dir/scripts/tasks/betterdisplay/settings/export.zsh"
local __task_import="$__fixture_dir/scripts/tasks/betterdisplay/settings/import.zsh"
local __tracked_plist="$__fixture_dir/home/.config/BetterDisplay/config.plist"
local __mise_bin="$(command -v mise)"

mkdir -p \
    "$__bin_dir" \
    "$__fixture_dir/empty" \
    "$__state_home" \
    "$__fixture_dir/scripts/tasks/betterdisplay/settings" \
    "$__fixture_dir/scripts/utils" \
    "$__fixture_dir/home/.config/BetterDisplay" \
    "$__fixture_dir/.mise/conf.d"
cp scripts/utils/betterdisplay.zsh "$__fixture_dir/scripts/utils/betterdisplay.zsh"
cp scripts/tasks/betterdisplay/settings/export.zsh "$__task_export"
cp scripts/tasks/betterdisplay/settings/import.zsh "$__task_import"
cp .mise/conf.d/tasks.toml "$__fixture_dir/.mise/conf.d/tasks.toml"
print -r -- "valid" >| "$__tracked_plist"
: >| "$__log_file"
trap 'rm -rf "$__fixture_dir"' EXIT

cat > "$__bin_dir/defaults" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "$*" >> "$BETTERDISPLAY_COMMAND_LOG"
case "$1" in
    export)
        [[ "${BETTERDISPLAY_EXPORT_STATUS:-ok}" == "ok" ]] || exit 1
        print -r -- "${BETTERDISPLAY_EXPORT_CONTENT:-backup}" >| "$3"
        ;;
    import)
        [[ "${BETTERDISPLAY_IMPORT_STATUS:-ok}" == "ok" ]] || exit 1
        ;;
esac
EOF

cat > "$__bin_dir/plutil" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

[[ "${BETTERDISPLAY_PLUTIL_STATUS:-ok}" == "ok" ]] || exit 1
grep -qF invalid "$2" && exit 1
exit 0
EOF

cat > "$__bin_dir/cmp" <<'EOF'
#!/usr/bin/env zsh
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
if [[ "${BETTERDISPLAY_OSASCRIPT_STATUS:-ok}" != "ok" ]]; then
    [[ "${BETTERDISPLAY_OSASCRIPT_EXIT_BEFORE_ERROR:-no}" == "yes" ]] &&
        print -r -- "stopped" >| "$BETTERDISPLAY_PROCESS_STATE"
    exit 1
fi
[[ "${BETTERDISPLAY_OSASCRIPT_KEEP_RUNNING:-no}" == "yes" ]] ||
    print -r -- "stopped" >| "$BETTERDISPLAY_PROCESS_STATE"
EOF

cat > "$__bin_dir/open" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "open $*" >> "$BETTERDISPLAY_COMMAND_LOG"
[[ "${BETTERDISPLAY_OPEN_STATUS:-ok}" == "ok" ]] || exit 1
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
if [[ "${BETTERDISPLAY_STAT_FLIP:-no}" == "yes" && "$__count" -gt 1 ]]; then
    print -r -- "changed"
else
    print -r -- "same"
fi
EOF

cat > "$__bin_dir/git" <<'EOF'
#!/usr/bin/env zsh
set -euo pipefail

print -r -- "$*" >> "$BETTERDISPLAY_GIT_LOG"
exit 99
EOF

chmod +x "$__bin_dir"/*

run_task() {
    local __task="$1"
    shift
    env -u MISE_ENV -u MISE_AUTO_ENV \
        HOME="$__fixture_dir/home" \
        ZDOTDIR="$__fixture_dir/empty" \
        PATH="$__bin_dir:/usr/bin:/bin" \
        MISE_PROJECT_ROOT="$__fixture_dir" \
        XDG_STATE_HOME="$__state_home" \
        BETTERDISPLAY_COMMAND_LOG="$__log_file" \
        BETTERDISPLAY_GIT_LOG="$__fixture_dir/git.log" \
        BETTERDISPLAY_PROCESS_STATE="$__process_state" \
        BETTERDISPLAY_STAT_COUNT_FILE="$__fixture_dir/stat.count" \
        MISE_PROJECT_ROOT="${BETTERDISPLAY_PROJECT_ROOT:-$__fixture_dir}" \
        "$@" /bin/zsh "$__task"
}

reset_fixture() {
    print -r -- "valid" >| "$__tracked_plist"
    print -r -- "stopped" >| "$__process_state"
    : >| "$__log_file"
    rm -f "$__fixture_dir/stat.count" "$__fixture_dir/git.log"
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
mv "$__fixture_dir/scripts/utils/betterdisplay.zsh" "$__fixture_dir/scripts/utils/betterdisplay.real.zsh"
ln -s betterdisplay.real.zsh "$__fixture_dir/scripts/utils/betterdisplay.zsh"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "symlinked helper was accepted"
fi
rm "$__fixture_dir/scripts/utils/betterdisplay.zsh"
mv "$__fixture_dir/scripts/utils/betterdisplay.real.zsh" "$__fixture_dir/scripts/utils/betterdisplay.zsh"

reset_fixture
mv "$__tracked_plist" "$__fixture_dir/home/.config/BetterDisplay/config.real.plist"
ln -s config.real.plist "$__tracked_plist"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "symlinked tracked plist was accepted"
fi
rm "$__tracked_plist"
mv "$__fixture_dir/home/.config/BetterDisplay/config.real.plist" "$__tracked_plist"

reset_fixture
mkdir -p "$__fixture_dir/escaped/utils"
cp "$__fixture_dir/scripts/utils/betterdisplay.zsh" "$__fixture_dir/escaped/utils/betterdisplay.zsh"
mv "$__fixture_dir/scripts/utils" "$__fixture_dir/scripts/utils.real"
ln -s "$__fixture_dir/escaped/utils" "$__fixture_dir/scripts/utils"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "symlinked helper parent was accepted"
fi
grep -qiF "symlinked or escaped ancestor" "$__fixture_dir/output" ||
    fail "symlinked helper parent was not rejected explicitly"
rm "$__fixture_dir/scripts/utils"
mv "$__fixture_dir/scripts/utils.real" "$__fixture_dir/scripts/utils"

reset_fixture
mkdir -p "$__fixture_dir/escaped-import/utils"
cp "$__fixture_dir/scripts/utils/betterdisplay.zsh" "$__fixture_dir/escaped-import/utils/betterdisplay.zsh"
mv "$__fixture_dir/scripts/utils" "$__fixture_dir/scripts/utils.real"
ln -s "$__fixture_dir/escaped-import/utils" "$__fixture_dir/scripts/utils"
if run_task "$__task_import" >| "$__fixture_dir/output" 2>&1; then
    fail "import accepted a symlinked helper parent"
fi
grep -qiF "symlinked or escaped ancestor" "$__fixture_dir/output" ||
    fail "import did not reject a symlinked helper parent explicitly"
if grep -qE 'osascript|defaults' "$__log_file"; then
    fail "import accessed BetterDisplay after a symlinked helper parent"
fi
rm "$__fixture_dir/scripts/utils"
mv "$__fixture_dir/scripts/utils.real" "$__fixture_dir/scripts/utils"

reset_fixture
mkdir -p "$__fixture_dir/escaped/plist"
cp "$__tracked_plist" "$__fixture_dir/escaped/plist/config.plist"
mv "$__fixture_dir/home/.config/BetterDisplay" "$__fixture_dir/home/.config/BetterDisplay.real"
ln -s "$__fixture_dir/escaped/plist" "$__fixture_dir/home/.config/BetterDisplay"
if run_task "$__task_export" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
    fail "symlinked tracked plist parent was accepted"
fi
grep -qiF "symlinked or escaped ancestor" "$__fixture_dir/output" ||
    fail "symlinked tracked plist parent was not rejected explicitly"
rm "$__fixture_dir/home/.config/BetterDisplay"
mv "$__fixture_dir/home/.config/BetterDisplay.real" "$__fixture_dir/home/.config/BetterDisplay"

reset_fixture
mkdir -p "$__fixture_dir/escaped-root/scripts/utils" "$__fixture_dir/escaped-root/home/.config/BetterDisplay"
cp "$__fixture_dir/scripts/utils/betterdisplay.zsh" \
    "$__fixture_dir/escaped-root/scripts/utils/betterdisplay.zsh"
cp "$__tracked_plist" "$__fixture_dir/escaped-root/home/.config/BetterDisplay/config.plist"
ln -s "$__fixture_dir/escaped-root" "$__fixture_dir/project-root-link"
for __task in "$__task_export" "$__task_import"; do
    if BETTERDISPLAY_PROJECT_ROOT="$__fixture_dir/project-root-link" \
        run_task "$__task" BETTERDISPLAY_EXPORT_CONTENT=changed >| "$__fixture_dir/output" 2>&1; then
        fail "escaped project root was accepted: $__task"
    fi
    grep -qiF "canonical physical directory" "$__fixture_dir/output" ||
        fail "escaped project root was not rejected explicitly: $__task"
done
rm "$__fixture_dir/project-root-link"

reset_fixture
print -r -- "running" >| "$__process_state"
run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=backup
[[ "$(cat "$__process_state")" == "running" ]] || fail "running application was not restarted"
grep -nF "osascript" "$__log_file" >/dev/null || fail "running application was not stopped"
grep -nF "export" "$__log_file" >/dev/null || fail "live backup was not exported"
grep -nF "import" "$__log_file" >/dev/null || fail "tracked settings were not imported"
grep -nF "open" "$__log_file" >/dev/null || fail "running application was not restarted"
local __backup_file="$(find "$__state_home/minusfive/BetterDisplay/backups" -type f -print -quit)"
[[ -n "$__backup_file" ]] || fail "live backup was not saved"

reset_fixture
run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=backup
if grep -qF "open " "$__log_file"; then
    fail "stopped application was restarted"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_EXPORT_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "backup failure was accepted"
fi
[[ "$(cat "$__process_state")" == "running" ]] || fail "backup failure did not restore the running application"
if grep -qF "import" "$__log_file"; then
    fail "import ran after backup failure"
fi

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_OSASCRIPT_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "stop failure was accepted"
fi
if grep -qF "export" "$__log_file"; then
    fail "backup ran after stop failure"
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
if run_task "$__task_import" BETTERDISPLAY_EXPORT_CONTENT=invalid >| "$__fixture_dir/output" 2>&1; then
    fail "invalid live backup was accepted"
fi
if grep -qF "import" "$__log_file"; then
    fail "import ran after invalid live backup"
fi

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
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_OPEN_STATUS=fail >| "$__fixture_dir/output" 2>&1; then
    fail "successful import followed by restart failure was accepted"
fi
grep -qF "settings imported, but the app could not be restarted" "$__fixture_dir/output" ||
    fail "restart failure after successful import was not reported"
grep -qF "import" "$__log_file" ||
    fail "successful import did not run before restart failure"

reset_fixture
print -r -- "running" >| "$__process_state"
if run_task "$__task_import" BETTERDISPLAY_STAT_FLIP=yes >| "$__fixture_dir/output" 2>&1; then
    fail "source identity change was accepted"
fi
if grep -qF "import" "$__log_file"; then
    fail "import ran after source identity changed"
fi

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
