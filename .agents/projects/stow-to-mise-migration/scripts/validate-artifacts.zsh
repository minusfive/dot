#!/usr/bin/env zsh

set -euo pipefail

typeset -r __script_dir="$(realpath "$(dirname "$0")")"
typeset -r __project_dir="$(dirname "$__script_dir")"

function normalize_dependencies {
    local __dependencies="${1:-}"
    local __normalized="$(print -r -- "$__dependencies" | tr -d '`" ')"

    if [[ -z "$__normalized" || "$__normalized" == "none" ]]; then
        print "none"
        return
    fi

    print -r -- "$__normalized" | tr ',' '\n' | sort | paste -sd, -
}

function normalize_focused_test_reference {
    local __reference="${1:-}"
    __reference="${__reference#zsh }"
    __reference="${__reference#./}"
    print -r -- "$__reference"
}

function read_focused_test_reference {
    local __document="$1"
    sed -n '/^- Focused test:/,/^- Target smoke test:/p' "$__document" |
        sed -n 's/^[[:space:]]*-[[:space:]]*`\([^`]*\)`.*/\1/p' |
        head -n 1
}

function validate_decision_records {
    local __planning_work="$1"
    local __pending_decisions="$2"
    local __plan="$3"
    local __inventory_dir="$4"
    local __pending_key_count __pending_status_count __plan02_block __plan02_status
    local __decision
    local -a __resolved_decisions

    __pending_key_count="$(grep -cF -- '**Decision key:**' "$__pending_decisions" || true)"
    __pending_status_count="$(grep -cF -- '**Status:** `pending`' "$__pending_decisions" || true)"

    if grep -qF -- '**Status:** `resolved`' "$__pending_decisions" ||
       grep -qF -- '**Resolution:**' "$__pending_decisions"; then
        print -u2 "Resolved decisions must be removed from the pending decisions file: $__pending_decisions"
        exit 1
    fi

    if (( __pending_key_count == 0 )); then
        grep -qF -- "No pending decisions." "$__pending_decisions" || {
            print -u2 "Pending decisions file has no records or explicit empty state: $__pending_decisions"
            exit 1
        }
        if grep -qF -- '**Status:**' "$__pending_decisions" ||
           grep -qF -- '**Resolution:**' "$__pending_decisions"; then
            print -u2 "Pending decisions file contains a resolved record: $__pending_decisions"
            exit 1
        fi
    else
        (( __pending_key_count == __pending_status_count )) || {
            print -u2 "Every pending decision must have Status: pending: $__pending_decisions"
            exit 1
        }
    fi

    __plan02_block="$(sed -n '/^### `PLAN-02`:/,/^### `/p' "$__planning_work")"
    __plan02_status="$(print -r -- "$__plan02_block" | sed -n 's/^- Status: `\([^`]*\)`.*/\1/p' | head -n 1)"
    if (( __pending_key_count == 0 )); then
        [[ "$__plan02_status" == "complete" ]] || {
            print -u2 "PLAN-02 must be complete when no pending decisions remain: $__planning_work"
            exit 1
        }
    else
        [[ "$__plan02_status" == "pending" ]] || {
            print -u2 "PLAN-02 must remain pending while decisions remain unresolved: $__planning_work"
            exit 1
        }
    fi

    __resolved_decisions=("${(@f)$(print -r -- "$__plan02_block" | grep -oE 'DEC-[[:alnum:]-]+' | sort -u)}")
    for __decision in "${__resolved_decisions[@]}"; do
        if ! grep -RqsF -- "$__decision" "$__plan" "$__inventory_dir"; then
            print -u2 "Resolved decision is not encoded in the roadmap or an inventory: $__decision"
            exit 1
        fi
        if grep -qF -- "$__decision" "$__pending_decisions"; then
            print -u2 "Resolved decision remains in the pending decisions file: $__decision"
            exit 1
        fi
    done
}

