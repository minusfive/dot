#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise config-directory migration compatibility..."

local __fixture_dir=''
local __installer_fixture=''
local __fixture_home=''
local __fixture_state=''
local __fixture_checkout=''
local __fixture_config=''
local __fixture_bin=''
local __fixture_canonical_bin=''
local __fixture_log=''
local __fixture_origin="https://github.com/minusfive/dot.git"
local __script="scripts/migrate-mise-config-dir.zsh"
local __installer="scripts/install-mise.zsh"
local __status=0

cleanup() {
    local __exit="$?"
    trap - EXIT INT TERM
    [[ -z "$__fixture_dir" ]] || rm -rf -- "$__fixture_dir"
    [[ -z "$__installer_fixture" ]] || rm -rf -- "$__installer_fixture"
    exit "$__exit"
}

fail() {
    echo "FAIL: $1"
    exit 1
}

__fixture_dir="$(test_fixture_dir config-dir-migration)" || {
    __status="$?"
    print -u2 -- "FAIL: could not create migration fixture directory"
    exit "$__status"
}
trap cleanup EXIT INT TERM

__fixture_home="$__fixture_dir/home"
__fixture_state="$__fixture_dir/state"
__fixture_checkout="$__fixture_home/dev/personal/dot"
__fixture_config="$__fixture_home/.config/mise"
__fixture_bin="$__fixture_dir/bin"
__fixture_canonical_bin="$__fixture_home/.local/bin"
__fixture_log="$__fixture_dir/mise.log"

fixture_env() {
    env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MODE="${MISE_MODE:-success}" \
        PATH="$__fixture_bin:$PATH" \
        "$@"
}

fixture_git() {
    env \
        HOME="$__fixture_home" \
        GIT_CONFIG_NOSYSTEM=1 \
        GIT_CONFIG_GLOBAL="$__fixture_dir/gitconfig" \
        git "$@"
}

