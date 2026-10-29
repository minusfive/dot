#!/usr/bin/env zsh

set -euo pipefail

typeset -r __canonical_origin="https://github.com/minusfive/dot.git"
typeset -r __canonical_relative_checkout="~/dev/personal/dot"
typeset -r __source_relative_path="home/.config/mise"
typeset -r __state_relative_path="minusfive/mise-config-dir-migration"
typeset -r __schema=1
typeset -r __canonical_mise_path="$HOME/.local/bin/mise"
typeset -r __selector_inventory_type="symlink"

typeset __dry_run=false
typeset __rollback=false
typeset __remove_backup=false
typeset __break_stale_lock=false
typeset __show_help=false
typeset __checkout=""
typeset __checkout_realpath=""
typeset __source=""
typeset __source_realpath=""
typeset __target=""
typeset __target_parent=""
typeset __state_dir=""
typeset __state_home_realpath=""
typeset __state_dir_realpath=""
typeset __state_backups_root=""
typeset __manifest=""
typeset __lock_dir=""
typeset __recovery_claim=""
typeset __backup=""
typeset __selector_state=""
typeset __rollback_quarantine=""
typeset __token=""
typeset __validated_lock_identity=""
typeset __validated_lock_owner_identity=""
typeset __validated_lock_token=""
typeset __owner_snapshot_lock_identity=""
typeset __owner_snapshot_owner_identity=""
typeset __owner_snapshot_pid=""
typeset __owner_snapshot_uid=""
typeset __owner_snapshot_host=""
typeset __owner_snapshot_started_at=""
typeset __owner_snapshot_token=""
typeset __recovery_claim_identity=""
typeset __recovery_claim_snapshot_identity=""
typeset __recovery_claim_snapshot_owner_identity=""
typeset __recovery_claim_snapshot_pid=""
typeset __recovery_claim_snapshot_uid=""
typeset __recovery_claim_snapshot_host=""
typeset __recovery_claim_snapshot_token=""
typeset __recovery_claim_snapshot_lock_token=""
typeset __recovery_claim_snapshot_lock_identity=""
typeset __transaction_state="prepared"
typeset __rollback_state="prepared"
typeset __error=""
typeset __main_status=0
typeset __completed_rerun=false
typeset __started_at=""
typeset __completed_at=""
typeset __relative=""
typeset __lock_acquired=false
typeset __lock_created=false
typeset __created_lock_identity=""
typeset __new_owner_identity=""
typeset __stale_owner_moved=false
typeset __stale_owner_path=""
typeset __stale_owner_transition_verified=false
typeset __backup_moved=false
typeset __selector_recorded=false
typeset __selector_preexisting=false
typeset __selector_type=""
typeset __selector_mode=""
typeset __selector_hash=""
typeset __base64_decode_mode=""
typeset __stat_mode=""
typeset __recorded_checkout=""
typeset __recorded_checkout_realpath=""
typeset __recorded_origin=""
typeset __recorded_source=""
typeset __recorded_target=""
typeset __recorded_backup=""
typeset __target_preexisting=false
typeset __target_identity=""
typeset __manifest_checkout=""
typeset __manifest_checkout_realpath=""
typeset __manifest_source=""
typeset __manifest_target=""
typeset __manifest_backup=""
typeset __manifest_quarantine=""
typeset -a __approved_paths=()
typeset -a __approved_types=()
typeset -a __approved_modes=()
typeset -a __approved_hashes=()
typeset -a __approved_owners=()
typeset -a __approved_link_targets=()
typeset -a __approved_optional=()
typeset -a __approved_preexisting=()
typeset -a __backup_paths=()
typeset -a __backup_types=()
typeset -a __backup_modes=()
typeset -a __backup_hashes=()
typeset -a __backup_owners=()
typeset -a __backup_link_targets=()
typeset -a __manifest_preexisting_paths=()
typeset -a __manifest_preexisting_values=()
typeset -a __rollback_remove_paths=()
typeset -a __inventory_approved_paths=()
typeset -a __inventory_approved_types=()
typeset -a __inventory_approved_modes=()
typeset -a __inventory_approved_hashes=()
typeset -a __inventory_approved_owners=()
typeset -a __inventory_approved_link_targets=()
typeset -a __inventory_approved_optional=()
typeset -a __inventory_approved_preexisting=()
typeset -a __inventory_backup_paths=()
typeset -a __inventory_backup_types=()
typeset -a __inventory_backup_modes=()
typeset -a __inventory_backup_hashes=()
typeset -a __inventory_backup_owners=()
typeset -a __inventory_backup_link_targets=()

print_error() {
    print -u2 -- "error: $*"
}

usage() {
    cat <<'EOF'
Usage: scripts/migrate-mise-config-dir.zsh [--dry-run]
       scripts/migrate-mise-config-dir.zsh --rollback [--break-stale-lock]
       scripts/migrate-mise-config-dir.zsh --remove-backup [--break-stale-lock]
       scripts/migrate-mise-config-dir.zsh --break-stale-lock
       scripts/migrate-mise-config-dir.zsh --help

Migrate the existing mise configuration directory to the repository source.

Options:
  --dry-run             Show the migration plan without changing files.
  --rollback            Restore the recorded configuration directory backup.
  --remove-backup       Remove a verified backup and commit the transaction.
  --break-stale-lock    Recover a lock that is stale by the documented policy.
  --help                Show this help.
EOF
}

parse_args() {
    while (( $# > 0 )); do
        case "$1" in
            --dry-run)
                __dry_run=true
                ;;
            --rollback)
                __rollback=true
                ;;
            --remove-backup)
                __remove_backup=true
                ;;
            --break-stale-lock)
                __break_stale_lock=true
                ;;
            --help)
                __show_help=true
                ;;
            *)
                print_error "unsupported option: $1"
                usage >&2
                return 2
                ;;
        esac
        shift
    done

    local __modes=0
    [[ "$__dry_run" == true ]] && (( __modes++ ))
    [[ "$__rollback" == true ]] && (( __modes++ ))
    [[ "$__remove_backup" == true ]] && (( __modes++ ))
    if [[ "$__show_help" == true ]]; then
        (( __modes == 0 )) || {
            print_error "--help cannot be combined with another mode"
            return 2
        }
        return 0
    fi
    if (( __modes > 1 )); then
        print_error "choose one migration mode"
        return 2
    fi
}

json_quote() {
    local __value="$1"
    __value="${__value//\\/\\\\}"
    __value="${__value//\"/\\\"}"
    __value="${__value//$'\n'/\\n}"
    print -rn -- "\"$__value\""
}

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

timestamp_utc() {
    date -u '+%Y%m%dT%H%M%SZ'
}

sha256_file() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    else
        sha256sum "$1" | cut -d ' ' -f 1
    fi
}

file_mode() {
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -L -f '%Lp' "$1"
    else
        stat -L -c '%a' "$1"
    fi
}

file_owner() {
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -L -f '%u' "$1"
    else
        stat -L -c '%u' "$1"
    fi
}

path_identity() {
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -f '%d:%i' "$1"
    else
        stat -c '%d:%i' "$1"
    fi
}

entry_owner() {
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -f '%u' "$1"
    else
        stat -c '%u' "$1"
    fi
}

device_id() {
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -f '%d' "$1"
    else
        stat -c '%d' "$1"
    fi
}

mtime_epoch() {
    local __value
    detect_stat_mode
    if [[ "$__stat_mode" == bsd ]]; then
        stat -f '%m' "$1"
    else
        stat -c '%Y' "$1"
    fi
}

detect_stat_mode() {
    [[ -n "$__stat_mode" ]] && return 0
    if stat -f '%Lp' /dev/null >/dev/null 2>&1; then
        __stat_mode=bsd
    else
        __stat_mode=gnu
    fi
}