function main {
    local __inventory_dir="$__project_dir/research/inventories"
    local __approval_dir="$__project_dir/research/approvals"
    local __planning_work="$__project_dir/research/planning-work.md"
    local __pending_decisions="$__project_dir/research/pending-decisions.md"
    local __registry="$__project_dir/module-registry.toml"
    local __template="$__project_dir/templates/module-inventory.md"
    local __plan="$__project_dir/plans/migration-roadmap-v1.md"

    [[ -f "$__template" ]] || {
        print -u2 "Missing inventory template: $__template"
        exit 1
    }
    [[ -f "$__plan" ]] || {
        print -u2 "Missing plan: $__plan"
        exit 1
    }
    [[ -f "$__registry" ]] || {
        print -u2 "Missing module registry: $__registry"
        exit 1
    }
    [[ -f "$__planning_work" ]] || {
        print -u2 "Missing planning work record: $__planning_work"
        exit 1
    }
    [[ -f "$__pending_decisions" ]] || {
        print -u2 "Missing pending decisions record: $__pending_decisions"
        exit 1
    }
    validate_decision_records "$__planning_work" "$__pending_decisions" "$__plan" "$__inventory_dir"
    if grep -Eq 'Sequence (group|position)' "$__template"; then
        print -u2 "Inventory template must not contain execution-order metadata: $__template"
        exit 1
    fi
    if grep -Eq '^(group|position) = ' "$__registry"; then
        print -u2 "Registry must not contain execution-order metadata: $__registry"
        exit 1
    fi

    local -a __required_sections=(
        "## Metadata"
        "## Scope manifest"
        "## Local and runtime inventory"
        "## Ownership and cutover"
        "## Coupling"
        "## Validation"
        "## Rollback"
        "## Findings and decisions"
    )
    local -a __required_table_patterns=(
        '^\|[[:space:]]*Source path[[:space:]]*\|[[:space:]]*Tracked[[:space:]]*\|[[:space:]]*Ignored[[:space:]]*\|[[:space:]]*Current owner[[:space:]]*\|[[:space:]]*Current target[[:space:]]*\|[[:space:]]*Target disposition[[:space:]]*\|[[:space:]]*New source path[[:space:]]*\|[[:space:]]*New target[[:space:]]*\|[[:space:]]*New mode[[:space:]]*\|[[:space:]]*Notes[[:space:]]*\|$'
        '^\|[[:space:]]*Path[[:space:]]*\|[[:space:]]*Exists[[:space:]]*\|[[:space:]]*Tracked[[:space:]]*\|[[:space:]]*Ignored[[:space:]]*\|[[:space:]]*Current location[[:space:]]*\|[[:space:]]*Active use evidence[[:space:]]*\|[[:space:]]*Classification[[:space:]]*\|[[:space:]]*Required action[[:space:]]*\|[[:space:]]*Runtime destination[[:space:]]*\|[[:space:]]*Metadata to preserve[[:space:]]*\|[[:space:]]*Secret or sensitive data[[:space:]]*\|$'
    )

    local __file __section __table_pattern
    local -a __files=("$__inventory_dir"/*.md(N))
    (( ${#__files} > 0 )) || {
        print -u2 "No inventory files found in $__inventory_dir"
        exit 1
    }

    for __file in "${__files[@]}"; do
        [[ "$(head -n 1 "$__file")" == "# Module Inventory: "* ]] || {
            print -u2 "Invalid inventory title: $__file"
            exit 1
        }
        if grep -Eq '^- Sequence (group|position): ' "$__file"; then
            print -u2 "Inventory must not contain execution-order metadata: $__file"
            exit 1
        fi

        for __section in "${__required_sections[@]}"; do
            grep -qF "$__section" "$__file" || {
                print -u2 "Missing section '$__section' in $__file"
                exit 1
            }
        done
        for __table_pattern in "${__required_table_patterns[@]}"; do
            grep -Eq "$__table_pattern" "$__file" || {
                print -u2 "Missing required inventory table in $__file"
                exit 1
            }
        done

        grep -qF -- "- Approval state: \`pending\`" "$__file" || {
            print -u2 "Approval state must remain pending: $__file"
            exit 1
        }
        grep -qF -- "- Inventory status: \`complete\`" "$__file" || {
            print -u2 "Inventory is not complete: $__file"
            exit 1
        }
    done

    local -a __module_keys=("${(@f)$(awk -F '"' '/^key = / {print $2}' "$__registry")}")
    (( ${#__module_keys} > 0 )) || {
        print -u2 "No modules found in $__registry"
        exit 1
    }

    grep -qF -- "## Strict sequencing" "$__plan" || {
        print -u2 "Plan is missing the strict sequencing section: $__plan"
        exit 1
    }
    grep -qF -- "The module story sections below define the strict execution order." "$__plan" || {
        print -u2 "Plan does not define strict story order: $__plan"
        exit 1
    }
    grep -qF -- "Do not run parallel jobs or" "$__plan" || {
        print -u2 "Plan does not prohibit parallel migration work: $__plan"
        exit 1
    }

    local -a __plan_story_numbers=("${(@f)$(sed -n 's/^## \([0-9][0-9]*\)\. Story `.*/\1/p' "$__plan")}")
    local -a __plan_story_ids=("${(@f)$(sed -n 's/^## [0-9][0-9]*\. Story `\([^`]*\)`.*/\1/p' "$__plan")}")
    (( ${#__plan_story_ids} == ${#__module_keys} + 1 )) || {
        print -u2 "Plan story count does not match the module registry plus MIG-90: $__plan"
        exit 1
    }
    (( ${#__plan_story_numbers} == ${#__plan_story_ids} )) || {
        print -u2 "Every roadmap story must have an integer sequence prefix: $__plan"
        exit 1
    }
    local __plan_index
    for (( __plan_index = 1; __plan_index <= ${#__plan_story_numbers}; __plan_index++ )); do
        [[ "${__plan_story_numbers[$__plan_index]}" == "$__plan_index" ]] || {
            print -u2 "Roadmap story prefixes must be sequential integers: $__plan"
            exit 1
        }
    done
    [[ "${__plan_story_ids[-1]}" == "MIG-90" ]] || {
        print -u2 "MIG-90 must be the final roadmap story: $__plan"
        exit 1
    }

    local __plan_story_id __plan_story_count __story_id
    for __plan_story_id in "${__plan_story_ids[@]}"; do
        __plan_story_count="$(print -rl -- "${__plan_story_ids[@]}" | grep -Fxc -- "$__plan_story_id")"
        (( __plan_story_count == 1 )) || {
            print -u2 "Roadmap story appears more than once: $__plan_story_id"
            exit 1
        }
    done

    for __story_id in "${(@f)$(awk -F '"' '/^story = / {print $2}' "$__registry")}"; do
        [[ "$(print -rl -- "${__plan_story_ids[@]}" | grep -Fxc -- "$__story_id")" == 1 ]] || {
            print -u2 "Registry story is missing or duplicated in the roadmap: $__story_id"
            exit 1
        }
    done

    local __module_key __story_block __story_section
    local __registry_dependency_line __registry_dependencies
    local __plan_dependencies __inventory_dependencies
    local -a __required_story_sections=(
        "### Metadata"
        "### Description"
        "### Steps"
        "### Acceptance checks"
        "### Rollback and mitigation"
    )
    for __module_key in "${__module_keys[@]}"; do
        local __inventory="$__inventory_dir/$__module_key.md"
        [[ -f "$__inventory" ]] || {
            print -u2 "Missing inventory for module: $__module_key"
            exit 1
        }
        grep -qF -- "- Module key: \`$__module_key\`" "$__inventory" || {
            print -u2 "Inventory module key does not match its path: $__inventory"
            exit 1
        }
        __story_id="MIG-MODULE-$__module_key"
        __story_block="$(sed -n "/^## [0-9][0-9.]*\. Story \`$__story_id\`:/,/^## [0-9]/p" "$__plan")"
        if ! print -r -- "$__story_block" | grep -qF -- "Inventory: \`.agents/projects/stow-to-mise-migration/research/inventories/$__module_key.md\`"; then
            print -u2 "Plan story has no matching inventory reference: $__story_id"
            exit 1
        fi
        for __story_section in "${__required_story_sections[@]}"; do
            if ! print -r -- "$__story_block" | grep -qF -- "$__story_section"; then
                print -u2 "Plan story is missing '$__story_section': $__story_id"
                exit 1
            fi
        done

        __registry_dependency_line="$(
            awk -v module_key="$__module_key" '
                $0 == "key = \"" module_key "\"" { in_module = 1; next }
                in_module && /^key = / { exit }
                in_module && /^dependencies = / { print; exit }
            ' "$__registry"
        )"
        __plan_dependencies="$(print -r -- "$__story_block" | sed -n 's/^- Dependencies: //p' | head -n 1)"
        __inventory_dependencies="$(sed -n 's/^- Dependencies: //p' "$__inventory" | head -n 1)"

        if [[ -z "$__registry_dependency_line" || -z "$__plan_dependencies" || -z "$__inventory_dependencies" ]]; then
            print -u2 "Missing dependency metadata for module: $__module_key"
            exit 1
        fi

        __registry_dependencies="$(print -r -- "$__registry_dependency_line" | sed -E 's/^dependencies = \[(.*)\]$/\1/')"
        __registry_dependencies="$(normalize_dependencies "$__registry_dependencies")"
        __plan_dependencies="$(normalize_dependencies "$__plan_dependencies")"
        __inventory_dependencies="$(normalize_dependencies "$__inventory_dependencies")"

        if [[ "$__registry_dependencies" != "$__plan_dependencies" || "$__registry_dependencies" != "$__inventory_dependencies" ]]; then
            print -u2 "Dependency graph mismatch for $__module_key:"
            print -u2 "  registry:  $__registry_dependencies"
            print -u2 "  roadmap:   $__plan_dependencies"
            print -u2 "  inventory: $__inventory_dependencies"
            exit 1
        fi
    done

    local __final_story_block
    __final_story_block="$(sed -n '/^## 30\. Story `MIG-90`:/,/^## [0-9]/p' "$__plan")"
    for __story_section in "${__required_story_sections[@]}"; do
        if ! print -r -- "$__final_story_block" | grep -qF -- "$__story_section"; then
            print -u2 "Plan is missing '$__story_section': MIG-90"
            exit 1
        fi
    done

    local -a __shared_stories=(MIG-90)
    local -a __story_ids=("${(@f)$(awk -F '"' '/^story = / {print $2}' "$__registry")}")
    local __approval __approval_story __approval_module __approval_inventory
    local __approval_state __final_decision __line
    local __approval_focused_test __inventory_focused_test __inventory_path
    local __registry_key="" __registry_story=""
    typeset -A __registry_module_for_story
    while IFS= read -r __line; do
        case "$__line" in
            'key = "'*)
                __registry_key="${__line#key = \"}"
                __registry_key="${__registry_key%\"}"
                ;;
            'story = "'*)
                __registry_story="${__line#story = \"}"
                __registry_story="${__registry_story%\"}"
                __registry_module_for_story[$__registry_story]="$__registry_key"
                ;;
        esac
    done < "$__registry"

    for __approval in "${__shared_stories[@]}" "${__story_ids[@]}"; do
        [[ -f "$__approval_dir/$__approval.md" ]] || {
            print -u2 "Missing approval record: $__approval"
            exit 1
        }
        __approval_story="$(sed -n 's/^- Story key: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
        [[ "$__approval_story" == "$__approval" ]] || {
            print -u2 "Approval story key does not match filename: $__approval"
            exit 1
        }

        if [[ "$__approval" == "MIG-90" ]]; then
            __approval_module="$(sed -n 's/^- Module key: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
            __approval_inventory="$(sed -n 's/^- Inventory: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
            [[ "$__approval_module" == "shared" && "$__approval_inventory" == "none" ]] || {
                print -u2 "Invalid shared approval identity: $__approval"
                exit 1
            }
        else
            __approval_module="$(sed -n 's/^- Module key: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
            __approval_inventory="$(sed -n 's/^- Inventory: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
            [[ "$__approval_module" == "${__registry_module_for_story[$__approval]}" ]] || {
                print -u2 "Approval module does not match registry: $__approval"
                exit 1
            }
            [[ "$__approval_inventory" == ".agents/projects/stow-to-mise-migration/research/inventories/$__approval_module.md" ]] || {
                print -u2 "Approval inventory does not match module: $__approval"
                exit 1
            }
            __inventory_path="$__project_dir/research/inventories/$__approval_module.md"
            __approval_focused_test="$(sed -n 's/^- Focused test: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
            __inventory_focused_test="$(read_focused_test_reference "$__inventory_path")"
            [[ -n "$__approval_focused_test" && -n "$__inventory_focused_test" ]] || {
                print -u2 "Focused test reference is missing: $__approval"
                exit 1
            }
            __approval_focused_test="$(normalize_focused_test_reference "$__approval_focused_test")"
            __inventory_focused_test="$(normalize_focused_test_reference "$__inventory_focused_test")"
            [[ "$__approval_focused_test" == "$__inventory_focused_test" ]] || {
                print -u2 "Focused test mismatch for $__approval:"
                print -u2 "  approval:  $__approval_focused_test"
                print -u2 "  inventory: $__inventory_focused_test"
                exit 1
            }
        fi
        __approval_state="$(sed -n 's/^- Approval state: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
        __final_decision="$(sed -n 's/^- Final decision: `\([^`]*\)`.*/\1/p' "$__approval_dir/$__approval.md")"
        case "$__approval_state" in
            pending)
                [[ "$__final_decision" == "pending" ]] || {
                    print -u2 "Pending approval has an invalid final decision: $__approval"
                    exit 1
                }
                ;;
            approved)
                [[ "$__final_decision" == "approved for execution" ]] || {
                    print -u2 "Approved record has an invalid final decision: $__approval"
                    exit 1
                }
                ;;
            *)
                print -u2 "Approval record has an invalid state: $__approval"
                exit 1
                ;;
        esac
    done

    print "Migration artifact validation passed."
}

main "$@"
