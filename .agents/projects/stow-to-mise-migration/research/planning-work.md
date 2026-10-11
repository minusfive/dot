# Migration planning work

This document tracks planning work. It is not an execution story list.

Execution cannot start until every required planning item is complete and the
pending-decisions document has no pending decision.

## Work items

### `PLAN-01`: Complete inventories and planning artifacts

- Status: `complete`
- Evidence:
  - 29 module inventories exist.
  - All inventories use the common template.
  - The artifact validator passes.
  - The prompt render test passes.
- Exit condition: complete.

### `PLAN-02`: Resolve pending migration decisions

- Status: `complete`
- Document: `.agents/projects/stow-to-mise-migration/research/pending-decisions.md`
- Owner: user and planning agent
- Evidence:
  - `DEC-mise-control-plane-transition-mechanism`: the mise control-plane
    story retains the temporary bridge.
  - `DEC-focused-test-surface`: each module story has one focused test path,
    and aggregate checks do not replace the module test.
  - `DEC-tmux-runtime-classification`: the tmux inventory classifies TPM as an
    external, unmanaged runtime dependency and defers plugin-load validation
    until TPM is installed.
- Exit condition: every decision has a recorded resolution and no record has
  status `pending`.

### `PLAN-03`: Complete the pre-execution baseline packet

- Status: `pending`
- Templates:
  - `.agents/projects/stow-to-mise-migration/templates/baseline-record.md`
  - `.agents/projects/stow-to-mise-migration/templates/approval-record.md`
- Scope:
  - record `mise` and Stow versions;
  - record current status and dry runs;
  - save tracked, ignored, and untracked manifests;
  - save complete target manifests; and
  - record pre-existing differences.
- Exit condition: the baseline record is complete and every mutation story has
  an approval record with an approved scope.

### `PLAN-04`: Approve the execution roadmap

- Status: `pending`
- Scope:
  - review the resolved pending decisions;
  - review the canonical reference hierarchy;
  - confirm that every execution story is deterministic;
  - confirm that dependencies and strict sequential ordering are valid; and
  - confirm that the validator and workflow enforce the next-story gate; and
  - approve the exact roadmap path for execution.
- Exit condition: the user approves
  `plans/migration-roadmap-v1.md` for execution.

## Planning rules

- Do not add planning discovery or decision steps to execution stories.
- Record new questions in `pending-decisions.md`.
- Resolve a question before adding its final instruction to the roadmap.
- Keep execution approvals separate from planning status.
- Do not apply migration changes from this document.
