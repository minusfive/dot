#!/usr/bin/env bun
//MISE description="Validate gh:project plan or result JSON"
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE flag "--schema <schema>" help="Schema contract: plan-v20 or result-v20"
//USAGE flag "--input <path>" help="JSON file to validate"

import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const schema = (process.env.usage_schema ?? "").trim();
const input = (process.env.usage_input ?? "").trim();
const requiredLanes = ["Blocked", "Todo", "Research", "Implement", "Validate", "Critique", "Done"];

function fail(message: string): never {
  throw new Error(message);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function stringValue(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim() === "") fail(`${name} must be a non-empty string`);
  return value.trim();
}

function positiveInteger(value: unknown, name: string): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) fail(`${name} must be a positive integer`);
  return value as number;
}

function arrayValue(value: unknown, name: string): unknown[] {
  if (!Array.isArray(value)) fail(`${name} must be an array`);
  return value;
}

function unique(values: string[], name: string): void {
  if (new Set(values).size !== values.length) fail(`${name} must contain unique values`);
}

function exactKeys(value: Record<string, unknown>, allowed: string[], name: string): void {
  const unexpected = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unexpected.length > 0) fail(`${name} contains unexpected fields: ${unexpected.join(",")}`);
}

function sha256Value(value: unknown, name: string): string {
  const digest = stringValue(value, name);
  if (!/^[a-f0-9]{64}$/.test(digest)) fail(`${name} must be a SHA-256 digest`);
  return digest;
}

function stringArray(value: unknown, name: string): string[] {
  return arrayValue(value, name).map((entry, index) => stringValue(entry, `${name}[${index}]`));
}

function targetValue(value: unknown, name: string): Record<string, string> {
  if (!isObject(value)) fail(`${name} must be an object`);
  exactKeys(value, ["host", "owner", "repository", "title", "key"], name);
  const host = stringValue(value.host, `${name}.host`).toLowerCase();
  const owner = stringValue(value.owner, `${name}.owner`).toLowerCase();
  const repository = stringValue(value.repository, `${name}.repository`).toLowerCase();
  const title = stringValue(value.title, `${name}.title`);
  const key = stringValue(value.key, `${name}.key`);
  if (host !== "github.com") fail(`${name}.host must be github.com`);
  if (key !== `${owner}/${repository}:${title}`) fail(`${name}.key does not match target identity`);
  return { host, owner, repository, title, key };
}

