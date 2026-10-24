#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing Copilot bootstrap configuration..."

local __config="home/.config/mise/conf.d/copilot.toml"
local __lsp_config="home/.copilot/lsp-config.json"
local __settings="home/.copilot/settings.json"
[[ -f "$__config" ]] || fail "missing $__config"
[[ -f "home/AGENTS.md" ]] || fail "missing shared global instructions"
[[ -f "$__lsp_config" && ! -L "$__lsp_config" ]] || fail "missing regular Copilot LSP config source"
[[ -f "$__settings" && ! -L "$__settings" ]] || fail "missing regular Copilot settings source"
[[ -x "home/.copilot/statusline-context.sh" ]] || fail "missing executable Copilot statusline"

grep -qF '"~/.copilot/copilot-instructions.md" = { source = "~/dev/personal/dot/home/AGENTS.md", mode = "symlink" }' "$__config" ||
    fail "Copilot instructions ownership is missing"
grep -qF '"~/.copilot/lsp-config.json/mise" = { source = "~/dev/personal/dot/home/.copilot/lsp-config.json", merge = true }' "$__config" ||
    fail "Copilot LSP config merge is missing"
grep -qF '"~/.copilot/settings.json/safe-settings" = { source = "~/dev/personal/dot/home/.copilot/settings.json", merge = true }' "$__config" ||
    fail "Copilot safe settings merge is missing"
grep -qF '"~/.copilot/statusline-context.sh" = { source = "~/dev/personal/dot/home/.copilot/statusline-context.sh", mode = "symlink" }' "$__config" ||
    fail "Copilot statusline source is missing"
if [[ -e home/.config/mise/conf.d/bootstrap-ai.toml ]] &&
    grep -qF '"~/.copilot"' home/.config/mise/conf.d/bootstrap-ai.toml; then
    fail "legacy AI declaration still owns ~/.copilot"
fi
grep -qF '"~/.config/mise/conf.d/copilot.toml"' home/.config/mise/conf.d/mise.toml ||
    fail "mise control-plane module does not deploy copilot.toml"
for __profile in work personal; do
    local __profile_config="$(
        env MISE_ENV="$__profile" \
            MISE_CONFIG_DIR="$__root_dir/home/.config/mise" MISE_ENV_CONF_D=true \
            mise -C "$__root_dir" config ls --no-truncate
    )"
    print -r -- "$__profile_config" | grep -qF "copilot.toml" ||
        fail "Copilot module must be selected by the $__profile profile"
done

local __settings_keys
__settings_keys="$(jq -cS 'keys' "$__settings")"
[[ "$__settings_keys" == '["colorMode","contextTier","effortLevel","experimental","footer","renderMarkdown","screenReader","showReasoning","theme"]' ]] ||
    fail "Copilot settings source must contain exactly the nine approved keys"
if jq -e 'keys | any(. == "model" or . == "allowedUrls" or . == "includeCoAuthoredBy" or . == "statusLine")' "$__settings" >/dev/null; then
    fail "excluded Copilot settings are tracked"
fi

zsh -n home/.copilot/statusline-context.sh || fail "Copilot statusline has syntax errors"
[[ ! -e home/.copilot/copilot-instructions.md ]] || fail "deleted source-tree Copilot alias remains"

local __fixture_root="$__root_dir/tests/.copilot-merge-fixture.$$"
local __fixture_home="$__fixture_root/home"
local __fixture_config="$__fixture_root/mise-config"
local __fixture_data="$__fixture_root/mise-data"
local __fixture_xdg="$__fixture_root/xdg-config"
local __fixture_state="$__fixture_root/mise-state"
local __fixture_repo="$__fixture_home/dev/personal/dot"
local __fixture_target="$__fixture_home/.copilot/settings.json"
local __fixture_lsp_target="$__fixture_home/.copilot/lsp-config.json"
local __live_settings="$HOME/.copilot/settings.json"
local __live_lsp_config="$HOME/.copilot/lsp-config.json"
local __live_mise_config="$HOME/.config/mise"
local __live_workspace_root="$(dirname "$__root_dir")"
local __live_before="absent"
local __live_lsp_before="absent"
if [[ -e "$__live_settings" ]]; then
    __live_before="$(shasum "$__live_settings")"
