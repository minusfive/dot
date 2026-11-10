# GitHub Project Evidence Schema

The current `project-result.v1` result schema and validator require these fields:

- `schema_version`
- `status`
- `live_vs_fixture`
- `mutation_authorized`
- `target`: `host`, `owner`, `repository`, `title`, and `key`
- `comparison_digest`
- `create_intent`: a persisted plan-bound pre-create intent, or `null`
- `durable_create_identity`: the complete response identity, or `null`
- `second_read`: `classification`, `comparison_digest`, and `converged`, or `null`
- `missing_children`
- `failures`
- `partial_failure`
- `partial_project_ids`: each entry has `id` and `number`
- `retry_count`
- `journal_entries`
- `retry_authorized`
- `retry_authorization`: `schema_version`, `authorized`, `current_turn_only`, `owner`, `expires`, and `plan_digest`, or `null`
- `lane_state`
- `secret_status`: `clean` or `detected`
- `redaction_status`: `clean`, `redacted`, or `failed`
- `secret_redaction_status`
- `second_read_consistency`
- `inventory`: open/closed page counts, cursor lists, and explicit terminated `open_termination` and `closed_termination` records

The validator also accepts these optional nested fields with exact shapes:

- `accepted_plan`: `path` and `sha256`
- `authorization`: `path`, `authorized`, `expires`, and `delivery_authorized`
- `blockers`
- `remaining_scope`
- `branch_worktree_state`: `branch`, `dirty_paths_preserved`, and `excluded_files_unchanged`
- `live_vs_fixture_classification`: `live` and `fixture`

`retry_count` is not authorization. Load a separate `retry-authorization.v1` file for every authorized retry. Its plan digest must match the current plan. Durable create evidence must include the plan digest, client mutation ID, pre-create intent timestamp, response timestamp, at least one provider request or response identity, Project node ID and number, and response digest before a retry is considered. A persisted intent blocks a later process from creating again until a fresh complete open-and-closed inventory reconciles the outcome.

Record complete open and closed inventory scope and pagination termination. Treat missing durable identity or incomplete inventory evidence as a hard failure.

Record default-board-view evidence in comparison or mutation-journal files. Include exactly one default marker, the Project node ID, the view node ID, `BOARD_LAYOUT`, the root Project URL, and the canonical view URL. Do not add these fields to `project-result.v1` unless its schema and validator define them.

Redact tokens, cookies, authorization headers, signed query values, and raw sensitive response bodies. Store a digest and a redaction marker instead of unsafe response content. Record safe command paths and result summaries.

Do not report `ready` unless the final second read proves exact identity and child convergence. Distinguish `live` and `fixture` evidence in every result.