path_inside() {
    local __path="$1"
    local __parent="$2"
    [[ "$__path" == "$__parent" || "$__path" == "$__parent"/* ]]
}

path_has_safe_components() {
    local __path="$1"
    local __components_path="$__path"
    local __component
    [[ -n "$__path" && "$__path" != *$'\n'* && "$__path" != *$'\r'* &&
        "$__path" != *$'\t'* ]] || return 1
    [[ "$__components_path" == /* ]] && __components_path="${__components_path#/}"
    [[ "$__path" != *'//'* ]] || return 1
    for __component in ${(s:/:)__components_path}; do
        [[ -n "$__component" && "$__component" != "." && "$__component" != ".." ]] || return 1
    done
}

validate_physical_ancestor_chain() {
    local __path="$1"
    local __root="$2"
    local __label="$3"
    local __root_realpath __ancestor __ancestor_realpath

    [[ ! -L "$__root" ]] || {
        print_error "$__label root is a symlink"
        return 1
    }
    __root_realpath="$(realpath "$__root" 2>/dev/null || true)"
    [[ -n "$__root_realpath" && -d "$__root_realpath" && ! -L "$__root_realpath" ]] || {
        print_error "$__label root is not a physical directory"
        return 1
    }
    __ancestor="${__path:h}"
    while true; do
        [[ -d "$__ancestor" && ! -L "$__ancestor" ]] || {
            print_error "$__label has a non-physical ancestor: $__ancestor"
            return 1
        }
        __ancestor_realpath="$(realpath "$__ancestor" 2>/dev/null || true)"
        [[ -n "$__ancestor_realpath" && "$__ancestor_realpath" == "$__ancestor" ]] || {
            print_error "$__label has a non-canonical ancestor: $__ancestor"
            return 1
        }
        path_inside "$__ancestor_realpath" "$__root_realpath" || {
            print_error "$__label escapes its expected root"
            return 1
        }
        [[ "$__ancestor" == "$__root_realpath" ]] && break
        __ancestor="${__ancestor:h}"
        [[ "$__ancestor" != "/" ]] || {
            print_error "$__label does not have the expected root ancestor"
            return 1
        }
    done
}

validate_physical_directory_chain() {
    local __path="$1"
    local __root="$2"
    local __label="$3"
    local __path_realpath

    [[ -d "$__path" && ! -L "$__path" ]] || {
        print_error "$__label is not a physical directory"
        return 1
    }
    __path_realpath="$(realpath "$__path" 2>/dev/null || true)"
    [[ -n "$__path_realpath" && "$__path_realpath" == "$__path" ]] || {
        print_error "$__label is not canonical"
        return 1
    }
    validate_physical_ancestor_chain "$__path" "$__root" "$__label" || return $?
    path_inside "$__path_realpath" "$(realpath "$__root" 2>/dev/null || true)" || {
        print_error "$__label resolves outside its expected root"
        return 1
    }
}

validate_manifest_absolute_path() {
    local __path="$1"
    local __label="$2"
    [[ "$__path" == /* ]] && path_has_safe_components "$__path" || {
        print_error "manifest $__label must be a normalized absolute path"
        return 1
    }
}

validate_manifest_relative_path() {
    local __path="$1"
    local __label="$2"
    [[ "$__path" != /* ]] && path_has_safe_components "$__path" || {
        print_error "manifest $__label must be a normalized relative path"
        return 1
    }
}

validate_manifest_entry_path() {
    local __root="$1"
    local __relative="$2"
    local __label="$3"
    local __root_realpath __parent __parent_realpath
    validate_manifest_relative_path "$__relative" "$__label" || return $?
    __root_realpath="$(realpath "$__root" 2>/dev/null || true)"
    if [[ -z "$__root_realpath" || ! -d "$__root_realpath" || -L "$__root_realpath" ]]; then
        return 0
    fi
    __parent="$__root/$__relative"
    __parent="${__parent:h}"
    while [[ "$__parent" != "$__root" ]]; do
        [[ -d "$__parent" && ! -L "$__parent" ]] || {
            print_error "manifest $__label has a non-physical parent"
            return 1
        }
        __parent_realpath="$(realpath "$__parent" 2>/dev/null || true)"
        [[ -n "$__parent_realpath" ]] &&
            path_inside "$__parent_realpath" "$__root_realpath" || {
            print_error "manifest $__label resolves outside its expected root"
            return 1
        }
        __parent="${__parent:h}"
    done
    return 0
}

validate_manifest_paths() {
    local __expected_checkout="$1"
    local __expected_checkout_realpath="$2"
    local __expected_source="$3"
    local __expected_source_realpath="$4"
    local __expected_target="$5"
    local __expected_target_parent="$6"
    local __expected_state_backups_root="$7"
    local __expected_selector_state="$8"
    local __entry __path __backup_realpath __backup_root_realpath __quarantine_realpath

    validate_manifest_absolute_path "$__manifest_checkout" checkout || return $?
    validate_manifest_absolute_path "$__manifest_checkout_realpath" checkout_realpath || return $?
    validate_manifest_absolute_path "$__manifest_source" config_source || return $?
    validate_manifest_absolute_path "$__manifest_target" target || return $?
    validate_manifest_absolute_path "$__manifest_backup" backup || return $?
    [[ -z "$__manifest_quarantine" ]] ||
        validate_manifest_absolute_path "$__manifest_quarantine" rollback_quarantine || return $?

    [[ "$__manifest_checkout" == "$__expected_checkout" &&
        "$__manifest_checkout_realpath" == "$__expected_checkout_realpath" &&
        "$__manifest_source" == "$__expected_source" &&
        "$__manifest_target" == "$__expected_target" ]] || {
        print_error "manifest path does not match the current migration roots"
        return 1
    }
    validate_physical_ancestor_chain "$__expected_state_backups_root" "$__state_dir_realpath" \
        "manifest backup root" || return $?
    __backup_root_realpath="$(realpath "$__expected_state_backups_root" 2>/dev/null || true)"
    [[ "$__manifest_backup" == "$__backup_root_realpath"/* ]] || {
        print_error "manifest backup is outside the migration backup root"
        return 1
    }
    if path_exists "$__manifest_backup"; then
        [[ -d "$__manifest_backup" && ! -L "$__manifest_backup" ]] || {
            print_error "manifest backup is not a physical directory"
            return 1
        }
        __backup_realpath="$(realpath "$__manifest_backup" 2>/dev/null || true)"
        [[ -n "$__backup_realpath" ]] && path_inside "$__backup_realpath" "$__backup_root_realpath" || {
            print_error "manifest backup resolves outside the migration backup root"
            return 1
        }
    fi
    [[ "$__manifest_target" == "$__expected_target" &&
        "$__expected_target_parent" == "${__expected_target:h}" ]] || {
        print_error "manifest target does not match the expected target parent"
        return 1
    }
    if [[ -n "$__manifest_quarantine" ]]; then
        [[ "$__manifest_quarantine" == "$__expected_target_parent"/* &&
            "$__manifest_quarantine" != "$__expected_target" ]] || {
            print_error "manifest rollback quarantine is outside the target parent"
            return 1
        }
        validate_physical_ancestor_chain "$__manifest_quarantine" "$__expected_target_parent" \
            "manifest rollback quarantine" || return $?
        if path_exists "$__manifest_quarantine"; then
            [[ -d "$__manifest_quarantine" && ! -L "$__manifest_quarantine" ]] || {
                print_error "manifest rollback quarantine is not a physical directory"
                return 1
            }
            __quarantine_realpath="$(realpath "$__manifest_quarantine" 2>/dev/null || true)"
            [[ -n "$__quarantine_realpath" ]] &&
                path_inside "$__quarantine_realpath" "$__expected_target_parent" || {
                print_error "manifest rollback quarantine resolves outside the target parent"
                return 1
            }
        fi
    fi
    for __entry in "${__backup_paths[@]}"; do
        validate_manifest_entry_path "$__manifest_backup/config-dir" "$__entry" "backup entry" || return $?
    done
    for __entry in "${__approved_paths[@]}"; do
        validate_manifest_entry_path "$__manifest_source" "$__entry" "approved entry" || return $?
    done
}

path_exists() {
    [[ -e "$1" || -L "$1" ]]
}

same_canonical_path() {
    local __left="$1"
    local __right="$2"
    local __left_realpath="$(realpath "$__left" 2>/dev/null || true)"
    local __right_realpath="$(realpath "$__right" 2>/dev/null || true)"
    [[ -n "$__left_realpath" && -n "$__right_realpath" &&
        "$__left_realpath" == "$__right_realpath" ]]
}

move_checked() {
    local __source_path="$1"
    local __target_path="$2"
    mv -- "$__source_path" "$__target_path" || return 1
    path_exists "$__target_path" && ! path_exists "$__source_path"
}

remove_checked() {
    local __path="$1"
    path_exists "$__path" || return 1
    rm -rf -- "$__path" || return 1
    ! path_exists "$__path"
}

read_manifest_scalar() {
    local __key="$1"
    local __value
    __value="$(sed -n "s/^[[:space:]]*\"${__key}\":[[:space:]]*\"\\(.*\\)\",[[:space:]]*$/\\1/p" "$__manifest" | head -n 1)"
    print -r -- "${__value//\\\"/\"}"
}

manifest_state() {
    read_manifest_scalar state
}

manifest_rollback_state() {
    read_manifest_scalar rollback_state
}

manifest_schema() {
    sed -n 's/^[[:space:]]*"schema":[[:space:]]*\([0-9][0-9]*\),[[:space:]]*$/\1/p' "$__manifest" | head -n 1
}

read_manifest_boolean() {
    local __key="$1"
    sed -n "s/^[[:space:]]*\"${__key}\":[[:space:]]*\\(true\\|false\\),[[:space:]]*$/\\1/p" "$__manifest" | head -n 1
}

manifest_backup() {
    read_manifest_scalar backup
}

manifest_checkout() {
    read_manifest_scalar checkout
}

manifest_source() {
    read_manifest_scalar config_source
}

decode_base64() {
    if [[ -z "$__base64_decode_mode" ]]; then
        if base64 -D >/dev/null 2>&1 <<< ""; then
            __base64_decode_mode=D
        else
            __base64_decode_mode=d
        fi
    fi
    if [[ "$__base64_decode_mode" == D ]]; then
        base64 -D
    else
        base64 -d
    fi
}

parse_manifest_strict() {
    local __manifest_path="$1"
    local __expected_checkout="$2"
    local __expected_source="$3"
    local __expected_mise="$4"
    local __expected_origin="$5"
    local __expected_config_dir="$6"
    python3 - "$__manifest_path" "$__expected_checkout" "$__expected_source" \
        "$__expected_mise" "$__expected_origin" "$__expected_config_dir" <<'PY_MANIFEST'
import base64
import json
import os
import re
import sys

(
    manifest_path,
    expected_checkout,
    expected_source,
    expected_mise,
    expected_origin,
    expected_config_dir,
) = sys.argv[1:]

top_fields = {
    "schema", "state", "rollback_state", "pid", "uid", "host", "started_at",
    "updated_at", "checkout", "checkout_realpath", "origin", "config_source",
    "target", "backup", "rollback_quarantine", "target_identity",
    "backup_moved", "target_preexisting",
    "selector_recorded", "selector_preexisting", "selector_type", "selector_mode",
    "selector_sha256", "backup_entries", "approved_files",
    "source_preexisting_facts", "native_command", "verification", "error",
    "completed_at",
}
entry_fields = {
    "backup_entries": {
        "path", "source_type", "mode", "sha256", "owner", "link_target"
    },
    "approved_files": {
        "path", "source_type", "mode", "sha256", "owner", "link_target",
        "optional", "source_preexisting"
    },
    "source_preexisting_facts": {"path", "source_preexisting"},
}
states = {
    "locked", "preflight_passed", "backup_pending", "backed_up", "staging",
    "staged", "linked", "verified", "failed", "rollback_pending", "rolled_back",
    "commit_pending", "committed",
}
valid_rollback_states = {
    "locked": {"prepared"},
    "preflight_passed": {"preflight_passed"},
    "backup_pending": {"backup_pending"},
    "backed_up": {"backed_up"},
    "staging": {"staging"},
    "staged": {"staged"},
    "linked": {"linked"},
    "verified": {"verified"},
    "failed": {
        "prepared",
        "preflight_passed", "backup_pending", "backed_up", "staging",
        "staged", "linked", "verified",
    },
    "rollback_pending": {"rollback_pending"},
    "rolled_back": {"rolled_back"},
    "commit_pending": {"commit_pending"},
    "committed": {"committed"},
}
digest_pattern = re.compile(r"^[0-9a-f]{64}$")
mode_pattern = re.compile(r"^[0-7]{3,4}$")


def fail(message):
    print(f"manifest: {message}", file=sys.stderr)
    raise SystemExit(1)


def pairs(pairs_list):
    result = {}
    for key, value in pairs_list:
        if key in result:
            fail(f"duplicate field: {key}")
        result[key] = value
    return result


def b64(value):
    return base64.b64encode(value.encode()).decode()


def require_string(obj, key, nonempty=True):
    value = obj.get(key)
    if not isinstance(value, str) or (nonempty and not value):
        fail(f"field {key} is malformed")
    return value


def require_bool(obj, key):
    value = obj.get(key)
    if not isinstance(value, bool):
        fail(f"field {key} is malformed")
    return value


def require_int(obj, key):
    value = obj.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        fail(f"field {key} is malformed")
    return value


def require_absolute_path(value, key):
    if "\n" in value or "\r" in value or "\t" in value or not value.startswith("/"):
        fail(f"field {key} is not a normalized absolute path")
    if "//" in value or os.path.normpath(value) != value:
        fail(f"field {key} is not a normalized absolute path")


def require_relative_path(value, key):
    if not value or value.startswith("/") or "\n" in value or "\r" in value or "\t" in value:
        fail(f"{key} is not a safe relative path")
    if "//" in value or any(part in {"", ".", ".."} for part in value.split("/")):
        fail(f"{key} is not a safe relative path")


def require_digest(value, key, allow_empty=False):
    if allow_empty and value == "":
        return
    if not digest_pattern.fullmatch(value):
        fail(f"field {key} has an invalid digest")


def require_mode(value, key, allow_empty=False):
    if allow_empty and value == "":
        return
    if not mode_pattern.fullmatch(value):
        fail(f"field {key} has an invalid mode")


def require_owner(value, key):
    if not re.fullmatch(r"[0-9]+", value):
        fail(f"field {key} has an invalid owner")


def require_link_target(value, key):
    if value and value != "-":
        require_absolute_path(value, key)


def require_identity(value, key):
    if value and not re.fullmatch(r"[0-9]+:[0-9]+", value):
        fail(f"field {key} has an invalid identity")


try:
    with open(manifest_path, encoding="utf-8") as handle:
        document = json.load(handle, object_pairs_hook=pairs)
except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
    fail(f"invalid JSON: {error}")

if not isinstance(document, dict):
    fail("top level must be an object")
unknown = set(document) - top_fields
missing = top_fields - set(document)
if unknown:
    fail(f"unknown field: {sorted(unknown)[0]}")
if missing:
    fail(f"missing field: {sorted(missing)[0]}")

if document["schema"] != 1:
    fail("unsupported schema")
for key in ("state", "rollback_state"):
    value = require_string(document, key)
    if value not in states:
        fail(f"field {key} has an invalid state")
if document["rollback_state"] not in valid_rollback_states[document["state"]]:
    fail("state and rollback_state combination is inconsistent")
for key in ("host", "started_at", "updated_at", "error", "completed_at"):
    require_string(document, key, nonempty=False)
for key in ("pid", "uid"):
    require_int(document, key)
for key in ("checkout", "checkout_realpath", "config_source", "target", "backup"):
    value = require_string(document, key)
    require_absolute_path(value, key)
for key in ("origin",):
    if require_string(document, key) != expected_origin:
        fail(f"field {key} does not match the canonical origin")
if document["checkout"] != expected_checkout:
    fail("checkout does not match the current checkout")
if document["config_source"] != expected_source:
    fail("config_source does not match the current source")
rollback_quarantine = require_string(document, "rollback_quarantine", nonempty=False)
if rollback_quarantine:
    require_absolute_path(rollback_quarantine, "rollback_quarantine")
target_identity = require_string(document, "target_identity", nonempty=False)
require_identity(target_identity, "target_identity")
for key in ("backup_moved", "target_preexisting", "selector_recorded", "selector_preexisting"):
    require_bool(document, key)
if document["target_preexisting"] and target_identity:
    fail("preexisting target has migration identity")
if not document["target_preexisting"] and document["backup_moved"]:
    fail("absent target has a moved backup")
selector_type = require_string(document, "selector_type", nonempty=False)
selector_mode = require_string(document, "selector_mode", nonempty=False)
selector_digest = require_string(document, "selector_sha256", nonempty=False)
if selector_type not in {"", "symlink"}:
    fail("selector_type is invalid")
require_mode(selector_mode, "selector_mode", allow_empty=True)
require_digest(selector_digest, "selector_sha256", allow_empty=True)
if not document["selector_recorded"] and (
    document["selector_preexisting"] or selector_type or selector_mode or selector_digest
):
    fail("unrecorded selector has recorded facts")

native_command = document["native_command"]
expected_command = [
    expected_mise, "--no-hooks", "bootstrap", "--from", expected_origin,
    "--from-dir", expected_checkout, "--config-dir", expected_config_dir,
    "--only", "files", "--yes",
]
if (
    not isinstance(native_command, list)
    or any(not isinstance(value, str) for value in native_command)
    or native_command != expected_command
):
    fail("native_command is not the normalized bootstrap command")
if not isinstance(document["verification"], list):
    fail("verification is malformed")

approved_paths = set()
for section in ("backup_entries", "approved_files", "source_preexisting_facts"):
    entries = document[section]
    if not isinstance(entries, list):
        fail(f"{section} is malformed")
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            fail(f"{section} contains a malformed entry")
        unknown = set(entry) - entry_fields[section]
        missing = entry_fields[section] - set(entry)
        if unknown:
            fail(f"{section} contains an unknown field: {sorted(unknown)[0]}")
        if missing:
            fail(f"{section} contains a missing field: {sorted(missing)[0]}")
        path = require_string(entry, "path")
        require_relative_path(path, f"{section}.path")
        if path in seen:
            fail(f"{section} contains a duplicate path: {path}")
        seen.add(path)
        if section == "source_preexisting_facts":
            require_bool(entry, "source_preexisting")
            continue
        source_type = require_string(entry, "source_type")
        if source_type not in {"regular", "symlink"}:
            fail(f"{section} has an invalid source type: {path}")
        require_mode(require_string(entry, "mode"), f"{section}.mode")
        require_digest(require_string(entry, "sha256"), f"{section}.sha256")
        require_owner(require_string(entry, "owner"), f"{section}.owner")
        require_link_target(
            require_string(entry, "link_target", nonempty=False),
            f"{section}.link_target",
        )
        if section == "approved_files":
            require_bool(entry, "optional")
            require_bool(entry, "source_preexisting")
            approved_paths.add(path)

facts = {
    entry["path"]: entry["source_preexisting"]
    for entry in document["source_preexisting_facts"]
}
if set(facts) != approved_paths:
    fail("source_preexisting facts do not cover approved_files exactly")
for entry in document["approved_files"]:
    if facts[entry["path"]] != entry["source_preexisting"]:
        fail(f"source_preexisting fact does not match approved entry: {entry['path']}")

print("SCALAR\ttransaction_state\t" + b64(document["state"]))
print("SCALAR\trollback_state\t" + b64(document["rollback_state"]))
for key in (
    "checkout", "checkout_realpath", "origin", "config_source", "target", "backup",
    "rollback_quarantine", "target_identity", "selector_type", "selector_mode",
    "selector_sha256",
):
    print("SCALAR\t" + key + "\t" + b64(document[key]))
for key in ("backup_moved", "target_preexisting", "selector_recorded", "selector_preexisting"):
    print("BOOL\t" + key + "\t" + str(document[key]).lower())
for entry in document["backup_entries"]:
    print(
        "BACKUP\t" + "\t".join(
            b64(str(entry[key]))
            for key in ("path", "source_type", "mode", "sha256", "owner", "link_target")
        )
    )
for entry in document["approved_files"]:
    print(
        "APPROVED\t" + "\t".join(
            [
                b64(str(entry["path"])),
                b64(str(entry["source_type"])),
                b64(str(entry["mode"])),
                b64(str(entry["sha256"])),
                b64(str(entry["owner"])),
                b64(str(entry["link_target"])),
                str(entry["optional"]).lower(),
                str(entry["source_preexisting"]).lower(),
            ]
        )
    )
for entry in document["source_preexisting_facts"]:
    print(
        "FACT\t" + b64(entry["path"]) + "\t" +
        str(entry["source_preexisting"]).lower()
    )
PY_MANIFEST
}

parse_inventory_strict() {
    local __inventory_path="$1"
    python3 - "$__inventory_path" <<'PY_INVENTORY'
import base64
import json
import re
import sys

inventory_path = sys.argv[1]
digest_pattern = re.compile(r"^[0-9a-f]{64}$")
mode_pattern = re.compile(r"^[0-7]{3,4}$")
entry_fields = {
    "backup_entries": {
        "path", "source_type", "mode", "sha256", "owner", "link_target"
    },
    "approved_files": {
        "path", "source_type", "mode", "sha256", "owner", "link_target",
        "optional", "source_preexisting"
    },
    "source_preexisting_facts": {"path", "source_preexisting"},
}


def fail(message):
    print(f"inventory: {message}", file=sys.stderr)
    raise SystemExit(1)


def pairs(pairs_list):
    result = {}
    for key, value in pairs_list:
        if key in result:
            fail(f"duplicate field: {key}")
        result[key] = value
    return result


def b64(value):
    return base64.b64encode(value.encode()).decode()


def require_string(obj, key, nonempty=True):
    value = obj.get(key)
    if not isinstance(value, str) or (nonempty and not value):
        fail(f"field {key} is malformed")
    return value


def require_bool(obj, key):
    if not isinstance(obj.get(key), bool):
        fail(f"field {key} is malformed")
    return obj[key]


def require_path(value, key):
    if value.startswith("/") or "\n" in value or "\r" in value or "\t" in value:
        fail(f"{key} is not a safe relative path")
    if "//" in value or any(part in {"", ".", ".."} for part in value.split("/")):
        fail(f"{key} is not a safe relative path")


def require_digest(value, key):
    if not digest_pattern.fullmatch(value):
        fail(f"field {key} has an invalid digest")


def require_mode(value, key):
    if not mode_pattern.fullmatch(value):
        fail(f"field {key} has an invalid mode")


def require_owner(value, key):
    if not re.fullmatch(r"[0-9]+", value):
        fail(f"field {key} has an invalid owner")


def require_link_target(value, key):
    if value and value != "-":
        if not value.startswith("/") or "//" in value:
            fail(f"{key} is not a normalized absolute path")


try:
    with open(inventory_path, encoding="utf-8") as handle:
        document = json.load(handle, object_pairs_hook=pairs)
except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
    fail(f"invalid JSON: {error}")

if not isinstance(document, dict):
    fail("top level must be an object")
if set(document) != {
    "schema", "approved_files", "backup_entries", "source_preexisting_facts"
}:
    fail("top-level fields are not exact")
if document["schema"] != 1:
    fail("unsupported schema")

for section in ("backup_entries", "approved_files", "source_preexisting_facts"):
    entries = document[section]
    if not isinstance(entries, list):
        fail(f"{section} is malformed")
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            fail(f"{section} contains a malformed entry")
        if set(entry) != entry_fields[section]:
            fail(f"{section} fields are not exact")
        path = require_string(entry, "path")
        require_path(path, f"{section}.path")
        if path in seen:
            fail(f"{section} contains a duplicate path: {path}")
        seen.add(path)
        if section == "source_preexisting_facts":
            require_bool(entry, "source_preexisting")
            continue
        source_type = require_string(entry, "source_type")
        if source_type not in {"regular", "symlink"}:
            fail(f"{section} has an invalid source type: {path}")
        require_mode(require_string(entry, "mode"), f"{section}.mode")
        require_digest(require_string(entry, "sha256"), f"{section}.sha256")
        require_owner(require_string(entry, "owner"), f"{section}.owner")
        require_link_target(
            require_string(entry, "link_target", nonempty=False),
            f"{section}.link_target",
        )
        if section == "approved_files":
            require_bool(entry, "optional")
            require_bool(entry, "source_preexisting")

approved_paths = {entry["path"] for entry in document["approved_files"]}
facts = {
    entry["path"]: entry["source_preexisting"]
    for entry in document["source_preexisting_facts"]
}
if facts.keys() != approved_paths:
    fail("source_preexisting facts do not cover approved_files exactly")
for entry in document["approved_files"]:
    if facts[entry["path"]] != entry["source_preexisting"]:
        fail(f"source_preexisting fact does not match approved entry: {entry['path']}")

for entry in document["backup_entries"]:
    print("BACKUP\t" + "\t".join(
        b64(str(entry[key]))
        for key in ("path", "source_type", "mode", "sha256", "owner", "link_target")
    ))
for entry in document["approved_files"]:
    print("APPROVED\t" + "\t".join([
        b64(entry["path"]),
        b64(entry["source_type"]),
        b64(entry["mode"]),
        b64(entry["sha256"]),
        b64(entry["owner"]),
        b64(entry["link_target"]),
        str(entry["optional"]).lower(),
        str(entry["source_preexisting"]).lower(),
    ]))
for entry in document["source_preexisting_facts"]:
    print(
        "FACT\t" + b64(entry["path"]) + "\t" +
        str(entry["source_preexisting"]).lower()
    )
PY_INVENTORY
}

write_inventory() {
    local __inventory="$__backup/source-inventory.json"
    local __tmp="$__inventory.tmp.$$.$RANDOM"
    local __index
    umask 077
    {
        print '{'
        print '  "schema": 1,'
        print '  "approved_files": ['
        for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__approved_paths[__index]}"), \"source_type\": $(json_quote "${__approved_types[__index]}"), \"mode\": $(json_quote "${__approved_modes[__index]}"), \"sha256\": $(json_quote "${__approved_hashes[__index]}"), \"owner\": $(json_quote "${__approved_owners[__index]}"), \"link_target\": $(json_quote "${__approved_link_targets[__index]}"), \"optional\": ${__approved_optional[__index]}, \"source_preexisting\": ${__approved_preexisting[__index]}}"
        done
        print
        print '  ],'
        print '  "backup_entries": ['
        for (( __index = 1; __index <= ${#__backup_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__backup_paths[__index]}"), \"source_type\": $(json_quote "${__backup_types[__index]}"), \"mode\": $(json_quote "${__backup_modes[__index]}"), \"sha256\": $(json_quote "${__backup_hashes[__index]}"), \"owner\": $(json_quote "${__backup_owners[__index]}"), \"link_target\": $(json_quote "${__backup_link_targets[__index]}")}"
        done
        print
        print '  ],'
        print '  "source_preexisting_facts": ['
        for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__approved_paths[__index]}"), \"source_preexisting\": ${__approved_preexisting[__index]}}"
        done
        print
        print '  ]'
        print '}'
    } >| "$__tmp" || {
        rm -f -- "$__tmp"
        return 1
    }
    chmod 600 "$__tmp" || {
        rm -f -- "$__tmp"
        return 1
    }
    mv -f -- "$__tmp" "$__inventory" || {
        rm -f -- "$__tmp"
        return 1
    }
}

write_manifest() {
    if [[ -n "${MISE_MIGRATION_TEST_BEFORE_MANIFEST_WRITE:-}" ]]; then
        "${MISE_MIGRATION_TEST_BEFORE_MANIFEST_WRITE}" || return $?
    fi
    local __tmp="$__state_dir/transaction.json.tmp.$$.$RANDOM"
    local __updated_at="$(now_utc)"
    local __index
    umask 077
    {
        print '{'
        print "  \"schema\": $__schema,"
        print "  \"state\": $(json_quote "$__transaction_state"),"
        print "  \"rollback_state\": $(json_quote "$__rollback_state"),"
        print "  \"pid\": $$,"
        print "  \"uid\": $(id -u),"
        print "  \"host\": $(json_quote "$(hostname)"),"
        print "  \"started_at\": $(json_quote "${__started_at:-$__updated_at}"),"
        print "  \"updated_at\": $(json_quote "$__updated_at"),"
        print "  \"checkout\": $(json_quote "$__checkout"),"
        print "  \"checkout_realpath\": $(json_quote "$__checkout_realpath"),"
        print "  \"origin\": $(json_quote "$__canonical_origin"),"
        print "  \"config_source\": $(json_quote "$__source"),"
        print "  \"target\": $(json_quote "$__target"),"
        print "  \"backup\": $(json_quote "$__backup"),"
        print "  \"rollback_quarantine\": $(json_quote "$__rollback_quarantine"),"
        print "  \"target_identity\": $(json_quote "$__target_identity"),"
        print "  \"backup_moved\": $__backup_moved,"
        print "  \"target_preexisting\": $__target_preexisting,"
        print "  \"selector_recorded\": $__selector_recorded,"
        print "  \"selector_preexisting\": $__selector_preexisting,"
        print "  \"selector_type\": $(json_quote "$__selector_type"),"
        print "  \"selector_mode\": $(json_quote "$__selector_mode"),"
        print "  \"selector_sha256\": $(json_quote "$__selector_hash"),"
        print '  "backup_entries": ['
        for (( __index = 1; __index <= ${#__backup_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__backup_paths[__index]}"), \"source_type\": $(json_quote "${__backup_types[__index]}"), \"mode\": $(json_quote "${__backup_modes[__index]}"), \"sha256\": $(json_quote "${__backup_hashes[__index]}"), \"owner\": $(json_quote "${__backup_owners[__index]}"), \"link_target\": $(json_quote "${__backup_link_targets[__index]}")}"
        done
        print
        print '  ],'
        print '  "approved_files": ['
        for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__approved_paths[__index]}"), \"source_type\": $(json_quote "${__approved_types[__index]}"), \"mode\": $(json_quote "${__approved_modes[__index]}"), \"sha256\": $(json_quote "${__approved_hashes[__index]}"), \"owner\": $(json_quote "${__approved_owners[__index]}"), \"link_target\": $(json_quote "${__approved_link_targets[__index]}"), \"optional\": ${__approved_optional[__index]}, \"source_preexisting\": ${__approved_preexisting[__index]}}"
        done
        print
        print '  ],'
        print "  \"source_preexisting_facts\": ["
        for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
            (( __index > 1 )) && print ','
            print -n "    {\"path\": $(json_quote "${__approved_paths[__index]}"), \"source_preexisting\": ${__approved_preexisting[__index]}}"
        done
        print
        print '  ],'
        print "  \"native_command\": [$(json_quote "$__canonical_mise_path"), \"--no-hooks\", \"bootstrap\", \"--from\", $(json_quote "$__canonical_origin"), \"--from-dir\", $(json_quote "$__checkout"), \"--config-dir\", $(json_quote "$__source_relative_path"), \"--only\", \"files\", \"--yes\"],"
        print '  "verification": [],'
        print "  \"error\": $(json_quote "$__error"),"
        print "  \"completed_at\": $(json_quote "${__completed_at:-}")"
        print '}'
    } >| "$__tmp" || {
        rm -f -- "$__tmp"
        return 1
    }
    chmod 600 "$__tmp" || {
        rm -f -- "$__tmp"
        return 1
    }
    mv -f -- "$__tmp" "$__manifest" || {
        rm -f -- "$__tmp"
        return 1
    }
}

write_owner() {
    validate_lock_paths || return $?
    local __tmp="$__lock_dir/owner.json.tmp.$$.$RANDOM"
    umask 077
    {
        print '{'
        print "  \"pid\": $$,"
        print "  \"uid\": $(id -u),"
        print "  \"host\": $(json_quote "$(hostname)"),"
        print "  \"started_at\": $(json_quote "$__started_at"),"
        print "  \"token\": $(json_quote "$__token")"
        print '}'
    } >| "$__tmp" || {
        rm -f -- "$__tmp" || true
        return 1
    }
    chmod 600 "$__tmp" || {
        rm -f -- "$__tmp" || true
        return 1
    }
    ln -- "$__tmp" "$__lock_dir/owner.json" || {
        local __status="$?"
        rm -f -- "$__tmp" || true
        return "$__status"
    }
    rm -f -- "$__tmp" || {
        print_error "could not remove the temporary migration lock owner"
        return 1
    }
    __new_owner_identity="$(path_identity "$__lock_dir/owner.json" 2>/dev/null || true)"
    [[ -n "$__new_owner_identity" ]] || {
        print_error "could not identify the new migration lock owner"
        return 1
    }
    validate_lock_paths || return $?
}

owner_snapshot_at() {
    local __owner_file="$1"
    [[ -f "$__owner_file" && ! -L "$__owner_file" ]] || return 1
    python3 - "$__owner_file" <<'PY_OWNER'
import json
import sys

owner_file = sys.argv[1]
expected_fields = {"pid", "uid", "host", "started_at", "token"}


def fail(message):
    print(f"lock owner metadata: {message}", file=sys.stderr)
    raise SystemExit(1)


def pairs(pairs_list):
    result = {}
    for key, value in pairs_list:
        if key in result:
            fail(f"duplicate field: {key}")
        result[key] = value
    return result


def require_int(document, key, minimum):
    value = document.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        fail(f"field {key} is malformed")
    return value


def require_string(document, key):
    value = document.get(key)
    if (
        not isinstance(value, str)
        or not value
        or any(character in value for character in ("\x00", "\n", "\r", "\t"))
    ):
        fail(f"field {key} is malformed")
    return value


try:
    with open(owner_file, encoding="utf-8") as handle:
        document = json.load(handle, object_pairs_hook=pairs)
except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
    fail(f"invalid JSON: {error}")

if not isinstance(document, dict):
    fail("top level must be an object")
unknown = set(document) - expected_fields
missing = expected_fields - set(document)
if unknown:
    fail(f"unknown field: {sorted(unknown)[0]}")
if missing:
    fail(f"missing field: {sorted(missing)[0]}")

require_int(document, "pid", 1)
require_int(document, "uid", 0)
for field in ("host", "started_at", "token"):
    require_string(document, field)

print("\t".join([
    str(document["pid"]),
    str(document["uid"]),
    document["host"],
    document["started_at"],
    document["token"],
]))
PY_OWNER
}

owner_snapshot() {
    validate_lock_paths || return $?
    local __owner_file="$__lock_dir/owner.json"
    local __lock_identity_before
    local __owner_identity_before
    local __snapshot
    __lock_identity_before="$(path_identity "$__lock_dir" 2>/dev/null || true)"
    __owner_identity_before="$(path_identity "$__owner_file" 2>/dev/null || true)"
    [[ -n "$__lock_identity_before" && -n "$__owner_identity_before" ]] || return 1
    __snapshot="$(owner_snapshot_at "$__owner_file")" || return $?
    if [[ -n "${MISE_MIGRATION_TEST_AFTER_OWNER_SNAPSHOT:-}" ]]; then
        "${MISE_MIGRATION_TEST_AFTER_OWNER_SNAPSHOT}" || return $?
    fi
    local __lock_identity_after
    local __owner_identity_after
    __lock_identity_after="$(path_identity "$__lock_dir" 2>/dev/null || true)"
    __owner_identity_after="$(path_identity "$__owner_file" 2>/dev/null || true)"
    [[ "$__lock_identity_before" == "$__lock_identity_after" &&
        "$__owner_identity_before" == "$__owner_identity_after" ]] || {
        print_error "migration lock owner changed during metadata snapshot"
        return 1
    }
    IFS=$'\t' read -r \
        __owner_snapshot_pid \
        __owner_snapshot_uid \
        __owner_snapshot_host \
        __owner_snapshot_started_at \
        __owner_snapshot_token <<< "$__snapshot" || return 1
    __owner_snapshot_lock_identity="$__lock_identity_before"
    __owner_snapshot_owner_identity="$__owner_identity_before"
}

recovery_claim_snapshot_at() {
    local __claim_file="$1"
    [[ -f "$__claim_file" && ! -L "$__claim_file" ]] || return 1
    python3 - "$__claim_file" <<'PY_CLAIM'
import json
import sys

claim_file = sys.argv[1]
expected_fields = {"pid", "uid", "host", "token", "lock_token", "lock_identity"}


def fail(message):
    print(f"recovery claim metadata: {message}", file=sys.stderr)
    raise SystemExit(1)


def pairs(pairs_list):
    result = {}
    for key, value in pairs_list:
        if key in result:
            fail(f"duplicate field: {key}")
        result[key] = value
    return result


def require_int(document, key, minimum):
    value = document.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        fail(f"field {key} is malformed")
    return value


def require_string(document, key):
    value = document.get(key)
    if (
        not isinstance(value, str)
        or not value
        or any(character in value for character in ("\x00", "\n", "\r", "\t"))
    ):
        fail(f"field {key} is malformed")
    return value


try:
    with open(claim_file, encoding="utf-8") as handle:
        document = json.load(handle, object_pairs_hook=pairs)
except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
    fail(f"invalid JSON: {error}")

if not isinstance(document, dict):
    fail("top level must be an object")
unknown = set(document) - expected_fields
missing = expected_fields - set(document)
if unknown:
    fail(f"unknown field: {sorted(unknown)[0]}")
if missing:
    fail(f"missing field: {sorted(missing)[0]}")

require_int(document, "pid", 1)
require_int(document, "uid", 0)
for field in ("host", "token", "lock_token", "lock_identity"):
    require_string(document, field)

print("\t".join([
    str(document["pid"]),
    str(document["uid"]),
    document["host"],
    document["token"],
    document["lock_token"],
    document["lock_identity"],
]))
PY_CLAIM
}

recovery_claim_snapshot() {
    local __claim_file="$__recovery_claim/owner.json"
    local __claim_identity_before
    local __owner_identity_before
    local __snapshot
    __claim_identity_before="$(path_identity "$__recovery_claim" 2>/dev/null || true)"
    __owner_identity_before="$(path_identity "$__claim_file" 2>/dev/null || true)"
    [[ -n "$__claim_identity_before" && -n "$__owner_identity_before" ]] || return 1
    __snapshot="$(recovery_claim_snapshot_at "$__claim_file")" || return $?
    local __claim_identity_after
    local __owner_identity_after
    __claim_identity_after="$(path_identity "$__recovery_claim" 2>/dev/null || true)"
    __owner_identity_after="$(path_identity "$__claim_file" 2>/dev/null || true)"
    [[ "$__claim_identity_before" == "$__claim_identity_after" &&
        "$__owner_identity_before" == "$__owner_identity_after" ]] || return 1
    IFS=$'\t' read -r \
        __recovery_claim_snapshot_pid \
        __recovery_claim_snapshot_uid \
        __recovery_claim_snapshot_host \
        __recovery_claim_snapshot_token \
        __recovery_claim_snapshot_lock_token \
        __recovery_claim_snapshot_lock_identity <<< "$__snapshot" || return 1
    __recovery_claim_snapshot_identity="$__claim_identity_before"
    __recovery_claim_snapshot_owner_identity="$__owner_identity_before"
}

lock_is_stale() {
    validate_lock_paths || return $?
    owner_snapshot || {
        print_error "lock owner metadata is missing or malformed"
        return 1
    }
    local __pid="$__owner_snapshot_pid"
    local __uid="$__owner_snapshot_uid"
    local __host="$__owner_snapshot_host"
    local __started="$__owner_snapshot_started_at"
    local __token="$__owner_snapshot_token"
    local __age
    [[ "$__pid" == <-> && "$__uid" == <-> && -n "$__host" && -n "$__started" && -n "$__token" ]] || {
        print_error "lock owner metadata is missing or malformed"
        return 1
    }
    [[ "$__uid" == "$(id -u)" ]] || {
        print_error "stale lock owner belongs to another user"
        return 1
    }
    [[ "$__host" == "$(hostname)" ]] || {
        print_error "stale lock owner belongs to another host"
        return 1
    }
    if kill -0 "$__pid" 2>/dev/null; then
        print_error "lock owner process $__pid is still active"
        return 1
    fi
    __age=$(( $(date +%s) - $(mtime_epoch "$__lock_dir") ))
    (( __age >= 86400 )) || {
        print_error "lock is not at least 24 hours old"
        return 1
    }
    __validated_lock_token="$__token"
    __validated_lock_identity="$(path_identity "$__lock_dir")"
    __validated_lock_owner_identity="$__owner_snapshot_owner_identity"
}

validate_lock_paths() {
    if [[ -d "$__state_dir" && ! -L "$__state_dir" ]]; then
        validate_physical_ancestor_chain "$__lock_dir" "$__state_dir_realpath" \
            "migration lock" || return $?
    fi
    if [[ -L "$__lock_dir" ]]; then
        print_error "migration lock path is a symlink"
        return 1
    fi
    if path_exists "$__lock_dir"; then
        [[ -d "$__lock_dir" && ! -L "$__lock_dir" ]] || {
            print_error "migration lock path is not a physical directory"
            return 1
        }
    fi
    if path_exists "$__lock_dir/owner.json"; then
        [[ -f "$__lock_dir/owner.json" && ! -L "$__lock_dir/owner.json" ]] || {
            print_error "migration lock owner path is not a physical file"
            return 1
        }
    fi
}

write_recovery_claim() {
    local __tmp="$__recovery_claim/owner.json.tmp.$$.$RANDOM"
    umask 077
    {
        print '{'
        print "  \"pid\": $$,"
        print "  \"uid\": $(id -u),"
        print "  \"host\": $(json_quote "$(hostname)"),"
        print "  \"token\": $(json_quote "$__token"),"
        print "  \"lock_token\": $(json_quote "$__validated_lock_token"),"
        print "  \"lock_identity\": $(json_quote "$__validated_lock_identity")"
        print '}'
    } >| "$__tmp" || {
        rm -f -- "$__tmp" || true
        return 1
    }
    chmod 600 "$__tmp" || {
        rm -f -- "$__tmp" || true
        return 1
    }
    mv -f -- "$__tmp" "$__recovery_claim/owner.json"
}

release_recovery_claim() {
    [[ "$__recovery_claim" == "$__lock_dir/recovery.claim" ]] || return 0
    [[ -d "$__recovery_claim" && ! -L "$__recovery_claim" ]] || return 0
    [[ "$(path_identity "$__recovery_claim" 2>/dev/null || true)" == "$__recovery_claim_identity" ]] || return 0
    if [[ -n "$__stale_owner_path" && -e "$__stale_owner_path" ]]; then
        [[ "$__stale_owner_transition_verified" == true ]] || {
            print_error "preserving the quarantined stale migration lock owner"
            return 1
        }
        rm -f -- "$__stale_owner_path" || return 1
    fi
    [[ -f "$__recovery_claim/owner.json" && ! -L "$__recovery_claim/owner.json" ]] || return 0
    recovery_claim_snapshot >/dev/null 2>&1 || return 0
    [[ "$__recovery_claim_snapshot_token" == "$__token" &&
        "$__recovery_claim_snapshot_lock_token" == "$__validated_lock_token" &&
        "$__recovery_claim_snapshot_lock_identity" == "$__validated_lock_identity" &&
        "$__recovery_claim_snapshot_identity" == "$__recovery_claim_identity" ]] || return 0
    rm -f -- "$__recovery_claim/owner.json" || return 1
    rmdir -- "$__recovery_claim" 2>/dev/null || return 1
    __recovery_claim=""
    __recovery_claim_identity=""
    __stale_owner_path=""
    __stale_owner_moved=false
    __stale_owner_transition_verified=false
}

claim_stale_lock() {
    __recovery_claim="$__lock_dir/recovery.claim"
    mkdir "$__recovery_claim" 2>/dev/null || {
        __recovery_claim=""
        __recovery_claim_identity=""
        print_error "another stale-lock recovery is already in progress"
        return 1
    }
    __recovery_claim_identity="$(path_identity "$__recovery_claim" 2>/dev/null || true)"
    [[ -n "$__recovery_claim_identity" ]] || {
        __recovery_claim=""
        __recovery_claim_identity=""
        print_error "could not identify the stale-lock recovery claim"
        return 1
    }
    write_recovery_claim || {
        rmdir -- "$__recovery_claim" 2>/dev/null || true
        __recovery_claim=""
        __recovery_claim_identity=""
        print_error "could not record the stale-lock recovery claim"
        return 1
    }
    if ! stale_lock_claim_valid; then
        release_recovery_claim || true
        print_error "migration lock changed during stale-lock recovery"
        return 1
    fi
    if [[ -n "${MISE_MIGRATION_TEST_AFTER_STALE_CLAIM:-}" ]]; then
        "${MISE_MIGRATION_TEST_AFTER_STALE_CLAIM}" || return $?
    fi
}

stale_lock_claim_valid() {
    owner_snapshot >/dev/null 2>&1 || return 1
    [[ "$__owner_snapshot_lock_identity" == "$__validated_lock_identity" &&
        "$__owner_snapshot_token" == "$__validated_lock_token" ]]
}

stale_lock_dir_claim_valid() {
    [[ "$(path_identity "$__lock_dir" 2>/dev/null || true)" == "$__validated_lock_identity" &&
        -d "$__recovery_claim" && ! -L "$__recovery_claim" &&
        "$(path_identity "$__recovery_claim" 2>/dev/null || true)" == "$__recovery_claim_identity" ]]
}

stale_owner_transition_valid() {
    owner_snapshot >/dev/null 2>&1 || return 1
    [[ "$__owner_snapshot_lock_identity" == "$__validated_lock_identity" &&
        -d "$__recovery_claim" && ! -L "$__recovery_claim" &&
        "$(path_identity "$__recovery_claim" 2>/dev/null || true)" == "$__recovery_claim_identity" &&
        -n "$__new_owner_identity" &&
        -f "$__lock_dir/owner.json" && ! -L "$__lock_dir/owner.json" &&
        "$__owner_snapshot_owner_identity" == "$__new_owner_identity" &&
        "$__owner_snapshot_token" == "$__token" ]]
}

restore_stale_owner_after_install_failure() {
    [[ "$__stale_owner_moved" == true ]] || return 0
    [[ -n "$__stale_owner_path" && -e "$__stale_owner_path" ]] || return 0
    if [[ "$(path_identity "$__lock_dir" 2>/dev/null || true)" == "$__validated_lock_identity" &&
        ! -e "$__lock_dir/owner.json" && ! -L "$__lock_dir/owner.json" ]]; then
        mv -- "$__stale_owner_path" "$__lock_dir/owner.json" || {
            print_error "could not restore the quarantined stale migration lock owner"
            return 1
        }
        if owner_snapshot >/dev/null 2>&1 &&
            [[ "$__owner_snapshot_lock_identity" == "$__validated_lock_identity" &&
                "$__owner_snapshot_owner_identity" == "$__validated_lock_owner_identity" &&
                "$__owner_snapshot_token" == "$__validated_lock_token" ]]; then
            __stale_owner_path=""
            __stale_owner_moved=false
            return 0
        fi
        print_error "restored migration lock owner failed its identity check"
        return 1
    fi
    print_error "preserving evidence because the migration lock changed during owner installation"
    return 1
}

prepare_stale_owner_transition() {
    __stale_owner_path="$__recovery_claim/stale-owner.json"
    [[ ! -e "$__stale_owner_path" && ! -L "$__stale_owner_path" ]] || {
        print_error "stale-lock recovery claim contains an unexpected owner"
        return 1
    }
    owner_snapshot >/dev/null 2>&1 &&
        [[ "$__owner_snapshot_lock_identity" == "$__validated_lock_identity" &&
            "$__owner_snapshot_owner_identity" == "$__validated_lock_owner_identity" &&
            "$__owner_snapshot_token" == "$__validated_lock_token" ]] || {
        print_error "migration lock owner changed during stale-lock recovery"
        return 1
    }
    mv -- "$__lock_dir/owner.json" "$__stale_owner_path" || {
        print_error "migration lock owner changed during stale-lock recovery"
        return 1
    }
    local __stale_owner_identity
    __stale_owner_identity="$(path_identity "$__stale_owner_path" 2>/dev/null || true)"
    local __stale_owner_snapshot
    __stale_owner_snapshot="$(owner_snapshot_at "$__stale_owner_path" 2>/dev/null || true)"
    [[ "$__stale_owner_identity" == "$__validated_lock_owner_identity" &&
        -n "$__stale_owner_snapshot" &&
        "${__stale_owner_snapshot##*$'\t'}" == "$__validated_lock_token" ]] || {
        if [[ ! -e "$__lock_dir/owner.json" && -e "$__stale_owner_path" ]]; then
            mv -- "$__stale_owner_path" "$__lock_dir/owner.json" || true
        fi
        print_error "migration lock owner changed during stale-lock recovery"
        return 1
    }
    stale_lock_dir_claim_valid || {
        if [[ ! -e "$__lock_dir/owner.json" && -e "$__stale_owner_path" ]]; then
            mv -- "$__stale_owner_path" "$__lock_dir/owner.json" || true
        fi
        print_error "migration lock changed during stale-lock recovery"
        return 1
    }
    __stale_owner_moved=true
    if [[ -n "${MISE_MIGRATION_TEST_AFTER_FINAL_STALE_IDENTITY_CHECK:-}" ]]; then
        "${MISE_MIGRATION_TEST_AFTER_FINAL_STALE_IDENTITY_CHECK}" || return $?
    fi
}

mark_lock_created() {
    __lock_created=true
    __created_lock_identity="$(path_identity "$__lock_dir" 2>/dev/null || true)"
    [[ -n "$__created_lock_identity" ]] || {
        __lock_created=false
        print_error "could not identify the newly created migration lock"
        return 1
    }
    if [[ -n "${MISE_MIGRATION_TEST_AFTER_LOCK_MKDIR:-}" ]]; then
        if "${MISE_MIGRATION_TEST_AFTER_LOCK_MKDIR}"; then
            :
        else
            local __status="$?"
            return "$__status"
        fi
    fi
}

run_after_owner_write_hook() {
    [[ -n "${MISE_MIGRATION_TEST_AFTER_OWNER_WRITE:-}" ]] || return 0
    "${MISE_MIGRATION_TEST_AFTER_OWNER_WRITE}"
}

acquire_lock() {
    validate_lock_paths || return $?
    [[ ! -e "$__lock_dir/recovery.claim" ]] || {
        print_error "stale-lock recovery is already in progress"
        return 1
    }
    [[ -n "$__started_at" ]] || __started_at="$(now_utc)"
    if mkdir "$__lock_dir" 2>/dev/null; then
        mark_lock_created || return $?
        __token="$(printf '%s:%s:%s' "$$" "$(date +%s)" "$RANDOM" | shasum -a 256 | cut -d ' ' -f 1)"
        write_owner || return $?
        run_after_owner_write_hook || return $?
        __lock_acquired=true
        return 0
    fi
    if [[ "$__break_stale_lock" != true ]]; then
        print_error "migration lock already exists; use --break-stale-lock after the stale-lock policy passes"
        return 1
    fi
    [[ -f "$__lock_dir/owner.json" && ! -L "$__lock_dir/owner.json" ]] || {
        print_error "cannot break a lock without owner metadata"
        return 1
    }
    lock_is_stale || return $?
    if [[ -n "${MISE_MIGRATION_TEST_BEFORE_STALE_CLAIM:-}" ]]; then
        "${MISE_MIGRATION_TEST_BEFORE_STALE_CLAIM}" || return $?
    fi
    __token="$(printf '%s:%s:%s' "$$" "$(date +%s)" "$RANDOM" | shasum -a 256 | cut -d ' ' -f 1)"
    claim_stale_lock || return $?
    stale_lock_claim_valid || {
        release_recovery_claim || true
        print_error "migration lock changed during stale-lock recovery"
        return 1
    }
    __lock_created=true
    __created_lock_identity="$__validated_lock_identity"
    prepare_stale_owner_transition || {
        local __status="$?"
        release_recovery_claim || true
        return "$__status"
    }
    write_owner || {
        local __status="$?"
        restore_stale_owner_after_install_failure || true
        release_recovery_claim || true
        return "$__status"
    }
    __created_lock_identity="$(path_identity "$__lock_dir" 2>/dev/null || true)"
    run_after_owner_write_hook || {
        local __status="$?"
        if stale_owner_transition_valid; then
            __stale_owner_transition_verified=true
            release_recovery_claim || {
                print_error "could not release the stale-lock recovery claim"
                return 1
            }
        else
            print_error "migration lock owner failed the post-install compare-and-swap check"
        fi
        return "$__status"
    }
    stale_owner_transition_valid || {
        print_error "migration lock owner failed the post-install compare-and-swap check"
        return 1
    }
    __stale_owner_transition_verified=true
    release_recovery_claim || {
        print_error "could not release the stale-lock recovery claim"
        return 1
    }
    __lock_acquired=true
}

release_lock() {
    [[ "$__lock_created" == true ]] || return 0
    [[ -d "$__lock_dir" && ! -L "$__lock_dir" ]] || {
        __lock_created=false
        __lock_acquired=false
        __created_lock_identity=""
        __new_owner_identity=""
        return 0
    }
    [[ "$(path_identity "$__lock_dir" 2>/dev/null || true)" == "$__created_lock_identity" ]] || return 0
    if path_exists "$__lock_dir/owner.json"; then
        [[ -f "$__lock_dir/owner.json" && ! -L "$__lock_dir/owner.json" ]] || {
            print_error "current migration lock owner path is not a physical file"
            return 1
        }
        [[ -n "$__token" ]] || return 0
        owner_snapshot >/dev/null 2>&1 || return 0
        [[ "$__owner_snapshot_token" == "$__token" &&
            "$__owner_snapshot_lock_identity" == "$__created_lock_identity" ]] || return 0
        rm -f -- "$__lock_dir/owner.json" || {
            print_error "could not remove the current migration lock owner metadata"
            return 1
        }
        [[ ! -e "$__lock_dir/owner.json" ]] || {
            print_error "migration lock owner metadata remains after removal"
            return 1
        }
    fi
    rmdir -- "$__lock_dir" 2>/dev/null || {
        print_error "could not remove the current migration lock"
        return 1
    }
    __lock_acquired=false
    __lock_created=false
    __created_lock_identity=""
    __new_owner_identity=""
}

cleanup_on_exit() {
    local __status="$?"
    trap - EXIT INT TERM
    if ! release_recovery_claim; then
        (( __status == 0 )) && __status=1
    fi
    if ! release_lock; then
        (( __status == 0 )) && __status=1
    fi
    exit "$__status"
}

trap 'exit 130' INT
trap 'exit 143' TERM
trap cleanup_on_exit EXIT

confirm() {
    print -n -- "Continue with the migration? [y/N] "
    local __answer
    read -r __answer || return 1
    [[ "$__answer" == [Yy] || "$__answer" == [Yy][Ee][Ss] ]]
}

tracked_source_file() {
    local __path="$1"
    local __relative="${__path#$__source_realpath/}"
    [[ "$__relative" != "$__path" ]] || return 1
    [[ -f "$__path" && ! -L "$__path" ]] || return 1
    git -C "$__checkout" ls-files --error-unmatch -- "$__source_relative_path/$__relative" >/dev/null 2>&1
}

record_approved() {
    local __relative="$1"
    local __path="$2"
    local __optional="$3"
    local __source_path="$__source/$__relative"
    local __link_target="-"
    __approved_paths+=("$__relative")
    if [[ "$__relative" == miserc.local.toml ]]; then
        __approved_types+=("$__selector_inventory_type")
    elif [[ -f "$__source_path" && ! -L "$__source_path" ]]; then
        __approved_types+=(regular)
    elif [[ -L "$__source_path" ]]; then
        __approved_types+=(symlink)
    elif [[ -L "$__path" ]]; then
        __approved_types+=(symlink)
    else
        __approved_types+=(regular)
    fi
    __approved_modes+=("$(file_mode "$__path")")
    __approved_hashes+=("$(sha256_file "$__path")")
    if [[ "$__relative" == miserc.local.toml ]]; then
        __link_target="$__selector_state"
    elif [[ -L "$__path" ]]; then
        __link_target="$(realpath "$__path" 2>/dev/null || true)"
    fi
    __approved_owners+=("$(entry_owner "$__path")")
    __approved_link_targets+=("$__link_target")
    __approved_optional+=("$__optional")
    if path_exists "$__source/$__relative"; then
        __approved_preexisting+=(true)
    else
        __approved_preexisting+=(false)
    fi
}

approved_local() {
    case "$1" in
        config.work.local.toml|conf.d/pip/config.pip.local.conf|conf.d/pip/mise.work.local.toml|conf.d/uv/config.uv.local.toml|conf.d/uv/mise.work.local.toml|miserc.local.toml)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

source_path_tracked() {
    local __relative="$1"
    git -C "$__checkout" ls-files --error-unmatch -- \
        "$__source_relative_path/$__relative" >/dev/null 2>&1
}

validate_approved_inventory() {
    local __index __relative __selector_index=0
    for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
        __relative="${__approved_paths[__index]}"
        approved_local "$__relative" || {
            print_error "manifest approved file is outside the approved local inventory: $__relative"
            return 1
        }
        source_path_tracked "$__relative" && {
            print_error "manifest approved file is tracked source: $__relative"
            return 1
        }
        if [[ "$__relative" == miserc.local.toml ]]; then
            (( __selector_index == 0 )) || {
                print_error "manifest approved inventory contains duplicate selector entries"
                return 1
            }
            __selector_index="$__index"
            [[ "${__approved_optional[__index]}" == true ]] || {
                print_error "manifest selector is not marked optional"
                return 1
            }
        else
            [[ "${__approved_optional[__index]}" == false ]] || {
                print_error "manifest local file is incorrectly marked optional: $__relative"
                return 1
            }
        fi
    done
    if [[ "$__selector_recorded" == true ]]; then
        (( __selector_index > 0 )) || {
            print_error "recorded selector metadata has no approved selector entry"
            return 1
        }
        [[ "$__selector_type" == "$__selector_inventory_type" &&
            -n "$__selector_mode" &&
            -n "$__selector_hash" &&
            "${__approved_types[__selector_index]}" == "$__selector_type" &&
            "${__approved_modes[__selector_index]}" == "$__selector_mode" &&
            "${__approved_hashes[__selector_index]}" == "$__selector_hash" ]] || {
            print_error "recorded selector metadata does not match the approved selector entry"
            return 1
        }
    else
        [[ "$__selector_preexisting" == false &&
            -z "$__selector_type" &&
            -z "$__selector_mode" &&
            -z "$__selector_hash" ]] || {
            print_error "unrecorded selector has recorded metadata"
            return 1
        }
    fi
}

compare_inventory_entries() {
    local __label="$1"
    local -a __manifest_paths=("${(@P)2}")
    local -a __manifest_types=("${(@P)3}")
    local -a __manifest_modes=("${(@P)4}")
    local -a __manifest_hashes=("${(@P)5}")
    local -a __manifest_owners=("${(@P)6}")
    local -a __manifest_link_targets=("${(@P)7}")
    local -a __inventory_paths=("${(@P)8}")
    local -a __inventory_types=("${(@P)9}")
    local -a __inventory_modes=("${(@P)10}")
    local -a __inventory_hashes=("${(@P)11}")
    local -a __inventory_owners=("${(@P)12}")
    local -a __inventory_link_targets=("${(@P)13}")
    local __index __inventory_index
    [[ "${#__manifest_paths}" -eq "${#__inventory_paths}" ]] || {
        print_error "$__label inventory does not match the recorded inventory"
        return 1
    }
    for (( __index = 1; __index <= ${#__manifest_paths}; __index++ )); do
        __inventory_index=1
        while (( __inventory_index <= ${#__inventory_paths} )) &&
            [[ "${__inventory_paths[__inventory_index]}" != "${__manifest_paths[__index]}" ]]; do
            (( __inventory_index++ ))
        done
        (( __inventory_index <= ${#__inventory_paths} )) || {
            print_error "$__label inventory has an unknown path: ${__manifest_paths[__index]}"
            return 1
        }
        [[ "${__manifest_types[__index]}" == "${__inventory_types[__inventory_index]}" &&
            "${__manifest_modes[__index]}" == "${__inventory_modes[__inventory_index]}" &&
            "${__manifest_hashes[__index]}" == "${__inventory_hashes[__inventory_index]}" &&
            "${__manifest_owners[__index]}" == "${__inventory_owners[__inventory_index]}" &&
            "${__manifest_link_targets[__index]}" == "${__inventory_link_targets[__inventory_index]}" ]] || {
            print_error "$__label inventory facts changed: ${__manifest_paths[__index]}"
            return 1
        }
    done
}

compare_source_preexisting_inventory() {
    local __index __inventory_index
    [[ "${#__approved_paths}" -eq "${#__inventory_approved_paths}" ]] || {
        print_error "approved source inventory does not match the recorded inventory"
        return 1
    }
    for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
        __inventory_index=1
        while (( __inventory_index <= ${#__inventory_approved_paths} )) &&
            [[ "${__inventory_approved_paths[__inventory_index]}" != "${__approved_paths[__index]}" ]]; do
            (( __inventory_index++ ))
        done
        (( __inventory_index <= ${#__inventory_approved_paths} )) || {
            print_error "approved source inventory has an unknown path: ${__approved_paths[__index]}"
            return 1
        }
        [[ "${__approved_types[__index]}" == "${__inventory_approved_types[__inventory_index]}" &&
            "${__approved_modes[__index]}" == "${__inventory_approved_modes[__inventory_index]}" &&
            "${__approved_hashes[__index]}" == "${__inventory_approved_hashes[__inventory_index]}" &&
            "${__approved_owners[__index]}" == "${__inventory_approved_owners[__inventory_index]}" &&
            "${__approved_link_targets[__index]}" == "${__inventory_approved_link_targets[__inventory_index]}" &&
            "${__approved_optional[__index]}" == "${__inventory_approved_optional[__inventory_index]}" &&
            "${__approved_preexisting[__index]}" == "${__inventory_approved_preexisting[__inventory_index]}" ]] || {
            print_error "approved source inventory facts changed: ${__approved_paths[__index]}"
            return 1
        }
    done
}

load_inventory() {
    local __inventory="$__backup/source-inventory.json"
    [[ -f "$__inventory" && ! -L "$__inventory" ]] || {
        print_error "recorded source inventory is missing"
        return 1
    }
    local __parsed_inventory
    __parsed_inventory="$(parse_inventory_strict "$__inventory" 2>&1)" || {
        print_error "$__parsed_inventory"
        return 1
    }
    __inventory_approved_paths=()
    __inventory_approved_types=()
    __inventory_approved_modes=()
    __inventory_approved_hashes=()
    __inventory_approved_owners=()
    __inventory_approved_link_targets=()
    __inventory_approved_optional=()
    __inventory_approved_preexisting=()
    __inventory_backup_paths=()
    __inventory_backup_types=()
    __inventory_backup_modes=()
    __inventory_backup_hashes=()
    __inventory_backup_owners=()
    __inventory_backup_link_targets=()
    local __kind __key __value __field4 __field5 __field6 __field7 __field8 __field9
    local __path __type __mode __hash __owner __link_target
    while IFS=$'\t' read -r __kind __key __value __field4 __field5 __field6 __field7 __field8 __field9; do
        case "$__kind" in
            BACKUP)
                __inventory_backup_paths+=("$(print -rn -- "$__key" | decode_base64)")
                __inventory_backup_types+=("$(print -rn -- "$__value" | decode_base64)")
                __inventory_backup_modes+=("$(print -rn -- "$__field4" | decode_base64)")
                __inventory_backup_hashes+=("$(print -rn -- "$__field5" | decode_base64)")
                __inventory_backup_owners+=("$(print -rn -- "$__field6" | decode_base64)")
                __inventory_backup_link_targets+=("$(print -rn -- "$__field7" | decode_base64)")
                ;;
            APPROVED)
                __inventory_approved_paths+=("$(print -rn -- "$__key" | decode_base64)")
                __inventory_approved_types+=("$(print -rn -- "$__value" | decode_base64)")
                __inventory_approved_modes+=("$(print -rn -- "$__field4" | decode_base64)")
                __inventory_approved_hashes+=("$(print -rn -- "$__field5" | decode_base64)")
                __inventory_approved_owners+=("$(print -rn -- "$__field6" | decode_base64)")
                __inventory_approved_link_targets+=("$(print -rn -- "$__field7" | decode_base64)")
                __inventory_approved_optional+=("$__field8")
                __inventory_approved_preexisting+=("$__field9")
                ;;
        esac
    done <<< "$__parsed_inventory"
    compare_inventory_entries "backup" \
        __backup_paths __backup_types __backup_modes __backup_hashes \
        __backup_owners __backup_link_targets \
        __inventory_backup_paths __inventory_backup_types \
        __inventory_backup_modes __inventory_backup_hashes \
        __inventory_backup_owners __inventory_backup_link_targets || return $?
    compare_source_preexisting_inventory || return $?
}

scan_target() {
    local __entry __relative __resolved __optional
    local -a __entries=() __children=()
    [[ -d "$__target" && ! -L "$__target" ]] || return 0
    __entries=("$__target"/**/*(ND))
    for __entry in "${__entries[@]}"; do
        __relative="${__entry#$__target/}"
        if [[ -d "$__entry" && ! -L "$__entry" ]]; then
            __children=("$__entry"/*(ND))
            (( ${#__children} > 0 )) || {
                print_error "unknown old-target directory: $__relative"
                return 1
            }
            continue
        fi
        if approved_local "$__relative"; then
            if [[ -d "$__entry" || ! -f "$__entry" && ! -L "$__entry" ]]; then
                print_error "approved entry has an invalid source type: $__relative"
                return 1
            fi
            if [[ "$__relative" != miserc.local.toml && -L "$__entry" ]]; then
                print_error "approved local file must be regular: $__relative"
                return 1
            fi
            if [[ "$__relative" == miserc.local.toml ]]; then
                    if [[ -L "$__entry" ]]; then
                        __resolved="$(realpath "$__entry" 2>/dev/null || true)"
                        same_canonical_path "$__entry" "$__selector_state" || {
                            print_error "old profile selector symlink does not resolve to the canonical selector state"
                            return 1
                        }
                        [[ -f "$__selector_state" && ! -L "$__selector_state" ]] || {
                            print_error "old profile selector symlink does not reference a regular selector state file"
                            return 1
                        }
                        [[ "$(file_owner "$__selector_state")" == "$(id -u)" ]] || {
                            print_error "old profile selector state is not owned by the current user"
                            return 1
                        }
                    elif [[ ! -f "$__entry" || -L "$__entry" ]]; then
                        print_error "miserc.local.toml has an invalid source type"
                        return 1
                    fi
                    local __contents="$(cat "$__entry" 2>/dev/null || true)"
                [[ "$__contents" == 'env = ["work"]' || "$__contents" == 'env = ["personal"]' ]] || {
                    print_error "miserc.local.toml has an invalid selector"
                    return 1
                }
                __optional=true
            else
                __optional=false
            fi
            record_approved "$__relative" "$__entry" "$__optional"
            continue
        fi
        [[ -L "$__entry" ]] || {
            print_error "unknown old-target entry: $__relative"
            return 1
        }
        __resolved="$(realpath "$__entry" 2>/dev/null || true)"
        [[ -n "$__resolved" ]] || {
            print_error "old-target symlink is unresolved: $__relative"
            return 1
        }
        tracked_source_file "$__resolved" || {
            print_error "old-target symlink does not resolve to a tracked source file: $__relative"
            return 1
        }
        continue
    done
}

check_source_collisions() {
    local __index=1
    local __relative __source_path __source_parent
    for __relative in "${__approved_paths[@]}"; do
        __source_path="$__source/$__relative"
        __source_parent="${__source_path:h}"
        while [[ "$__source_parent" != "$__source_realpath" ]]; do
            [[ -d "$__source_parent" && ! -L "$__source_parent" ]] || {
                print_error "source parent is not a physical directory: $__relative"
                return 1
            }
            __source_parent="${__source_parent:h}"
        done
        if [[ "$__relative" == miserc.local.toml ]]; then
            if path_exists "$__source_path"; then
                [[ -L "$__source_path" ]] && same_canonical_path "$__source_path" "$__selector_state" || {
                    print_error "source collision for the optional selector: $__relative"
                    return 1
                }
            fi
        elif path_exists "$__source_path"; then
            [[ -f "$__source_path" && ! -L "$__source_path" ]] || {
                print_error "source collision for approved file: $__relative"
                return 1
            }
            [[ "$(file_mode "$__source_path")" == "${__approved_modes[__index]}" && "$(sha256_file "$__source_path")" == "${__approved_hashes[__index]}" ]] || {
                print_error "source collision for approved file: $__relative"
                return 1
            }
        fi
        source_path_tracked "$__relative" && {
            print_error "approved source path is tracked: $__relative"
            return 1
        }
        (( __index++ ))
    done
}

preflight() {
    local __recovery="${1:-false}"
    local __git_root __origin __parent_real __state_fs_parent
    __checkout="$HOME/dev/personal/dot"
    [[ -d "$__checkout" ]] || {
        print_error "canonical checkout is missing: $__canonical_relative_checkout"
        return 1
    }
    __git_root="$(git -C "$__checkout" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$__git_root" ]] || {
        print_error "canonical checkout is not a Git worktree"
        return 1
    }
    __checkout_realpath="$(realpath "$__git_root")"
    [[ "$__checkout_realpath" == "$(realpath "$__checkout")" ]] || {
        print_error "checkout path does not resolve to the canonical path: $__canonical_relative_checkout"
        return 1
    }
    __checkout="$__checkout_realpath"
    __origin="$(git -C "$__checkout_realpath" config --get remote.origin.url 2>/dev/null || true)"
    [[ "$__origin" == "$__canonical_origin" ]] || {
        print_error "checkout origin must be $__canonical_origin"
        return 1
    }
    __source="$__checkout_realpath/$__source_relative_path"
    [[ -d "$__source" && ! -L "$__source" ]] || {
        print_error "config source is not a physical directory inside the checkout"
        return 1
    }
    __source_realpath="$(realpath "$__source")"
    path_inside "$__source_realpath" "$__checkout_realpath" || {
        print_error "config source is outside the checkout"
        return 1
    }
    __target="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
    __target_parent="${__target:h}"
    [[ -d "$__target_parent" ]] || {
        print_error "config target parent is unresolved: $__target_parent"
        return 1
    }
    __parent_real="$(realpath "$__target_parent")"
    __target_parent="$__parent_real"
    __target="$__target_parent/mise"
    if [[ "$__recovery" != true ]]; then
        if path_exists "$__target"; then
            __target_preexisting=true
        else
            __target_preexisting=false
        fi
    fi
    path_inside "$__parent_real" "$(realpath "$HOME")" || {
        print_error "config target is outside HOME"
        return 1
    }
    if [[ -L "$__target" ]]; then
        [[ "$(realpath "$__target" 2>/dev/null || true)" == "$__source_realpath" ]] || {
            print_error "config target is already a link to another source"
            return 1
        }
    elif [[ -d "$__target" && "$(realpath "$__target")" == "$__source_realpath" ]]; then
        print_error "config target must be a symlink to the repository source"
        return 1
    elif path_exists "$__target" && [[ ! -d "$__target" ]]; then
        print_error "config target is not a directory or the expected source link"
        return 1
    fi
    local __state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    __state_home_realpath="$(python3 - "$__state_home" <<'PY_STATE_PATH'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY_STATE_PATH
)" || {
        print_error "state home cannot be normalized"
        return 1
    }
    __state_dir="$__state_home_realpath/$__state_relative_path"
    __state_dir_realpath="$(python3 - "$__state_dir" <<'PY_STATE_PATH'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY_STATE_PATH
)" || {
        print_error "state directory cannot be normalized"
        return 1
    }
    __manifest="$__state_dir/transaction.json"
    __lock_dir="$__state_dir/transaction.lock"
    __state_backups_root="$__state_dir_realpath/backups"
    __selector_state="$__state_home_realpath/minusfive/miserc.local.toml"
    __state_fs_parent="$__state_dir"
    while [[ ! -d "$__state_fs_parent" ]]; do
        __state_fs_parent="${__state_fs_parent:h}"
        [[ "$__state_fs_parent" == "/" ]] && break
    done
    [[ "$(device_id "$__parent_real")" == "$(device_id "$__state_fs_parent")" ]] || {
        print_error "config target and source are on different filesystems"
        return 1
    }
    if path_exists "$__state_dir"; then
        [[ -d "$__state_dir" && ! -L "$__state_dir" &&
            "$(realpath "$__state_dir" 2>/dev/null || true)" == "$__state_dir_realpath" ]] || {
            print_error "migration state directory is not a physical canonical directory"
            return 1
        }
    fi
    if path_exists "$__state_backups_root"; then
        validate_physical_ancestor_chain "$__state_backups_root" "$__state_dir_realpath" \
            "migration backup root" || return $?
    fi
    if [[ "$__recovery" != true && ! -x "$__canonical_mise_path" ]]; then
        print_error "canonical mise binary is missing: $__canonical_mise_path"
        return 1
    fi
    if [[ "$__recovery" != true ]]; then
        if [[ -d "$__target" && ! -L "$__target" ]]; then
            scan_target || return $?
        fi
        check_source_collisions || return $?
    fi
}

new_migration_manifest_guard() {
    path_exists "$__manifest" || return 0
    local __existing_state="$(manifest_state)"
    case "$__existing_state" in
        verified|committed)
            load_manifest || return $?
            recovery_preflight || return $?
            verify_target || return $?
            verify_approved || return $?
            __completed_rerun=true
            return 0
            ;;
        rolled_back)
            return 0
            ;;
        *)
            print_error "a nonterminal transaction manifest already exists; run --rollback or recovery before starting a new migration"
            return 1
            ;;
    esac
}

recovery_preflight() {
    preflight true || return $?
    [[ -d "$__state_dir" && ! -L "$__state_dir" &&
        "$(realpath "$__state_dir" 2>/dev/null || true)" == "$__state_dir_realpath" ]] || {
        print_error "transaction state directory is not a physical canonical directory"
        return 1
    }
    validate_physical_ancestor_chain "$__lock_dir" "$__state_dir_realpath" \
        "transaction lock" || return $?
    if path_exists "$__state_backups_root"; then
        validate_physical_ancestor_chain "$__state_backups_root" "$__state_dir_realpath" \
            "transaction backup root" || return $?
    fi
    [[ "$__recorded_checkout" == "$__checkout" ]] || {
        print_error "transaction belongs to another checkout"
        return 1
    }
    [[ "$__recorded_checkout_realpath" == "$__checkout_realpath" ]] || {
        print_error "transaction checkout identity changed"
        return 1
    }
    [[ "$__recorded_origin" == "$__canonical_origin" ]] || {
        print_error "transaction origin is not canonical"
        return 1
    }
    [[ "$__recorded_source" == "$__source" ]] || {
        print_error "transaction belongs to another config source"
        return 1
    }
    [[ "$__recorded_target" == "$__target" ]] || {
        print_error "transaction belongs to another config target"
        return 1
    }
    [[ -d "$__state_backups_root" && ! -L "$__state_backups_root" ]] &&
        __state_backups_root="$(realpath "$__state_backups_root")"
    [[ "$__recorded_backup" == "$__state_backups_root/"* ]] || {
        print_error "transaction backup is outside the migration state directory"
        return 1
    }
    if path_exists "$__recorded_backup"; then
        [[ -d "$__recorded_backup" && ! -L "$__recorded_backup" ]] || {
            print_error "transaction backup is not a physical directory"
            return 1
        }
        local __backup_realpath="$(realpath "$__recorded_backup" 2>/dev/null || true)"
        local __backups_realpath="$(realpath "$__state_backups_root" 2>/dev/null || true)"
        [[ -n "$__backup_realpath" && -n "$__backups_realpath" ]] &&
            path_inside "$__backup_realpath" "$__backups_realpath" || {
            print_error "transaction backup resolves outside the migration state directory"
            return 1
        }
    fi
}

prepare_backup_entries() {
    local __entry __relative
    __backup_paths=()
    __backup_types=()
    __backup_modes=()
    __backup_hashes=()
    __backup_owners=()
    __backup_link_targets=()
    [[ -d "$__target" && ! -L "$__target" ]] || return 0
    local -a __entries=("$__target"/**/*(ND))
    for __entry in "${__entries[@]}"; do
        [[ -d "$__entry" && ! -L "$__entry" ]] && continue
        __relative="${__entry#$__target/}"
        __backup_paths+=("$__relative")
        if [[ -L "$__entry" ]]; then
            __backup_types+=(symlink)
        else
            __backup_types+=(regular)
        fi
        __backup_modes+=("$(file_mode "$__entry")")
        __backup_hashes+=("$(sha256_file "$__entry")")
        __backup_owners+=("$(entry_owner "$__entry")")
        if [[ -L "$__entry" ]]; then
            __backup_link_targets+=("$(realpath "$__entry" 2>/dev/null || true)")
        else
            __backup_link_targets+=("-")
        fi
    done
}

stage_file() {
    local __relative="$1"
    local __source_path="$__source/$__relative"
    local __backup_path="$__backup/config-dir/$__relative"
    local __tmp="$__source_path.tmp.$$.$RANDOM"
    local __parent="${__source_path:h}"
    local __index=1
    while (( __index <= ${#__approved_paths} )) && [[ "${__approved_paths[__index]}" != "$__relative" ]]; do
        (( __index++ ))
    done
    (( __index <= ${#__approved_paths} )) || {
        print_error "approved file was not recorded: $__relative"
        return 1
    }
    mkdir -p -- "$__parent"
    local __status="$?"
    (( __status == 0 )) || return "$__status"
    if path_exists "$__source_path"; then
        case "${__approved_types[__index]}" in
            regular)
                [[ -f "$__source_path" && ! -L "$__source_path" ]] || {
                    print_error "source collision for approved file: $__relative"
                    return 1
                }
                ;;
            symlink)
                [[ -L "$__source_path" ]] || {
                    print_error "source collision for approved file: $__relative"
                    return 1
                }
                ;;
            *)
                print_error "approved file has an unsupported source type: $__relative"
                return 1
                ;;
        esac
        [[ "$(file_mode "$__source_path")" == "${__approved_modes[__index]}" && "$(sha256_file "$__source_path")" == "${__approved_hashes[__index]}" ]] || {
            print_error "source collision for approved file: $__relative"
            return 1
        }
        return 0
    fi
    [[ -f "$__backup_path" || -L "$__backup_path" ]] || return 0
    if [[ -L "$__backup_path" ]]; then
        ln -s "$(readlink "$__backup_path")" "$__tmp"
        __status="$?"
    else
        cp -p "$__backup_path" "$__tmp"
        __status="$?"
    fi
    if (( __status != 0 )); then
        rm -f -- "$__tmp" || true
        return "$__status"
    fi
    mv -f -- "$__tmp" "$__source_path"
    __status="$?"
    if (( __status != 0 )); then
        rm -f -- "$__tmp" || true
        return "$__status"
    fi
}

stage_selector() {
    local __index=1
    local __relative
    local __status
    for __relative in "${__approved_paths[@]}"; do
        [[ "$__relative" == miserc.local.toml ]] || {
            (( __index++ ))
            continue
        }
        local __backup_path="$__backup/config-dir/$__relative"
        if path_exists "$__selector_state"; then
            [[ -f "$__selector_state" && ! -L "$__selector_state" ]] || {
                print_error "existing profile selector has an unsupported type"
                return 1
            }
            [[ "$(file_owner "$__selector_state")" == "$(id -u)" ]] || {
                print_error "existing profile selector is not owned by the current user"
                return 1
            }
            [[ "$(file_mode "$__selector_state")" == "${__approved_modes[__index]}" &&
                "$(sha256_file "$__selector_state")" == "${__approved_hashes[__index]}" ]] || {
                print_error "existing profile selector content or mode does not match the recorded selector"
                return 1
            }
            __selector_recorded=true
            __selector_preexisting=true
            __selector_type="$__selector_inventory_type"
            __selector_mode="$(file_mode "$__selector_state")"
            __selector_hash="$(sha256_file "$__selector_state")"
        else
            __selector_recorded=true
            __selector_preexisting=false
            __selector_type="$__selector_inventory_type"
            __selector_mode="${__approved_modes[__index]}"
            __selector_hash="${__approved_hashes[__index]}"
        fi
        write_manifest || return $?
        local __tmp="$__selector_state.tmp.$$.$RANDOM"
        mkdir -p -- "${__selector_state:h}" "${__source:h}"
        __status="$?"
        (( __status == 0 )) || return "$__status"
        if [[ "$__selector_preexisting" == false ]]; then
            cp -p "$__backup_path" "$__tmp"
            __status="$?"
            if (( __status != 0 )); then
                rm -f -- "$__tmp" || true
                return "$__status"
            fi
            chmod "${__approved_modes[__index]}" "$__tmp"
            __status="$?"
            if (( __status != 0 )); then
                rm -f -- "$__tmp" || true
                return "$__status"
            fi
            mv -f -- "$__tmp" "$__selector_state"
            __status="$?"
            if (( __status != 0 )); then
                rm -f -- "$__tmp" || true
                return "$__status"
            fi
        fi
        if [[ -n "${MISE_MIGRATION_TEST_AFTER_SELECTOR_MOVE:-}" ]]; then
            "${MISE_MIGRATION_TEST_AFTER_SELECTOR_MOVE}"
            __status="$?"
            (( __status == 0 )) || return "$__status"
        fi
        local __link_tmp="$__source/miserc.local.toml.tmp.$$.$RANDOM"
        if path_exists "$__source/miserc.local.toml"; then
            [[ -L "$__source/miserc.local.toml" ]] &&
                same_canonical_path "$__source/miserc.local.toml" "$__selector_state" || {
                print_error "source collision for the profile selector"
                return 1
            }
        else
            ln -s "$__selector_state" "$__link_tmp"
            __status="$?"
            if (( __status != 0 )); then
                rm -f -- "$__link_tmp" || true
                return "$__status"
            fi
            mv -f -- "$__link_tmp" "$__source/miserc.local.toml"
            __status="$?"
            if (( __status != 0 )); then
                rm -f -- "$__link_tmp" || true
                return "$__status"
            fi
        fi
        break
    done
}

record_backup_entries() {
    local __entry __relative
    __backup_paths=()
    __backup_types=()
    __backup_modes=()
    __backup_hashes=()
    __backup_owners=()
    __backup_link_targets=()
    __selector_recorded=false
    __selector_preexisting=false
    __selector_type=""
    __selector_mode=""
    __selector_hash=""
    [[ -d "$__backup/config-dir" ]] || return 0
    local -a __entries=("$__backup/config-dir"/**/*(ND))
    for __entry in "${__entries[@]}"; do
        [[ -d "$__entry" && ! -L "$__entry" ]] && continue
        __relative="${__entry#$__backup/config-dir/}"
        __backup_paths+=("$__relative")
        [[ -L "$__entry" ]] && __backup_types+=(symlink) || __backup_types+=(regular)
        __backup_modes+=("$(file_mode "$__entry")")
        __backup_hashes+=("$(sha256_file "$__entry")")
        __backup_owners+=("$(entry_owner "$__entry")")
        if [[ -L "$__entry" ]]; then
            __backup_link_targets+=("$(realpath "$__entry" 2>/dev/null || true)")
        else
            __backup_link_targets+=("-")
        fi
    done
}

load_manifest_impl() {
    [[ -n "$__source_realpath" ]] || preflight true || return $?
    local __expected_checkout="$__checkout"
    local __expected_checkout_realpath="$__checkout_realpath"
    local __expected_source="$__source"
    local __expected_source_realpath="$__source_realpath"
    local __expected_target="$__target"
    local __expected_target_parent="$__target_parent"
    local __expected_state_backups_root="$__state_backups_root"
    local __expected_selector_state="$__selector_state"
    __manifest="$__state_dir/transaction.json"
    __lock_dir="$__state_dir/transaction.lock"
    [[ -f "$__manifest" ]] || {
        print_error "transaction manifest is missing: $__manifest"
        return 1
    }
    local __parsed_manifest
    __parsed_manifest="$(
        parse_manifest_strict "$__manifest" "$__expected_checkout" "$__expected_source" \
            "$__canonical_mise_path" "$__canonical_origin" "$__source_relative_path" 2>&1
    )" || {
        print_error "$__parsed_manifest"
        return 1
    }
    __manifest_checkout=""
    __manifest_checkout_realpath=""
    __recorded_origin=""
    __manifest_source=""
    __manifest_target=""
    __manifest_backup=""
    __manifest_quarantine=""
    __target_preexisting=false
    __target_identity=""
    __transaction_state=""
    __rollback_state=""
    __backup_moved=false
    __selector_recorded=false
    __selector_preexisting=false
    __selector_type=""
    __selector_mode=""
    __selector_hash=""
    __approved_paths=()
    __approved_types=()
    __approved_modes=()
    __approved_hashes=()
    __approved_owners=()
    __approved_link_targets=()
    __approved_optional=()
    __approved_preexisting=()
    __backup_paths=()
    __backup_types=()
    __backup_modes=()
    __backup_hashes=()
    __backup_owners=()
    __backup_link_targets=()
    __rollback_remove_paths=()
    __manifest_preexisting_paths=()
    __manifest_preexisting_values=()
    local __kind __key __value __field4 __field5 __field6 __field7 __field8 __field9
    local __path __type __mode __hash __owner __link_target __optional __preexisting
    while IFS=$'\t' read -r __kind __key __value __field4 __field5 __field6 __field7 __field8 __field9; do
        case "$__kind" in
            SCALAR)
                __value="$(print -rn -- "$__value" | decode_base64)"
                case "$__key" in
                    transaction_state) __transaction_state="$__value" ;;
                    rollback_state) __rollback_state="$__value" ;;
                    checkout) __manifest_checkout="$__value" ;;
                    checkout_realpath) __manifest_checkout_realpath="$__value" ;;
                    origin) __recorded_origin="$__value" ;;
                    config_source) __manifest_source="$__value" ;;
                    target) __manifest_target="$__value" ;;
                    backup) __manifest_backup="$__value" ;;
                    rollback_quarantine) __manifest_quarantine="$__value" ;;
                    target_identity) __target_identity="$__value" ;;
                    selector_type) __selector_type="$__value" ;;
                    selector_mode) __selector_mode="$__value" ;;
                    selector_sha256) __selector_hash="$__value" ;;
                esac
                ;;
            BOOL)
                case "$__key" in
                    backup_moved) __backup_moved="$__value" ;;
                    target_preexisting) __target_preexisting="$__value" ;;
                    selector_recorded) __selector_recorded="$__value" ;;
                    selector_preexisting) __selector_preexisting="$__value" ;;
                esac
                ;;
            BACKUP)
                __path="$(print -rn -- "$__key" | decode_base64)"
                __type="$(print -rn -- "$__value" | decode_base64)"
                __mode="$(print -rn -- "$__field4" | decode_base64)"
                __hash="$(print -rn -- "$__field5" | decode_base64)"
                __owner="$(print -rn -- "$__field6" | decode_base64)"
                __link_target="$(print -rn -- "$__field7" | decode_base64)"
                __backup_paths+=("$__path")
                __backup_types+=("$__type")
                __backup_modes+=("$__mode")
                __backup_hashes+=("$__hash")
                __backup_owners+=("$__owner")
                __backup_link_targets+=("$__link_target")
                ;;
            APPROVED)
                __path="$(print -rn -- "$__key" | decode_base64)"
                __type="$(print -rn -- "$__value" | decode_base64)"
                __mode="$(print -rn -- "$__field4" | decode_base64)"
                __hash="$(print -rn -- "$__field5" | decode_base64)"
                __owner="$(print -rn -- "$__field6" | decode_base64)"
                __link_target="$(print -rn -- "$__field7" | decode_base64)"
                __approved_paths+=("$__path")
                __approved_types+=("$__type")
                __approved_modes+=("$__mode")
                __approved_hashes+=("$__hash")
                __approved_owners+=("$__owner")
                __approved_link_targets+=("$__link_target")
                __approved_optional+=("$__field8")
                __approved_preexisting+=("$__field9")
                ;;
            FACT)
                __manifest_preexisting_paths+=("$(print -rn -- "$__key" | decode_base64)")
                __manifest_preexisting_values+=("$__value")
                ;;
        esac
    done <<< "$__parsed_manifest"

    validate_manifest_paths \
        "$__expected_checkout" \
        "$__expected_checkout_realpath" \
        "$__expected_source" \
        "$__expected_source_realpath" \
        "$__expected_target" \
        "$__expected_target_parent" \
        "$__expected_state_backups_root" \
        "$__expected_selector_state" || return $?
    validate_approved_inventory || return $?

    [[ "${#__approved_paths}" -eq "${#__manifest_preexisting_paths}" ]] || {
        print_error "manifest source_preexisting facts are incomplete"
        return 1
    }
    local __index
    for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
        [[ "${__manifest_preexisting_paths[__index]}" == "${__approved_paths[__index]}" &&
            "${__manifest_preexisting_values[__index]}" == "${__approved_preexisting[__index]}" ]] || {
            print_error "manifest source_preexisting facts do not match approved files"
            return 1
        }
    done

    __recorded_checkout="$__manifest_checkout"
    __recorded_checkout_realpath="$__manifest_checkout_realpath"
    __recorded_source="$__manifest_source"
    __recorded_target="$__manifest_target"
    __recorded_backup="$__manifest_backup"
    __checkout="$__recorded_checkout"
    __checkout_realpath="$__recorded_checkout_realpath"
    __source="$__recorded_source"
    __source_realpath="$__expected_source_realpath"
    __target="$__recorded_target"
    __backup="$__recorded_backup"
    __rollback_quarantine="$__manifest_quarantine"
    case "$__transaction_state" in
        backup_pending|backed_up|staging|staged|linked|verified|rollback_pending|commit_pending)
            load_inventory || return $?
            ;;
        failed)
            [[ "$__rollback_state" == prepared ]] || load_inventory || return $?
            ;;
    esac
}

