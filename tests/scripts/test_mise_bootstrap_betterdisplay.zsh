#!/usr/bin/env zsh

set -euo pipefail

source "$(dirname "$0")/mise_test_helpers.zsh"

echo "Testing BetterDisplay package bootstrap configuration..."
assert_module_package betterdisplay brew-cask:betterdisplay

local __module="home/.config/mise/conf.d/module.betterdisplay.toml"
local __control_plane="home/.config/mise/conf.d/module.mise.toml"
local __export_task="home/.config/mise/tasks/betterdisplay/settings/export.zsh"
local __import_task="home/.config/mise/tasks/betterdisplay/settings/import.zsh"

[[ -x "$__export_task" ]] || fail "export task is not executable"
[[ -x "$__import_task" ]] || fail "import task is not executable"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/export.zsh" = { source = "~/dev/personal/dot/home/.config/mise/tasks/betterdisplay/settings/export.zsh", mode = "symlink" }' "$__control_plane" ||
    fail "export task control-plane link is missing"
grep -qF '"~/.config/mise/tasks/betterdisplay/settings/import.zsh" = { source = "~/dev/personal/dot/home/.config/mise/tasks/betterdisplay/settings/import.zsh", mode = "symlink" }' "$__control_plane" ||
    fail "import task control-plane link is missing"

grep -qF '[dotfiles]' "$__module" || fail "BetterDisplay dotfiles declaration is missing"
grep -qF 'mode = "symlink-each"' "$__module" || fail "BetterDisplay ownership mode changed"
grep -qF '[bootstrap.macos.launchd.agents.betterdisplay-settings-export]' "$__module" ||
    fail "BetterDisplay export LaunchAgent declaration is missing"
for __declaration in \
    'program = "~/.local/bin/mise"' \
    'args = ["run", "betterdisplay:settings:export"]' \
    'working_directory = "{{ env.HOME }}/dev/personal/dot"' \
    'environment = { HOME = "{{ env.HOME }}", PATH = "{{ env.PATH }}" }' \
    'start_interval = 60' \
    'run_at_load = true' \
    'throttle_interval = 60' \
    'process_type = "Background"' \
    'stdout_path = "~/Library/Logs/betterdisplay-settings-export.log"' \
    'stderr_path = "~/Library/Logs/betterdisplay-settings-export.err.log"'; do
    grep -qF "$__declaration" "$__module" || fail "missing LaunchAgent declaration: $__declaration"
done
for __forbidden in keep_alive keep_alive_on_failure kickstart; do
    if grep -qF "$__forbidden" "$__module"; then
        fail "forbidden LaunchAgent field remains: $__forbidden"
    fi
done
grep -qF 'MISE_PROJECT_ROOT' scripts/utils/betterdisplay.zsh || fail "repository discovery helper is missing"
grep -qF 'MISE_ORIGINAL_CWD' scripts/utils/betterdisplay.zsh || fail "original cwd fallback is missing"
grep -qF 'plutil -lint' scripts/utils/betterdisplay.zsh || fail "plist validation helper is missing"
grep -qF 'XDG_STATE_HOME' scripts/utils/betterdisplay.zsh || fail "runtime backup path is missing"
grep -qF 'lock_dir="$runtime_dir/lock"' scripts/utils/betterdisplay.zsh || fail "shared lock is missing"
grep -qF 'pid=' scripts/utils/betterdisplay.zsh || fail "lock owner PID metadata is missing"
grep -qF 'start=' scripts/utils/betterdisplay.zsh || fail "lock owner start metadata is missing"
grep -qF 'betterdisplay_process_start' scripts/utils/betterdisplay.zsh || fail "PID reuse safety is missing"
grep -qF 'BETTERDISPLAY_LOCK_STALE_AFTER' scripts/utils/betterdisplay.zsh || fail "stale lock age bound is missing"
grep -qF 'rmdir "$lock_dir"' scripts/utils/betterdisplay.zsh || fail "stale lock cleanup is not narrow"
[[ ! -e scripts/betterdisplay.zsh ]] || fail "legacy BetterDisplay script remains"
if grep -R -qE 'scripts/betterdisplay\.zsh|--display' scripts --exclude='test_*'; then
    fail "legacy BetterDisplay init path remains"
fi
plutil -lint home/.config/BetterDisplay/config.plist >/dev/null || fail "tracked BetterDisplay plist is invalid"

local __launchagent_fixture="$__root_dir/.agents/test-runs/betterdisplay-launchagent-$$"
local __launchagent_home="$__launchagent_fixture/home"
local __launchagent_program="$__launchagent_home/.local/bin/mise"
local __launchagent_log="$__launchagent_fixture/invocation.log"
mkdir -p "${__launchagent_program:h}"
trap 'rm -rf "$__launchagent_fixture"' EXIT
cat > "$__launchagent_program" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$LAUNCHAGENT_LOG"
EOF
chmod 700 "$__launchagent_program"
HOME="$__launchagent_home" LAUNCHAGENT_LOG="$__launchagent_log" \
    "$__launchagent_program" run betterdisplay:settings:export
print -r -- 'run' > "$__launchagent_fixture/expected.log"
print -r -- 'betterdisplay:settings:export' >> "$__launchagent_fixture/expected.log"
diff -u "$__launchagent_fixture/expected.log" "$__launchagent_log" ||
    fail "LaunchAgent program did not receive the declared invocation"
rm -rf "$__launchagent_fixture"
trap - EXIT

echo "BetterDisplay package bootstrap configuration passed."
