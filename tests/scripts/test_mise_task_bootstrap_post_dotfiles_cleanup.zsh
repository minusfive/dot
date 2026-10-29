#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing bootstrap:post-dotfiles:cleanup task..."

local __task="home/.config/mise/tasks/bootstrap/post-dotfiles/cleanup.zsh"
local __task_path="$PWD/$__task"
local __fixture_dir
__fixture_dir="$(test_fixture_dir cleanup)" || exit 1
local __fixture_home="$__fixture_dir/home"
local __fixture_root="$__fixture_dir/repository"
local __source_dir="$__fixture_root/home"
local __target_dir="$__fixture_home/.config/mise"
local __example_target="$__fixture_home/.config/example"
local __global_config="$__fixture_dir/global-mise.toml"
local __host_mise_config="$HOME/.config/mise"
local __output="$__fixture_dir/output"
local __failure_output="$__fixture_dir/failure-output"
local __block_failure_output="$__fixture_dir/block-failure-output"
trap 'rm -rf "$__fixture_dir"' EXIT

[[ -x "$__task" ]] || fail "cleanup task is not executable"
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
        mise -C "$__test_mise_repository" tasks info bootstrap:post-dotfiles:cleanup
)"
print -r -- "$__task_info" | grep -qF "Task: bootstrap:post-dotfiles:cleanup" ||
    fail "cleanup task is not discoverable from the active mise source configuration"

mkdir -p \
    "$__source_dir/.config/mise/conf.d" \
    "$__source_dir/.config/mise/active" \
    "$__source_dir/.config/zsh" \
    "$__source_dir/.config/example" \
    "$__source_dir/.local/state/mise" \
    "$__target_dir/conf.d" \
    "$__target_dir/active" \
    "$__target_dir/conf.d/old" \
    "$__example_target" \
    "$__fixture_home/.config/work-targets" \
    "$__fixture_home/.config/personal-targets" \
    "$__fixture_home/.config/zsh" \
    "$__fixture_home/.local/state/mise/tracked-configs"
mkdir -p "$__fixture_home/dev/personal/dot"
ln -s "$__source_dir" "$__fixture_home/dev/personal/dot/home"
cat > "$__source_dir/.config/mise/conf.d/fixture.toml" <<'EOF'
[dotfiles]
"~/.config/zsh/.zshrc/active" = { block = '''
active
''' }
EOF
printf 'active\n' > "$__source_dir/.config/zsh/active.zsh"
printf 'active\n' > "$__source_dir/.config/example/owned.conf"
cat > "$__global_config" <<'EOF'
[settings.dotfiles]
relative_symlinks = true

[dotfiles."cleanup/mise/conf.d"]
source = "~/dev/personal/dot/home/.config/mise/conf.d"
mode = "symlink-each"
variants = [{ default = true, target = "{{ mise_config_dir }}/conf.d" }]

[dotfiles."cleanup/mise/active"]
source = "~/dev/personal/dot/home/.config/mise/active"
mode = "symlink-each"
variants = [{ default = true, target = "{{ mise_config_dir }}/active" }]

[dotfiles."cleanup/config/zsh"]
source = "~/dev/personal/dot/home/.config/zsh"
mode = "symlink-each"
variants = [{ default = true, target = "{{ xdg_config_home }}/zsh" }]

[dotfiles."cleanup/config/example/owned.conf"]
source = "~/dev/personal/dot/home/.config/example/owned.conf"
mode = "symlink"
variants = [{ default = true, target = "{{ xdg_config_home }}/example/owned.conf" }]

[dotfiles."cleanup/root-target"]
source = "~/dev/personal/dot/home/.config/example/owned.conf"
mode = "symlink"
variants = [{ default = true, target = "~/.cleanup-root-target" }]