load_manifest() {
    local __saved_checkout="$__checkout"
    local __saved_checkout_realpath="$__checkout_realpath"
    local __saved_source="$__source"
    local __saved_source_realpath="$__source_realpath"
    local __saved_target="$__target"
    local __saved_target_parent="$__target_parent"
    local __saved_state_home_realpath="$__state_home_realpath"
    local __saved_state_dir="$__state_dir"
    local __saved_state_dir_realpath="$__state_dir_realpath"
    local __saved_state_backups_root="$__state_backups_root"
    local __saved_manifest="$__manifest"
    local __saved_lock_dir="$__lock_dir"
    local __saved_backup="$__backup"
    local __saved_selector_state="$__selector_state"
    local __saved_rollback_quarantine="$__rollback_quarantine"
    local __saved_transaction_state="$__transaction_state"
    local __saved_rollback_state="$__rollback_state"
    local __saved_backup_moved="$__backup_moved"
    local __saved_selector_recorded="$__selector_recorded"
    local __saved_selector_preexisting="$__selector_preexisting"
    local __saved_selector_type="$__selector_type"
    local __saved_selector_mode="$__selector_mode"
    local __saved_selector_hash="$__selector_hash"
    local __saved_recorded_checkout="$__recorded_checkout"
    local __saved_recorded_checkout_realpath="$__recorded_checkout_realpath"
    local __saved_recorded_origin="$__recorded_origin"
    local __saved_recorded_source="$__recorded_source"
    local __saved_recorded_target="$__recorded_target"
    local __saved_recorded_backup="$__recorded_backup"
    local __saved_manifest_checkout="$__manifest_checkout"
    local __saved_manifest_checkout_realpath="$__manifest_checkout_realpath"
    local __saved_manifest_source="$__manifest_source"
    local __saved_manifest_target="$__manifest_target"
    local __saved_manifest_backup="$__manifest_backup"
    local __saved_manifest_quarantine="$__manifest_quarantine"
    local __saved_target_preexisting="$__target_preexisting"
    local __saved_target_identity="$__target_identity"
    local -a __saved_approved_paths=("${__approved_paths[@]}")
    local -a __saved_approved_types=("${__approved_types[@]}")
    local -a __saved_approved_modes=("${__approved_modes[@]}")
    local -a __saved_approved_hashes=("${__approved_hashes[@]}")
    local -a __saved_approved_owners=("${__approved_owners[@]}")
    local -a __saved_approved_link_targets=("${__approved_link_targets[@]}")
    local -a __saved_approved_optional=("${__approved_optional[@]}")
    local -a __saved_approved_preexisting=("${__approved_preexisting[@]}")
    local -a __saved_backup_paths=("${__backup_paths[@]}")
    local -a __saved_backup_types=("${__backup_types[@]}")
    local -a __saved_backup_modes=("${__backup_modes[@]}")
    local -a __saved_backup_hashes=("${__backup_hashes[@]}")
    local -a __saved_backup_owners=("${__backup_owners[@]}")
    local -a __saved_backup_link_targets=("${__backup_link_targets[@]}")
    local -a __saved_manifest_preexisting_paths=("${__manifest_preexisting_paths[@]}")
    local -a __saved_manifest_preexisting_values=("${__manifest_preexisting_values[@]}")
    local -a __saved_inventory_approved_paths=("${__inventory_approved_paths[@]}")
    local -a __saved_inventory_approved_types=("${__inventory_approved_types[@]}")
    local -a __saved_inventory_approved_modes=("${__inventory_approved_modes[@]}")
    local -a __saved_inventory_approved_hashes=("${__inventory_approved_hashes[@]}")
    local -a __saved_inventory_approved_owners=("${__inventory_approved_owners[@]}")
    local -a __saved_inventory_approved_link_targets=("${__inventory_approved_link_targets[@]}")
    local -a __saved_inventory_approved_optional=("${__inventory_approved_optional[@]}")
    local -a __saved_inventory_approved_preexisting=("${__inventory_approved_preexisting[@]}")
    local -a __saved_inventory_backup_paths=("${__inventory_backup_paths[@]}")
    local -a __saved_inventory_backup_types=("${__inventory_backup_types[@]}")
    local -a __saved_inventory_backup_modes=("${__inventory_backup_modes[@]}")
    local -a __saved_inventory_backup_hashes=("${__inventory_backup_hashes[@]}")
    local -a __saved_inventory_backup_owners=("${__inventory_backup_owners[@]}")
    local -a __saved_inventory_backup_link_targets=("${__inventory_backup_link_targets[@]}")
    local __status=0

    load_manifest_impl || __status=$?
    if (( __status != 0 )); then
        __checkout="$__saved_checkout"
        __checkout_realpath="$__saved_checkout_realpath"
        __source="$__saved_source"
        __source_realpath="$__saved_source_realpath"
        __target="$__saved_target"
        __target_parent="$__saved_target_parent"
        __state_home_realpath="$__saved_state_home_realpath"
        __state_dir="$__saved_state_dir"
        __state_dir_realpath="$__saved_state_dir_realpath"
        __state_backups_root="$__saved_state_backups_root"
        __manifest="$__saved_manifest"
        __lock_dir="$__saved_lock_dir"
        __backup="$__saved_backup"
        __selector_state="$__saved_selector_state"
        __rollback_quarantine="$__saved_rollback_quarantine"
        __transaction_state="$__saved_transaction_state"
        __rollback_state="$__saved_rollback_state"
        __backup_moved="$__saved_backup_moved"
        __selector_recorded="$__saved_selector_recorded"
        __selector_preexisting="$__saved_selector_preexisting"
        __selector_type="$__saved_selector_type"
        __selector_mode="$__saved_selector_mode"
        __selector_hash="$__saved_selector_hash"
        __recorded_checkout="$__saved_recorded_checkout"
        __recorded_checkout_realpath="$__saved_recorded_checkout_realpath"
        __recorded_origin="$__saved_recorded_origin"
        __recorded_source="$__saved_recorded_source"
        __recorded_target="$__saved_recorded_target"
        __recorded_backup="$__saved_recorded_backup"
        __manifest_checkout="$__saved_manifest_checkout"
        __manifest_checkout_realpath="$__saved_manifest_checkout_realpath"
        __manifest_source="$__saved_manifest_source"
        __manifest_target="$__saved_manifest_target"
        __manifest_backup="$__saved_manifest_backup"
        __manifest_quarantine="$__saved_manifest_quarantine"
        __target_preexisting="$__saved_target_preexisting"
        __target_identity="$__saved_target_identity"
        __approved_paths=("${__saved_approved_paths[@]}")
        __approved_types=("${__saved_approved_types[@]}")
        __approved_modes=("${__saved_approved_modes[@]}")
        __approved_hashes=("${__saved_approved_hashes[@]}")
        __approved_owners=("${__saved_approved_owners[@]}")
        __approved_link_targets=("${__saved_approved_link_targets[@]}")
        __approved_optional=("${__saved_approved_optional[@]}")
        __approved_preexisting=("${__saved_approved_preexisting[@]}")
        __backup_paths=("${__saved_backup_paths[@]}")
        __backup_types=("${__saved_backup_types[@]}")
        __backup_modes=("${__saved_backup_modes[@]}")
        __backup_hashes=("${__saved_backup_hashes[@]}")
        __backup_owners=("${__saved_backup_owners[@]}")
        __backup_link_targets=("${__saved_backup_link_targets[@]}")
        __manifest_preexisting_paths=("${__saved_manifest_preexisting_paths[@]}")
        __manifest_preexisting_values=("${__saved_manifest_preexisting_values[@]}")
        __inventory_approved_paths=("${__saved_inventory_approved_paths[@]}")
        __inventory_approved_types=("${__saved_inventory_approved_types[@]}")
        __inventory_approved_modes=("${__saved_inventory_approved_modes[@]}")
        __inventory_approved_hashes=("${__saved_inventory_approved_hashes[@]}")
        __inventory_approved_owners=("${__saved_inventory_approved_owners[@]}")
        __inventory_approved_link_targets=("${__saved_inventory_approved_link_targets[@]}")
        __inventory_approved_optional=("${__saved_inventory_approved_optional[@]}")
        __inventory_approved_preexisting=("${__saved_inventory_approved_preexisting[@]}")
        __inventory_backup_paths=("${__saved_inventory_backup_paths[@]}")
        __inventory_backup_types=("${__saved_inventory_backup_types[@]}")
        __inventory_backup_modes=("${__saved_inventory_backup_modes[@]}")
        __inventory_backup_hashes=("${__saved_inventory_backup_hashes[@]}")
        __inventory_backup_owners=("${__saved_inventory_backup_owners[@]}")
        __inventory_backup_link_targets=("${__saved_inventory_backup_link_targets[@]}")
        return "$__status"
    fi
}

