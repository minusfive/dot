#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing mise:cleanup:inventory task..."

local __task="home/.config/mise/tasks/mise/cleanup/inventory.zsh"
local __fixture_dir="$(test_fixture_dir cleanup-inventory)"
local __fixture_root="$__fixture_dir/repository"
local __fixture_home="$__fixture_dir/home"
local __manifest="$__fixture_root/home/.config/mise/cleanup.paths"
local __blocks_manifest="$__fixture_root/home/.config/mise/cleanup.blocks"
local __migrations_manifest="$__fixture_root/home/.config/mise/cleanup.migrations"
local __global_config="$__fixture_dir/global-mise.toml"
local __host_mise_config="$HOME/.config/mise"
trap 'rm -rf "$__fixture_dir"' EXIT

[[ -x "$__task" ]] || fail "cleanup inventory task is not executable"
grep -qF '"mise/config/mise/tasks/mise/cleanup/inventory.zsh"' \
    home/.config/mise/conf.d/mise.toml ||
    fail "cleanup inventory task is not deployed by the mise control plane"

mkdir -p "$__fixture_root/home/.config/mise/conf.d"
cat > "$__fixture_root/home/.config/mise/conf.d/example.toml" <<'EOF'
[dotfiles]
"example/config/example" = { source = "~/dev/personal/dot/home/.config/example", mode = "symlink-each", variants = [{ default = true, target = "{{ xdg_config_home }}/example" }] }
"~/.config/example/config.toml/old" = { block = '''
old
''' }
EOF
mkdir -p "$__fixture_root/home/.config/example"
mkdir -p "$__fixture_home/dev/personal/dot"
ln -s "$__fixture_root/home" "$__fixture_home/dev/personal/dot/home"
cat > "$__global_config" <<'EOF'
[settings.dotfiles]
relative_symlinks = true

[dotfiles."example/config/example"]
source = "~/dev/personal/dot/home/.config/example"
mode = "symlink-each"
variants = [{ default = true, target = "{{ xdg_config_home }}/example" }]

[dotfiles."example/profile-target"]
source = "~/dev/personal/dot/home/.config/example"
mode = "symlink-each"
variants = [
    { profile = "work", target = "{{ xdg_config_home }}/work-targets/example" },
    { profile = "personal", target = "{{ xdg_config_home }}/personal-targets/example" },
]
EOF
printf '# Relative paths under $HOME that historically contained repository-managed targets.\nlegacy/managed\n' \
    > "$__manifest"
printf '# Literal migration rows that inventory must preserve.\n.config/old\thome/.config/example/old\n' \
    > "$__migrations_manifest"

git -C "$__fixture_root" init -q
git -C "$__fixture_root" config user.email test@example.com
git -C "$__fixture_root" config user.name "Cleanup Test"
git -C "$__fixture_root" add home
git -C "$__fixture_root" -c commit.gpgsign=false commit -q -m "seed cleanup inventory fixture"

local -a __fixture_env=(
    "HOME=$__fixture_home"
    "XDG_CONFIG_HOME=$__fixture_dir/custom-xdg/config"
    "XDG_DATA_HOME=$__fixture_dir/custom-xdg/data"
    "XDG_STATE_HOME=$__fixture_dir/custom-xdg/state"
    "XDG_CACHE_HOME=$__fixture_dir/custom-xdg/cache"
    "MISE_CONFIG_DIR=$__fixture_dir/custom-mise"
    "MISE_GLOBAL_CONFIG_FILE=$__global_config"
    "MISE_GLOBAL_CONFIG_ROOT=$__fixture_dir"
    "MISE_PROJECT_ROOT=$__fixture_root"
    "MISE_DATA_DIR=$__fixture_dir/mise-data"
    "MISE_STATE_DIR=$__fixture_dir/mise-state"
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
)
mkdir -p "$__fixture_dir/custom-xdg/config" "$__fixture_dir/custom-xdg/data" \
    "$__fixture_dir/custom-xdg/state" "$__fixture_dir/custom-xdg/cache" \
    "$__fixture_dir/custom-mise"
env "${__fixture_env[@]}" \
    mise -C "$__fixture_root" trust "$__global_config" >/dev/null ||
    fail "could not trust inventory fixture config"
env "${__fixture_env[@]}" zsh "$__task"

grep -qF 'legacy/managed' "$__manifest" ||
    fail "inventory removed an existing historical path"
grep -qF '.config/example' "$__manifest" ||
    fail "inventory omitted a current resolved target path"
grep -qF '.config/work-targets/example' "$__manifest" ||
    fail "inventory omitted a work-profile target path"
grep -qF '.config/personal-targets/example' "$__manifest" ||
    fail "inventory omitted a personal-profile target path"
if grep -qF 'custom-xdg' "$__manifest"; then
    fail "inventory stored a custom XDG path"
fi
grep -qF $'.config/example/config.toml\told' "$__blocks_manifest" ||
    fail "inventory omitted a current block"
if grep -qF '"' "$__manifest"; then
    fail "cleanup inventory contains quoted paths"
fi
grep -qF $'.config/old\thome/.config/example/old' "$__migrations_manifest" ||
    fail "inventory rewrote cleanup.migrations"

local __blocks_backup="$__fixture_dir/cleanup.blocks.before"
cp "$__blocks_manifest" "$__blocks_backup"
print -r -- '"~/.config/example-two" = { source = "~/dev/personal/dot/home/.config/example", mode = "symlink-each" }' \
    >> "$__fixture_root/home/.config/mise/conf.d/example.toml"
env "${__fixture_env[@]}" zsh "$__task"
grep -qF '.config/example-two' "$__manifest" ||
    fail "inventory omitted a new home-relative target path"
cmp -s "$__blocks_backup" "$__blocks_manifest" ||
    fail "inventory changed cleanup.blocks when only cleanup.paths changed"

echo "mise:cleanup:inventory task passed."