reset_fixture_root() {
    find "$__fixture_dir" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

setup_fixture() {
    reset_fixture_root
    mkdir -p \
        "$__fixture_home/.config" \
        "$__fixture_canonical_bin" \
        "$__fixture_home/dev/personal" \
        "$__fixture_state" \
        "$__fixture_bin"
    mkdir -p \
        "$__fixture_checkout/home/.config/mise/conf.d/pip" \
        "$__fixture_checkout/home/.config/mise/conf.d/uv"
    fixture_git -C "$__fixture_checkout" init -q -b main
    fixture_git -C "$__fixture_checkout" config user.email test@example.com
    fixture_git -C "$__fixture_checkout" config user.name "mise test"
    fixture_git -C "$__fixture_checkout" config remote.origin.url "$__fixture_origin"
    print -r -- '[settings]' >| "$__fixture_checkout/home/.config/mise/config.toml"
    print -r -- '[tools]' >| "$__fixture_checkout/home/.config/mise/conf.d/example.toml"
    fixture_git -C "$__fixture_checkout" add .
    fixture_git -C "$__fixture_checkout" commit -qm initial
    cat >| "$__fixture_canonical_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'canonical\n' >> "$MISE_LOG"
    if [[ "${1:-}" == version && "${2:-}" == -q ]]; then
        printf '%s\n' "${MISE_VERSION_OUTPUT-2026.10.21 macos-arm64 (fixture)}"
        exit 0
    fi
        actual=("$@")
    expected=(
        --no-hooks
        bootstrap
        --from
        https://github.com/minusfive/dot.git
        --from-dir
        "$HOME/dev/personal/dot"
        --config-dir
        home/.config/mise
        --only
        files
        --yes
    )
    if [[ "${actual[7]:-}" == /* ]]; then
        printf 'absolute config-dir rejected\n' >&2
        exit 92
    fi
    if (( ${#actual[@]} != ${#expected[@]} )); then
        printf 'unexpected native bootstrap argument count\n' >&2
        exit 93
    fi
    for (( index = 0; index < ${#expected[@]}; index++ )); do
        if [[ "${actual[index]}" != "${expected[index]}" ]]; then
            printf 'unexpected native bootstrap argument %s: %s\n' \
                "$index" "${actual[index]}" >&2
            exit 94
        fi
    done
    printf '%s\n' "$*" >> "$MISE_LOG"
    if [[ "${MISE_MODE:-success}" == failure-no-link ]]; then
        exit 23
    fi
if [[ "${MISE_MODE:-success}" == failure ]]; then
    ln -s "$HOME/dev/personal/dot/home/.config/mise" "$HOME/.config/mise"
    printf 'hook ran\n' >| "$HOME/hook-ran"
    exit 23
fi
ln -s "$HOME/dev/personal/dot/home/.config/mise" "$HOME/.config/mise"
EOF
    chmod +x "$__fixture_canonical_bin/mise"
    cat >| "$__fixture_bin/mise" <<'EOF_CONFLICTING'
#!/usr/bin/env bash
set -euo pipefail
printf 'conflicting\n' >> "$MISE_LOG"
exit 91
EOF_CONFLICTING
    chmod +x "$__fixture_bin/mise"
    reset_old_target
    : >| "$__fixture_log"
}

reset_old_target() {
    rm -rf -- "$__fixture_config"
    mkdir -p "$__fixture_config/conf.d/pip" "$__fixture_config/conf.d/uv"
    ln -s "$__fixture_checkout/home/.config/mise/config.toml" "$__fixture_config/config.toml"
    ln -s "$__fixture_checkout/home/.config/mise/conf.d/example.toml" "$__fixture_config/conf.d/example.toml"
    print -r -- work-local >| "$__fixture_config/config.work.local.toml"
    print -r -- pip-config >| "$__fixture_config/conf.d/pip/config.pip.local.conf"
    print -r -- pip-mise >| "$__fixture_config/conf.d/pip/mise.work.local.toml"
    print -r -- uv-config >| "$__fixture_config/conf.d/uv/config.uv.local.toml"
    print -r -- uv-mise >| "$__fixture_config/conf.d/uv/mise.work.local.toml"
    print -r -- 'env = ["work"]' >| "$__fixture_config/miserc.local.toml"
}

run_migration() {
    fixture_env zsh "$__script" "$@"
}

run_migration_with_version_output() {
    local __version_output="$1"
    shift
    MISE_VERSION_OUTPUT="$__version_output" run_migration "$@"
}

run_migration_with_version_output_yes() {
    local __version_output="$1"
    shift
    printf 'y\n' | run_migration_with_version_output "$__version_output" "$@"
}

run_migration_with_state_home() {
    local __state_home="$1"
    shift
    env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__state_home" \
        MISE_LOG="$__fixture_log" \
        MISE_MODE="${MISE_MODE:-success}" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_yes() {
    printf 'y\n' | run_migration "$@"
}

run_migration_with_state_home_yes() {
    local __state_home="$1"
    shift
    printf 'y\n' | run_migration_with_state_home "$__state_home" "$@"
}

run_migration_with_source_target() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_checkout/home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_race() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_BEFORE_STALE_CLAIM="$__fixture_dir/replace-lock.zsh" \
        RACE_LOCK_DIR="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_owner_snapshot_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_OWNER_SNAPSHOT="$__fixture_dir/owner-snapshot-hook.zsh" \
        RACE_LOCK_DIR="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_stale_claim_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_STALE_CLAIM="$__fixture_dir/stale-claim-hook.zsh" \
        CLAIM_OWNER_FIXTURE="${MISE_MIGRATION_CLAIM_OWNER_FIXTURE:-}" \
        CLAIM_CASE="${CLAIM_CASE:-}" \
        MIGRATION_SCRIPT="$__script" \
        RACE_LOCK_DIR="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" \
        RACE_LOG="$__fixture_dir/race.log" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_backup_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_BACKUP_MOVE="$__fixture_dir/interrupt-after-backup.zsh" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_before_rollback_source_delete() {
    env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_BEFORE_ROLLBACK_SOURCE_DELETE="$__fixture_dir/mutate-rollback-source.zsh" \
        MUTATION_SOURCE="$__fixture_checkout/home/.config/mise/config.work.local.toml" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_rollback_source_stage() {
    env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_ROLLBACK_SOURCE_STAGE="$__fixture_dir/mutate-later-rollback-source.zsh" \
        MUTATION_SOURCE="$__fixture_checkout/home/.config/mise/conf.d/pip/mise.work.local.toml" \
        MUTATION_MARKER="$__fixture_dir/later-rollback-source.marker" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_manifest_write_failure() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_BEFORE_MANIFEST_WRITE="$__fixture_dir/fail-after-backup-move-manifest.zsh" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_initial_manifest_failure() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_BEFORE_MANIFEST_WRITE="$__fixture_dir/fail-initial-manifest.zsh" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_before_backup_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_BEFORE_BACKUP_MOVE="$__fixture_dir/interrupt-before-backup.zsh" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_selector_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_SELECTOR_MOVE="$__fixture_dir/interrupt-after-selector.zsh" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_lock_mkdir_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_LOCK_MKDIR="$__fixture_dir/interrupt-after-lock-mkdir.zsh" \
        RACE_LOCK_DIR="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

run_migration_after_owner_write_hook() {
    printf 'y\n' | env \
        HOME="$__fixture_home" \
        XDG_CONFIG_HOME="$__fixture_home/.config" \
        XDG_STATE_HOME="$__fixture_state" \
        MISE_LOG="$__fixture_log" \
        MISE_MIGRATION_TEST_AFTER_OWNER_WRITE="${MISE_MIGRATION_TEST_AFTER_OWNER_WRITE_PATH:-$__fixture_dir/interrupt-after-owner-write.zsh}" \
        RACE_LOCK_DIR="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" \
        PATH="$__fixture_bin:$PATH" \
        zsh "$__script" "$@"
}

expect_failure() {
    local __message="$1"
    local __expected="$2"
    shift 2
    if "$@" >| "$__fixture_dir/command.out" 2>&1; then
        cat "$__fixture_dir/command.out"
        fail "$__message unexpectedly succeeded"
    fi
    grep -qiF -- "$__expected" "$__fixture_dir/command.out" ||
        fail "$__message did not report $__expected"
}

assert_old_target() {
    [[ -L "$__fixture_config/config.toml" ]] || fail "old target link changed"
    [[ -f "$__fixture_config/config.work.local.toml" ]] || fail "old local file changed"
    [[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
        fail "old target operation wrote a transaction manifest"
}

snapshot_recovery_files() {
    local __snapshot="$1"
    shift
    python3 - "$__snapshot" "$@" <<'PY_RECOVERY_SNAPSHOT'
import hashlib
import os
import stat
import sys

snapshot, roots = sys.argv[1], sys.argv[2:]
records = []


def visit(label, path):
    info = os.lstat(path)
    mode = stat.S_IMODE(info.st_mode)
    if stat.S_ISLNK(info.st_mode):
        records.append((label, "symlink", oct(mode), os.readlink(path)))
        return
    if stat.S_ISREG(info.st_mode):
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
        records.append((label, "file", oct(mode), digest))
        return
    if stat.S_ISDIR(info.st_mode):
        records.append((label, "directory", oct(mode), ""))
        for name in sorted(os.listdir(path)):
            visit(f"{label}/{name}", os.path.join(path, name))
        return
    records.append((label, "other", oct(mode), str(info.st_mode)))


for index, root in enumerate(roots):
    if os.path.lexists(root):
        visit(f"{index}:{root}", root)
    else:
        records.append((f"{index}:{root}", "absent", "", ""))

with open(snapshot, "w", encoding="utf-8") as handle:
    for record in sorted(records):
        handle.write("\t".join(record) + "\n")
PY_RECOVERY_SNAPSHOT
}

mutate_recovery_json() {
    local __path="$1"
    local __case="$2"
    local __backup_alt="$3"
    python3 - "$__path" "$__case" "$__backup_alt" <<'PY_RECOVERY_MUTATION'
import json
import sys

path, case, backup_alt = sys.argv[1:]
raw = open(path, encoding="utf-8").read()
if case == "duplicate":
    raw = raw.replace('"schema": 1,', '"schema": 1, "schema": 1,', 1)
    open(path, "w", encoding="utf-8").write(raw)
    raise SystemExit(0)

document = json.loads(raw)
if case == "arbitrary":
    document["approved_files"][0]["path"] = "arbitrary.toml"
elif case == "tracked":
    pass
elif case == "optional":
    document["approved_files"][-1]["optional"] = False
elif case == "source-preexisting":
    document["source_preexisting_facts"][0]["source_preexisting"] = not document["source_preexisting_facts"][0]["source_preexisting"]
elif case == "digest":
    document["approved_files"][0]["sha256"] = "0" * 64
elif case == "mode":
    document["approved_files"][0]["mode"] = "600"
elif case == "unknown":
    document["unexpected"] = True
elif case == "backup-path":
    if "backup" in document:
        document["backup"] = backup_alt
    else:
        document["backup_entries"][0]["path"] = "tampered-backup-path"
elif case == "selector-metadata":
    document["selector_mode"] = "600"
elif case == "inconsistent-state":
    document["rollback_state"] = "staging"
else:
    raise SystemExit(f"unknown mutation: {case}")

with open(path, "w", encoding="utf-8") as handle:
    json.dump(document, handle, indent=2)
    handle.write("\n")
PY_RECOVERY_MUTATION
}

assert_recovery_tamper_rejected() {
    local __kind="$1"
    local __case="$2"
    local __expected="$3"
    local __manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
    local __inventory="$__backup_dir/source-inventory.json"
    local __pristine_manifest="$__fixture_dir/pristine-transaction.json"
    local __pristine_inventory="$__fixture_dir/pristine-source-inventory.json"
    local __before="$__fixture_dir/tamper-before.snapshot"
    local __after="$__fixture_dir/tamper-after.snapshot"
    local __lock="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
    cp "$__pristine_manifest" "$__manifest"
    cp "$__pristine_inventory" "$__inventory"
    if [[ "$__kind" == transaction ]]; then
        mutate_recovery_json "$__manifest" "$__case" \
            "$(realpath "$__fixture_state")/minusfive/mise-config-dir-migration/tampered-backup"
    else
        mutate_recovery_json "$__inventory" "$__case" \
            "$__fixture_state/minusfive/mise-config-dir-migration/backups/tampered"
    fi
    snapshot_recovery_files "$__before" \
        "$__fixture_config" \
        "$__fixture_checkout/home/.config/mise" \
        "$__fixture_state/minusfive/miserc.local.toml" \
        "$__backup_dir" \
        "$__manifest" \
        "$__inventory" \
        "$__lock"
    expect_failure "$__kind $__case rollback" "$__expected" run_migration --rollback
    snapshot_recovery_files "$__after" \
        "$__fixture_config" \
        "$__fixture_checkout/home/.config/mise" \
        "$__fixture_state/minusfive/miserc.local.toml" \
        "$__backup_dir" \
        "$__manifest" \
        "$__inventory" \
        "$__lock"
    [[ "$(cat "$__before")" == "$(cat "$__after")" ]] ||
        fail "$__kind $__case rollback changed the filesystem"
    [[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
        fail "$__kind $__case rollback created a lock"
    expect_failure "$__kind $__case backup removal" "$__expected" run_migration --remove-backup
    snapshot_recovery_files "$__after" \
        "$__fixture_config" \
        "$__fixture_checkout/home/.config/mise" \
        "$__fixture_state/minusfive/miserc.local.toml" \
        "$__backup_dir" \
        "$__manifest" \
        "$__inventory" \
        "$__lock"
    [[ "$(cat "$__before")" == "$(cat "$__after")" ]] ||
        fail "$__kind $__case backup removal changed the filesystem"
    [[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
        fail "$__kind $__case backup removal created a lock"
}

[[ -x "$__installer" ]] || fail "mise installer is missing or not executable"
[[ -x "$__script" ]] || fail "migration script is missing or not executable"
zsh -n "$__installer" "$__script" || fail "migration scripts have syntax errors"
grep -qF 'curl -fsSL https://mise.run | sh' "$__installer" ||
    fail "mise installer acquisition command is missing"
grep -qF '\"$HOME/.local/bin/mise\" bootstrap --from https://github.com/minusfive/dot.git' "$__installer" ||
    fail "mise installer next-step command is missing"
if grep -qF 'bootstrap --help' "$__installer" || grep -qF 'scripts/mise-env.zsh' "$__installer"; then
    fail "mise installer retains lifecycle or environment setup"
fi

__installer_fixture="$(test_fixture_dir mise-installer)" || {
    __status="$?"
    print -u2 -- "FAIL: could not create installer fixture directory"
    exit "$__status"
}
mkdir -p "$__installer_fixture/bin" "$__installer_fixture/home/.local/bin" "$__installer_fixture/source"
print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/source/mise"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/source/mise"
print -r -- 'if [[ "${1:-}" == version ]]; then' >> "$__installer_fixture/source/mise"
print -r -- '    printf "fixture-version\n"' >> "$__installer_fixture/source/mise"
print -r -- '    exit 0' >> "$__installer_fixture/source/mise"
print -r -- 'fi' >> "$__installer_fixture/source/mise"
print -r -- 'printf "%s\n" "$*" >> "$MISE_INSTALLER_LOG"' >> "$__installer_fixture/source/mise"
chmod +x "$__installer_fixture/source/mise"
print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/bin/curl"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/bin/curl"
print -r -- 'printf "%s\n" "$*" >> "$MISE_CURL_LOG"' >> "$__installer_fixture/bin/curl"
print -r -- "printf '%s\n' 'mkdir -p \"\$HOME/.local/bin\"' 'cp \"\$MISE_SOURCE\" \"\$HOME/.local/bin/mise\"' 'chmod +x \"\$HOME/.local/bin/mise\"'" >> "$__installer_fixture/bin/curl"
chmod +x "$__installer_fixture/bin/curl"
env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    MISE_SOURCE="$__installer_fixture/source/mise" \
    MISE_CURL_LOG="$__installer_fixture/curl.log" \
    MISE_INSTALLER_LOG="$__installer_fixture/installer.log" \
    zsh "$__installer" >| "$__installer_fixture/clean.out"
[[ -x "$__installer_fixture/home/.local/bin/mise" ]] ||
    fail "clean-machine installer did not install the canonical binary"
grep -qF "$__installer_fixture/home/.local/bin/mise" "$__installer_fixture/clean.out" ||
    fail "clean-machine installer did not print the canonical binary path"
grep -qF 'installed.' "$__installer_fixture/clean.out" ||
    fail "clean-machine installer did not report installation"
python3 - "$__installer_fixture/clean.out" "$__installer_fixture/home/.local/bin/mise" <<'PY_INSTALLER_COMMAND'
import re
import sys

output = open(sys.argv[1], encoding="utf-8").read()
output = re.sub(r"\x1b\[[0-9;]*m", "", output)
expected = (
    f'Run PATH="{sys.argv[2].rsplit("/", 1)[0]}:$PATH" "{sys.argv[2]}" bootstrap --from https://github.com/minusfive/dot.git '
    '--from-dir ~/dev/personal/dot --config-dir home/.config/mise --dry-run '
    'to review changes.'
)
assert expected in output
PY_INSTALLER_COMMAND

rm -f -- "$__installer_fixture/home/.local/bin/mise" "$__installer_fixture/curl.log"
print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/bin/curl"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/bin/curl"
print -r -- 'printf "help acquired mise\n" >> "$MISE_CURL_LOG"' >> "$__installer_fixture/bin/curl"
print -r -- 'exit 17' >> "$__installer_fixture/bin/curl"
chmod +x "$__installer_fixture/bin/curl"
env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    MISE_CURL_LOG="$__installer_fixture/curl.log" \
    zsh "$__installer" --help >| "$__installer_fixture/help.out"
grep -qF 'Usage:' "$__installer_fixture/help.out" || fail "installer help output is missing"
[[ ! -s "$__installer_fixture/curl.log" ]] || fail "installer help attempted acquisition"
[[ ! -e "$__installer_fixture/home/.local/bin/mise" ]] || fail "installer help acquired mise"

print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/bin/mise"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/bin/mise"
print -r -- 'printf "conflicting mise\n" >> "$MISE_INSTALLER_LOG"' >> "$__installer_fixture/bin/mise"
chmod +x "$__installer_fixture/bin/mise"
if env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    MISE_INSTALLER_LOG="$__installer_fixture/installer.log" \
    zsh "$__installer" >| "$__installer_fixture/conflict.out" 2>&1; then
    fail "installer accepted a non-canonical mise binary"
fi
grep -qF 'installed outside' "$__installer_fixture/conflict.out" ||
    fail "installer did not enforce the canonical binary path"
[[ ! -s "$__installer_fixture/installer.log" ]] ||
    fail "installer invoked the conflicting mise binary"

cp "$__installer_fixture/source/mise" "$__installer_fixture/home/.local/bin/mise"
chmod +x "$__installer_fixture/home/.local/bin/mise"
: >| "$__installer_fixture/installer.log"
env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    MISE_INSTALLER_LOG="$__installer_fixture/installer.log" \
    zsh "$__installer" >| "$__installer_fixture/existing.out"
grep -qF 'already installed' "$__installer_fixture/existing.out" ||
    fail "installer did not recognize the canonical binary"
grep -qF 'fixture-version' "$__installer_fixture/existing.out" ||
    fail "installer did not report the canonical binary version"

rm -f -- "$__installer_fixture/home/.local/bin/mise"
rm -f -- "$__installer_fixture/bin/mise"
print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/bin/curl"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/bin/curl"
print -r -- 'exit 19' >> "$__installer_fixture/bin/curl"
chmod +x "$__installer_fixture/bin/curl"
if env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    zsh "$__installer" >| "$__installer_fixture/acquire-failure.out" 2>&1; then
    fail "installer swallowed acquisition failure"
fi
grep -qF 'installation failed' "$__installer_fixture/acquire-failure.out" ||
    fail "installer did not report acquisition failure"

print -r -- '#!/usr/bin/env bash' >| "$__installer_fixture/home/.local/bin/mise"
print -r -- 'set -euo pipefail' >> "$__installer_fixture/home/.local/bin/mise"
print -r -- 'exit 41' >> "$__installer_fixture/home/.local/bin/mise"
chmod +x "$__installer_fixture/home/.local/bin/mise"
if env \
    HOME="$__installer_fixture/home" \
    PATH="$__installer_fixture/bin:/usr/bin:/bin" \
    zsh "$__installer" >| "$__installer_fixture/version-failure.out" 2>&1; then
    fail "installer swallowed canonical binary failure"
fi

setup_fixture
run_migration --help >| "$__fixture_dir/help.out"
grep -qF -- "--dry-run" "$__fixture_dir/help.out" || fail "migration help omits dry-run"
grep -qF -- "--rollback" "$__fixture_dir/help.out" || fail "migration help omits rollback"
grep -qF -- "--remove-backup" "$__fixture_dir/help.out" || fail "migration help omits backup removal"
grep -qF -- "--break-stale-lock" "$__fixture_dir/help.out" || fail "migration help omits stale-lock recovery"

local __target_snapshot
__target_snapshot="$(find "$__fixture_config" -type l -o -type f | sort)" ||
    fail "could not snapshot the old target"
run_migration --dry-run >| "$__fixture_dir/dry-run.out"
[[ "$__target_snapshot" == "$(find "$__fixture_config" -type l -o -type f | sort)" ]] ||
    fail "dry run changed the old target"
assert_old_target
[[ ! -e "$__fixture_home/hook-ran" ]] || fail "dry run ran a hook"

printf 'n\n' | run_migration >| "$__fixture_dir/refused.out"
grep -qF "cancelled" "$__fixture_dir/refused.out" || fail "confirmation refusal was not reported"
assert_old_target

setup_fixture
local __old_version_target_snapshot
__old_version_target_snapshot="$(find "$__fixture_config" -type l -o -type f | sort)" ||
    fail "could not snapshot the old target for the old-version case"
expect_failure "old mise version" "older than the minimum required version" \
    run_migration_with_version_output "2026.10.20 macos-arm64 (fixture)"
[[ "$__old_version_target_snapshot" == "$(find "$__fixture_config" -type l -o -type f | sort)" ]] ||
    fail "old mise version changed the old target"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "old mise version wrote migration state"

setup_fixture
local __invalid_version_state="$__fixture_state/minusfive/mise-config-dir-migration"
local __invalid_version_snapshot="$__fixture_dir/invalid-version.snapshot"
snapshot_recovery_files "$__invalid_version_snapshot" \
    "$__fixture_config" \
    "$__invalid_version_state/backups" \
    "$__invalid_version_state/transaction.json" \
    "$__invalid_version_state/transaction.lock"
expect_failure "empty mise version" "unparseable" \
    run_migration_with_version_output ""
snapshot_recovery_files "$__fixture_dir/invalid-version.after" \
    "$__fixture_config" \
    "$__invalid_version_state/backups" \
    "$__invalid_version_state/transaction.json" \
    "$__invalid_version_state/transaction.lock"
cmp -s "$__invalid_version_snapshot" "$__fixture_dir/invalid-version.after" ||
    fail "empty mise version changed migration files"

setup_fixture
run_migration_with_version_output_yes "2026.10.21 macos-arm64 (fixture)" >| "$__fixture_dir/minimum-version.out"
[[ -L "$__fixture_config" ]] || fail "minimum mise version did not allow the migration"

setup_fixture
fixture_git -C "$__fixture_checkout" config remote.origin.url https://github.com/example/wrong.git
expect_failure "origin preflight" "origin must be" run_migration_yes
assert_old_target

setup_fixture
print -r -- work-local >| "$__fixture_checkout/home/.config/mise/config.work.local.toml"
chmod 644 "$__fixture_checkout/home/.config/mise/config.work.local.toml"
fixture_git -C "$__fixture_checkout" add -f home/.config/mise/config.work.local.toml
fixture_git -C "$__fixture_checkout" commit -qm "track approved local file"
expect_failure "tracked approved source path" "tracked" run_migration_yes
assert_old_target
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "tracked approved source path created a migration lock"

setup_fixture
expect_failure "physical source target" "must be a symlink" run_migration_with_source_target
[[ -d "$__fixture_checkout/home/.config/mise" && ! -L "$__fixture_checkout/home/.config/mise" ]] ||
    fail "physical source target changed during rejection"

setup_fixture
print -r -- unknown >| "$__fixture_config/unknown.txt"
expect_failure "unknown old-target entry" "unknown old-target entry" run_migration_yes
assert_old_target

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
print -r -- '{' >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json"
expect_failure "malformed lock recovery" "malformed" run_migration_yes --break-stale-lock
assert_old_target

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<'EOF_DUPLICATE_OWNER'
{
  "pid": 999999,
  "uid": 501,
  "host": "duplicate-owner",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "duplicate-old",
  "token": "duplicate-new",
  "unexpected": "field"
}
EOF_DUPLICATE_OWNER
local __duplicate_owner="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json"
local __duplicate_owner_digest
__duplicate_owner_digest="$(shasum -a 256 "$__duplicate_owner" | cut -d ' ' -f 1)" ||
    fail "could not snapshot duplicate owner metadata"
local __duplicate_target_snapshot
__duplicate_target_snapshot="$(find "$__fixture_config" -type l -o -type f | sort)" ||
    fail "could not snapshot duplicate owner target"
expect_failure "duplicate and unknown owner fields" "duplicate field" run_migration_yes --break-stale-lock
[[ "$(shasum -a 256 "$__duplicate_owner" | cut -d ' ' -f 1)" == "$__duplicate_owner_digest" ]] ||
    fail "duplicate and unknown owner fields changed the lock"
[[ "$__duplicate_target_snapshot" == "$(find "$__fixture_config" -type l -o -type f | sort)" ]] ||
    fail "duplicate and unknown owner fields changed the target"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "duplicate and unknown owner fields wrote migration evidence"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<'EOF_UNKNOWN_OWNER'
{
  "pid": 999999,
  "uid": 501,
  "host": "unknown-owner",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "unknown-owner",
  "unexpected": "field"
}
EOF_UNKNOWN_OWNER
local __unknown_owner="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json"
local __unknown_owner_digest
__unknown_owner_digest="$(shasum -a 256 "$__unknown_owner" | cut -d ' ' -f 1)" ||
    fail "could not snapshot unknown owner metadata"
local __unknown_target_snapshot
__unknown_target_snapshot="$(find "$__fixture_config" -type l -o -type f | sort)" ||
    fail "could not snapshot unknown owner target"
expect_failure "unknown owner field" "unknown field" run_migration_yes --break-stale-lock
[[ "$(shasum -a 256 "$__unknown_owner" | cut -d ' ' -f 1)" == "$__unknown_owner_digest" ]] ||
    fail "unknown owner field changed the lock"
[[ "$__unknown_target_snapshot" == "$(find "$__fixture_config" -type l -o -type f | sort)" ]] ||
    fail "unknown owner field changed the target"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "unknown owner field wrote migration evidence"

setup_fixture
cat >| "$__fixture_dir/interrupt-after-lock-mkdir.zsh" <<'EOF_INTERRUPT_LOCK_HOOK'
#!/usr/bin/env zsh
exit 130
EOF_INTERRUPT_LOCK_HOOK
chmod +x "$__fixture_dir/interrupt-after-lock-mkdir.zsh"
__status=0
run_migration_after_lock_mkdir_hook >| "$__fixture_dir/interrupted-lock.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "interrupted lock acquisition did not preserve the interruption status"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "interrupted lock acquisition retained the lock created by this process"

setup_fixture
cat >| "$__fixture_dir/interrupt-after-owner-write.zsh" <<'EOF_INTERRUPT_OWNER_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
[[ -s "$RACE_LOCK_DIR/owner.json" ]] || exit 77
grep -qF '"token": "' "$RACE_LOCK_DIR/owner.json"
exit 130
EOF_INTERRUPT_OWNER_HOOK
chmod +x "$__fixture_dir/interrupt-after-owner-write.zsh"
__status=0
run_migration_after_owner_write_hook >| "$__fixture_dir/interrupted-owner.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "post-owner-write interruption did not preserve the interruption status"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "post-owner-write interruption retained this process's lock"

setup_fixture
cat >| "$__fixture_dir/interrupt-after-lock-mkdir.zsh" <<'EOF_UNKNOWN_LOCK_HOOK'
#!/usr/bin/env zsh
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999997,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "token": "unknown"' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
exit 130
EOF_UNKNOWN_LOCK_HOOK
    chmod +x "$__fixture_dir/interrupt-after-lock-mkdir.zsh"
    __status=0
    run_migration_after_lock_mkdir_hook >| "$__fixture_dir/unknown-lock.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "unknown lock interruption did not preserve the interruption status"
grep -qF '"token": "unknown"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "cleanup removed an unknown lock owner"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_ACTIVE
{
  "pid": $$,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "active"
}
EOF_ACTIVE
expect_failure "active lock recovery" "still active" run_migration_yes --break-stale-lock
assert_old_target
[[ -f "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ]] ||
    fail "active lock recovery removed another owner's lock"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_STALE
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "stale"
}
EOF_STALE
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
run_migration_yes --break-stale-lock >| "$__fixture_dir/stale.out"
[[ -f "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "stale-lock recovery did not complete"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_RACE_OLD
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "race-old"
}
EOF_RACE_OLD
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/replace-lock.zsh" <<'EOF_RACE_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
rm -rf -- "$RACE_LOCK_DIR"
mkdir -p -- "$RACE_LOCK_DIR"
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999998,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "token": "race-new"' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
EOF_RACE_HOOK
chmod +x "$__fixture_dir/replace-lock.zsh"
expect_failure "stale-lock replacement race" "changed during stale-lock recovery" run_migration_race --break-stale-lock
grep -qF '"token": "race-new"' "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "stale-lock replacement race removed the replacement owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim" ]] ||
    fail "stale-lock replacement race retained a claim on the replacement owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "stale-lock replacement race started a migration"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_RACE_VALIDATED
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "validated-old"
}
EOF_RACE_VALIDATED
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/stale-claim-hook.zsh" <<'EOF_RACE_AFTER_CLAIM_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
rm -rf -- "$RACE_LOCK_DIR"
mkdir -p -- "$RACE_LOCK_DIR"
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999997,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "token": "replacement-after-validation"' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
EOF_RACE_AFTER_CLAIM_HOOK
chmod +x "$__fixture_dir/stale-claim-hook.zsh"
expect_failure "post-claim replacement race" "changed during stale-lock recovery" \
    run_migration_after_stale_claim_hook --break-stale-lock
grep -qF '"token": "replacement-after-validation"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "post-claim replacement race removed the replacement owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim" ]] ||
    fail "post-claim replacement race retained a claim on the replacement owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "post-claim replacement race started a migration"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_SNAPSHOT_RACE
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "snapshot-old"
}
EOF_SNAPSHOT_RACE
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/owner-snapshot-hook.zsh" <<'EOF_OWNER_SNAPSHOT_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
rm -rf -- "$RACE_LOCK_DIR"
mkdir -p -- "$RACE_LOCK_DIR"
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999998,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "token": "snapshot-replacement"' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
EOF_OWNER_SNAPSHOT_HOOK
chmod +x "$__fixture_dir/owner-snapshot-hook.zsh"
expect_failure "owner snapshot replacement race" "changed during metadata snapshot" \
    run_migration_after_owner_snapshot_hook --break-stale-lock
grep -qF '"token": "snapshot-replacement"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "owner snapshot replacement race removed the replacement owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim" ]] ||
    fail "owner snapshot replacement race retained a recovery claim"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "owner snapshot replacement race started a migration"

for __claim_case in malformed duplicate unknown; do
    setup_fixture
    mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
    cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_CLAIM_STALE
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "claim-parser-old"
}
EOF_CLAIM_STALE
    touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
    case "$__claim_case" in
        malformed)
            print -r -- '{' >| "$__fixture_dir/claim-owner.json"
            ;;
        duplicate)
            cat >| "$__fixture_dir/claim-owner.json" <<'EOF_CLAIM_DUPLICATE'
{
  "pid": 999998,
  "uid": 501,
  "host": "claim-owner",
  "token": "claim-token-old",
  "token": "claim-token-new",
  "lock_token": "claim-parser-old",
  "lock_identity": "claim-lock"
}
EOF_CLAIM_DUPLICATE
            ;;
        unknown)
            cat >| "$__fixture_dir/claim-owner.json" <<'EOF_CLAIM_UNKNOWN'
{
  "pid": 999998,
  "uid": 501,
  "host": "claim-owner",
  "token": "claim-token",
  "lock_token": "claim-parser-old",
  "lock_identity": "claim-lock",
  "unexpected": "field"
}
EOF_CLAIM_UNKNOWN
            ;;
    esac
    cat >| "$__fixture_dir/stale-claim-hook.zsh" <<'EOF_CLAIM_PARSER_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
cp -- "$CLAIM_OWNER_FIXTURE" "$RACE_LOCK_DIR/recovery.claim/owner.json"
rm -f -- "$RACE_LOCK_DIR/owner.json"
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999997,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"token\": \"claim-parser-replacement-$CLAIM_CASE\"" >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
exit 130
EOF_CLAIM_PARSER_HOOK
    chmod +x "$__fixture_dir/stale-claim-hook.zsh"
    __status=0
    MISE_MIGRATION_CLAIM_OWNER_FIXTURE="$__fixture_dir/claim-owner.json" \
        CLAIM_CASE="$__claim_case" \
        run_migration_after_stale_claim_hook --break-stale-lock \
        >| "$__fixture_dir/claim-$__claim_case.out" 2>&1 || __status="$?"
    [[ "$__status" == 130 ]] ||
        fail "$__claim_case recovery-claim interruption did not preserve the interruption status"
    grep -qF '"token": "claim-parser-replacement-' \
        "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
        fail "$__claim_case recovery-claim cleanup overwrote another owner"
    [[ -f "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim/owner.json" ]] ||
        fail "$__claim_case recovery-claim cleanup removed malformed claim metadata"
    [[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
        fail "$__claim_case recovery-claim cleanup started a migration"
done

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_COMPETING_RECOVERY
{
  "pid": 999996,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "competing-old"
}
EOF_COMPETING_RECOVERY
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/stale-claim-hook.zsh" <<'EOF_COMPETING_RECOVERY_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
grep -qF '"token": "competing-old"' "$RACE_LOCK_DIR/owner.json"
__status=0
printf 'y\n' | env -u MISE_MIGRATION_TEST_AFTER_STALE_CLAIM \
    zsh "$MIGRATION_SCRIPT" --break-stale-lock >| "$RACE_LOG" 2>&1 || __status="$?"
[[ "$__status" != 0 ]]
grep -qF "stale-lock recovery is already in progress" "$RACE_LOG"
grep -qF '"token": "competing-old"' "$RACE_LOCK_DIR/owner.json"
EOF_COMPETING_RECOVERY_HOOK
chmod +x "$__fixture_dir/stale-claim-hook.zsh"
run_migration_after_stale_claim_hook --break-stale-lock >| "$__fixture_dir/competing-recovery.out"
[[ -f "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "competing stale-lock recovery prevented the owning recovery"
grep -qF '"state": "verified"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "competing stale-lock recovery did not preserve the transaction"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_STALE_INTERRUPT
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "stale-interrupt"
}
EOF_STALE_INTERRUPT
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/interrupt-after-owner-write.zsh" <<'EOF_INTERRUPT_STALE_OWNER_HOOK'
#!/usr/bin/env zsh
set -euo pipefail
[[ -s "$RACE_LOCK_DIR/owner.json" ]] || exit 77
grep -qF '"token": "' "$RACE_LOCK_DIR/owner.json"
exit 130
EOF_INTERRUPT_STALE_OWNER_HOOK
chmod +x "$__fixture_dir/interrupt-after-owner-write.zsh"
__status=0
run_migration_after_owner_write_hook --break-stale-lock >| "$__fixture_dir/interrupted-stale-owner.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "stale-lock post-owner-write interruption did not preserve the interruption status"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "stale-lock post-owner-write interruption retained this process's lock"
[[ -z "$(find "$__fixture_state/minusfive/mise-config-dir-migration" -maxdepth 1 -name 'transaction.lock.stale.*' -print -quit)" ]] ||
    fail "stale-lock post-owner-write interruption retained the quarantined lock"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_STALE_REPLACEMENT
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "stale-replacement"
}
EOF_STALE_REPLACEMENT
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_dir/replace-owner-after-install.zsh" <<'EOF_REPLACE_OWNER_AFTER_INSTALL'
#!/usr/bin/env zsh
set -euo pipefail
rm -f -- "$RACE_LOCK_DIR/owner.json"
print -r -- '{' >| "$RACE_LOCK_DIR/owner.json"
print -r -- '  "pid": 999998,' >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"uid\": $(id -u)," >> "$RACE_LOCK_DIR/owner.json"
print -r -- "  \"host\": \"$(hostname)\"," >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "started_at": "2020-01-01T00:00:00Z",' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '  "token": "replacement-after-install"' >> "$RACE_LOCK_DIR/owner.json"
print -r -- '}' >> "$RACE_LOCK_DIR/owner.json"
EOF_REPLACE_OWNER_AFTER_INSTALL
chmod +x "$__fixture_dir/replace-owner-after-install.zsh"
cp "$__fixture_dir/replace-owner-after-install.zsh" \
    "$__fixture_dir/interrupt-after-owner-write.zsh"
expect_failure "post-install owner replacement race" "compare-and-swap" \
    run_migration_after_owner_write_hook --break-stale-lock
grep -qF '"token": "replacement-after-install"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "post-install owner replacement removed the replacement owner"
[[ -f "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim/stale-owner.json" ]] ||
    fail "post-install owner replacement discarded the quarantined stale owner"
[[ -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim" ]] ||
    fail "post-install owner replacement released its recovery claim"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "post-install owner replacement started a migration"

setup_fixture
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_STALE_WRITE_FAILURE
{
  "pid": 999999,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "stale-write-failure"
}
EOF_STALE_WRITE_FAILURE
touch -t 202001010000 "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_bin/ln" <<'EOF_FAIL_OWNER_LN'
#!/usr/bin/env bash
set -euo pipefail
destination="${@: -1}"
if [[ "$destination" == */transaction.lock/owner.json ]]; then
    exit 77
fi
exec /bin/ln "$@"
EOF_FAIL_OWNER_LN
chmod +x "$__fixture_bin/ln"
__status=0
run_migration_yes --break-stale-lock >| "$__fixture_dir/stale-owner-write-failure.out" 2>&1 || __status="$?"
[[ "$__status" == 77 ]] || fail "stale-owner write failure status was not preserved"
grep -qF '"token": "stale-write-failure"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "stale-owner write failure did not restore the old owner"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim" ]] ||
    fail "stale-owner write failure retained its recovery claim after restoration"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/recovery.claim/stale-owner.json" ]] ||
    fail "stale-owner write failure retained the restored stale owner"

setup_fixture
cat >| "$__fixture_dir/interrupt-after-backup.zsh" <<'EOF_INTERRUPT_HOOK'
#!/usr/bin/env zsh
exit 130
EOF_INTERRUPT_HOOK
chmod +x "$__fixture_dir/interrupt-after-backup.zsh"
__status=0
run_migration_after_backup_hook >| "$__fixture_dir/interrupted.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "interrupted backup move did not preserve the interruption status"
local __interrupted_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "backup_pending"' "$__interrupted_manifest" ||
    fail "interrupted backup move was not rollback-eligible"
[[ -n "$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 2 -maxdepth 2 -type d -name config-dir -print -quit)" ]] ||
    fail "interrupted backup move did not retain the backup"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "interrupted backup move left the old target in place"
run_migration --rollback >| "$__fixture_dir/interrupted-rollback.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "interrupted backup rollback did not restore the old target"
[[ -L "$__fixture_config/config.toml" ]] || fail "interrupted backup rollback lost old entries"

setup_fixture
cat >| "$__fixture_dir/fail-after-backup-move-manifest.zsh" <<'EOF_MANIFEST_FAILURE'
#!/usr/bin/env zsh
set -euo pipefail
count_file="${MISE_LOG}.manifest-count"
count=0
[[ -f "$count_file" ]] && count="$(cat "$count_file")"
count=$((count + 1))
print -r -- "$count" >| "$count_file"
if (( count == 5 )); then
    exit 77
fi
EOF_MANIFEST_FAILURE
chmod +x "$__fixture_dir/fail-after-backup-move-manifest.zsh"
__status=0
run_migration_manifest_write_failure >| "$__fixture_dir/manifest-write-failure.out" 2>&1 || __status="$?"
[[ "$__status" == 77 ]] || fail "manifest write failure did not preserve the failure status"
local __manifest_write_failure="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "failed"' "$__manifest_write_failure" ||
    fail "manifest write failure did not retain the failed state"
grep -qF '"backup_moved": true' "$__manifest_write_failure" ||
    fail "manifest write failure did not retain the completed move state"
local __manifest_write_failure_backup
__manifest_write_failure_backup="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 2 -maxdepth 2 -type d -name config-dir -print -quit)" ||
    fail "could not locate the preserved manifest-write backup"
[[ -n "$__manifest_write_failure_backup" ]] ||
    fail "manifest write failure did not retain the moved backup"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "manifest write failure left the old target in place"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "manifest write failure retained the interrupted migration lock"
print -r -- unexpected >| "$__manifest_write_failure_backup/unexpected"
expect_failure "unexpected reconciled backup entry" "unexpected" run_migration --rollback
[[ -f "$__manifest_write_failure_backup/unexpected" ]] ||
    fail "unexpected reconciled backup entry was removed"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "unexpected reconciled backup entry acquired a rollback lock"
rm -f -- "$__manifest_write_failure_backup/unexpected"
run_migration --rollback >| "$__fixture_dir/manifest-write-failure-rollback.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "manifest write failure rollback did not restore the old target"
[[ -L "$__fixture_config/config.toml" ]] ||
    fail "manifest write failure rollback lost old entries"
[[ ! -d "$__manifest_write_failure_backup" ]] ||
    fail "manifest write failure rollback retained the consumed backup"
grep -qF '"state": "rolled_back"' "$__manifest_write_failure" ||
    fail "manifest write failure rollback did not finalize the transaction"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "manifest write failure rollback retained its lock"

setup_fixture
cat >| "$__fixture_dir/fail-initial-manifest.zsh" <<'EOF_INITIAL_MANIFEST_FAILURE'
#!/usr/bin/env zsh
exit 77
EOF_INITIAL_MANIFEST_FAILURE
chmod +x "$__fixture_dir/fail-initial-manifest.zsh"
__status=0
run_migration_initial_manifest_failure >| "$__fixture_dir/initial-manifest-failure.out" 2>&1 || __status="$?"
[[ "$__status" == 77 ]] || fail "initial manifest failure did not preserve the failure status"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ]] ||
    fail "initial manifest failure left an unusable transaction manifest"
