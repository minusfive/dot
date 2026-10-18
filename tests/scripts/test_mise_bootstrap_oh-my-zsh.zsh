#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Oh My Zsh bootstrap configuration..."

local __config="home/.config/mise/conf.d/module.oh-my-zsh.toml"
local __source="home/.config/oh-my-zsh/custom/plugins/zsh-vi-mode/config.zsh"
local __old_source="home/.config/zsh/plugins/zsh-vi-mode/config.zsh"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "$__source" ]] || fail "missing tracked vi-mode source"
[[ ! -e "$__old_source" ]] || fail "old tracked vi-mode source remains"
zsh -n "$__source" || fail "tracked vi-mode source has syntax errors"
zsh -n home/.config/oh-my-zsh/zshrc.zsh || fail "Oh My Zsh source has syntax errors"
zsh -n home/.config/zsh/.zshrc-zone-0.zsh || fail "Zone 0 source has syntax errors"
if grep -qE '^[[:space:]]*ZSH_THEME=' home/.config/oh-my-zsh/zshrc.zsh; then
    fail "Powerlevel10k theme selection must not be owned by Oh My Zsh"
fi

local __plugins_block="$(sed -n '/^plugins=(/,/^)/p' home/.config/oh-my-zsh/zshrc.zsh)"
for __plugin in \
    git zsh-vi-mode zoxide fzf fzf-tab fzf-tab-source zsh-autosuggestions \
    fast-syntax-highlighting colored-man-pages ohmyzsh-full-autoupdate mise bun; do
    grep -qF "    $__plugin" <<< "$__plugins_block" ||
        fail "Oh My Zsh plugin array is missing $__plugin"
done

grep -qF '[bootstrap.repos]' "$__config" || fail "repository bootstrap section is missing"
grep -qF '"~/.config/oh-my-zsh" = { url = "https://github.com/ohmyzsh/ohmyzsh.git" }' "$__config" ||
    fail "Oh My Zsh repository declaration is missing"
for __url in \
    'https://github.com/ohmyzsh/ohmyzsh.git' \
    'https://github.com/zdharma-continuum/fast-syntax-highlighting.git' \
    'https://github.com/Aloxaf/fzf-tab.git' \
    'https://github.com/Freed-Wu/fzf-tab-source.git' \
    'https://github.com/Pilaton/OhMyZsh-full-autoupdate.git' \
    'https://github.com/zsh-users/zsh-autosuggestions.git' \
    'https://github.com/jeffreytse/zsh-vi-mode.git'; do
    grep -qF "$__url" "$__config" || fail "Oh My Zsh repository URL is missing: $__url"
done

local __vi_entry='"~/.config/zsh/.zshrc-zone-0.zsh/oh-my-zsh-zsh-vi-mode" = { source = "~/dev/personal/dot/home/.config/oh-my-zsh/custom/plugins/zsh-vi-mode/config.zsh", template = "tera" }'
local __omz_entry='"~/.config/zsh/.zshrc-zone-1.zsh/oh-my-zsh" = { source = "~/dev/personal/dot/home/.config/oh-my-zsh/zshrc.zsh", template = "tera" }'
grep -qF "$__vi_entry" "$__config" || fail "Zone 0 vi-mode edit is missing"
grep -qF "$__omz_entry" "$__config" || fail "Oh My Zsh zshrc edit is missing"
local __vi_line="$(grep -nF "$__vi_entry" "$__config" | cut -d: -f1)"
local __omz_line="$(grep -nF "$__omz_entry" "$__config" | cut -d: -f1)"
(( __vi_line < __omz_line )) || fail "Zone 0 vi-mode edit must precede the Zone 1 framework edit"
if grep -qE 'VI_MODE_|zsh-vi-mode/config|zvm_(config|after_init)' home/.config/zsh/.zshrc-zone-0.zsh; then
    fail "generic Zone 0 source still owns vi-mode configuration"
fi
for __function in zvm_config zvm_after_init; do
    [[ "$(grep -R -l "^${__function}()" home/.config/oh-my-zsh home/.config/zsh 2>/dev/null | wc -l | tr -d ' ')" == "1" ]] ||
        fail "$__function has duplicate tracked definitions"