verify_target() {
    [[ -L "$__target" && "$(realpath "$__target")" == "$__source_realpath" ]] || {
        print_error "config target does not resolve to the recorded source"
        return 1
    }
}

record_migration_target_identity() {
    [[ "$__target_preexisting" == false && -z "$__target_identity" ]] || return 0
    [[ -L "$__target" &&
        "$(realpath "$__target" 2>/dev/null || true)" == "$__source_realpath" ]] || return 0
    __target_identity="$(path_identity "$__target" 2>/dev/null || true)"
    [[ -n "$__target_identity" ]] || {
        print_error "could not identify the migration-created config target"
        return 1
    }
}

verify_migration_created_target() {
    [[ "$__target_preexisting" == false ]] || {
        print_error "rollback target was present before migration"
        return 1
    }
    if ! path_exists "$__target"; then
        return 0
    fi
    [[ -L "$__target" &&
        "$(realpath "$__target" 2>/dev/null || true)" == "$__source_realpath" ]] || {
        print_error "migration-created config target does not resolve to the recorded source"
        return 1
    }
    [[ -n "$__target_identity" &&
        "$(path_identity "$__target" 2>/dev/null || true)" == "$__target_identity" ]] || {
        print_error "migration-created config target identity changed"
        return 1
    }
}