[[ ! -e "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "initial manifest failure retained its migration lock"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "initial manifest failure changed the old target"
run_migration --rollback >| "$__fixture_dir/initial-manifest-rollback.out"
grep -qF "No migration transaction is available" "$__fixture_dir/initial-manifest-rollback.out" ||
    fail "early rollback did not report its safe no-op"
run_migration_yes >| "$__fixture_dir/initial-manifest-rerun.out"
grep -qF '"state": "verified"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "early-state rerun did not create a verified transaction"

setup_fixture
cat >| "$__fixture_dir/interrupt-before-backup.zsh" <<'EOF_INTERRUPT_BEFORE_BACKUP_HOOK'
#!/usr/bin/env zsh
exit 130
EOF_INTERRUPT_BEFORE_BACKUP_HOOK
chmod +x "$__fixture_dir/interrupt-before-backup.zsh"
__status=0
run_migration_before_backup_hook >| "$__fixture_dir/interrupted-before-backup.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "pre-move interruption did not preserve the interruption status"
local __pre_move_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "backup_pending"' "$__pre_move_manifest" ||
    fail "pre-move interruption was not rollback-eligible"
grep -qF '"backup_moved": false' "$__pre_move_manifest" ||
    fail "pre-move interruption did not record that the target move was incomplete"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "pre-move interruption changed the old target"
[[ -z "$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 2 -maxdepth 2 -type d -name config-dir -print -quit)" ]] ||
    fail "pre-move interruption created a moved backup"
run_migration --rollback >| "$__fixture_dir/interrupted-before-backup-rollback.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "pre-move rollback did not retain the old target"
grep -qF '"state": "rolled_back"' "$__pre_move_manifest" ||
    fail "pre-move rollback did not finalize the transaction"

setup_fixture
mkdir -p "$__fixture_state/minusfive"
print -r -- 'env = ["work"]' >| "$__fixture_state/minusfive/miserc.local.toml"
chmod 644 "$__fixture_state/minusfive/miserc.local.toml"
local __external_selector_digest
__external_selector_digest="$(shasum -a 256 "$__fixture_state/minusfive/miserc.local.toml" | cut -d ' ' -f 1)" ||
    fail "could not snapshot the external selector"
cat >| "$__fixture_dir/interrupt-after-selector.zsh" <<'EOF_INTERRUPT_SELECTOR_HOOK'
#!/usr/bin/env zsh
exit 130
EOF_INTERRUPT_SELECTOR_HOOK
chmod +x "$__fixture_dir/interrupt-after-selector.zsh"
__status=0
run_migration_after_selector_hook >| "$__fixture_dir/interrupted-selector.out" 2>&1 || __status="$?"
[[ "$__status" == 130 ]] || fail "selector interruption did not preserve the interruption status"
local __selector_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"selector_preexisting": true' "$__selector_manifest" ||
    fail "selector interruption did not record preexisting external state"
[[ "$(shasum -a 256 "$__fixture_state/minusfive/miserc.local.toml" | cut -d ' ' -f 1)" == "$__external_selector_digest" ]] ||
    fail "selector staging overwrote the existing external selector"
run_migration --rollback >| "$__fixture_dir/interrupted-selector-rollback.out"
[[ "$(shasum -a 256 "$__fixture_state/minusfive/miserc.local.toml" | cut -d ' ' -f 1)" == "$__external_selector_digest" ]] ||
    fail "selector rollback changed the preexisting external selector"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "selector rollback did not restore the old target"
[[ ! -e "$__fixture_checkout/home/.config/mise/miserc.local.toml" && ! -L "$__fixture_checkout/home/.config/mise/miserc.local.toml" ]] ||
    fail "selector rollback left a migration-owned selector link"

print -r -- "[partial-staging] preparing the copy-failure fixture"
setup_fixture
cat >| "$__fixture_bin/cp" <<EOF_PARTIAL_CP
#!/usr/bin/env bash
set -euo pipefail
count_file="$__fixture_dir/cp.count"
count=0
[[ -f "\$count_file" ]] && count="\$(cat "\$count_file")"
count=\$((count + 1))
printf '%s\n' "\$count" >| "\$count_file"
if (( count == 1 )); then
    exec /bin/cp "\$@"
fi
exit 77
EOF_PARTIAL_CP
chmod +x "$__fixture_bin/cp"
print -r -- "[partial-staging] running the interrupted staging transaction"
__status=0
run_migration_yes >| "$__fixture_dir/partial-staging.out" 2>&1 || __status="$?"
[[ "$__status" == 77 ]] || fail "partial staging failure status was not preserved"
local __partial_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "failed"' "$__partial_manifest" ||
    fail "partial staging failure did not persist failed state"
grep -qF '"rollback_state": "staging"' "$__partial_manifest" ||
    fail "partial staging failure did not retain staging rollback state"
print -r -- modified >| "$__fixture_checkout/home/.config/mise/config.work.local.toml"
print -r -- unknown >| "$__fixture_checkout/home/.config/mise/unknown.partial"
print -r -- "[partial-staging] rolling back; modified-entry stderr is expected"
run_migration --rollback >| "$__fixture_dir/partial-rollback.out" 2>&1
grep -qF "retaining modified migration entry: config.work.local.toml" \
    "$__fixture_dir/partial-rollback.out" ||
    fail "partial staging rollback did not capture its expected stderr"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "partial staging rollback did not restore the old target"
[[ "$(cat "$__fixture_checkout/home/.config/mise/config.work.local.toml")" == modified ]] ||
    fail "partial staging rollback removed a modified migration entry"
[[ -f "$__fixture_checkout/home/.config/mise/unknown.partial" ]] ||
    fail "partial staging rollback removed an unknown source entry"
print -r -- "[partial-staging] rollback completed"

setup_fixture
cat >| "$__fixture_bin/cp" <<EOF_SELECTOR_CP
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${3:-}" == *'/miserc.local.toml.tmp.'* ]]; then
    exit 77
fi
exec /bin/cp "\$@"
EOF_SELECTOR_CP
chmod +x "$__fixture_bin/cp"
__status=0
run_migration_yes >| "$__fixture_dir/selector-copy-failure.out" 2>&1 || __status="$?"
[[ "$__status" == 77 ]] || fail "selector copy failure status was not preserved"
local __selector_failure_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "failed"' "$__selector_failure_manifest" ||
    fail "selector copy failure did not persist failed state"
grep -qF '"rollback_state": "staging"' "$__selector_failure_manifest" ||
    fail "selector copy failure did not retain staging rollback state"
[[ -z "$(find "$__fixture_state" -name 'miserc.local.toml.tmp.*' -print -quit)" ]] ||
    fail "selector copy failure left a temporary selector file"

print -r -- "[manifest-chmod] injecting the final manifest chmod failure"
setup_fixture
cat >| "$__fixture_bin/chmod" <<EOF_MANIFEST_CHMOD
#!/usr/bin/env bash
set -euo pipefail
count_file="$__fixture_dir/manifest-chmod.count"
count=0
[[ -f "\$count_file" ]] && count="\$(cat "\$count_file")"
if [[ "\${2:-}" == *'/transaction.json.tmp.'* ]]; then
    count=\$((count + 1))
    printf '%s\n' "\$count" >| "\$count_file"
    if (( count == 10 )); then
        exit 77
    fi
fi
exec /bin/chmod "\$@"
EOF_MANIFEST_CHMOD
chmod +x "$__fixture_bin/chmod"
__status=0
run_migration_yes >| "$__fixture_dir/manifest-chmod.out" 2>&1 || __status="$?"
[[ "$__status" == 1 ]] || fail "manifest chmod failure status was not preserved"
local __manifest_chmod="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "failed"' "$__manifest_chmod" ||
    fail "manifest chmod failure did not preserve failed state"
[[ -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] &&
    fail "manifest chmod failure retained the migration lock"
local __manifest_chmod_backup
__manifest_chmod_backup="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the preserved chmod-failure backup"
[[ -d "$__manifest_chmod_backup/config-dir" ]] ||
    fail "manifest chmod failure did not preserve the backup"
print -r -- "[manifest-chmod] recovering the preserved transaction"
run_migration --rollback >| "$__fixture_dir/manifest-chmod-rollback.out" 2>&1
grep -qF '"state": "rolled_back"' "$__manifest_chmod" ||
    fail "manifest chmod failure was not recoverable"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "manifest chmod recovery did not restore the old target"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "manifest chmod recovery retained the rollback lock"

print -r -- "[manifest-mv] injecting the final atomic manifest move failure"
setup_fixture
cat >| "$__fixture_bin/mv" <<EOF_MANIFEST_MV
#!/usr/bin/env bash
set -euo pipefail
count_file="$__fixture_dir/manifest-mv.count"
count=0
[[ -f "\$count_file" ]] && count="\$(cat "\$count_file")"
destination="\${@: -1}"
if [[ "\$destination" == */transaction.json ]]; then
    count=\$((count + 1))
    printf '%s\n' "\$count" >| "\$count_file"
    if (( count == 10 )); then
        exit 77
    fi
fi
exec /bin/mv "\$@"
EOF_MANIFEST_MV
chmod +x "$__fixture_bin/mv"
__status=0
run_migration_yes >| "$__fixture_dir/manifest-mv.out" 2>&1 || __status="$?"
[[ "$__status" == 1 ]] || fail "manifest atomic move failure status was not preserved"
local __manifest_mv="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
grep -qF '"state": "failed"' "$__manifest_mv" ||
    fail "manifest atomic move failure did not preserve failed state"
[[ -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] &&
    fail "manifest atomic move failure retained the migration lock"
local __manifest_mv_backup
__manifest_mv_backup="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the preserved manifest-move backup"
[[ -d "$__manifest_mv_backup/config-dir" ]] ||
    fail "manifest atomic move failure did not preserve the backup"
print -r -- "[manifest-mv] recovering the preserved transaction"
run_migration --rollback >| "$__fixture_dir/manifest-mv-rollback.out" 2>&1
grep -qF '"state": "rolled_back"' "$__manifest_mv" ||
    fail "manifest atomic move failure was not recoverable"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "manifest atomic move recovery did not restore the old target"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "manifest atomic move recovery retained the rollback lock"

setup_fixture
run_migration_yes >| "$__fixture_dir/migration.out"
local __manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
local __backup_dir
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the migration backup"
[[ -L "$__fixture_config" ]] || fail "migration did not create the config-directory link"
for __approved_file in \
    config.work.local.toml \
    conf.d/pip/config.pip.local.conf \
    conf.d/pip/mise.work.local.toml \
    conf.d/uv/config.uv.local.toml \
    conf.d/uv/mise.work.local.toml \
    miserc.local.toml; do
    [[ -f "$__fixture_config/$__approved_file" || -L "$__fixture_config/$__approved_file" ]] ||
        fail "migration did not stage $__approved_file"
done
local __selector_state
__selector_state="$(realpath "$__fixture_state/minusfive/miserc.local.toml")" ||
    fail "could not resolve the migration selector"
[[ "$(readlink "$__fixture_checkout/home/.config/mise/miserc.local.toml")" == "$__selector_state" ]] ||
    fail "migration selector link does not target the exact state file"
python3 - "$__selector_state" <<'PY_SELECTOR'
import sys
from pathlib import Path

assert Path(sys.argv[1]).read_bytes() == b'env = ["work"]\n'
PY_SELECTOR
local __selector_digest
__selector_digest="$(shasum -a 256 "$__selector_state" | cut -d ' ' -f 1)" ||
    fail "could not snapshot the migration selector"
python3 - "$__manifest" "$__selector_digest" "$__selector_state" <<'PY_SELECTOR_MANIFEST'
import json
import sys

manifest = json.loads(open(sys.argv[1], encoding="utf-8").read())
selector = next(entry for entry in manifest["approved_files"] if entry["path"] == "miserc.local.toml")
assert selector["sha256"] == sys.argv[2]
assert selector["link_target"] == sys.argv[3]
PY_SELECTOR_MANIFEST
python3 - "$__manifest" <<'PY_BACKUP_METADATA'
import json
import os
import sys

manifest = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert manifest["backup_entries"]
for entry in manifest["backup_entries"]:
    assert entry["owner"] == str(os.getuid())
    if entry["source_type"] == "symlink":
        assert entry["link_target"] != "-"
    else:
        assert entry["link_target"] == "-"
PY_BACKUP_METADATA
grep -qF -- '--no-hooks bootstrap --from https://github.com/minusfive/dot.git' "$__fixture_log" ||
    fail "migration did not use the exact native command"
grep -qF -- 'canonical' "$__fixture_log" ||
    fail "migration did not use the canonical installed mise binary"
if grep -qF -- 'conflicting' "$__fixture_log"; then
    fail "migration used the conflicting PATH mise binary"
fi
grep -qF -- '--only files --yes' "$__fixture_log" ||
    fail "migration omitted the files-only native command"
[[ ! -e "$__fixture_home/hook-ran" ]] || fail "migration ran a lifecycle hook"
if env \
    HOME="$__fixture_home" \
    MISE_LOG="$__fixture_log" \
    MISE_MODE=success \
    "$__fixture_canonical_bin/mise" \
    --no-hooks bootstrap \
    --from "$__fixture_origin" \
    --from-dir "$__fixture_checkout" \
    --config-dir "$__fixture_checkout/home/.config/mise" \
    --only files \
    --yes >| "$__fixture_dir/absolute-config-dir.out" 2>&1; then
    fail "fixture accepted a conflicting absolute config-dir invocation"
fi
grep -qF -- "absolute config-dir rejected" "$__fixture_dir/absolute-config-dir.out" ||
    fail "fixture did not reject a conflicting absolute config-dir invocation"
if stat -f '%Lp' "$__manifest" 2>/dev/null | grep -Eq '^[0-9]+$'; then
    [[ "$(stat -f '%Lp' "$__manifest")" == 600 ]] || fail "transaction manifest is not mode 0600"
else
    [[ "$(stat -c '%a' "$__manifest")" == 600 ]] || fail "transaction manifest is not mode 0600"
fi
[[ ! -e "$__manifest.tmp" ]] || fail "transaction manifest left a temporary file"
[[ -z "$(find "$__fixture_state/minusfive/mise-config-dir-migration" -maxdepth 1 -name 'transaction.json.tmp.*' -print -quit)" ]] ||
    fail "transaction manifest left an atomic-write temporary file"
[[ -d "$__backup_dir/config-dir" ]] || fail "migration did not retain the timestamped backup"
grep -qF '"state": "verified"' "$__manifest" || fail "migration did not verify the transaction"
python3 - "$__manifest" "$__fixture_canonical_bin/mise" "$__fixture_checkout" <<'PY_MANIFEST'
import json
import sys

manifest = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert manifest["native_command"] == [
    sys.argv[2],
    "--no-hooks",
    "bootstrap",
    "--from",
    "https://github.com/minusfive/dot.git",
    "--from-dir",
    sys.argv[3],
    "--config-dir",
    "home/.config/mise",
    "--only",
    "files",
    "--yes",
]
assert manifest["schema"] == 1
assert manifest["state"] == "verified"
assert manifest["origin"] == "https://github.com/minusfive/dot.git"
assert isinstance(manifest["backup_entries"], list)
assert isinstance(manifest["approved_files"], list)
assert len(manifest["approved_files"]) == 6
assert {
    entry["path"]
    for entry in manifest["approved_files"]
} == {
    "config.work.local.toml",
    "conf.d/pip/config.pip.local.conf",
    "conf.d/pip/mise.work.local.toml",
    "conf.d/uv/config.uv.local.toml",
    "conf.d/uv/mise.work.local.toml",
    "miserc.local.toml",
}
PY_MANIFEST
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "migration retained its completed lock"
run_migration >| "$__fixture_dir/verified-rerun.out"
grep -qF "already verified" "$__fixture_dir/verified-rerun.out" ||
    fail "verified rerun did not pass the recorded guards"

cp "$__manifest" "$__fixture_dir/pristine-transaction.json"
cp "$__backup_dir/source-inventory.json" "$__fixture_dir/pristine-source-inventory.json"
for __tamper_case __tamper_expected in \
    arbitrary "source_preexisting facts do not cover approved_files exactly" \
    optional optional \
    source-preexisting "source_preexisting" \
    digest "facts changed" \
    mode "facts changed" \
    unknown "unknown field" \
    backup-path "manifest backup is outside" \
    selector-metadata "selector metadata" \
    inconsistent-state "state and rollback_state combination" \
    duplicate "duplicate field"; do
    assert_recovery_tamper_rejected transaction "$__tamper_case" "$__tamper_expected"
done

print -r -- work-local >| "$__fixture_checkout/home/.config/mise/config.work.local.toml"
fixture_git -C "$__fixture_checkout" add -f home/.config/mise/config.work.local.toml
fixture_git -C "$__fixture_checkout" commit -qm "track approved local file for transaction recovery check"
assert_recovery_tamper_rejected transaction tracked tracked
fixture_git -C "$__fixture_checkout" rm --cached -q home/.config/mise/config.work.local.toml
fixture_git -C "$__fixture_checkout" commit -qm "restore approved local file to untracked state"

for __tamper_case __tamper_expected in \
    arbitrary "source_preexisting facts do not cover approved_files exactly" \
    optional "facts changed" \
    source-preexisting "source_preexisting" \
    digest "facts changed" \
    mode "facts changed" \
    unknown "top-level fields are not exact" \
    backup-path "unknown path" \
    duplicate "duplicate field"; do
    assert_recovery_tamper_rejected inventory "$__tamper_case" "$__tamper_expected"
done

fixture_git -C "$__fixture_checkout" add -f home/.config/mise/config.work.local.toml
fixture_git -C "$__fixture_checkout" commit -qm "track approved local file for inventory recovery check"
assert_recovery_tamper_rejected inventory tracked tracked
fixture_git -C "$__fixture_checkout" rm --cached -q home/.config/mise/config.work.local.toml
fixture_git -C "$__fixture_checkout" commit -qm "restore approved local file to untracked state"

setup_fixture
run_migration_yes >| "$__fixture_dir/atomic-rollback.out"
local __atomic_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
local __atomic_backup_dir
__atomic_backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the atomic rollback backup"
print -r -- changed >| "$__fixture_checkout/home/.config/mise/conf.d/pip/config.pip.local.conf"
snapshot_recovery_files "$__fixture_dir/atomic-rollback-before.snapshot" \
    "$__fixture_config" \
    "$__fixture_checkout/home/.config/mise" \
    "$__fixture_state/minusfive/miserc.local.toml" \
    "$__atomic_backup_dir" \
    "$__atomic_manifest" \
    "$__atomic_backup_dir/source-inventory.json" \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
expect_failure "later rollback source entry" "digest" run_migration --rollback
snapshot_recovery_files "$__fixture_dir/atomic-rollback-after.snapshot" \
    "$__fixture_config" \
    "$__fixture_checkout/home/.config/mise" \
    "$__fixture_state/minusfive/miserc.local.toml" \
    "$__atomic_backup_dir" \
    "$__atomic_manifest" \
    "$__atomic_backup_dir/source-inventory.json" \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
[[ "$(cat "$__fixture_dir/atomic-rollback-before.snapshot")" == \
    "$(cat "$__fixture_dir/atomic-rollback-after.snapshot")" ]] ||
    fail "later rollback source entry changed the filesystem before validation completed"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-stage-race.out"
cat >| "$__fixture_dir/mutate-later-rollback-source.zsh" <<'EOF_MUTATE_LATER_ROLLBACK_SOURCE'
#!/usr/bin/env zsh
set -euo pipefail
if [[ ! -e "$MUTATION_MARKER" ]]; then
    print -r -- changed >| "$MUTATION_SOURCE"
    : >| "$MUTATION_MARKER"
fi
EOF_MUTATE_LATER_ROLLBACK_SOURCE
chmod +x "$__fixture_dir/mutate-later-rollback-source.zsh"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the staged rollback-race backup"
expect_failure "later rollback source staging race" "digest" \
    run_migration_after_rollback_source_stage --rollback
[[ "$(cat "$__fixture_checkout/home/.config/mise/conf.d/pip/config.pip.local.conf")" == pip-config ]] ||
    fail "later rollback source staging race did not restore the first staged entry"
[[ "$(cat "$__fixture_checkout/home/.config/mise/conf.d/pip/mise.work.local.toml")" == changed ]] ||
    fail "later rollback source staging race did not preserve the later mutation"
[[ -L "$__fixture_config" ]] || fail "later rollback source staging race changed the target"
[[ -d "$__backup_dir/config-dir" ]] ||
    fail "later rollback source staging race consumed the backup"
grep -qF '"state": "verified"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "later rollback source staging race changed the transaction manifest"

setup_fixture
run_migration_yes >| "$__fixture_dir/remove-setup.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the backup-removal backup"
[[ -n "$__backup_dir" && -d "$__backup_dir/config-dir" ]] ||
    fail "backup-removal setup did not create a backup"
run_migration --remove-backup >| "$__fixture_dir/remove.out"
grep -qF '"state": "committed"' "$__manifest" || fail "backup removal did not commit"
[[ ! -d "$__backup_dir" ]] || fail "backup removal did not remove the backup"
run_migration >| "$__fixture_dir/committed-rerun.out"
grep -qF "already committed" "$__fixture_dir/committed-rerun.out" ||
    fail "committed rerun did not pass the recorded guards"

setup_fixture
rm -f -- "$__fixture_config/miserc.local.toml"
mkdir -p "$__fixture_state/minusfive"
print -r -- 'env = ["work"]' >| "$__fixture_state/minusfive/miserc.local.toml"
chmod 644 "$__fixture_state/minusfive/miserc.local.toml"
ln -s "$__fixture_state/minusfive/miserc.local.toml" \
    "$__fixture_config/miserc.local.toml"
run_migration_yes >| "$__fixture_dir/symlink-selector-migration.out"
local __symlink_selector_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
python3 - "$__symlink_selector_manifest" <<'PY_SYMLINK_SELECTOR_MANIFEST'
import json
import sys

manifest = json.loads(open(sys.argv[1], encoding="utf-8").read())
selector = next(
    entry for entry in manifest["approved_files"]
    if entry["path"] == "miserc.local.toml"
)
backup_selector = next(
    entry for entry in manifest["backup_entries"]
    if entry["path"] == "miserc.local.toml"
)
assert selector["source_type"] == "symlink"
assert backup_selector["source_type"] == "symlink"
assert manifest["selector_type"] == "symlink"
PY_SYMLINK_SELECTOR_MANIFEST
run_migration --rollback >| "$__fixture_dir/symlink-selector-rollback.out"
[[ -L "$__fixture_config/miserc.local.toml" ]] ||
    fail "symlink selector rollback did not restore the selector link"
[[ "$(readlink "$__fixture_config/miserc.local.toml")" == \
    "$__fixture_state/minusfive/miserc.local.toml" ]] ||
    fail "symlink selector rollback changed the selector target"
[[ -f "$__fixture_state/minusfive/miserc.local.toml" &&
    ! -L "$__fixture_state/minusfive/miserc.local.toml" ]] ||
    fail "symlink selector rollback changed the canonical selector state"

setup_fixture
local __noncanonical_state="$__fixture_dir/state/../state"
run_migration_with_state_home_yes "$__noncanonical_state" >| "$__fixture_dir/noncanonical-state.out"
run_migration_with_state_home "$__noncanonical_state" >| "$__fixture_dir/noncanonical-state-rerun.out"
grep -Eq "already (verified|committed)" "$__fixture_dir/noncanonical-state-rerun.out" ||
    fail "noncanonical state path did not pass the selector collision guard"

setup_fixture
local __symlinked_state="$__fixture_dir/state-link"
ln -s "$__fixture_state" "$__symlinked_state"
run_migration_with_state_home_yes "$__symlinked_state" >| "$__fixture_dir/symlinked-state.out"
run_migration_with_state_home "$__symlinked_state" --rollback >| "$__fixture_dir/symlinked-state-rollback.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "symlinked state rollback did not restore the old target"
[[ -L "$__fixture_config/config.toml" ]] ||
    fail "symlinked state rollback did not restore old entries"

setup_fixture
rm -rf -- "$__fixture_config"
run_migration_yes >| "$__fixture_dir/absent-target-migration.out"
local __absent_target_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
python3 - "$__absent_target_manifest" "$__fixture_config" <<'PY_ABSENT_TARGET_MANIFEST'
import json
import os
import sys

manifest = json.loads(open(sys.argv[1], encoding="utf-8").read())
assert manifest["target_preexisting"] is False
assert manifest["backup_moved"] is False
assert manifest["target_identity"]
device, inode = manifest["target_identity"].split(":")
assert device.isdigit() and inode.isdigit()
assert os.path.islink(sys.argv[2])
PY_ABSENT_TARGET_MANIFEST
run_migration --rollback >| "$__fixture_dir/absent-target-rollback.out"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "rollback from an absent target did not remove the migration-created link"
grep -qF '"state": "rolled_back"' "$__absent_target_manifest" ||
    fail "rollback from an absent target did not finalize the transaction"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "rollback from an absent target retained the migration lock"

setup_fixture
rm -rf -- "$__fixture_config"
run_migration_yes >| "$__fixture_dir/absent-target-guarded-migration.out"
rm -f -- "$__fixture_config"
ln -s "$__fixture_checkout/home/.config/mise" "$__fixture_config"
expect_failure "absent target identity guard" "identity changed" run_migration --rollback
[[ -L "$__fixture_config" ]] ||
    fail "absent target identity guard removed a changed target"
grep -qF '"state": "verified"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "absent target identity guard changed the transaction state"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "absent target identity guard retained the migration lock"

setup_fixture
__status=0
MISE_MODE=failure run_migration_yes >| "$__fixture_dir/failure.out" 2>&1 || __status="$?"
[[ "$__status" == 23 ]] || fail "native failure status was not preserved"
grep -qF '"state": "failed"' "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "native failure did not persist failed state"
[[ ! -d "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock" ]] ||
    fail "native failure retained the current owner's lock"
expect_failure "failed transaction with a link" "nonterminal transaction manifest" run_migration_yes
run_migration --rollback >| "$__fixture_dir/rollback.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] || fail "rollback did not restore the old directory"
[[ -L "$__fixture_config/config.toml" ]] || fail "rollback did not restore old entries"

setup_fixture
__status=0
MISE_MODE=failure-no-link run_migration_yes >| "$__fixture_dir/failure-no-link.out" 2>&1 || __status="$?"
[[ "$__status" == 23 ]] || fail "native failure without a replacement target was not preserved"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "native failure without a replacement target left an unexpected target"
run_migration --rollback >| "$__fixture_dir/rollback-no-link.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "rollback did not restore the backup when the target was absent"
[[ -L "$__fixture_config/config.toml" ]] || fail "absent-target rollback did not restore old entries"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-absent-source.out"
rm -f -- "$__fixture_checkout/home/.config/mise/config.work.local.toml"
run_migration --rollback >| "$__fixture_dir/rollback-absent-source.out"
[[ -d "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "rollback with an absent migration entry did not restore the old target"
[[ -L "$__fixture_config/config.toml" ]] ||
    fail "rollback with an absent migration entry lost old entries"
grep -qF '"state": "rolled_back"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json" ||
    fail "rollback with an absent migration entry did not finalize the transaction"

setup_fixture
__status=0
MISE_MODE=failure-no-link run_migration_yes >| "$__fixture_dir/rerun-failure.out" 2>&1 || __status="$?"
[[ "$__status" == 23 ]] || fail "rerun fixture did not create the initial failed transaction"
local __rerun_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
local __rerun_manifest_digest
__rerun_manifest_digest="$(shasum -a 256 "$__rerun_manifest" | cut -d ' ' -f 1)" ||
    fail "could not snapshot the rerun manifest"
local __rerun_backup_dir
__rerun_backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the rerun backup"
expect_failure "rerun with a nonterminal manifest" "nonterminal transaction manifest" run_migration_yes
[[ "$(shasum -a 256 "$__rerun_manifest" | cut -d ' ' -f 1)" == "$__rerun_manifest_digest" ]] ||
    fail "rerun replaced the first transaction manifest"
[[ -d "$__rerun_backup_dir/config-dir" ]] ||
    fail "rerun removed the first transaction backup"
[[ ! -e "$__fixture_config" && ! -L "$__fixture_config" ]] ||
    fail "rerun recreated a target while the first transaction was unresolved"

setup_fixture
run_migration_yes >| "$__fixture_dir/guarded.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
rm -f "$__fixture_config"
mkdir -p "$__fixture_config"
expect_failure "rollback target guard" "does not resolve" run_migration --rollback
[[ -d "$__backup_dir/config-dir" ]] || fail "rollback guard removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/backup-guard.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
print -r -- changed >| "$__fixture_checkout/home/.config/mise/config.work.local.toml"
expect_failure "backup removal digest guard" "digest" run_migration --remove-backup
[[ -d "$__backup_dir/config-dir" ]] || fail "backup guard removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-guard.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
print -r -- changed >| "$__fixture_checkout/home/.config/mise/config.work.local.toml"
expect_failure "rollback approved-file guard" "digest" run_migration --rollback
[[ -d "$__backup_dir/config-dir" ]] || fail "rollback guard removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/symlinked-backup.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
local __symlinked_backup_target="$__fixture_dir/external-backup"
mv -- "$__backup_dir/config-dir" "$__symlinked_backup_target"
ln -s "$__symlinked_backup_target" "$__backup_dir/config-dir"
snapshot_recovery_files "$__fixture_dir/symlinked-backup-before.snapshot" \
    "$__fixture_config" \
    "$__fixture_checkout/home/.config/mise" \
    "$__backup_dir" \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
expect_failure "symlinked backup rollback" "physical directory" run_migration --rollback
snapshot_recovery_files "$__fixture_dir/symlinked-backup-after.snapshot" \
    "$__fixture_config" \
    "$__fixture_checkout/home/.config/mise" \
    "$__backup_dir" \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
[[ "$(cat "$__fixture_dir/symlinked-backup-before.snapshot")" == \
    "$(cat "$__fixture_dir/symlinked-backup-after.snapshot")" ]] ||
    fail "symlinked backup rollback mutated the target or backup"
[[ -L "$__backup_dir/config-dir" &&
    "$(readlink "$__backup_dir/config-dir")" == "$__symlinked_backup_target" ]] ||
    fail "symlinked backup rollback changed the backup link"

setup_fixture
run_migration_yes >| "$__fixture_dir/mutation-between-validation-and-delete.out"
cat >| "$__fixture_dir/mutate-rollback-source.zsh" <<'EOF_MUTATE_ROLLBACK_SOURCE'
#!/usr/bin/env zsh
set -euo pipefail
print -r -- changed >| "$MUTATION_SOURCE"
EOF_MUTATE_ROLLBACK_SOURCE
chmod +x "$__fixture_dir/mutate-rollback-source.zsh"
expect_failure "rollback source mutation race" "digest" \
    run_migration_before_rollback_source_delete --rollback
[[ "$(cat "$__fixture_checkout/home/.config/mise/config.work.local.toml")" == changed ]] ||
    fail "rollback source mutation race changed the mutated source entry"
[[ -L "$__fixture_config" ]] || fail "rollback source mutation race changed the target"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
[[ -d "$__backup_dir/config-dir" && ! -L "$__backup_dir/config-dir" ]] ||
    fail "rollback source mutation race consumed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-mode.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
chmod 600 "$__fixture_checkout/home/.config/mise/config.work.local.toml"
expect_failure "rollback mode-only guard" "mode" run_migration --rollback
[[ -L "$__fixture_config" ]] || fail "mode-only rollback removed the config link"
[[ -d "$__backup_dir/config-dir" ]] || fail "mode-only rollback removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-selector-type.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
rm -f "$__fixture_state/minusfive/miserc.local.toml"
mkdir "$__fixture_state/minusfive/miserc.local.toml"
expect_failure "rollback selector type guard" "unexpected type" run_migration --rollback
[[ -L "$__fixture_config" ]] || fail "selector type rollback removed the config link"
[[ -d "$__backup_dir/config-dir" ]] || fail "selector type rollback removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-selector-mode.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
chmod 600 "$__fixture_state/minusfive/miserc.local.toml"
expect_failure "rollback selector mode guard" "rollback guard" run_migration --rollback
[[ -L "$__fixture_config" ]] || fail "selector mode rollback removed the config link"
[[ -d "$__backup_dir/config-dir" ]] || fail "selector mode rollback removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-selector-target.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
print -r -- 'env = ["work"]' >| "$__fixture_dir/alternate-selector"
rm -f "$__fixture_checkout/home/.config/mise/miserc.local.toml"
ln -s "$__fixture_dir/alternate-selector" "$__fixture_checkout/home/.config/mise/miserc.local.toml"
expect_failure "rollback selector canonical-target guard" "uncertain target" run_migration --rollback
[[ -L "$__fixture_config" ]] || fail "selector target rollback removed the config link"
[[ -d "$__backup_dir/config-dir" ]] || fail "selector target rollback removed the backup"

setup_fixture
run_migration_yes >| "$__fixture_dir/rollback-lock.out"
__backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" -mindepth 1 -maxdepth 1 -type d -print -quit)"
mkdir -p "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
cat >| "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" <<EOF_ROLLBACK_LOCK
{
  "pid": $$,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "rollback-contention"
}
EOF_ROLLBACK_LOCK
expect_failure "rollback lock contention" "already exists" run_migration --rollback
[[ -L "$__fixture_config" ]] || fail "rollback lock contention changed the current target"
[[ -d "$__backup_dir/config-dir" ]] || fail "rollback lock contention removed the backup"
grep -qF '"token": "rollback-contention"' \
    "$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock/owner.json" ||
    fail "rollback lock contention changed the lock owner"

setup_fixture
run_migration_yes >| "$__fixture_dir/remove-backup-lock-setup.out"
local __remove_backup_manifest="$__fixture_state/minusfive/mise-config-dir-migration/transaction.json"
local __remove_backup_dir
__remove_backup_dir="$(find "$__fixture_state/minusfive/mise-config-dir-migration/backups" \
    -mindepth 1 -maxdepth 1 -type d -print -quit)" ||
    fail "could not locate the backup for backup-removal lock contention"
local __remove_backup_lock="$__fixture_state/minusfive/mise-config-dir-migration/transaction.lock"
mkdir -p "$__remove_backup_lock"
cat >| "$__remove_backup_lock/owner.json" <<EOF_REMOVE_BACKUP_LOCK
{
  "pid": $$,
  "uid": $(id -u),
  "host": "$(hostname)",
  "started_at": "2020-01-01T00:00:00Z",
  "token": "remove-backup-contention"
}
EOF_REMOVE_BACKUP_LOCK
snapshot_recovery_files "$__fixture_dir/remove-backup-lock-before.snapshot" \
    "$__fixture_config" \
    "$__remove_backup_dir" \
    "$__remove_backup_manifest" \
    "$__remove_backup_lock/owner.json"
expect_failure "backup removal lock contention" "already exists" \
    run_migration --remove-backup
snapshot_recovery_files "$__fixture_dir/remove-backup-lock-after.snapshot" \
    "$__fixture_config" \
    "$__remove_backup_dir" \
    "$__remove_backup_manifest" \
    "$__remove_backup_lock/owner.json"
[[ "$(cat "$__fixture_dir/remove-backup-lock-before.snapshot")" == \
    "$(cat "$__fixture_dir/remove-backup-lock-after.snapshot")" ]] ||
    fail "backup removal lock contention changed the backup, target, manifest, or lock owner"
grep -qF '"token": "remove-backup-contention"' "$__remove_backup_lock/owner.json" ||
    fail "backup removal lock contention changed the lock owner"

if grep -qF 'git@github.com/minusfive/dot.git' README.md; then
    fail "README contains an SSH origin"
fi
grep -qF 'https://github.com/minusfive/dot.git' README.md || fail "README omits the HTTPS origin"
grep -qF './scripts/migrate-mise-config-dir.zsh --dry-run' README.md || fail "README omits the migration dry run"
grep -qF 'PATH="$HOME/.local/bin:$PATH" "$HOME/.local/bin/mise" -E personal bootstrap' README.md ||
    fail "README omits the personal profile journey"

echo "mise config-directory migration compatibility passed."