[dotfiles."cleanup/profile-target/owned.conf"]
source = "~/dev/personal/dot/home/.config/example/owned.conf"
mode = "symlink"
variants = [
    { profile = "work", target = "{{ xdg_config_home }}/work-targets/owned.conf" },
    { profile = "personal", target = "{{ xdg_config_home }}/personal-targets/owned.conf" },
]
EOF
local __xdg_data="$__fixture_dir/xdg/data"
local __xdg_state="$__fixture_dir/xdg/state"
local __xdg_cache="$__fixture_dir/xdg/cache"
mkdir -p "$__xdg_data" "$__xdg_state" "$__xdg_cache"
local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_home/.config"
    "XDG_DATA_HOME=$__xdg_data"
    "XDG_STATE_HOME=$__xdg_state"
    "XDG_CACHE_HOME=$__xdg_cache"
    "MISE_CONFIG_DIR=$__target_dir"
    "MISE_GLOBAL_CONFIG_FILE=$__global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_PROJECT_ROOT=$__fixture_root"
    "MISE_DATA_DIR=$__fixture_dir/mise-data"
    "MISE_STATE_DIR=$__fixture_home/.local/state/mise"
    "MISE_CACHE_DIR=$__fixture_dir/mise-cache"
    "MISE_TMP_DIR=$__fixture_dir/mise-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/system-config"
    "MISE_INSTALLS_DIR=$__fixture_dir/mise-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_dir/mise-install-store"
    "MISE_PLUGINS_DIR=$__fixture_dir/mise-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_dir/mise-downloads"
    "MISE_SHIMS_DIR=$__fixture_dir/mise-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_dir/system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_dir/system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_dir/system-shims"
    "MISE_IGNORED_CONFIG_PATHS=$__host_mise_config"
    "MISE_CEILING_PATHS=$__fixture_root"
    "MISE_NO_HOOKS=1"
)
env "${__fixture_env[@]}" \
    mise -C "$__fixture_root" trust "$__global_config" >/dev/null ||
    fail "could not trust cleanup fixture config"
printf 'external\n' > "$__fixture_dir/external"
cat > "$__source_dir/.config/mise/cleanup.paths" <<'EOF'
# fixture inventory
.config/mise
.config/zsh
.local/state/mise
.stale-root-link
EOF
printf '# Relative target paths and block IDs that historically belonged to this repository.\n' \
    > "$__source_dir/.config/mise/cleanup.blocks"
printf '%s\t%s\n' '.config/zsh/.zshrc' active >> "$__source_dir/.config/mise/cleanup.blocks"
printf '%s\t%s\n' '.config/zsh/.zshrc' removed >> "$__source_dir/.config/mise/cleanup.blocks"
cat > "$__fixture_home/.config/zsh/.zshrc" <<'EOF'
header
# >>> mise:active >>> managed by mise — do not edit between markers
active
# <<< mise:active <<<
# >>> mise:removed >>> managed by mise — do not edit between markers
removed
# <<< mise:removed <<<
# >>> mise:foreign >>> managed by mise — do not edit between markers
foreign
# <<< mise:foreign <<<
EOF
printf 'active\n' > "$__source_dir/.config/mise/conf.d/active.toml"
printf 'active\n' > "$__source_dir/.config/mise/active/current"
printf 'other\n' > "$__source_dir/.config/example/other.conf"
cat > "$__source_dir/.config/mise/cleanup.migrations" <<'EOF'
# Old HOME-relative targets and repository-relative sources for migrated whole-file dotfiles.
.config/example/old.conf	home/.config/example/owned.conf
.config/example/mismatch.conf	home/.config/example/owned.conf
.config/example/external.conf	home/.config/example/owned.conf
.config/zsh/active.zsh	home/.config/zsh/active.zsh
.config/work-targets/owned.conf	home/.config/example/owned.conf
.config/personal-targets/owned.conf	home/.config/example/owned.conf
EOF

ln -s "$__source_dir/.config/mise/conf.d/active.toml" \
    "$__target_dir/conf.d/active.toml"
ln -s "$__source_dir/.config/mise/conf.d/direct-removed.toml" \
    "$__target_dir/conf.d/direct-removed.toml"
ln -s "$__source_dir/.config/mise/conf.d/removed.toml" \
    "$__target_dir/conf.d/removed.toml"
ln -s "$__source_dir/.config/mise/conf.d/old/removed.toml" \
    "$__target_dir/conf.d/old/removed.toml"
ln -s "$__source_dir/.config/mise/active/current" \
    "$__target_dir/active/current"
