#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing zsh bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.zsh.toml"
assert_module_package zsh brew:zsh
local __source="home/.config/zsh"
local __fixture_root
__fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/zsh-bootstrap.XXXXXX")" ||
    fail "could not create Zsh fixture"
__fixture_root="$(realpath "$__fixture_root")"
trap 'rm -rf -- "$__fixture_root"' EXIT
local __target="$__fixture_root/.config/zsh"
mkdir -p "$__target" "$__fixture_root/.local/state" "$__fixture_root/.local/share" "$__fixture_root/.cache"
local __relative_source
for __path in .zshenv custom_functions.zsh; do
    __relative_source="$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$__root_dir/home/.config/zsh/$__path" "$__target")"
    ln -s "$__relative_source" "$__target/$__path"
done
for __path in .zshrc .zshrc-zone-0.zsh .zshrc-zone-2.zsh .zshrc-zones.zsh; do
    cp "$__source/$__path" "$__target/$__path"
done
touch "$__target/.zshrc-zone-1.zsh" "$__target/.zshrc-zone-3.zsh"
cat >> "$__target/.zshrc" <<'EOF'
source "$ZDOTDIR/.zshrc-zones.zsh"
EOF
print -r -- 'history-state' > "$__target/.zsh_history"
print -r -- 'completion-state' > "$__target/.zcompdump"
chmod 600 "$__target/.zsh_history"
chmod 644 "$__target/.zcompdump"
__relative_source="$(python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$__root_dir/home/.config/zsh/.zshenv" "$__fixture_root")"
ln -s "$__relative_source" "$__fixture_root/.zshenv"
local __migration_task="home/.config/mise/tasks/zsh/migrate.zsh"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -x "$__migration_task" ]] || fail "missing executable Zsh migration task"
zsh -n "$__migration_task" || fail "Zsh migration task has syntax errors"
grep -qF '[bootstrap.hooks]' "$__config" || fail "Zsh bootstrap hooks are missing"
grep -qF 'pre-dotfiles = "mise run zsh:migrate"' "$__config" ||
    fail "Zsh migration hook is missing"
grep -qF '"~/.config/mise/tasks/zsh/migrate.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy the Zsh migration task"
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" tasks info zsh:migrate
)"
print -r -- "$__task_info" | grep -qF "Task: zsh:migrate" ||
    fail "Zsh migration task is not discoverable"
grep -qF '"~/.config/zsh" = { source = "~/dev/personal/dot/home/.config/zsh", mode = "symlink-each", exclude = [".p10k.zsh", ".zshrc", ".zshrc-zone-0.zsh", ".zshrc-zone-2.zsh", ".zshrc-zones.zsh"] }' "$__config" ||
    fail "zsh symlink-each declaration is missing"
for __entry in \
    '~/.config/zsh/.zshrc/zshrc' \
    '~/.config/zsh/.zshrc/zones' \
    '~/.config/zsh/.zshrc-zone-0.zsh/bootstrap' \
    '~/.config/zsh/.zshrc-zone-2.zsh/user'; do
    grep -qF "\"$__entry\"" "$__config" ||
        fail "zshrc edit is missing: $__entry"
done
grep -qF '"~/.config/zsh/.zshrc/zones" = { source = "~/dev/personal/dot/home/.config/zsh/.zshrc-zones.zsh", template = "tera" }' "$__config" ||
    fail "zsh zone bootstrap block source is missing"
for __source_path in .zshrc .zshrc-zones.zsh .zshrc-zone-0.zsh .zshrc-zone-2.zsh; do
    [[ -f "$__source/$__source_path" ]] ||
        fail "zshrc edit source is missing: $__source_path"
    zsh -n "$__source/$__source_path" ||
        fail "zshrc edit source has syntax errors: $__source_path"
done
for __zone in 0 1 2 3; do
    grep -qF "[[ -r \"\$ZDOTDIR/.zshrc-zone-$__zone.zsh\" ]] && source \"\$ZDOTDIR/.zshrc-zone-$__zone.zsh\"" "$__source/.zshrc-zones.zsh" ||
        fail "zsh zone $__zone bootstrap source is missing"
done
local __expected_path_block=$'path=(\n    /usr/local/bin\n    /usr/local/sbin\n    $HOME/.local/bin\n    $path\n)'
local __actual_path_block="$(sed -n '/^path=(/,/^)/p' "$__source/.zshrc-zone-0.zsh")"
[[ "$__actual_path_block" == "$__expected_path_block" ]] ||
    fail "local Zsh paths must precede inherited default paths"