function validatePlan(value: Record<string, unknown>): void {
  exactKeys(value, ["schema_version", "target", "lanes", "issues", "dependencies", "required_labels"], "plan");
  if (value.schema_version !== "gh-project-plan.v20") fail("expected schema_version gh-project-plan.v20");
  const target = targetValue(value.target, "target");
  const lanes = arrayValue(value.lanes, "lanes").map((lane, index) => stringValue(lane, `lanes[${index}]`));
  unique(lanes, "lanes");
  if (JSON.stringify(lanes) !== JSON.stringify(requiredLanes))
    fail("lanes must contain exactly the seven required status lanes");
  const issues = arrayValue(value.issues, "issues");
  if (issues.length === 0) fail("issues must not be empty");
  const issueNumbers: number[] = [];
  const issueKeys: string[] = [];
  const issueLabels = new Set<string>();
  for (const [index, raw] of issues.entries()) {
    if (!isObject(raw)) fail(`issues[${index}] must be an object`);
    exactKeys(raw, ["number", "key", "labels", "node_id", "label_node_ids"], `issues[${index}]`);
    const number = positiveInteger(raw.number, `issues[${index}].number`);
    const key = stringValue(raw.key, `issues[${index}].key`);
    const labels = arrayValue(raw.labels, `issues[${index}].labels`).map((label, labelIndex) =>
      stringValue(label, `issues[${index}].labels[${labelIndex}]`),
    );
    if (raw.node_id !== undefined) stringValue(raw.node_id, `issues[${index}].node_id`);
    if (raw.label_node_ids !== undefined) {
      if (!isObject(raw.label_node_ids)) fail(`issues[${index}].label_node_ids must be an object`);
      for (const [label, nodeId] of Object.entries(raw.label_node_ids))
        stringValue(nodeId, `issues[${index}].label_node_ids.${label}`);
      const declaredLabels = new Set(labels.map((label) => label.toLowerCase()));
      const labelNames = Object.keys(raw.label_node_ids).map((label) => label.toLowerCase());
      if (labelNames.some((label) => !declaredLabels.has(label)))
        fail(`issues[${index}].label_node_ids must reference declared labels`);
      unique(labelNames, `issues[${index}].label_node_ids`);
      unique(
        Object.values(raw.label_node_ids).map((nodeId) => String(nodeId)),
        `issues[${index}].label_node_ids`,
      );
    }
    unique(labels, `issues[${index}].labels`);
    issueNumbers.push(number);
    issueKeys.push(key);
    labels.forEach((label) => issueLabels.add(label.toLowerCase()));
  }
  unique(issueNumbers.map(String), "issue numbers");
  unique(issueKeys, "issue keys");
  const dependencies = arrayValue(value.dependencies, "dependencies");
  const dependencyKeys: string[] = [];
  for (const [index, raw] of dependencies.entries()) {
    if (!isObject(raw)) fail(`dependencies[${index}] must be an object`);
    exactKeys(raw, ["source", "target", "kind"], `dependencies[${index}]`);
    const source = positiveInteger(raw.source, `dependencies[${index}].source`);
    const targetNumber = positiveInteger(raw.target, `dependencies[${index}].target`);
    if (raw.kind !== "blocked_by") fail(`dependencies[${index}].kind must be blocked_by`);
    if (source === targetNumber || !issueNumbers.includes(source) || !issueNumbers.includes(targetNumber))
      fail(`dependencies[${index}] must reference distinct declared issues`);
    dependencyKeys.push(`${source}->${targetNumber}:blocked_by`);
  }
  unique(dependencyKeys, "dependencies");
  const labels = stringArray(value.required_labels, "required_labels");
  unique(
    labels.map((label) => label.toLowerCase()),
    "required_labels",
  );
  if (labels.some((label) => !issueLabels.has(label.toLowerCase())))
    fail("required_labels must be declared by an issue");
  void target;
}

