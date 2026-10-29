#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Git bootstrap configuration..."

local __config="home/.config/mise/conf.d/git.toml"
assert_module_package git brew:git
local __source_config="home/.config/git/config"
local __source_ignore="home/.config/git/ignore"
local __source_zsh="home/.config/git/zshrc.zsh"
local __source_domains="home/dev/personal/.domains"
local __target_domains='"~/dev/personal/.domains" = { source = "~/dev/personal/dot/home/dev/personal/.domains", mode = "symlink" }'
[[ -f "$__config" && -f "$__source_config" && -f "$__source_ignore" && -f "$__source_domains" ]] ||
    fail "Git source or declaration is missing"
[[ -f "$__source_zsh" ]] || fail "missing Git Zsh source"
zsh -n "$__source_zsh" || fail "Git Zsh source has syntax errors"
grep -qF '"git/config/git" = { source = "~/dev/personal/dot/home/.config/git", mode = "symlink-each", exclude = ["zshrc.zsh"], variants = [{ default = true, target = "{{ xdg_config_home }}/git" }] }' "$__config" ||
    fail "Git symlink-each declaration is missing"
grep -qF "$__target_domains" "$__config" ||
    fail "personal domain manifest symlink declaration is missing"
grep -qF '"~/.config/zsh/.zshrc-zone-0.zsh/git"' "$__config" ||
    fail "Git Zsh edit is missing"
[[ ! -e home/dev/work/.domains && ! -e home/dev/work/.gitconfig ]] ||
    fail "work profile files must stay outside tracked sources"
[[ "$(git config --file "$__source_config" --get gpg.format)" == "ssh" ]] ||
    fail "Git SSH signing format changed"
git config --file "$__source_config" --get gpg.ssh.program >/dev/null ||
    fail "Git SSH signing program is missing"
grep -qFx "github.com" "$__source_domains" ||
    fail "personal domain manifest does not include the public Git host"
if rg -n -i '(api[_-]?key|token|secret|credential|private[[:space:]_-]?key|auth[.]db)' \
    "$__source_config" "$__source_ignore" "$__source_domains"; then
    fail "credential-like content found in Git sources"
fi

local __fixture_dir
__fixture_dir="$(test_fixture_dir git-bootstrap-test)" || exit 1
local __home="$__fixture_dir/home"
local __xdg_config="$__fixture_dir/xdg/config"
local __bin="$__fixture_dir/bin"
local __global_config="$__fixture_dir/global.gitconfig"
local __personal_repo="$__home/dev/personal/repo"
local __work_repo="$__home/dev/work/repo"
local __personal_profile="$__home/dev/personal/.gitconfig"
local __work_profile="$__home/dev/work/.gitconfig"
local __helper_log="$__fixture_dir/helpers.log"
trap 'rm -rf -- "$__fixture_dir"' EXIT
mkdir -p "$__home/dev/personal" "$__home/dev/work" "$__bin" "$__xdg_config/git" \
    "$__xdg_config/delta/themes" "$__xdg_config/gh/personal"

__relative_link() {
    local __source="$1"
    local __target="$2"
    local __relative
    __relative="$(python3 -c 'import os,sys; print(os.path.relpath(os.path.realpath(sys.argv[1]), os.path.realpath(os.path.dirname(sys.argv[2]))))' \
        "$__source" "$__target")"
    ln -s "$__relative" "$__target"
}
__relative_link "$(realpath "$__source_config")" "$__xdg_config/git/config"
__relative_link "$(realpath "$__source_ignore")" "$__xdg_config/git/ignore"
__relative_link "$(realpath "$__source_domains")" "$__home/dev/personal/.domains"
__relative_link "$(realpath home/.config/delta/themes/catppuccin.gitconfig)" \
    "$__xdg_config/delta/themes/catppuccin.gitconfig"