remove_migration_target() {
    [[ "$__target_preexisting" == false ]] || return 0
    path_exists "$__target" || return 0
    verify_migration_created_target || return $?
    rm -f -- "$__target" || {
        print_error "could not remove the migration-created config target"
        return 1
    }
    ! path_exists "$__target" || {
        print_error "migration-created config target remains after removal"
        return 1
    }
}

verify_rollback_target() {
    if [[ "$__target_preexisting" == false && "$__backup_moved" == false ]]; then
        [[ ! -e "$__backup/config-dir" && ! -L "$__backup/config-dir" ]] || {
            print_error "absent target has an unexpected moved backup"
            return 1
        }
        verify_migration_created_target
        return $?
    fi
    if [[ "$__backup_moved" == false ]]; then
        if ! path_exists "$__target" && path_exists "$__backup/config-dir"; then
            verify_backup || return $?
            __backup_moved=true
        fi
    fi
    if [[ "$__backup_moved" == false ]]; then
        [[ -d "$__target" && ! -L "$__target" ]] || {
            print_error "pre-move rollback requires the original physical config directory"
            return 1
        }
        ! path_exists "$__backup/config-dir" || {
            print_error "pre-move rollback found an unexpected moved backup"
            return 1
        }
        return 0
    fi
    verify_backup || return $?
    if path_exists "$__target"; then
        verify_target
    else
        [[ -d "$__backup/config-dir" && ! -L "$__backup/config-dir" ]] || {
            print_error "rollback cannot restore the backup because it is missing"
            return 1
        }

    fi
}