ln -s "$__source_dir/.config/mise/active/removed" \
    "$__target_dir/active/removed"
ln -s "$__source_dir/.config/zsh/active.zsh" \
    "$__fixture_home/.config/zsh/active.zsh"
ln -s "$__source_dir/.config/zsh/removed.zsh" \
    "$__fixture_home/.config/zsh/removed.zsh"
ln -s "$__source_dir/.config/zsh/tracked-config.zsh" \
    "$__fixture_home/.local/state/mise/tracked-configs/config"
ln -s "$__source_dir/.config/example/missing.conf" "$__example_target/removed.conf"
ln -s "$__source_dir/.config/example/owned.conf" "$__example_target/old.conf"
ln -s "$__source_dir/.config/example/other.conf" "$__example_target/mismatch.conf"
ln -s "$__source_dir/.config/example/owned.conf" "$__example_target/unrelated.conf"
ln -s "$__fixture_dir/external" "$__example_target/external.conf"
ln -s "$__source_dir/.config/example/missing-work.conf" \
    "$__fixture_home/.config/work-targets/removed.conf"
ln -s "$__source_dir/.config/example/missing-personal.conf" \
    "$__fixture_home/.config/personal-targets/removed.conf"
ln -s "$__source_dir/.config/example/owned.conf" \
    "$__fixture_home/.config/work-targets/owned.conf"
ln -s "$__source_dir/.config/example/owned.conf" \
    "$__fixture_home/.config/personal-targets/owned.conf"
ln -s "$__fixture_dir/missing-external" "$__fixture_home/external-broken"
ln -s "$__fixture_dir/external" "$__target_dir/external"
ln -s "$__source_dir/.config/example/missing-root.conf" \
    "$__fixture_home/.stale-root-link"
mkdir -p "$__fixture_home/unrelated"
ln -s "$__source_dir/.config/example/missing-nested.conf" \
    "$__fixture_home/unrelated/stale"

env "${__fixture_env[@]}" usage_dry_run=true zsh "$__task" > "$__output"

grep -qF "would remove stale mise link" "$__output" ||
    fail "dry run did not report stale links"
grep -qF "would remove stale mise block" "$__output" ||
    fail "dry run did not report stale blocks"
[[ -L "$__target_dir/conf.d/removed.toml" ]] || fail "dry run removed a stale link"
[[ -L "$__example_target/old.conf" ]] || fail "dry run removed a valid migrated link"
[[ -L "$__example_target/mismatch.conf" ]] || fail "dry run removed a mismatched link"
[[ -L "$__example_target/external.conf" ]] || fail "dry run removed an external link"
[[ -L "$__example_target/unrelated.conf" ]] || fail "dry run removed an unrelated link"
[[ -L "$__fixture_home/.config/zsh/active.zsh" ]] ||
    fail "dry run removed an active symlink-each child"
grep -qF 'mise:removed' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "dry run removed a stale block"
[[ -L "$__fixture_home/.config/zsh/removed.zsh" ]] ||
    fail "dry run removed a stale link outside mise"
[[ -L "$__example_target/removed.conf" ]] ||
    fail "dry run removed a stale link from a resolved file-target parent"
[[ -L "$__fixture_home/.config/work-targets/removed.conf" ]] ||
    fail "dry run removed the work-profile target link"
[[ -L "$__fixture_home/.config/personal-targets/removed.conf" ]] ||
    fail "dry run removed the personal-profile target link"
[[ -L "$__fixture_home/.local/state/mise/tracked-configs/config" ]] ||
    fail "dry run removed a tracked-config link"
[[ -L "$__fixture_home/external-broken" ]] || fail "dry run removed an external link"
[[ -L "$__fixture_home/.stale-root-link" ]] ||
    fail "dry run removed a direct HOME child"
[[ -L "$__fixture_home/unrelated/stale" ]] ||
    fail "dry run removed a nested link outside an exact HOME target"

env "${__fixture_env[@]}" zsh "$__task" > "$__output"

[[ -L "$__target_dir/conf.d/active.toml" ]] || fail "active managed link was removed"
[[ ! -L "$__target_dir/conf.d/direct-removed.toml" ]] ||
    fail "broken direct repository link remains"