fi
if [[ -e "$__live_lsp_config" ]]; then
    __live_lsp_before="$(shasum "$__live_lsp_config")"
fi
trap 'rm -rf -- "${__fixture_root:-}"' EXIT

mkdir -p "$__fixture_home/.copilot" "$__fixture_repo/home/.copilot" "$__fixture_config/conf.d" "$__fixture_data" "$__fixture_xdg" "$__fixture_state"
cp "$__lsp_config" "$__fixture_repo/home/.copilot/lsp-config.json"
cp "$__settings" "$__fixture_repo/home/.copilot/settings.json"
cp home/AGENTS.md "$__fixture_repo/home/AGENTS.md"
cp home/.copilot/statusline-context.sh "$__fixture_repo/home/.copilot/statusline-context.sh"
cp "$__config" "$__fixture_config/conf.d/copilot.toml"
: >"$__fixture_config/config.toml"
cat >"$__fixture_config/miserc.toml" <<'EOF'
env_conf_d = true
env = ["copilot"]
EOF
cat >"$__fixture_target" <<'EOF'
{
  "renderMarkdown": false,
  "screenReader": true,
  "theme": "unmanaged-theme",
  "footer": {
    "showModelEffort": false,
    "unmanagedFooter": "preserve-me"
  },
  "colorMode": "unmanaged-color",
  "experimental": false,
  "showReasoning": true,
  "effortLevel": "low",
  "contextTier": "short_context",
  "model": "unmanaged-model",
  "allowedUrls": ["https://example.test"],
  "includeCoAuthoredBy": false,
  "statusLine": {"type": "unmanaged"},
  "unmanagedTopLevel": {"keep": true}
}
EOF
cat >"$__fixture_lsp_target" <<'EOF'
{
  "lspServers": {
    "mise": {
      "command": "unmanaged-mise",
      "args": ["old"],
      "fileExtensions": {
        ".toml": "old"
      }
    },
    "other": {
      "command": "other-lsp",
      "args": []
    }
  },
  "unmanaged": true
}
EOF

local __excluded_before
__excluded_before="$(jq -cS '{model, allowedUrls, includeCoAuthoredBy, statusLine}' "$__fixture_target")"
local __unmanaged_lsp_before
__unmanaged_lsp_before="$(jq -cS '{other: .lspServers.other, unmanaged}' "$__fixture_lsp_target")"
local __dry_run
__dry_run="$(
    env MISE_ENV=work HOME="$__fixture_home" XDG_CONFIG_HOME="$__fixture_xdg" \
        MISE_DATA_DIR="$__fixture_data" MISE_STATE_DIR="$__fixture_state" \
        MISE_CONFIG_DIR="$__fixture_config" MISE_CONFIG_ROOT="$__fixture_config" \
        MISE_IGNORED_CONFIG_PATHS="$__live_mise_config" \
        MISE_TRUSTED_CONFIG_PATHS="$__live_workspace_root" \
        mise -C "$__fixture_repo" bootstrap --only dotfiles --dry-run 2>&1
)"
print -r -- "$__dry_run" | grep -qF "merge:safe-settings" ||
    fail "Copilot dry run does not report merge:safe-settings"
print -r -- "$__dry_run" | grep -qF "merge:mise" ||
    fail "Copilot dry run does not report merge:mise"
print -r -- "$__dry_run" | grep -qF "copilot-instructions.md" ||
    fail "Copilot dry run does not report the instruction symlink"
print -r -- "$__dry_run" | grep -qF "statusline-context.sh" ||
    fail "Copilot dry run does not report the statusline symlink"