verify_rollback_selector() {
    [[ "$__selector_recorded" == true ]] || return 0
    [[ "$__selector_type" == "$__selector_inventory_type" ]] || {
        print_error "profile selector rollback metadata has an unexpected type"
        return 1
    }
    if [[ "$__selector_preexisting" == true ]]; then
        [[ -f "$__selector_state" && ! -L "$__selector_state" ]] || {
            print_error "preexisting profile selector is missing or has an unexpected type"
            return 1
        }
    elif ! path_exists "$__selector_state"; then
        return 0
    else
        [[ -f "$__selector_state" && ! -L "$__selector_state" ]] || {
            print_error "migration-created profile selector has an unexpected type"
            return 1
        }
    fi
    [[ "$(file_owner "$__selector_state")" == "$(id -u)" &&
        "$(file_mode "$__selector_state")" == "$__selector_mode" &&
        "$(sha256_file "$__selector_state")" == "$__selector_hash" ]] || {
        print_error "profile selector rollback guard failed"
        return 1
    }
}

remove_migration_selector() {
    [[ "$__selector_recorded" == true && "$__selector_preexisting" == false ]] || return 0
    path_exists "$__selector_state" || return 0
    verify_rollback_selector || return $?
    rm -f -- "$__selector_state" || {
        print_error "could not remove the migration-created profile selector"
        return 1
    }
}

