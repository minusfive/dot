#!/usr/bin/env zsh

set -euo pipefail

local __fixture_dir="$(mktemp -d)"
__fixture_dir="$(realpath "$__fixture_dir")"
trap 'rm -rf -- "$__fixture_dir"' EXIT

local __task_root="$__fixture_dir/task-root"
local __task_scripts="$__task_root/scripts"
local __task_utils="$__task_scripts/utils"
local __task_dir="$__task_scripts/tasks/betterdisplay/settings"
local __task_marker="$__fixture_dir/task-sourced"
mkdir -p "$__task_utils" "$__task_dir" "$__task_root/home/.config/BetterDisplay"
cp scripts/utils/filesystem.zsh "$__task_utils/filesystem.zsh"
cp scripts/tasks/betterdisplay/settings/export.zsh "$__task_dir/export.zsh"
cp scripts/tasks/betterdisplay/settings/import.zsh "$__task_dir/import.zsh"
print -r -- 'valid' >| "$__task_root/home/.config/BetterDisplay/config.plist"
print -r -- 'print -r -- sourced >| "$BOUNDARY_TASK_MARKER"' >> "$__task_utils/filesystem.zsh"

__boundary_task_name() {
    print -r -- "betterdisplay:settings:${${1:t}%.zsh}"
}

__expect_boundary_rejection() {
    local __task="$1"
    local __project_root="${2:-}"
    local __output="$__fixture_dir/boundary-output"
    local __task_name="$(__boundary_task_name "$__task")"
    rm -f -- "$__task_marker" "$__output"
    if [[ -n "$__project_root" ]]; then
        if env -u MISE_ENV \
            MISE_PROJECT_ROOT="$__project_root" \
            MISE_TASK_NAME="$__task_name" \
            BOUNDARY_TASK_MARKER="$__task_marker" \
            /bin/zsh "$__task" >| "$__output" 2>&1; then
            print -u2 -- "boundary accepted: $__task ($__project_root)"
            exit 1
        fi
    else
        if env -u MISE_ENV -u MISE_PROJECT_ROOT \
            MISE_TASK_NAME="$__task_name" \
            BOUNDARY_TASK_MARKER="$__task_marker" \
            /bin/zsh "$__task" >| "$__output" 2>&1; then
            print -u2 -- "boundary accepted: $__task (missing root)"
            exit 1
        fi
    fi
    [[ ! -e "$__task_marker" ]] ||
        { print -u2 -- "boundary sourced filesystem utility: $__task"; exit 1; }
}

for __boundary_task in "$__task_dir/export.zsh" "$__task_dir/import.zsh"; do
    __expect_boundary_rejection "$__boundary_task"
    __expect_boundary_rejection "$__boundary_task" "$__task_root/.."
done

local __root_link="$__fixture_dir/root-link"
ln -s "$__task_root" "$__root_link"
for __boundary_task in "$__task_dir/export.zsh" "$__task_dir/import.zsh"; do
    __expect_boundary_rejection "$__boundary_task" "$__root_link"
done
rm "$__root_link"

mv "$__task_utils/filesystem.zsh" "$__task_utils/filesystem.real.zsh"
ln -s filesystem.real.zsh "$__task_utils/filesystem.zsh"
for __boundary_task in "$__task_dir/export.zsh" "$__task_dir/import.zsh"; do
    __expect_boundary_rejection "$__boundary_task" "$__task_root"
done
rm "$__task_utils/filesystem.zsh"
mv "$__task_utils/filesystem.real.zsh" "$__task_utils/filesystem.zsh"

mv "$__task_utils" "$__task_scripts/utils.real"
ln -s utils.real "$__task_utils"
for __boundary_task in "$__task_dir/export.zsh" "$__task_dir/import.zsh"; do
    __expect_boundary_rejection "$__boundary_task" "$__task_root"
done
rm "$__task_utils"
mv "$__task_scripts/utils.real" "$__task_utils"

source scripts/utils/filesystem.zsh
source scripts/utils/application.zsh

[[ "$(filesystem::project_root "$PWD")" == "$PWD" ]] ||
    { print -u2 -- "canonical project root was not resolved"; exit 1; }

local __file="$__fixture_dir/file"
print -r -- content >| "$__file"
filesystem::is_physical_file "$__file" ||
    { print -u2 -- "physical file was not accepted"; exit 1; }
[[ -n "$(filesystem::physical_path "$__file")" ]] ||
    { print -u2 -- "physical file path was not resolved"; exit 1; }
[[ -n "$(filesystem::identity "$__file")" ]] ||
    { print -u2 -- "physical file identity was not returned"; exit 1; }
local __file_identity="$(filesystem::identity "$__file")"
filesystem::identity_matches "$__file" "$__file" "$__file_identity" ||
    { print -u2 -- "matching physical file identity was not accepted"; exit 1; }

ln -s "$__file" "$__fixture_dir/link"
if filesystem::is_physical_file "$__fixture_dir/link"; then
    print -u2 -- "symlinked file was accepted as physical"
    exit 1
fi
if filesystem::identity_matches \
    "$__fixture_dir/link" "$__file" "$__file_identity"; then
    print -u2 -- "symlinked file identity was accepted"
    exit 1
fi

local __temporary_file="$__fixture_dir/known-temp"
print -r -- temporary >| "$__temporary_file"
filesystem::cleanup_known_temp "$__temporary_file" ||
    { print -u2 -- "known temporary file cleanup failed"; exit 1; }
[[ ! -e "$__temporary_file" ]] ||
    { print -u2 -- "known temporary file remained"; exit 1; }

local __application_state=stopped
pgrep() {
    [[ "$__application_state" == running ]]
}
open() {
    __application_state=running
}
sleep() {
    :
}

application::wait_for_state ExampleApp stopped 1 ||
    { print -u2 -- "stopped application state was not detected"; exit 1; }
__application_state=running
application::wait_for_state ExampleApp running 1 ||
    { print -u2 -- "running application state was not detected"; exit 1; }
application::restart ExampleApp ExampleApp 1 ||
    { print -u2 -- "application restart did not complete"; exit 1; }

echo "Script utility tests passed."