for __path in "$__xdg_config/git/config" "$__xdg_config/git/ignore" \
    "$__home/dev/personal/.domains"; do
    case "$(readlink "$__path")" in
        /*) fail "Git target link is absolute: $__path" ;;
    esac
done
[[ "$(realpath "$__xdg_config/git/config")" == "$(realpath "$__source_config")" ]] ||
    fail "Git config target does not resolve to its tracked source"
[[ "$(realpath "$__xdg_config/git/ignore")" == "$(realpath "$__source_ignore")" ]] ||
    fail "Git ignore target does not resolve to its tracked source"
[[ "$(realpath "$__home/dev/personal/.domains")" == "$(realpath "$__source_domains")" ]] ||
    fail "personal domains target does not resolve to its tracked source"

cat > "$__bin/inherited-helper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'inherited\n' >> "$GIT_HELPER_LOG"
EOF
cat > "$__bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s|%s\n' "$GH_CONFIG_DIR" "$*" >> "$GIT_HELPER_LOG"
EOF
chmod +x "$__bin/inherited-helper" "$__bin/gh"
export GIT_HELPER_LOG="$__helper_log"

{
    printf '[user]\n name = shared\n'
    printf '[credential]\n helper = %s/inherited-helper\n' "$__bin"
} > "$__global_config"
git config --file "$__global_config" --add include.path "$__xdg_config/git/config"
git config --file "$__global_config" --add core.excludesFile "$__xdg_config/git/ignore"
git config --file "$__global_config" --add commit.gpgsign true
git config --file "$__global_config" --add tag.gpgsign true
git config --file "$__personal_profile" user.name personal
git config --file "$__personal_profile" user.email personal@example.test
git config --file "$__personal_profile" --add credential.https://github.com.helper ""
git config --file "$__personal_profile" --add credential.https://github.com.helper \
    '!GH_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gh/personal" gh auth git-credential'
git config --file "$__work_profile" user.name work
git config --file "$__work_profile" user.email work@example.test

git init -q "$__personal_repo"
git init -q "$__work_repo"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" config --includes --global --get user.name |
    grep -Fx personal >/dev/null || fail "personal profile did not override the shared identity"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__work_repo" config --includes --global --get user.name |
    grep -Fx work >/dev/null || fail "work profile did not override the shared identity"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" config --includes --global --get gpg.format |
    grep -Fx ssh >/dev/null || fail "Git SSH signing format changed"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" config --includes --global --get commit.gpgsign |
    grep -Fx true >/dev/null || fail "Git commit signing changed"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" config --includes --global --get tag.gpgsign |
    grep -Fx true >/dev/null || fail "Git tag signing changed"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" check-ignore -q --no-index mise.local.toml ||
    fail "Git global ignore does not cover mise.local.toml"
env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" check-ignore -q --no-index config.personal.local.toml ||
    fail "Git global ignore does not cover config.personal.local.toml"
env HOME="$__home" XDG_CONFIG_HOME="$__home/.config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" check-ignore -q --no-index example.local.yaml ||
    fail "Git global ignore does not cover a generic local-suffix file"
local __explicit_local_path="explicit.local.yaml"
print -r -- "fixture" > "$__personal_repo/$__explicit_local_path"
if env HOME="$__home" XDG_CONFIG_HOME="$__home/.config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" add -- "$__explicit_local_path" >/dev/null 2>&1; then
    fail "Git added an ignored local file without force"
fi
env HOME="$__home" XDG_CONFIG_HOME="$__home/.config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" add -f -- "$__explicit_local_path" ||
    fail "Git did not force-add the explicitly selected local file"
git -C "$__personal_repo" ls-files --error-unmatch "$__explicit_local_path" >/dev/null ||
    fail "force-added local file is missing from the Git index"
env HOME="$__home" XDG_CONFIG_HOME="$__home/.config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" check-ignore -q --no-index .cache/qmd/.qmd-embed.lock ||
    fail "Git global ignore does not cover the QMD embedding lock"
if env HOME="$__home" XDG_CONFIG_HOME="$__home/.config" GIT_CONFIG_GLOBAL="$__global_config" \
    GIT_CONFIG_NOSYSTEM=1 git -C "$__personal_repo" check-ignore -q --no-index .cache/qmd/.qmd-embed.lock.backup; then
    fail "Git global ignore unexpectedly covers a non-lock filename"
fi
if printf 'protocol=https\nhost=github.com\n\n' |
    env HOME="$__home" XDG_CONFIG_HOME="$__xdg_config" GIT_CONFIG_GLOBAL="$__global_config" \
        GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0 PATH="$__bin:$PATH" \
        git -C "$__personal_repo" credential fill >/dev/null 2>&1; then
    fail "fixture credential helpers unexpectedly returned credentials"
fi
grep -qF "$__xdg_config/gh/personal|auth git-credential get" "$__helper_log" ||
    fail "personal credential helper did not use the personal authentication store"
if grep -qF "inherited" "$__helper_log"; then
    fail "personal helper reset did not suppress the inherited helper"
fi

echo "Git bootstrap configuration passed."