verify_backup() {
    local __index __path __expected __actual __relative __entry __link_target
    validate_physical_directory_chain "$__backup/config-dir" "$__state_backups_root" \
        "recorded backup config directory" || return $?
    [[ "$(entry_owner "$__backup/config-dir")" == "$(id -u)" ]] || {
        print_error "recorded backup is not owned by the current user"
        return 1
    }
    for (( __index = 1; __index <= ${#__backup_paths}; __index++ )); do
        __path="${__backup_paths[__index]}"
        __expected="${__backup_hashes[__index]}"
        validate_manifest_entry_path "$__backup/config-dir" "$__path" "backup entry" || return $?
        path_exists "$__backup/config-dir/$__path" || {
            print_error "backup entry is missing: $__path"
            return 1
        }
        case "${__backup_types[__index]}" in
            symlink)
                [[ -L "$__backup/config-dir/$__path" ]] || {
                    print_error "backup entry type guard failed: $__path"
                    return 1
                }
                ;;
            regular)
                [[ -f "$__backup/config-dir/$__path" && ! -L "$__backup/config-dir/$__path" ]] || {
                    print_error "backup entry type guard failed: $__path"
                    return 1
                }
                ;;
            *)
                print_error "backup entry has an unsupported type: $__path"
                return 1
                ;;
        esac
        [[ "$(entry_owner "$__backup/config-dir/$__path")" == "${__backup_owners[__index]}" &&
            "$(file_mode "$__backup/config-dir/$__path")" == "${__backup_modes[__index]}" ]] || {
            print_error "backup ownership or mode guard failed: $__path"
            return 1
        }
        __link_target="-"
        [[ -L "$__backup/config-dir/$__path" ]] &&
            __link_target="$(realpath "$__backup/config-dir/$__path" 2>/dev/null || true)"
        [[ "$__link_target" == "${__backup_link_targets[__index]}" ]] || {
            print_error "backup link target guard failed: $__path"
            return 1
        }
        __actual="$(sha256_file "$__backup/config-dir/$__path" 2>/dev/null || true)"
        [[ -n "$__expected" && "$__actual" == "$__expected" ]] || {
            print_error "backup digest guard failed: $__path"
            return 1
        }
    done
    local -a __entries=("$__backup/config-dir"/**/*(ND))
    for __entry in "${__entries[@]}"; do
        __relative="${__entry#$__backup/config-dir/}"
        if [[ -d "$__entry" && ! -L "$__entry" ]]; then
            local __has_recorded_child=false
            for __path in "${__backup_paths[@]}"; do
                if [[ "$__path" == "$__relative/"* ]]; then
                    __has_recorded_child=true
                    break
                fi
            done
            [[ "$__has_recorded_child" == true ]] || {
                print_error "backup contains an unexpected directory: $__relative"
                return 1
            }
            continue
        fi
        local __recorded=false
        for __path in "${__backup_paths[@]}"; do
            if [[ "$__path" == "$__relative" ]]; then
                __recorded=true
                break
            fi
        done
        [[ "$__recorded" == true ]] || {
            print_error "backup contains an unexpected entry: $__relative"
            return 1
        }
    done
}

verify_approved() {
    local __index __path __expected __actual __resolved
    for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
        __path="${__approved_paths[__index]}"
        __expected="${__approved_hashes[__index]}"
        path_exists "$__source/$__path" || {
            print_error "approved file is missing from the source: $__path"
            return 1
        }
        if [[ "$__path" == miserc.local.toml ]]; then
            [[ "${__approved_types[__index]}" == "$__selector_inventory_type" ]] || {
                print_error "approved profile selector has an unexpected inventory type"
                return 1
            }
            [[ -L "$__source/$__path" ]] &&
                same_canonical_path "$__source/$__path" "$__selector_state" || {
                print_error "approved profile selector does not resolve to the canonical selector state"
                return 1
            }
            [[ -f "$__selector_state" && ! -L "$__selector_state" ]] || {
                print_error "approved profile selector state has an unexpected type"
                return 1
            }
            [[ "$(file_owner "$__selector_state")" == "$(id -u)" ]] || {
                print_error "approved profile selector state is not owned by the current user"
                return 1
            }
        else
            case "${__approved_types[__index]}" in
                regular)
                    [[ -f "$__source/$__path" && ! -L "$__source/$__path" ]] || {
                        print_error "approved file source type guard failed: $__path"
                        return 1
                    }
                    ;;
                symlink)
                    [[ -L "$__source/$__path" ]] || {
                        print_error "approved file source type guard failed: $__path"
                        return 1
                    }
                    __resolved="$(realpath "$__source/$__path" 2>/dev/null || true)"
                    [[ -n "$__resolved" ]] || {
                        print_error "approved file symlink is unresolved: $__path"
                        return 1
                    }
                    tracked_source_file "$__resolved" || {
                        print_error "approved file symlink does not resolve to a tracked source file: $__path"
                        return 1
                    }
                    ;;
                *)
                    print_error "approved file has an unsupported source type: $__path"
                    return 1
                    ;;
            esac
        fi
        [[ "$(file_mode "$__source/$__path")" == "${__approved_modes[__index]}" ]] || {
            print_error "approved file mode guard failed: $__path"
            return 1
        }
        __actual="$(sha256_file "$__source/$__path" 2>/dev/null || true)"
        [[ "$__actual" == "$__expected" ]] || {
            print_error "approved file digest guard failed: $__path"
            return 1
        }
    done
}

verify_restored_target() {
    local __index __path __expected __actual __relative __entry
    [[ -d "$__target" && ! -L "$__target" ]] || {
        print_error "restored config target is not a physical directory"
        return 1
    }
    [[ "$(entry_owner "$__target")" == "$(id -u)" ]] || {
        print_error "restored config target is not owned by the current user"
        return 1
    }
    for (( __index = 1; __index <= ${#__backup_paths}; __index++ )); do
        __path="${__backup_paths[__index]}"
        path_exists "$__target/$__path" || {
            print_error "restored target entry is missing: $__path"
            return 1
        }
        case "${__backup_types[__index]}" in
            symlink)
                [[ -L "$__target/$__path" ]] || {
                    print_error "restored target entry type guard failed: $__path"
                    return 1
                }
                ;;
            regular)
                [[ -f "$__target/$__path" && ! -L "$__target/$__path" ]] || {
                    print_error "restored target entry type guard failed: $__path"
                    return 1
                }
                ;;
            *)
                print_error "restored target entry has an unsupported type: $__path"
                return 1
                ;;
        esac
        [[ "$(entry_owner "$__target/$__path")" == "$(id -u)" &&
            "$(file_mode "$__target/$__path")" == "${__backup_modes[__index]}" ]] || {
            print_error "restored target ownership or mode guard failed: $__path"
            return 1
        }
        __expected="${__backup_hashes[__index]}"
        __actual="$(sha256_file "$__target/$__path" 2>/dev/null || true)"
        [[ -n "$__expected" && "$__actual" == "$__expected" ]] || {
            print_error "restored target digest guard failed: $__path"
            return 1
        }
    done
    local -a __entries=("$__target"/**/*(ND))
    for __entry in "${__entries[@]}"; do
        __relative="${__entry#$__target/}"
        if [[ -d "$__entry" && ! -L "$__entry" ]]; then
            local __has_recorded_child=false
            for __path in "${__backup_paths[@]}"; do
                if [[ "$__path" == "$__relative/"* ]]; then
                    __has_recorded_child=true
                    break
                fi
            done
            [[ "$__has_recorded_child" == true ]] || {
                print_error "restored target contains an unexpected directory: $__relative"
                return 1
            }
            continue
        fi
        local __recorded=false
        for __path in "${__backup_paths[@]}"; do
            if [[ "$__path" == "$__relative" ]]; then
                __recorded=true
                break
            fi
        done
        [[ "$__recorded" == true ]] || {
            print_error "restored target contains an unexpected entry: $__relative"
            return 1
        }
    done
}

verify_rollback_source() {
    local __index __path __expected __actual __preexisting __allow_modified __resolved
    __rollback_remove_paths=()
    __allow_modified=false
    [[ "$__rollback_state" == backup_pending || "$__rollback_state" == staging ]] &&
        __allow_modified=true
    for (( __index = 1; __index <= ${#__approved_paths}; __index++ )); do
        __path="${__approved_paths[__index]}"
        __expected="${__approved_hashes[__index]}"
        __preexisting="${__approved_preexisting[__index]:-true}"
        validate_manifest_entry_path "$__source" "$__path" "rollback source entry" || return $?
        path_exists "$__source/$__path" || {
            [[ "$__preexisting" == false ]] && continue
            print_error "approved file is missing from the source: $__path"
            return 1
        }
        if [[ "$__path" == miserc.local.toml ]]; then
            [[ "$__selector_type" == "$__selector_inventory_type" &&
                "${__approved_types[__index]}" == "$__selector_inventory_type" &&
                -L "$__source/$__path" &&
                "$(realpath "$__source/$__path" 2>/dev/null || true)" == "$(realpath "$__selector_state" 2>/dev/null || true)" ]] || {
                [[ "$__allow_modified" == true && "$__preexisting" == false ]] && {
                    print_error "retaining migration-owned selector with an uncertain target"
                    continue
                }
                print_error "migration-owned selector has an uncertain target"
                return 1
            }
            [[ "$(entry_owner "$__source/$__path")" == "$(id -u)" &&
                -f "$__selector_state" && ! -L "$__selector_state" &&
                "$(file_owner "$__selector_state")" == "$(id -u)" &&
                "$(file_mode "$__selector_state")" == "$__selector_mode" ]] || {
                print_error "profile selector rollback mode or ownership guard failed"
                return 1
            }
        else
            case "${__approved_types[__index]}" in
                regular)
                    [[ -f "$__source/$__path" && ! -L "$__source/$__path" ]] || {
                        [[ "$__allow_modified" == true && "$__preexisting" == false ]] && {
                            print_error "retaining migration-owned entry with an uncertain source type: $__path"
                            continue
                        }
                        print_error "approved file source type guard failed: $__path"
                        return 1
                    }
                    [[ "$(entry_owner "$__source/$__path")" == "$(id -u)" &&
                        "$(file_mode "$__source/$__path")" == "${__approved_modes[__index]}" ]] || {
                        print_error "approved file ownership or mode guard failed: $__path"
                        return 1
                    }
                    ;;
                symlink)
                    [[ -L "$__source/$__path" ]] || {
                        [[ "$__allow_modified" == true && "$__preexisting" == false ]] && {
                            print_error "retaining migration-owned entry with an uncertain source type: $__path"
                            continue
                        }
                        print_error "approved file source type guard failed: $__path"
                        return 1
                    }
                    __resolved="$(realpath "$__source/$__path" 2>/dev/null || true)"
                    [[ -n "$__resolved" ]] && tracked_source_file "$__resolved" || {
                        [[ "$__allow_modified" == true && "$__preexisting" == false ]] && {
                            print_error "retaining migration-owned symlink with an uncertain target: $__path"
                            continue
                        }
                        print_error "approved file symlink target guard failed: $__path"
                        return 1
                    }
                    [[ "$(entry_owner "$__source/$__path")" == "$(id -u)" &&
                        "$(file_mode "$__source/$__path")" == "${__approved_modes[__index]}" ]] || {
                        print_error "approved file ownership or mode guard failed: $__path"
                        return 1
                    }
                    ;;
                *)
                    print_error "approved file has an unsupported source type: $__path"
                    return 1
                    ;;
            esac
        fi
        __actual="$(sha256_file "$__source/$__path" 2>/dev/null || true)"
        if [[ "$__actual" != "$__expected" ]]; then
            if [[ "$__preexisting" == false && "$__allow_modified" == true ]]; then
                print_error "retaining modified migration entry: $__path"
                continue
            fi
            print_error "approved file digest guard failed: $__path"
            return 1
        fi
        [[ "$__preexisting" == false ]] || continue
        __rollback_remove_paths+=("$__path")
    done
}

verify_rollback_source_entry_now() {
    local __index="$1"
    local __path="$2"
    local __source_path="$__source/$__path"
    local __expected_type="${__approved_types[__index]}"
    local __expected_target="${__approved_link_targets[__index]}"
    local __actual_target=""
    local __expected_canonical="$__source_path"
    local __actual_canonical

    validate_manifest_entry_path "$__source" "$__path" \
        "rollback source entry" || return $?
    path_exists "$__source_path" || {
        print_error "rollback source entry disappeared: $__path"
        return 1
    }
    case "$__expected_type" in
        regular)
            [[ -f "$__source_path" && ! -L "$__source_path" ]] || {
                print_error "rollback source entry type changed: $__path"
                return 1
            }
            ;;
        symlink)
            [[ -L "$__source_path" ]] || {
                print_error "rollback source entry type changed: $__path"
                return 1
            }
            __actual_target="$(realpath "$__source_path" 2>/dev/null || true)"
            [[ -n "$__actual_target" && "$__actual_target" == "$__expected_target" ]] || {
                print_error "rollback source entry link target changed: $__path"
                return 1
            }
            tracked_source_file "$__actual_target" || {
                [[ "$__path" == miserc.local.toml &&
                    "$__actual_target" == "$(realpath "$__selector_state" 2>/dev/null || true)" ]] || {
                    print_error "rollback source entry link target is not recorded: $__path"
                    return 1
                }
            }
            __expected_canonical="$__expected_target"
            ;;
        *)
            print_error "rollback source entry has an unsupported type: $__path"
            return 1
            ;;
    esac
    __actual_canonical="$(realpath "$__source_path" 2>/dev/null || true)"
    [[ -n "$__actual_canonical" && "$__actual_canonical" == "$__expected_canonical" ]] || {
        print_error "rollback source entry canonical path changed: $__path"
        return 1
    }
    [[ "$(entry_owner "$__source_path")" == "${__approved_owners[__index]}" ]] || {
        print_error "rollback source entry owner changed: $__path"
        return 1
    }
    [[ "$(file_mode "$__source_path")" == "${__approved_modes[__index]}" ]] || {
        print_error "rollback source entry mode changed: $__path"
        return 1
    }
    [[ "$(sha256_file "$__source_path" 2>/dev/null || true)" == "${__approved_hashes[__index]}" ]] || {
        print_error "rollback source entry digest changed: $__path"
        return 1
    }
}

revalidate_rollback_after_lock() {
    recovery_preflight || return $?
    case "$__transaction_state" in
        backup_pending|backed_up|staging|staged|linked|verified|rollback_pending)
            load_inventory || return $?
            ;;
        failed)
            [[ "$__rollback_state" == prepared ]] || load_inventory || return $?
            ;;
    esac
    verify_rollback_target || return $?
    verify_rollback_selector || return $?
    verify_rollback_source || return $?
}