function validateResult(value: Record<string, unknown>): void {
  exactKeys(
    value,
    [
      "schema_version",
      "status",
      "live_vs_fixture",
      "mutation_authorized",
      "target",
      "comparison_digest",
      "create_intent",
      "durable_create_identity",
      "second_read",
      "missing_children",
      "failures",
      "partial_failure",
      "partial_project_ids",
      "retry_count",
      "journal_entries",
      "retry_authorized",
      "retry_authorization",
      "secret_status",
      "redaction_status",
      "second_read_consistency",
      "inventory",
      "accepted_plan",
      "authorization",
      "lane_state",
      "blockers",
      "remaining_scope",
      "branch_worktree_state",
      "secret_redaction_status",
      "live_vs_fixture_classification",
    ],
    "result",
  );
  if (value.schema_version !== "project-result.v1") fail("expected schema_version project-result.v1");
  const status = stringValue(value.status, "status");
  if (!["ready", "bootstrap_required", "incomplete", "hard_failure"].includes(status)) fail("result status is invalid");
  if (typeof value.live_vs_fixture !== "string" || !["live", "fixture"].includes(value.live_vs_fixture))
    fail("live_vs_fixture is invalid");
  if (typeof value.mutation_authorized !== "boolean") fail("mutation_authorized must be boolean");
  targetValue(value.target, "target");
  if (typeof value.comparison_digest !== "string" || !/^[a-f0-9]{64}$/.test(value.comparison_digest))
    fail("comparison_digest must be a SHA-256 digest");
  if (value.create_intent !== null) {
    if (!isObject(value.create_intent)) fail("create_intent must be an object or null");
    exactKeys(
      value.create_intent,
      ["schema_version", "plan_digest", "target", "client_mutation_id", "intent_timestamp"],
      "create_intent",
    );
    if (value.create_intent.schema_version !== "project-create-intent.v1")
      fail("create_intent.schema_version is invalid");
    sha256Value(value.create_intent.plan_digest, "create_intent.plan_digest");
    targetValue(value.create_intent.target, "create_intent.target");
    stringValue(value.create_intent.client_mutation_id, "create_intent.client_mutation_id");
    stringValue(value.create_intent.intent_timestamp, "create_intent.intent_timestamp");
  }
  if (value.durable_create_identity !== null) {
    if (!isObject(value.durable_create_identity)) fail("durable_create_identity must be an object or null");
    exactKeys(
      value.durable_create_identity,
      [
        "plan_digest",
        "client_mutation_id",
        "intent_timestamp",
        "response_timestamp",
        "provider_request_id",
        "provider_response_id",
        "project_node_id",
        "project_number",
        "response_digest",
      ],
      "durable_create_identity",
    );
    sha256Value(value.durable_create_identity.plan_digest, "durable_create_identity.plan_digest");
    stringValue(value.durable_create_identity.client_mutation_id, "durable_create_identity.client_mutation_id");
    stringValue(value.durable_create_identity.intent_timestamp, "durable_create_identity.intent_timestamp");
    stringValue(value.durable_create_identity.response_timestamp, "durable_create_identity.response_timestamp");
    if (
      value.durable_create_identity.provider_request_id === undefined &&
      value.durable_create_identity.provider_response_id === undefined
    )
      fail("durable_create_identity requires provider request or response identity");
    if (value.durable_create_identity.provider_request_id !== undefined)
      stringValue(value.durable_create_identity.provider_request_id, "durable_create_identity.provider_request_id");
    if (value.durable_create_identity.provider_response_id !== undefined)
      stringValue(value.durable_create_identity.provider_response_id, "durable_create_identity.provider_response_id");
    stringValue(value.durable_create_identity.project_node_id, "durable_create_identity.project_node_id");
    positiveInteger(value.durable_create_identity.project_number, "durable_create_identity.project_number");
    sha256Value(value.durable_create_identity.response_digest, "durable_create_identity.response_digest");
  }
  const missingChildren = arrayValue(value.missing_children, "missing_children");
  if (missingChildren.some((item) => typeof item !== "string" || item === "")) fail("missing_children is malformed");
  const failures = arrayValue(value.failures, "failures");
  if (failures.some((item) => typeof item !== "string" || item === "")) fail("failures is malformed");
  if (value.partial_failure !== null && typeof value.partial_failure !== "string")
    fail("partial_failure must be a string or null");
  const ids = arrayValue(value.partial_project_ids, "partial_project_ids");
  const partialIdentityKeys: string[] = [];
  for (const [index, raw] of ids.entries()) {
    if (!isObject(raw)) fail(`partial_project_ids[${index}] must be an object`);
    exactKeys(raw, ["id", "number"], `partial_project_ids[${index}]`);
    if ((typeof raw.id !== "string" && typeof raw.id !== "number") || String(raw.id).trim() === "")
      fail(`partial_project_ids[${index}] has malformed id`);
    if (raw.number !== null) positiveInteger(raw.number, `partial_project_ids[${index}].number`);
    partialIdentityKeys.push(`${String(raw.id)}|${raw.number === null ? "null" : String(raw.number)}`);
  }
  unique(partialIdentityKeys, "partial_project_ids");
  if (!Number.isSafeInteger(value.retry_count) || (value.retry_count as number) < 0)
    fail("retry_count must be a non-negative integer");
  if (!Number.isSafeInteger(value.journal_entries) || (value.journal_entries as number) < 0)
    fail("journal_entries must be a non-negative integer");
  if (typeof value.retry_authorized !== "boolean") fail("retry_authorized must be boolean");
  if ((value.retry_count as number) === 0 && (value.retry_authorized || value.retry_authorization !== null))
    fail("zero retry_count requires retry_authorized false and retry_authorization null");
  if (value.retry_authorized) {
    if ((value.retry_count as number) < 1) fail("retry_authorized requires retry_count greater than zero");
    if (!isObject(value.retry_authorization)) fail("authorized result requires retry_authorization");
    exactKeys(
      value.retry_authorization,
      ["schema_version", "authorized", "current_turn_only", "owner", "expires", "plan_digest"],
      "retry_authorization",
    );
    if (value.retry_authorization.schema_version !== "retry-authorization.v1")
      fail("retry_authorization.schema_version is invalid");
    if (value.retry_authorization.authorized !== true || value.retry_authorization.current_turn_only !== true)
      fail("retry_authorization must be authorized and current-turn only");
    if (stringValue(value.retry_authorization.owner, "retry_authorization.owner") !== "external orchestrator")
      fail("retry_authorization.owner must be external orchestrator");
    if (value.retry_authorization.expires !== "end of current turn") fail("retry_authorization.expires is invalid");
    sha256Value(value.retry_authorization.plan_digest, "retry_authorization.plan_digest");
  } else if (value.retry_authorization !== null) {
    fail("unauthorized result must use null retry_authorization");
  }
  if ((value.retry_count as number) > 0 && value.status !== "hard_failure" && !value.retry_authorized)
    fail("retry_count cannot authorize an unauthorized retry result");
  stringValue(value.lane_state, "lane_state");
  if (!["clean", "detected"].includes(String(value.secret_status))) fail("secret_status is invalid");
  if (!["clean", "redacted", "failed"].includes(String(value.redaction_status))) fail("redaction_status is invalid");
  if (typeof value.second_read_consistency !== "boolean") fail("second_read_consistency must be boolean");
  if (!isObject(value.inventory)) fail("inventory must be an object");
  exactKeys(
    value.inventory,
    [
      "open_pages",
      "closed_pages",
      "open_complete",
      "closed_complete",
      "open_cursors",
      "closed_cursors",
      "open_termination",
      "closed_termination",
    ],
    "inventory",
  );
  positiveInteger(value.inventory.open_pages, "inventory.open_pages");
  positiveInteger(value.inventory.closed_pages, "inventory.closed_pages");
  if (
    value.status !== "hard_failure" &&
    (value.inventory.open_complete !== true || value.inventory.closed_complete !== true)
  )
    fail("inventory completeness flags must prove termination");
  stringArray(value.inventory.open_cursors, "inventory.open_cursors");
  stringArray(value.inventory.closed_cursors, "inventory.closed_cursors");
  if (
    value.status !== "hard_failure" &&
    ((value.inventory.open_cursors as unknown[]).length < 1 || (value.inventory.closed_cursors as unknown[]).length < 1)
  )
    fail("inventory cursor lists must prove page coverage");
  for (const scope of ["open", "closed"]) {
    const termination = value.inventory[`${scope}_termination`];
    if (!isObject(termination)) fail(`inventory.${scope}_termination must be an object`);
    exactKeys(termination, ["has_next_page", "end_cursor"], `inventory.${scope}_termination`);
    if (termination.has_next_page !== false || termination.end_cursor !== null)
      fail(`inventory.${scope}_termination must prove termination`);
  }
  if (value.accepted_plan !== undefined) {
    if (!isObject(value.accepted_plan)) fail("accepted_plan must be an object");
    exactKeys(value.accepted_plan, ["path", "sha256"], "accepted_plan");
    stringValue(value.accepted_plan.path, "accepted_plan.path");
    sha256Value(value.accepted_plan.sha256, "accepted_plan.sha256");
  }
  if (value.authorization !== undefined) {
    if (!isObject(value.authorization)) fail("authorization must be an object");
    exactKeys(value.authorization, ["path", "authorized", "expires", "delivery_authorized"], "authorization");
    stringValue(value.authorization.path, "authorization.path");
    if (typeof value.authorization.authorized !== "boolean") fail("authorization.authorized must be boolean");
    stringValue(value.authorization.expires, "authorization.expires");
    if (typeof value.authorization.delivery_authorized !== "boolean")
      fail("authorization.delivery_authorized must be boolean");
  }
  if (value.lane_state !== undefined && typeof value.lane_state !== "string") fail("lane_state must be a string");
  for (const field of ["blockers", "remaining_scope"]) {
    if (value[field] !== undefined) {
      stringArray(value[field], field);
    }
  }
  if (value.branch_worktree_state !== undefined) {
    if (!isObject(value.branch_worktree_state)) fail("branch_worktree_state must be an object");
    exactKeys(
      value.branch_worktree_state,
      ["branch", "dirty_paths_preserved", "excluded_files_unchanged"],
      "branch_worktree_state",
    );
    stringValue(value.branch_worktree_state.branch, "branch_worktree_state.branch");
    stringArray(value.branch_worktree_state.dirty_paths_preserved, "branch_worktree_state.dirty_paths_preserved");
    if (typeof value.branch_worktree_state.excluded_files_unchanged !== "boolean")
      fail("branch_worktree_state.excluded_files_unchanged must be boolean");
  }
  if (!["clean", "redacted", "failed"].includes(String(value.secret_redaction_status)))
    fail("secret_redaction_status is invalid");
  if (value.live_vs_fixture_classification !== undefined) {
    if (!isObject(value.live_vs_fixture_classification)) fail("live_vs_fixture_classification must be an object");
    exactKeys(value.live_vs_fixture_classification, ["live", "fixture"], "live_vs_fixture_classification");
    stringValue(value.live_vs_fixture_classification.live, "live_vs_fixture_classification.live");
    stringValue(value.live_vs_fixture_classification.fixture, "live_vs_fixture_classification.fixture");
  }
  if (value.second_read !== null) {
    if (!isObject(value.second_read)) fail("second_read must be an object or null");
    exactKeys(value.second_read, ["classification", "comparison_digest", "converged"], "second_read");
    const secondRead = value.second_read;
    if (
      typeof secondRead.classification !== "string" ||
      !["ready", "bootstrap_required", "incomplete", "hard_failure"].includes(secondRead.classification)
    )
      fail("second_read.classification is invalid");
    if (typeof secondRead.comparison_digest !== "string" || !/^[a-f0-9]{64}$/.test(secondRead.comparison_digest))
      fail("second_read.comparison_digest must be a SHA-256 digest");
    if (typeof secondRead.converged !== "boolean") fail("second_read.converged must be boolean");
    if (secondRead.converged !== (secondRead.classification === "ready"))
      fail("second_read.converged must match its classification");
  }
  if (status === "ready") {
    if (value.partial_failure !== null || failures.length > 0 || missingChildren.length > 0)
      fail("ready result cannot contain failures or missing children");
    if (
      !isObject(value.second_read) ||
      value.second_read.classification !== "ready" ||
      value.second_read.converged !== true
    )
      fail("ready result requires a converged ready second_read");
    if (!value.second_read_consistency) fail("ready result requires consistent second reads");
    if (value.secret_status !== "clean" || value.redaction_status !== "clean")
      fail("ready result requires clean secret and redaction status");
  }
  if (status === "bootstrap_required" && value.mutation_authorized !== false)
    fail("bootstrap_required cannot authorize mutation");
  if (status === "incomplete" && typeof value.partial_failure !== "string")
    fail("incomplete result requires partial_failure");
  if (status === "hard_failure" && value.mutation_authorized !== false) fail("hard_failure cannot authorize mutation");
  if (status === "hard_failure" && failures.length === 0) fail("hard_failure requires explicit failures");
}

if (!input) fail("--input is required");
if (!["plan-v20", "result-v20"].includes(schema)) fail("--schema must be plan-v20 or result-v20");
let value: unknown;
try {
  const contents =
    input === "-" ? await new Response(Bun.stdin.stream()).text() : await readFile(resolve(input), "utf8");
  value = JSON.parse(contents);
} catch (error) {
  fail(`invalid JSON: ${error instanceof Error ? error.message : String(error)}`);
}
if (!isObject(value)) fail("document must be an object");
if (schema === "plan-v20") validatePlan(value);
else validateResult(value);
process.stdout.write(`valid ${schema}: ${resolve(input)}\n`);