grep -qF 'KEYTIMEOUT=1' "$__source/.zshrc-zone-2.zsh" ||
    fail "generic KEYTIMEOUT must remain in the Zone 2 source"
if grep -qF 'KEYTIMEOUT=' "$__source/.zshrc-zone-0.zsh"; then
    fail "generic KEYTIMEOUT must not move into the Zone 0 source"
fi
for __zone_path in .zshrc .zshrc-zone-0.zsh .zshrc-zone-1.zsh .zshrc-zone-2.zsh .zshrc-zone-3.zsh; do
    [[ -f "$__target/$__zone_path" && ! -L "$__target/$__zone_path" ]] ||
        fail "zsh zone target is not a regular file: $__zone_path"
done
grep -qF '"~/.zshenv" = { source = "~/dev/personal/dot/home/.config/zsh/.zshenv", mode = "symlink" }' "$__config" ||
    fail "zsh environment symlink declaration is missing"
if grep -qF 'source "$__dotfiles_dir/home/.config/zsh/.zshenv"' scripts/install-mise.zsh; then
    fail "install-mise.zsh must not source the Zsh environment before mise bootstrap"
fi
[[ -L "$__fixture_root/.zshenv" ]] || fail "zsh environment target is not a symlink"
case "$(readlink "$__fixture_root/.zshenv")" in
    /*) fail "zsh environment target link is absolute" ;;
esac
[[ "$(realpath "$__fixture_root/.zshenv")" == "$(realpath "home/.config/zsh/.zshenv")" ]] ||
    fail "zsh environment target does not resolve to the tracked source"
[[ ! -e "$__source/.zsh_history" && ! -e "$__source/.zcompdump" ]] ||
    fail "zsh runtime files must remain outside the tracked source"
[[ ! -e "$__source/plugins/zsh-vi-mode/config.zsh" ]] ||
    fail "generic Zsh source still owns the tracked vi-mode configuration"
[[ -f "$__source/.zshrc" ]] || fail "zshrc edit source is missing"
for __declaration in 'typeset -aU path' 'typeset -aU fpath' 'typeset -aU manpath'; do
    grep -qF "$__declaration" "$__source/.zshrc" ||
        fail "Zsh array declaration is missing: $__declaration"
done
for __path in .zshenv custom_functions.zsh; do
    [[ -f "$__source/$__path" ]] || fail "missing zsh source: $__path"
    [[ -L "$__target/$__path" ]] || fail "zsh target is not a symlink: $__path"
    case "$(readlink "$__target/$__path")" in
        /*) fail "zsh target link is absolute: $__path" ;;
    esac
done
[[ -f "$__target/.zshrc" && ! -L "$__target/.zshrc" ]] ||
    fail "zshrc target is not a regular file"
[[ -f "$__target/.zsh_history" && ! -L "$__target/.zsh_history" ]] ||
    fail "zsh history runtime file was not preserved"
[[ -f "$__target/.zcompdump" && ! -L "$__target/.zcompdump" ]] ||
    fail "zsh completion runtime file was not preserved"
[[ "$(stat -c '%a' "$__target/.zsh_history")" == "600" ]] || fail "zsh history mode changed"
[[ "$(stat -c '%a' "$__target/.zcompdump")" == "644" ]] || fail "zsh completion dump mode changed"
[[ ! -e "$__source/.zprofile" ]] || fail "zsh module source still contains the brew-owned .zprofile"
grep -qF '"~/.config/zsh/.zprofile/brew-shellenv"' home/.config/mise/conf.d/module.brew.toml ||
    fail "brew module does not own the zprofile shell environment entry"
grep -Fq 'ZDOTDIR="$XDG_CONFIG_HOME/zsh"' home/.config/zsh/.zshenv || fail "ZDOTDIR source is missing"
if find "$__source" -name '.zsh_history' -o -name '.zcompdump' | grep -q .; then
    fail "zsh runtime files remain in the source tree"
fi
env -u ZDOTDIR HOME="$__fixture_root" \
    MISE_DATA_DIR="$__fixture_root/mise-data" MISE_CACHE_DIR="$__fixture_root/mise-cache" \
    zsh -lic 'exit' >/dev/null 2>&1 ||
    fail "zsh login shell smoke test failed"

local __migration_home="$__fixture_root/migration"
mkdir -p "$__migration_home"
local __migration_config="$__migration_home/.config/zsh"
local __migration_target="$__migration_config/.zshrc"
local __migration_backup="$__migration_target.bak"
mkdir -p "$__migration_config"
ln -s "$__root_dir/home/.config/zsh/.zshrc" "$__migration_target"
local __migration_output="$(
    env HOME="$__migration_home" XDG_CONFIG_HOME="$__migration_home/.config" \
        MISE_PROJECT_ROOT="$__root_dir" zsh "$__root_dir/$__migration_task" 2>&1
)"
[[ ! -e "$__migration_target" ]] || fail "legacy Zsh startup symlink was not removed"
[[ -f "$__migration_backup" ]] || fail "legacy Zsh startup backup was not created"
cmp -s "$__root_dir/home/.config/zsh/.zshrc" "$__migration_backup" ||
    fail "legacy Zsh startup backup does not match the source"
print -r -- "$__migration_output" | grep -qF "$__migration_backup" ||
    fail "Zsh migration did not report the backup path"
rm -rf "$__migration_home"

local __profile_migration_home="$__fixture_root/profile-migration"
mkdir -p "$__profile_migration_home"
local __profile_migration_config="$__profile_migration_home/.config/zsh"
local __profile_migration_target="$__profile_migration_config/.zprofile"
local __profile_migration_backup="$__profile_migration_target.bak"
mkdir -p "$__profile_migration_config"
ln -s "$__root_dir/home/.config/zsh/.zprofile" "$__profile_migration_target"
local __profile_migration_output="$(
    env HOME="$__profile_migration_home" XDG_CONFIG_HOME="$__profile_migration_home/.config" \
        MISE_PROJECT_ROOT="$__root_dir" zsh "$__root_dir/$__migration_task" 2>&1
)"
[[ ! -L "$__profile_migration_target" ]] || fail "legacy Zsh profile symlink was not removed"
[[ -f "$__profile_migration_backup" ]] || fail "legacy Zsh profile backup was not created"
grep -qF 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$__profile_migration_backup" ||
    fail "legacy Zsh profile backup was not recovered from Git history"
print -r -- "$__profile_migration_output" | grep -qF 'from Git history' ||
    fail "Zsh profile recovery was not reported"
rm -rf "$__profile_migration_home"

local __foreign_home="$__fixture_root/foreign"
mkdir -p "$__foreign_home"
local __foreign_config="$__foreign_home/.config/zsh"
local __foreign_target="$__foreign_config/.zshrc"
mkdir -p "$__foreign_config"
print -r -- '# unrelated startup file' > "$__foreign_home/unrelated.zshrc"
ln -s "$__foreign_home/unrelated.zshrc" "$__foreign_target"
local __foreign_output
if __foreign_output="$(
    env HOME="$__foreign_home" XDG_CONFIG_HOME="$__foreign_home/.config" \
        MISE_PROJECT_ROOT="$__root_dir" zsh "$__root_dir/$__migration_task" 2>&1
)"; then
    fail "Zsh migration replaced an unrelated startup symlink"
fi
[[ -L "$__foreign_target" ]] || fail "unrelated Zsh startup symlink was removed"
print -r -- "$__foreign_output" | grep -qF "non-repository Zsh startup symlink" ||
    fail "Zsh migration did not report the unrelated symlink"
rm -rf "$__foreign_home"

local __dangling_home="$__fixture_root/dangling"
mkdir -p "$__dangling_home"
local __dangling_project="$__dangling_home/project"
local __dangling_config="$__dangling_home/.config/zsh"
local __dangling_target="$__dangling_config/.zshrc"
mkdir -p "$__dangling_config" "$__dangling_project/home/.config/zsh"
print -r -- '# legacy startup file from Git history' > "$__dangling_project/home/.config/zsh/.zshrc"
git -C "$__dangling_project" init -q
git -C "$__dangling_project" config user.email test@example.com
git -C "$__dangling_project" config user.name "Migration Test"
git -C "$__dangling_project" config commit.gpgsign false
git -C "$__dangling_project" add home/.config/zsh/.zshrc
git -C "$__dangling_project" commit -qm "Add legacy startup file"
rm "$__dangling_project/home/.config/zsh/.zshrc"
ln -s "$__dangling_project/home/.config/zsh/.zshrc" "$__dangling_target"
local __dangling_output="$(
    env HOME="$__dangling_home" XDG_CONFIG_HOME="$__dangling_home/.config" \
        MISE_PROJECT_ROOT="$__dangling_project" zsh "$__root_dir/$__migration_task" 2>&1
)"
[[ -f "$__dangling_target.bak" ]] || fail "dangling Zsh startup backup was not created"
grep -qF 'legacy startup file from Git history' "$__dangling_target.bak" ||
    fail "dangling Zsh startup backup was not recovered from Git history"
print -r -- "$__dangling_output" | grep -qF 'from Git history' ||
    fail "dangling Zsh startup recovery was not reported"
rm -rf "$__dangling_home"

echo "zsh bootstrap configuration passed."