rollback_source_quarantine_restore() {
    local __quarantine="$1"
    shift
    local __index __path __source_path __staged_path
    local __status=0
    local -a __paths=("$@")
    for (( __index = ${#__paths}; __index >= 1; __index-- )); do
        __path="${__paths[__index]}"
        __source_path="$__source/$__path"
        __staged_path="$__quarantine/$__path"
        if path_exists "$__source_path"; then
            print_error "rollback source entry changed while restoring: $__path"
            __status=1
            continue
        fi
        validate_physical_ancestor_chain "$__source_path" "$__source_realpath" \
            "rollback source entry" || {
            __status=1
            continue
        }
        path_exists "$__staged_path" || {
            print_error "rollback source quarantine entry is missing: $__path"
            __status=1
            continue
        }
        mkdir -p -- "${__source_path:h}" || {
            __status=1
            continue
        }
        move_checked "$__staged_path" "$__source_path" || {
            print_error "could not restore the staged migration entry: $__path"
            __status=1
        }
    done
    (( __status == 0 )) && rm -rf -- "$__quarantine"
    return "$__status"
}

remove_verified_rollback_source() {
    local __path __index __source_path __destination __quarantine_path
    local __status
    local -a __staged_paths=()
    if [[ -n "${MISE_MIGRATION_TEST_BEFORE_ROLLBACK_SOURCE_DELETE:-}" ]]; then
        "${MISE_MIGRATION_TEST_BEFORE_ROLLBACK_SOURCE_DELETE}" || return $?
    fi

    __quarantine_path="$__state_dir/rollback-source-quarantine.$$.$RANDOM"
    [[ ! -e "$__quarantine_path" && ! -L "$__quarantine_path" ]] || {
        print_error "rollback source quarantine already exists"
        return 1
    }
    validate_physical_ancestor_chain "$__quarantine_path" "$__state_dir_realpath" \
        "rollback source quarantine" || return $?
    mkdir -p -- "$__quarantine_path" || {
        print_error "could not create the rollback source quarantine"
        return 1
    }

    # Validate the complete deletion set before staging any entry. Staging is
    # reversible; deleting the quarantine is the final commit.
    for __path in "${__rollback_remove_paths[@]}"; do
        __index=1
        while (( __index <= ${#__approved_paths} )) &&
            [[ "${__approved_paths[__index]}" != "$__path" ]]; do
            (( __index++ ))
        done
        (( __index <= ${#__approved_paths} )) || {
            print_error "rollback source entry was not recorded: $__path"
            rmdir -- "$__quarantine_path" 2>/dev/null || true
            return 1
        }
        path_exists "$__source/$__path" || {
            print_error "rollback source entry disappeared: $__path"
            rmdir -- "$__quarantine_path" 2>/dev/null || true
            return 1
        }
        verify_rollback_source_entry_now "$__index" "$__path" || {
            rmdir -- "$__quarantine_path" 2>/dev/null || true
            return 1
        }
    done

    for __path in "${__rollback_remove_paths[@]}"; do
        __index=1
        while (( __index <= ${#__approved_paths} )) &&
            [[ "${__approved_paths[__index]}" != "$__path" ]]; do
            (( __index++ ))
        done
        verify_rollback_source_entry_now "$__index" "$__path" || {
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        __source_path="$__source/$__path"
        __destination="$__quarantine_path/$__path"
        mkdir -p -- "${__destination:h}" || {
            print_error "could not prepare the rollback source quarantine: $__path"
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        validate_physical_ancestor_chain "$__source_path" "$__source_realpath" \
            "rollback source entry" || {
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        validate_physical_ancestor_chain "$__destination" "$__state_dir_realpath" \
            "rollback source quarantine entry" || {
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        move_checked "$__source_path" "$__destination" || {
            print_error "could not stage the unchanged migration entry: $__path"
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        __staged_paths+=("$__path")
        if [[ -n "${MISE_MIGRATION_TEST_AFTER_ROLLBACK_SOURCE_STAGE:-}" ]]; then
            "${MISE_MIGRATION_TEST_AFTER_ROLLBACK_SOURCE_STAGE}"
            __status="$?"
            if (( __status != 0 )); then
                rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
                return "$__status"
            fi
        fi
    done

    for __path in "${__rollback_remove_paths[@]}"; do
        [[ ! -e "$__source/$__path" && ! -L "$__source/$__path" ]] || {
            print_error "rollback source entry changed during staging: $__path"
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
        [[ -e "$__quarantine_path/$__path" || -L "$__quarantine_path/$__path" ]] || {
            print_error "rollback source quarantine entry disappeared: $__path"
            rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
            return 1
        }
    done

    remove_checked "$__quarantine_path" || {
        print_error "could not commit removal of the unchanged migration entries"
        rollback_source_quarantine_restore "$__quarantine_path" "${__staged_paths[@]}" || true
        return 1
    }
    return 0
}

transaction_fail() {
    local __status="$1"
    local __message="$2"
    __error="$__message"
    record_migration_target_identity || true
    __transaction_state=failed
    if [[ -n "$__manifest" && -d "$__state_dir" ]]; then
        write_manifest || print_error "could not persist failed transaction state"
    fi
    release_lock
    print_error "$__message"
    return "$__status"
}

run_migration() {
    local __native_status=0
    local __status=0
    preflight || return $?
    new_migration_manifest_guard || return $?
    if [[ "$__completed_rerun" == true ]]; then
        print -r -- "Migration is already $__transaction_state and all recorded guards still pass."
        return 0
    fi
    if [[ -L "$__target" && "$(realpath "$__target" 2>/dev/null || true)" == "$__source_realpath" ]]; then
        print -r -- "The mise config directory already points to $__source."
        return 0
    fi
    print -r -- "Checkout: $__checkout_realpath"
    print -r -- "Source:   $__source"
    print -r -- "Target:   $__target"
    print -r -- "Approved old-target entries: ${#__approved_paths}"
    if [[ "$__dry_run" == true ]]; then
        print -r -- "Dry run: no files, lock, manifest, or backup will be changed."
        return 0
    fi
    confirm || {
        print -r -- "Migration cancelled."
        return 0
    }
    set +e
    mkdir -p -- "$__state_dir"
    __status="$?"
    if (( __status != 0 )); then
        set -e
        return "$__status"
    fi
    [[ -d "$__state_dir" && ! -L "$__state_dir" &&
        "$(realpath "$__state_dir" 2>/dev/null || true)" == "$__state_dir_realpath" ]] || {
        set -e
        print_error "migration state directory is not a physical canonical directory"
        return 1
    }
    validate_physical_ancestor_chain "$__lock_dir" "$__state_dir_realpath" "migration lock"
    __status="$?"
    if (( __status != 0 )); then
        set -e
        return "$__status"
    fi
    __started_at="$(now_utc)"
    acquire_lock || return $?
    __status="$?"
    if (( __status != 0 )); then
        set -e
        return "$__status"
    fi
    mkdir -p -- "$__state_backups_root"
    __status="$?"
    if (( __status != 0 )); then
        print_error "could not create the migration backup directory"
        release_lock
        set -e
        return "$__status"
    fi
    __state_backups_root="$(realpath "$__state_backups_root")"
    __backup="$__state_backups_root/$(timestamp_utc)"
    __transaction_state=locked
    __rollback_state=prepared
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        __error="could not write the initial transaction manifest"
        __transaction_state=failed
        __rollback_state=prepared
        if write_manifest; then
            :
        else
            print_error "$__error"
        fi
        release_lock
        print_error "$__error"
        set -e
        return "$__status"
    fi
    __transaction_state=preflight_passed
    __rollback_state=preflight_passed
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not record the migration backup directory"
        __status="$?"
        set -e
        return "$__status"
    fi
    mkdir -p -- "$__backup"
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not create the migration backup directory"
        __status="$?"
        set -e
        return "$__status"
    fi
    __backup="$(realpath "$__backup")"
    prepare_backup_entries
    write_inventory
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the immutable migration inventory"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=backup_pending
    __rollback_state=backup_pending
    __backup_moved=false
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the rollback-ready transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    if [[ -n "${MISE_MIGRATION_TEST_BEFORE_BACKUP_MOVE:-}" ]]; then
        "${MISE_MIGRATION_TEST_BEFORE_BACKUP_MOVE}"
        __status="$?"
        if (( __status != 0 )); then
            return "$__status"
        fi
    fi
    if [[ -d "$__target" && ! -L "$__target" ]]; then
        validate_physical_ancestor_chain "$__backup" "$__state_backups_root" \
            "migration backup"
        __status="$?"
        if (( __status != 0 )); then
            transaction_fail "$__status" "migration backup path validation failed"
            __status="$?"
            set -e
            return "$__status"
        fi
        mv -- "$__target" "$__backup/config-dir"
        __status="$?"
        if (( __status != 0 )); then
            transaction_fail "$__status" "could not move the old config directory to its backup"
            __status="$?"
            set -e
            return "$__status"
        fi
        __backup_moved=true
        write_manifest
        __status="$?"
        if (( __status != 0 )); then
            transaction_fail "$__status" "could not persist the completed config directory move"
            __status="$?"
            set -e
            return "$__status"
        fi
    fi
    if [[ -n "${MISE_MIGRATION_TEST_AFTER_BACKUP_MOVE:-}" ]]; then
        "${MISE_MIGRATION_TEST_AFTER_BACKUP_MOVE}"
        __status="$?"
        if (( __status != 0 )); then
            return "$__status"
        fi
    fi
    record_backup_entries
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not record the migration backup entries"
        __status="$?"
        set -e
        return "$__status"
    fi
    load_inventory
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "migration backup inventory changed during the config directory move"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=backed_up
    __rollback_state=backed_up
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the backed-up transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=staging
    __rollback_state=staging
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the staging transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    for __relative in "${__approved_paths[@]}"; do
        case "$__relative" in
            miserc.local.toml)
                ;;
            *)
                stage_file "$__relative"
                __status="$?"
                if (( __status != 0 )); then
                    transaction_fail "$__status" "could not stage approved file: $__relative"
                    __status="$?"
                    set -e
                    return "$__status"
                fi
                ;;
        esac
    done
    stage_selector
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not stage the profile selector"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=staged
    __rollback_state=staged
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the staged transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    [[ -x "$__canonical_mise_path" ]] || {
        transaction_fail 1 "canonical mise binary is missing: $__canonical_mise_path"
        __status="$?"
        set -e
        return "$__status"
    }
    if "$__canonical_mise_path" --no-hooks bootstrap \
        --from "$__canonical_origin" \
        --from-dir "$__checkout" \
        --config-dir "$__source_relative_path" \
        --only files \
        --yes; then
        :
    else
        __native_status="$?"
        __error="native mise bootstrap failed with status $__native_status"
        transaction_fail "$__native_status" "$__error"
        __status="$?"
        set -e
        return "$__status"
    fi
    record_migration_target_identity
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not record the migration-created config target"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=linked
    __rollback_state=linked
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the linked transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    verify_target
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "migration verification found an unexpected config target"
        __status="$?"
        set -e
        return "$__status"
    fi
    verify_approved
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "migration verification found an unapproved source change"
        __status="$?"
        set -e
        return "$__status"
    fi
    __transaction_state=verified
    __rollback_state=verified
    __completed_at="$(now_utc)"
    write_manifest
    __status="$?"
    if (( __status != 0 )); then
        transaction_fail "$__status" "could not write the verified transaction state"
        __status="$?"
        set -e
        return "$__status"
    fi
    release_lock
    __status="$?"
    set -e
    if (( __status != 0 )); then
        return "$__status"
    fi
    print -r -- "Migration verified. Keep the backup until the normal bootstrap is complete."
}

run_rollback() {
    preflight true || return $?
    if [[ ! -f "$__manifest" ]]; then
        [[ ! -e "$__lock_dir" ]] || {
            print_error "transaction manifest is missing while the migration lock exists"
            return 1
        }
        if [[ -d "$__state_backups_root" ]]; then
            [[ -z "$(find "$__state_backups_root" -mindepth 2 -maxdepth 2 -type d -name config-dir -print -quit)" ]] || {
                print_error "transaction manifest is missing while a moved backup exists"
                return 1
            }
        fi
        print -r -- "No migration transaction is available to roll back."
        return 0
    fi
    load_manifest || return $?
    [[ "$__transaction_state" == locked || "$__transaction_state" == preflight_passed || "$__transaction_state" == backup_pending || "$__transaction_state" == backed_up || "$__transaction_state" == staging || "$__transaction_state" == staged || "$__transaction_state" == linked || "$__transaction_state" == verified || "$__transaction_state" == failed || "$__transaction_state" == rollback_pending ]] || {
        print_error "rollback is not permitted from transaction state $__transaction_state"
        return 1
    }
    recovery_preflight || return $?
    if [[ "$__transaction_state" == rollback_pending ]]; then
        if path_exists "$__backup/config-dir"; then
            verify_backup || return $?
        fi
        if [[ -d "$__target" && ! -L "$__target" ]]; then
            verify_restored_target || return $?
        elif path_exists "$__target"; then
            [[ -d "$__backup/config-dir" && ! -L "$__backup/config-dir" ]] || {
                print_error "rollback cannot quarantine the current target because the recorded backup is missing"
                return 1
            }
            verify_target || return $?
        elif ! path_exists "$__backup/config-dir"; then
            print_error "rollback completion intent has neither a restored target nor a backup"
            return 1
        fi
    else
        verify_rollback_target || return $?
    fi
    verify_rollback_selector || return $?
    acquire_lock || return $?
    revalidate_rollback_after_lock || return $?
    remove_verified_rollback_source || return $?
    if [[ "$__backup_moved" == false ]]; then
        remove_migration_target || return $?
        remove_migration_selector || return $?
        __transaction_state=rolled_back
        __rollback_state=rolled_back
        __completed_at="$(now_utc)"
        if ! write_manifest; then
            print_error "pre-move rollback finalized the transaction but could not persist its state"
            return 1
        fi
        print -r -- "Rollback cancelled the pre-move migration."
        return 0
    fi
    if [[ "$__transaction_state" != rollback_pending ]]; then
        __rollback_quarantine="${__target:h}/mise.rollback-quarantine.$(timestamp_utc)"
        [[ ! -e "$__rollback_quarantine" && ! -L "$__rollback_quarantine" ]] || {
            print_error "rollback quarantine already exists"
            return 1
        }
        validate_physical_ancestor_chain "$__rollback_quarantine" "$__target_parent" \
            "rollback quarantine" || return $?
        __transaction_state=rollback_pending
        __rollback_state=rollback_pending
        write_manifest || {
            print_error "rollback could not persist its completion intent"
            return 1
        }
    fi
    if [[ -n "$__rollback_quarantine" ]]; then
        validate_physical_ancestor_chain "$__rollback_quarantine" "$__target_parent" \
            "rollback quarantine" || return $?
    fi
    if [[ -d "$__target" && ! -L "$__target" ]]; then
        if path_exists "$__backup/config-dir"; then
            print_error "rollback found a physical target while its backup is still present"
            return 1
        fi
        verify_restored_target || return $?
    elif path_exists "$__target"; then
        if [[ -n "$__rollback_quarantine" ]] && ! path_exists "$__rollback_quarantine"; then
            move_checked "$__target" "$__rollback_quarantine" || {
                print_error "rollback could not quarantine the current config target"
                return 1
            }
        elif path_exists "$__target"; then
            print_error "rollback found an unexpected current config target"
            return 1
        fi
    fi
    if path_exists "$__backup/config-dir"; then
        verify_backup || return $?
        move_checked "$__backup/config-dir" "$__target" || {
            if [[ -n "$__rollback_quarantine" ]] && path_exists "$__rollback_quarantine" && ! path_exists "$__target"; then
                move_checked "$__rollback_quarantine" "$__target" || {
                    print_error "rollback could not restore the quarantined config target"
                }
            fi
            print_error "rollback could not restore the recorded backup"
            return 1
        }
    fi
    verify_restored_target || return $?
    remove_migration_selector || return $?
    __transaction_state=rolled_back
    __rollback_state=rolled_back
    __completed_at="$(now_utc)"
    if ! write_manifest; then
        print_error "rollback restored the target but could not persist the transaction state; rerun --rollback to reconcile it"
        return 1
    fi
    print -r -- "Rollback restored $__target. Review and remove $__rollback_quarantine separately."
}

run_remove_backup() {
    load_manifest || return $?
    [[ "$__transaction_state" == verified || "$__transaction_state" == commit_pending ]] || {
        print_error "backup removal requires a verified transaction"
        return 1
    }
    recovery_preflight || return $?
    acquire_lock || return $?
    recovery_preflight || return $?
    load_inventory || return $?
    verify_target || return $?
    verify_approved || return $?
    if path_exists "$__backup"; then
        verify_backup || return $?
    fi
    if [[ "$__transaction_state" != commit_pending ]]; then
        __transaction_state=commit_pending
        __rollback_state=commit_pending
        write_manifest || {
            print_error "backup removal could not persist its completion intent"
            return 1
        }
    fi
    if path_exists "$__backup"; then
        remove_checked "$__backup" || {
            print_error "backup removal failed; transaction remains commit-pending"
            return 1
        }
    fi
    __transaction_state=committed
    __rollback_state=committed
    __completed_at="$(now_utc)"
    if ! write_manifest; then
        print_error "backup was removed but could not persist the committed transaction state; rerun --remove-backup to reconcile it"
        return 1
    fi
    print -r -- "Backup removed and migration committed."
}

main() {
    parse_args "$@" || exit $?
    if [[ "$__show_help" == true ]]; then
        usage
        return 0
    fi
    if [[ "$__rollback" == true ]]; then
        run_rollback
    elif [[ "$__remove_backup" == true ]]; then
        run_remove_backup
    else
        run_migration
    fi
}

if main "$@"; then
    exit 0
else
    __main_status="$?"
    exit "$__main_status"
fi