done
grep -qF '[bootstrap.hooks]' "$__config" || fail "Oh My Zsh bootstrap hooks are missing"
grep -qF 'post-dotfiles = "mise run omz:update"' "$__config" ||
    fail "Oh My Zsh update hook is missing"
grep -qF '"~/.config/mise/conf.d/module.oh-my-zsh.toml"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy module.oh-my-zsh.toml"
grep -qF '"~/.config/mise/tasks/omz/update.zsh"' home/.config/mise/conf.d/module.mise.toml ||
    fail "mise control-plane module does not deploy the Oh My Zsh update task"
grep -qF "'oh-my-zsh'," home/.config/mise/miserc.toml ||
    fail "oh-my-zsh must be present in the shared module list"
[[ -f "home/.config/mise/tasks/omz/update.zsh" ]] ||
    fail "missing Oh My Zsh update task"
zsh -n home/.config/mise/tasks/omz/update.zsh ||
    fail "Oh My Zsh update task has syntax errors"
grep -qF 'mise' home/.config/oh-my-zsh/zshrc.zsh ||
    fail "Oh My Zsh does not load the mise plugin"
if grep -qE 'mise (activate|completion)' scripts/tasks/bootstrap.zsh; then
    fail "bootstrap task must not own shell activation or completion"
fi
local __task_info="$(
    env -u MISE_ENV MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
        mise -C "$__root_dir" tasks info omz:update
)"
print -r -- "$__task_info" | grep -qF 'Task: omz:update' ||
    fail "Oh My Zsh update task is not discoverable"

local __fixture_root
__fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/oh-my-zsh.XXXXXX")" ||
    fail "could not create Oh My Zsh fixture"
__fixture_root="$(realpath "$__fixture_root")"
trap 'rm -rf -- "$__fixture_root"' EXIT
mkdir -p \
    "$__fixture_root/.config/zsh" \
    "$__fixture_root/.config/oh-my-zsh/custom/plugins" \
    "$__fixture_root/.local/state" \
    "$__fixture_root/.local/share" \
    "$__fixture_root/.cache"
for __plugin in \
    fast-syntax-highlighting \
    fzf-tab \
    fzf-tab-source \
    ohmyzsh-full-autoupdate \
    zsh-autosuggestions \
    zsh-vi-mode; do
    mkdir -p "$__fixture_root/.config/oh-my-zsh/custom/plugins/$__plugin"
done
for __profile in work personal; do
    local __profile_config="$(
        env -u MISE_ENV HOME="$__fixture_root" XDG_CONFIG_HOME="$__fixture_root/.config" \
            MISE_DATA_DIR="$__fixture_root/mise-data" MISE_CACHE_DIR="$__fixture_root/mise-cache" \
            DOT_PROFILE="$__profile" MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "module.oh-my-zsh.toml" ||
        fail "Oh My Zsh must be selected by the $__profile profile"
done
cp home/.config/zsh/.zshenv "$__fixture_root/.zshenv"
cp home/.config/zsh/.zshrc "$__fixture_root/.config/zsh/.zshrc"
cp home/.config/zsh/.zshrc-zones.zsh "$__fixture_root/.config/zsh/.zshrc-zones.zsh"
cp home/.config/zsh/.zshrc-zone-2.zsh "$__fixture_root/.config/zsh/.zshrc-zone-2.zsh"
cp home/.config/aliases/.aliases "$__fixture_root/.config/zsh/.aliases"
cp home/.config/zsh/custom_functions.zsh "$__fixture_root/.config/zsh/custom_functions.zsh"
cat >> "$__fixture_root/.config/zsh/.zshrc" <<'EOF'
source "$ZDOTDIR/.zshrc-zones.zsh"
EOF
{
    print -r -- '# >>> mise:oh-my-zsh-zsh-vi-mode >>> managed by mise'
    cat "$__source"
    print -r -- '# <<< mise:oh-my-zsh-zsh-vi-mode <<<'
} > "$__fixture_root/.config/zsh/.zshrc-zone-0.zsh"
{
    print -r -- '# >>> mise:oh-my-zsh >>> managed by mise'
    cat home/.config/oh-my-zsh/zshrc.zsh
    print -r -- '# <<< mise:oh-my-zsh <<<'
} > "$__fixture_root/.config/zsh/.zshrc-zone-1.zsh"
print -r -- 'history-state' > "$__fixture_root/.config/zsh/.zsh_history"
print -r -- 'completion-state' > "$__fixture_root/.config/zsh/.zcompdump"
chmod 600 "$__fixture_root/.config/zsh/.zsh_history"
chmod 644 "$__fixture_root/.config/zsh/.zcompdump"
print -r -- '# physical runtime checkout' > "$__fixture_root/.config/oh-my-zsh/README"
cat > "$__fixture_root/.config/oh-my-zsh/oh-my-zsh.sh" <<'EOF'
#!/usr/bin/env zsh