env MISE_ENV=work HOME="$__fixture_home" XDG_CONFIG_HOME="$__fixture_xdg" \
    MISE_DATA_DIR="$__fixture_data" MISE_STATE_DIR="$__fixture_state" \
    MISE_CONFIG_DIR="$__fixture_config" MISE_CONFIG_ROOT="$__fixture_config" \
    MISE_IGNORED_CONFIG_PATHS="$__live_mise_config" \
    MISE_TRUSTED_CONFIG_PATHS="$__live_workspace_root" \
    mise -C "$__fixture_repo" bootstrap --only dotfiles --yes >/dev/null

[[ -f "$__fixture_target" && ! -L "$__fixture_target" ]] ||
    fail "merged Copilot settings target must remain a regular file"
[[ -f "$__fixture_lsp_target" && ! -L "$__fixture_lsp_target" ]] ||
    fail "merged Copilot LSP target must remain a regular file"
local __expected_managed
local __actual_managed
__expected_managed="$(jq -cS 'with_entries(select(.key | IN("renderMarkdown","screenReader","theme","footer","colorMode","experimental","showReasoning","effortLevel","contextTier")))' "$__settings")"
__actual_managed="$(jq -cS 'with_entries(select(.key | IN("renderMarkdown","screenReader","theme","footer","colorMode","experimental","showReasoning","effortLevel","contextTier")))' "$__fixture_target")"
__expected_managed="$(jq -cS 'del(.footer)' <<<"$__expected_managed")"
__actual_managed="$(jq -cS 'del(.footer)' <<<"$__actual_managed")"
[[ "$__actual_managed" == "$__expected_managed" ]] || fail "managed Copilot settings were not applied"
[[ "$(jq -cS '.lspServers.mise' "$__fixture_lsp_target")" == "$(jq -cS '.lspServers.mise' "$__lsp_config")" ]] ||
    fail "managed Copilot LSP settings were not applied"
jq -e --slurpfile source "$__settings" --slurpfile target "$__fixture_target" \
    'reduce ($source[0].footer | to_entries[]) as $entry (true; . and ($target[0].footer[$entry.key] == $entry.value))' \
    "$__fixture_target" >/dev/null ||
    fail "managed nested footer settings were not applied"
[[ "$(jq -cS '{model, allowedUrls, includeCoAuthoredBy, statusLine}' "$__fixture_target")" == "$__excluded_before" ]] ||
    fail "excluded Copilot settings were changed"
[[ "$(jq -r '.footer.unmanagedFooter' "$__fixture_target")" == "preserve-me" ]] ||
    fail "unmanaged nested footer setting was not preserved"
[[ "$(jq -r '.unmanagedTopLevel.keep' "$__fixture_target")" == "true" ]] ||
    fail "unmanaged top-level setting was not preserved"
[[ "$(jq -cS '{other: .lspServers.other, unmanaged}' "$__fixture_lsp_target")" == "$__unmanaged_lsp_before" ]] ||
    fail "unmanaged Copilot LSP settings were not preserved"
[[ -L "$__fixture_home/.copilot/copilot-instructions.md" ]] ||
    fail "fixture Copilot instructions target is not a symlink"
[[ -L "$__fixture_home/.copilot/statusline-context.sh" && -x "$__fixture_home/.copilot/statusline-context.sh" ]] ||
    fail "fixture Copilot statusline target is not an executable symlink"

if [[ -e "$__live_settings" ]]; then
    [[ "$(shasum "$__live_settings")" == "$__live_before" ]] || fail "live Copilot settings changed"
else
    [[ ! -e "$__live_settings" ]] || fail "live Copilot settings were created"
fi
if [[ -e "$__live_lsp_config" ]]; then
    [[ "$(shasum "$__live_lsp_config")" == "$__live_lsp_before" ]] || fail "live Copilot LSP config changed"
else
    [[ ! -e "$__live_lsp_config" ]] || fail "live Copilot LSP config was created"
fi

echo "Copilot bootstrap configuration passed."
