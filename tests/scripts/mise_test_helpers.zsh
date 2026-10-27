#!/usr/bin/env zsh

set -euo pipefail

typeset -g __test_dir="$(realpath "$(dirname "$0")")"
typeset -g __root_dir="$(dirname "$(dirname "$__test_dir")")"
typeset -g __test_mise_repository="${TEST_MISE_REPOSITORY:-$__root_dir}"
typeset -g __test_mise_config_dir="${TEST_MISE_CONFIG_DIR:-$__root_dir/home/.config/mise}"

fail() {
    echo "FAIL: $1"
    exit 1
}

test_fixture_dir() {
    local __name="$1"
    local __path="$__root_dir/.test-${__name}-${PPID}-$$-${RANDOM}${RANDOM}"
    mkdir "$__path" || fail "could not create fixture directory: $__path"
    print -r -- "$__path"
}

module_filename() {
    local __module="$1"
    case "$__module" in
        discord|opencode|softraid|whatsapp)
            print -r -- "${__module}.personal.toml"
            ;;
        *)
            print -r -- "${__module}.toml"
            ;;
    esac
}

assert_module_package() {
    local __module="$1"
    local __package="$2"
    local __module_file="$(module_filename "$__module")"
    local __config="home/.config/mise/conf.d/$__module_file"
    [[ -f "$__config" ]] || fail "missing $__config"
    grep -q "\"$__package\" = \"latest\"" "$__config" ||
        fail "$__package is missing from $__config"
    local __profile_config
    for __profile in work personal; do
        __profile_config="$(
            env MISE_ENV="$__profile" \
                MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
                mise -C "$__test_mise_repository" config ls --no-truncate
        )"
        print -r -- "$__profile_config" | grep -qF "$__module_file" ||
            fail "$__module must be selected by the $__profile profile"
    done
}

assert_tool_module() {
    local __module="$1"
    local __declaration="$2"
    local __module_file="$(module_filename "$__module")"
    local __config="home/.config/mise/conf.d/$__module_file"
    local __control_plane="home/.config/mise/conf.d/mise.toml"
    [[ -f "$__config" ]] || fail "missing $__config"
    grep -qF "[tools]" "$__config" || fail "tools section is missing from $__config"
    grep -qF "$__declaration" "$__config" ||
        fail "$__declaration is missing from $__config"
    grep -qF "\"mise/config/mise/conf.d/$__module_file\"" "$__control_plane" ||
        fail "control-plane module does not deploy $__module_file"
    grep -qF "target = \"{{ mise_config_dir }}/conf.d/$__module_file\"" "$__control_plane" ||
        fail "control-plane module target does not follow MISE_CONFIG_DIR for $__module_file"
    local __profile_config
    for __profile in work personal; do
        __profile_config="$(
            env MISE_ENV="$__profile" \
                MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
                mise -C "$__test_mise_repository" config ls --no-truncate
        )"
        print -r -- "$__profile_config" | grep -qF "$__module_file" ||
            fail "$__module must be selected by the $__profile profile"
    done
}

assert_module_repo() {
    local __module="$1"
    local __url="$2"
    local __target="$3"
    local __ref="${4:-}"
    local __module_file="$(module_filename "$__module")"
    local __config="home/.config/mise/conf.d/$__module_file"
    local __control_plane="home/.config/mise/conf.d/mise.toml"
    [[ -f "$__config" ]] || fail "missing $__config"
    grep -qF "[bootstrap.repos]" "$__config" || fail "repository bootstrap section is missing from $__config"
    grep -qF "$__url" "$__config" || fail "$__url is missing from $__config"
    grep -qF "\"mise/config/mise/conf.d/$__module_file\"" "$__control_plane" ||
        fail "control-plane module does not deploy $__module_file"
    grep -qF "target = \"{{ mise_config_dir }}/conf.d/$__module_file\"" "$__control_plane" ||
        fail "control-plane module target does not follow MISE_CONFIG_DIR for $__module_file"
    for __profile in work personal; do
        local __profile_config="$(
            env MISE_ENV="$__profile" \
                MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
                mise -C "$__test_mise_repository" config ls --no-truncate
        )"
        print -r -- "$__profile_config" | grep -qF "$__module_file" ||
            fail "$__module must be selected by the $__profile profile"
    done
    [[ -d "$__target" && ! -L "$__target" ]] || fail "repository target is not a physical directory: $__target"
    local __origin="$(git -C "$__target" config --get remote.origin.url)"
    [[ "${__origin%.git}" == "${__url%.git}" ]] ||
        fail "repository target origin is incorrect: $__target"
    if [[ -n "$__ref" ]]; then
        [[ "$(git -C "$__target" symbolic-ref --short HEAD)" == "$__ref" ]] ||
            fail "repository target is not on $__ref: $__target"
    fi
}

assert_personal_module_package() {
    local __module="$1"
    local __package="$2"
    local __module_file="$(module_filename "$__module")"
    local __config="home/.config/mise/conf.d/$__module_file"
    [[ -f "$__config" ]] || fail "missing $__config"
    grep -q "\"$__package\" = \"latest\"" "$__config" ||
        fail "$__package is missing from $__config"
    local __personal_config
    local __work_config
    __personal_config="$(
        env MISE_ENV=personal \
            MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
            mise -C "$__test_mise_repository" config ls --no-truncate
    )"
    print -r -- "$__personal_config" | grep -qF "$__module_file" ||
        fail "$__module must be selected by the personal profile"
    __work_config="$(
        env MISE_ENV=work \
            MISE_CONFIG_DIR="$__test_mise_config_dir" MISE_ENV_CONF_D=true \
            mise -C "$__test_mise_repository" config ls --no-truncate
    )"
    if print -r -- "$__work_config" | grep -qF "$__module_file"; then
        fail "$__module must not be selected by the work profile"
    fi
}

cd "$__root_dir"