[[ ! -L "$__target_dir/conf.d/removed.toml" ]] || fail "stale managed link remains"
[[ ! -L "$__example_target/old.conf" ]] || fail "valid migrated link remains"
[[ -L "$__example_target/mismatch.conf" ]] || fail "mismatched link was removed"
[[ "$(readlink "$__example_target/mismatch.conf")" == "$__source_dir/.config/example/other.conf" ]] ||
    fail "mismatched link target changed"
[[ -L "$__example_target/external.conf" ]] || fail "external link was removed"
[[ "$(readlink "$__example_target/external.conf")" == "$__fixture_dir/external" ]] ||
    fail "external link target changed"
[[ -L "$__example_target/unrelated.conf" ]] || fail "unrelated link was removed"
[[ "$(readlink "$__example_target/unrelated.conf")" == "$__source_dir/.config/example/owned.conf" ]] ||
    fail "unrelated link target changed"
[[ ! -L "$__target_dir/conf.d/old/removed.toml" ]] ||
    fail "stale link with a missing source directory remains"
[[ -L "$__target_dir/active/current" ]] || fail "active symlink-each link was removed"
[[ ! -L "$__target_dir/active/removed" ]] || fail "stale symlink-each link remains"
[[ -L "$__fixture_home/.config/zsh/active.zsh" ]] ||
    fail "active symlink-each child was removed"
[[ "$(readlink "$__fixture_home/.config/zsh/active.zsh")" == "$__source_dir/.config/zsh/active.zsh" ]] ||
    fail "active symlink-each child target changed"
grep -qF 'mise:active' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "active mise block was removed"
if grep -qF 'mise:removed' "$__fixture_home/.config/zsh/.zshrc"; then
    fail "stale mise block remains"
fi
grep -qF 'mise:foreign' "$__fixture_home/.config/zsh/.zshrc" ||
    fail "unlisted mise block was removed"
[[ ! -L "$__fixture_home/.config/zsh/removed.zsh" ]] ||
    fail "stale link outside the mise directory remains"
[[ ! -L "$__example_target/removed.conf" ]] ||
    fail "stale link in a resolved file-target parent remains"
[[ ! -L "$__fixture_home/.config/work-targets/removed.conf" ]] ||
    fail "stale work-profile target link remains"
[[ ! -L "$__fixture_home/.config/personal-targets/removed.conf" ]] ||
    fail "stale personal-profile target link remains"
[[ -L "$__fixture_home/.config/work-targets/owned.conf" ]] ||
    fail "active work-profile link was removed"
[[ -L "$__fixture_home/.config/personal-targets/owned.conf" ]] ||
    fail "active personal-profile link was removed"
[[ "$(readlink "$__fixture_home/.config/work-targets/owned.conf")" == "$__source_dir/.config/example/owned.conf" ]] ||
    fail "active work-profile link target changed"
[[ "$(readlink "$__fixture_home/.config/personal-targets/owned.conf")" == "$__source_dir/.config/example/owned.conf" ]] ||
    fail "active personal-profile link target changed"
[[ -L "$__fixture_home/.local/state/mise/tracked-configs/config" ]] ||
    fail "tracked-config link was removed"
[[ -L "$__fixture_home/external-broken" ]] || fail "external broken link was removed"
[[ ! -L "$__fixture_home/.stale-root-link" ]] ||
    fail "stale direct HOME child remains"
[[ -L "$__fixture_home/unrelated/stale" ]] ||
    fail "cleanup recursively scanned HOME"

mv "$__target_dir" "$__fixture_dir/legacy-mise-config"
ln -s "$__source_dir/.config/mise" "$__target_dir"
ln -s "$__source_dir/.config/example/missing-from-source-tree.conf" \
    "$__source_dir/.config/mise/conf.d/source-tree-link"
env "${__fixture_env[@]}" zsh "$__task" > "$__output"
[[ -L "$__target_dir" ]] || fail "active global mise config link was removed"
[[ "$(realpath "$__target_dir")" == "$(realpath "$__source_dir/.config/mise")" ]] ||
    fail "active global mise config link target changed"