print -r -- "plugin-init:start" >> "$ZVM_EVENT_LOG"
zvm_cursor_style() { print -r -- "$1"; }
zvm_define_widget() { print -r -- "zvm-widget:$1" >> "$ZVM_EVENT_LOG"; }
zvm_bindkey() { print -r -- "zvm-bindkey:$1:$2" >> "$ZVM_EVENT_LOG"; }
autosuggest-accept() { :; }
bindkey() { print -r -- "autosuggestion-bindkey" >> "$ZVM_EVENT_LOG"; }
(( $+functions[zvm_config] )) || exit 71
(( $+functions[zvm_after_init] )) || exit 72
print -r -- "zvm-functions-ready" >> "$ZVM_EVENT_LOG"
zvm_config
zvm_after_init
print -r -- "plugin-init:end" >> "$ZVM_EVENT_LOG"
EOF
chmod +x "$__fixture_root/.config/oh-my-zsh/oh-my-zsh.sh"
local __event_log="$__fixture_root/events.log"
local __smoke_output
if ! __smoke_output="$(
    env -u MISE_ENV -u ZDOTDIR HOME="$__fixture_root" ZVM_EVENT_LOG="$__event_log" \
        MISE_DATA_DIR="$__fixture_root/mise-data" MISE_CACHE_DIR="$__fixture_root/mise-cache" \
        zsh -lic 'exit 0' 2>&1
)"; then
    print -r -- "$__smoke_output"
    fail "dummy-tree login shell smoke test failed"
fi
for __plugin in \
    fast-syntax-highlighting \
    fzf-tab \
    fzf-tab-source \
    ohmyzsh-full-autoupdate \
    zsh-autosuggestions \
    zsh-vi-mode; do
    [[ -d "$__fixture_root/.config/oh-my-zsh/custom/plugins/$__plugin" &&
        ! -L "$__fixture_root/.config/oh-my-zsh/custom/plugins/$__plugin" ]] ||
        fail "runtime plugin directory is not physical: $__plugin"
done
[[ ! -e "$__fixture_root/.config/oh-my-zsh/custom/plugins/zsh-vi-mode/config.zsh" ]] ||
    fail "tracked vi-mode source was deployed into the runtime checkout"
local __plugin_line="$(grep -nF 'plugin-init:start' "$__event_log" | cut -d: -f1)"
local __ready_line="$(grep -nF 'zvm-functions-ready' "$__event_log" | cut -d: -f1)"
local __bindkey_line="$(grep -nF 'autosuggestion-bindkey' "$__event_log" | cut -d: -f1)"
[[ -n "$__plugin_line" && -n "$__ready_line" && -n "$__bindkey_line" ]] ||
    fail "plugin lifecycle events are missing"
(( __plugin_line < __ready_line && __ready_line < __bindkey_line )) ||
    fail "vi-mode definitions and autosuggestion bindings are out of order"
[[ "$(<"$__fixture_root/.config/zsh/.zsh_history")" == "history-state" ]] ||
    fail "history runtime file changed"
[[ "$(<"$__fixture_root/.config/zsh/.zcompdump")" == "completion-state" ]] ||
    fail "completion runtime file changed"
[[ "$(stat -c '%a' "$__fixture_root/.config/zsh/.zsh_history")" == "600" ]] ||
    fail "history runtime file mode changed"
[[ "$(stat -c '%a' "$__fixture_root/.config/zsh/.zcompdump")" == "644" ]] ||
    fail "completion runtime file mode changed"

echo "Oh My Zsh bootstrap configuration passed."