[[ -L "$__source_dir/.config/mise/conf.d/source-tree-link" ]] ||
    fail "link inside the active mise source tree was removed"
rm -f "$__source_dir/.config/mise/conf.d/source-tree-link"

mkdir -p "$__source_dir/old-mise"
rm -f "$__target_dir"
ln -s "$__source_dir/old-mise" "$__target_dir"
env "${__fixture_env[@]}" zsh "$__task" > "$__output"
[[ ! -L "$__target_dir" ]] || fail "stale repository-owned global config link remains"
mkdir -p "$__fixture_dir/external-mise"
ln -s "$__fixture_dir/external-mise" "$__target_dir"
env "${__fixture_env[@]}" zsh "$__task" > "$__output"
[[ -L "$__target_dir" ]] || fail "external global config link was removed"
[[ "$(readlink "$__target_dir")" == "$__fixture_dir/external-mise" ]] ||
    fail "external global config link target changed"

local __blocks_backup="$__fixture_dir/cleanup.blocks.backup"
cp "$__source_dir/.config/mise/cleanup.blocks" "$__blocks_backup"
printf '%s\t%s\n' '../outside' removed >> "$__source_dir/.config/mise/cleanup.blocks"
if env "${__fixture_env[@]}" zsh "$__task" > "$__block_failure_output" 2>&1; then
    fail "cleanup accepted a block target outside HOME"
fi
grep -qF "outside HOME" "$__block_failure_output" ||
    fail "cleanup did not explain the block path containment refusal"
mv "$__blocks_backup" "$__source_dir/.config/mise/cleanup.blocks"


[[ -L "$__fixture_dir/legacy-mise-config/external" ]] ||
    fail "external link was removed"

mkdir -p "$__fixture_dir/external-source"
ln -s "$__fixture_dir/external-source" "$__source_dir/alias"
ln -s "$__source_dir/alias/missing" "$__fixture_home/.config/zsh/physical-bypass"
if env "${__fixture_env[@]}" zsh "$__task" > "$__failure_output" 2>&1; then
    fail "cleanup removed a link whose physical source is outside the repository"
fi
grep -qF "outside this repository" "$__failure_output" ||
    fail "cleanup did not explain the physical containment refusal"
[[ -L "$__fixture_home/.config/zsh/physical-bypass" ]] ||
    fail "cleanup removed the physically external link"

local __ownership_root="$__fixture_dir/ownership-repository"
local __ownership_home="$__fixture_dir/ownership-home"
local __ownership_source="$__ownership_root/home/.config/mise"
local __ownership_xdg="$__fixture_dir/ownership-xdg/config"
local __ownership_explicit="$__fixture_dir/ownership-explicit/mise"
local __ownership_global_config="$__fixture_dir/ownership-global.toml"
local __ownership_external="$__fixture_dir/ownership-external"
mkdir -p "$__ownership_source" "$__ownership_home" "$__ownership_xdg" \
    "$__ownership_root/home/stale-mise" "$__ownership_external" \
    "$(dirname "$__ownership_explicit")"
printf '[settings]\n' > "$__ownership_global_config"
: > "$__ownership_source/cleanup.paths"
: > "$__ownership_source/cleanup.blocks"
: > "$__ownership_source/cleanup.migrations"
local -a __ownership_env=(
    "HOME=$__ownership_home"
    "XDG_CONFIG_HOME=$__ownership_xdg"
    "MISE_GLOBAL_CONFIG_FILE=$__ownership_global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_PROJECT_ROOT=$__ownership_root"
    "MISE_DATA_DIR=$__fixture_dir/ownership-data"
    "MISE_STATE_DIR=$__fixture_dir/ownership-state"
    "MISE_CACHE_DIR=$__fixture_dir/ownership-cache"
    "MISE_TMP_DIR=$__fixture_dir/ownership-tmp"
    "MISE_SYSTEM_CONFIG_DIR=$__fixture_dir/ownership-system-config"
    "MISE_INSTALLS_DIR=$__fixture_dir/ownership-installs"
    "MISE_INSTALL_STORE_DIR=$__fixture_dir/ownership-install-store"
    "MISE_PLUGINS_DIR=$__fixture_dir/ownership-plugins"
    "MISE_DOWNLOADS_DIR=$__fixture_dir/ownership-downloads"
    "MISE_SHIMS_DIR=$__fixture_dir/ownership-shims"
    "MISE_SYSTEM_DATA_DIR=$__fixture_dir/ownership-system-data"
    "MISE_SYSTEM_INSTALLS_DIR=$__fixture_dir/ownership-system-installs"
    "MISE_SYSTEM_SHIMS_DIR=$__fixture_dir/ownership-system-shims"
    "MISE_NO_HOOKS=1"
)
env -u MISE_CONFIG_DIR "${__ownership_env[@]}" \
    mise -C "$__ownership_root" trust "$__ownership_global_config" >/dev/null ||
    fail "could not trust ownership cleanup fixture config"

ln -s "$__ownership_root/home/stale-mise" "$__ownership_xdg/mise"
(cd "$__ownership_root" && env "${__ownership_env[@]}" MISE_CONFIG_DIR=home/.config/mise \
    zsh "$__task_path") > "$__output"
[[ ! -L "$__ownership_xdg/mise" ]] ||
    fail "relative source-selected global config link remains"

ln -s "$__ownership_root/home/stale-mise" "$__ownership_xdg/mise"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_source" \
    zsh "$__task" > "$__output"
[[ ! -L "$__ownership_xdg/mise" ]] ||
    fail "stale repository-owned source-selected global config link remains"
ln -s "$__ownership_source" "$__ownership_xdg/mise"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_source" \
    zsh "$__task" > "$__output"
[[ -L "$__ownership_xdg/mise" ]] ||
    fail "active source-selected global config link was removed"
[[ "$(realpath "$__ownership_xdg/mise")" == "$(realpath "$__ownership_source")" ]] ||
    fail "active source-selected global config link target changed"
rm -f "$__ownership_xdg/mise"
ln -s "$__ownership_external" "$__ownership_xdg/mise"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_source" \
    zsh "$__task" > "$__output"
[[ -L "$__ownership_xdg/mise" ]] ||
    fail "external source-selected global config link was removed"
[[ "$(readlink "$__ownership_xdg/mise")" == "$__ownership_external" ]] ||
    fail "external source-selected global config link target changed"
rm -f "$__ownership_xdg/mise"

ln -s "$__ownership_root/home/stale-mise" "$__ownership_xdg/mise"
env -u MISE_CONFIG_DIR "${__ownership_env[@]}" zsh "$__task" > "$__output"
[[ ! -L "$__ownership_xdg/mise" ]] ||
    fail "stale repository-owned custom XDG mise config link remains"
ln -s "$__ownership_source" "$__ownership_xdg/mise"
env -u MISE_CONFIG_DIR "${__ownership_env[@]}" zsh "$__task" > "$__output"
[[ -L "$__ownership_xdg/mise" ]] ||
    fail "active custom XDG mise source link was removed"
rm -f "$__ownership_xdg/mise"
ln -s "$__ownership_external" "$__ownership_xdg/mise"
env -u MISE_CONFIG_DIR "${__ownership_env[@]}" zsh "$__task" > "$__output"
[[ -L "$__ownership_xdg/mise" ]] ||
    fail "external custom XDG mise config link was removed"

ln -s "$__ownership_root/home/stale-mise" "$__ownership_explicit"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_explicit" \
    zsh "$__task" > "$__output"
[[ ! -L "$__ownership_explicit" ]] ||
    fail "stale repository-owned explicit mise config link remains"
ln -s "$__ownership_source" "$__ownership_explicit"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_explicit" \
    zsh "$__task" > "$__output"
[[ -L "$__ownership_explicit" ]] ||
    fail "active explicit mise source link was removed"
rm -f "$__ownership_explicit"
ln -s "$__ownership_external" "$__ownership_explicit"
env "${__ownership_env[@]}" MISE_CONFIG_DIR="$__ownership_explicit" \
    zsh "$__task" > "$__output"
[[ -L "$__ownership_explicit" ]] ||
    fail "external explicit mise config link was removed"

echo "bootstrap:post-dotfiles:cleanup task passed."
