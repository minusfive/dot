#!/usr/bin/env bun
//MISE description="Plan and reconcile a repository-linked GitHub Project"
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE flag "--plan <path>" help="Versioned Project plan JSON"
//USAGE flag "--fixture <path>" help="Isolated fixture state JSON instead of GitHub"
//USAGE flag "--evidence-dir <path>" help="Write ORCH-108 evidence artifacts"
//USAGE flag "--dry-run" help="Classify without mutating"
//USAGE flag "--confirm <token>" help="Required mutation confirmation token: APPLY"
//USAGE flag "--retry <count>" help="Retry transient operations" default="0"
//USAGE flag "--retry-authorization <path>" help="Current-turn retry authorization JSON"

import { createHash } from "node:crypto";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { spawn } from "node:child_process";

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Obj = { [key: string]: Json };

type PlanIssue = {
  number: number;
  key: string;
  labels: string[];
  node_id?: string;
  label_node_ids?: { [label: string]: string };
};

type Plan = {
  schema_version: "gh-project-plan.v20";
  target: {
    host: string;
    owner: string;
    repository: string;
    title: string;
    key: string;
  };
  lanes: string[];
  issues: PlanIssue[];
  dependencies: Array<{ source: number; target: number; kind: "blocked_by" }>;
  required_labels: string[];
};

type Snapshot = {
  capabilities: { project: boolean; repo: boolean };
  host: string;
  owner: { type: string; login: string; id?: string };
  repository: { name: string; nameWithOwner: string; id?: string; linkage_id?: string };
  projects: Project[];
  inventory: Inventory;
};

type Inventory = {
  open_pages: number;
  closed_pages: number;
  open_complete: boolean;
  closed_complete: boolean;
  open_cursors: string[];
  closed_cursors: string[];
  open_termination: { has_next_page: false; end_cursor: null };
  closed_termination: { has_next_page: false; end_cursor: null };
};

type RetryAuthorization = {
  schema_version: "retry-authorization.v1";
  authorized: boolean;
  current_turn_only: boolean;
  owner: string;
  expires: string;
  plan_digest: string;
};

type Project = {
  number: number;
  id: string;
  title: string;
  key?: string | null;
  host?: string;
  owner?: { type: string; login: string; id?: string };
  repository?: { name: string; nameWithOwner: string; id?: string; linkage_id?: string } | null;
  fields: Field[];
  items: Item[];
  labels: Label[];
  dependencies: Dependency[];
};

type Field = {
  id: string;
  name: string;
  type: string;
  __typename?: string;
  options?: Array<{ id: string; name: string; color: string; description: string }>;
};
type Item = { id: string; issue: { id: string; number: number; repository: string; labels: string[] } };
type Label = { id: string; name: string; repository: string; issue_numbers: number[] };
type Dependency = { id: string; source: number; target: number; kind: "blocked_by" };

type Comparison = {
  schema_version: "project-comparison.v1";
  classification: "ready" | "bootstrap_required" | "hard_failure";
  mutation_authorized: false;
  target: Obj;
  parent_matches: Obj[];
  missing_children: string[];
  failures: string[];
  canonical: Obj;
  comparison_digest: string;
  inventory: Inventory;
};

type JournalEntry = {
  operation: string;
  status: "planned" | "applied" | "failed" | "skipped";
  identifier?: string | number;
  project_number?: number;
  error?: string;
  durable_identity?: DurableCreateIdentity;
};

type DurableCreateIdentity = {
  plan_digest: string;
  client_mutation_id: string;
  intent_timestamp: string;
  response_timestamp: string;
  provider_request_id?: string;
  provider_response_id?: string;
  project_node_id: string;
  project_number: number;
  response_digest: string;
};

type CreateIntent = {
  schema_version: "project-create-intent.v1";
  plan_digest: string;
  target: Obj;
  client_mutation_id: string;
  intent_timestamp: string;
};

type RedactionState = {
  secret_status: "clean" | "detected";
  redaction_status: "clean" | "redacted" | "failed";
};

const REQUIRED_LANES = ["Blocked", "Todo", "Research", "Implement", "Validate", "Critique", "Done"];
const STATUS_COLORS = ["BLUE", "GRAY", "GREEN", "YELLOW", "ORANGE", "RED", "PURPLE"];

class LiveReadError extends Error {
  constructor(
    public readonly operation: string,
    public readonly evidence: string[],
  ) {
    super(`${operation}: ${evidence.join("; ")}`);
    this.name = "LiveReadError";
  }
}

class ReconciliationError extends Error {
  constructor(errorMessage: string) {
    super(errorMessage);
    this.name = "ReconciliationError";
  }
}

const PLAN_PATH = (process.env.usage_plan ?? "").trim();
const FIXTURE_PATH = (process.env.usage_fixture ?? "").trim();
const EVIDENCE_DIR = (process.env.usage_evidence_dir ?? "").trim();
const DRY_RUN = (process.env.usage_dry_run ?? "").toLowerCase() === "true";
const CONFIRM = (process.env.usage_confirm ?? "").trim();
const RETRY_VALUE = Number(process.env.usage_retry ?? "0");
if (!Number.isSafeInteger(RETRY_VALUE) || RETRY_VALUE < 0 || RETRY_VALUE > 3)
  fail("--retry must be an integer from 0 through 3");
const RETRY = RETRY_VALUE;
const RETRY_AUTHORIZATION_PATH = (process.env.usage_retry_authorization ?? "").trim();
const GITHUB_HOST = "github.com";

function fail(message: string): never {
  throw new Error(message);
}

function message(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

let runtimeRedactionObserved = false;

function redactText(value: string): { value: string; redacted: boolean } {
  let redacted = false;
  const replace = (pattern: RegExp, replacement: string): void => {
    if (pattern.test(value)) redacted = true;
    value = value.replace(pattern, replacement);
  };
  replace(/Bearer\s+[A-Za-z0-9._~+/-]+/gi, "Bearer [REDACTED]");
  replace(/(token|access_token|authorization|cookie|set-cookie|signature|sig)=([^&\s]+)/gi, "$1=[REDACTED]");
  replace(/(gh[pousr]_[A-Za-z0-9_]+)/g, "[REDACTED_TOKEN]");
  if (redacted) runtimeRedactionObserved = true;
  return { value, redacted };
}

function redactionState(value: Json): RedactionState {
  const rendered = JSON.stringify(value);
  const redacted = redactText(rendered);
  return {
    secret_status: redacted.redacted ? "detected" : "clean",
    redaction_status: redacted.redacted ? "redacted" : "clean",
  };
}

function safeError(value: unknown): string {
  return redactText(message(value)).value;
}

function isObject(value: Json): value is Obj {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readString(value: Json, name: string): string {
  if (typeof value !== "string" || value.trim() === "") fail(`${name} must be a non-empty string`);
  return value.trim();
}

function readNumber(value: Json, name: string): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value <= 0)
    fail(`${name} must be a positive integer`);
  return value;
}

function arrayOf<T>(value: Json, name: string, reader: (item: Json, index: number) => T): T[] {
  if (!Array.isArray(value)) fail(`${name} must be an array`);
  return value.map(reader);
}

function parsePlan(value: Json): Plan {
  if (!isObject(value) || value.schema_version !== "gh-project-plan.v20")
    fail("plan must use schema_version gh-project-plan.v20");
  const targetValue = value.target;
  if (!isObject(targetValue)) fail("plan.target must be an object");
  const target = {
    host: readString(targetValue.host, "target.host").toLowerCase(),
    owner: readString(targetValue.owner, "target.owner").toLowerCase(),
    repository: readString(targetValue.repository, "target.repository").toLowerCase(),
    title: readString(targetValue.title, "target.title"),
    key: readString(targetValue.key, "target.key"),
  };
  if (target.host !== "github.com") fail("only github.com is supported");
  if (target.key !== `${target.owner}/${target.repository}:${target.title}`)
    fail("target.key does not match normalized target identity");
  const lanes = arrayOf(value.lanes, "lanes", (item, index) => readString(item, `lanes[${index}]`));
  if (new Set(lanes).size !== lanes.length || lanes.length === 0) fail("lanes must be unique and non-empty");
  if (stable(lanes) !== stable(REQUIRED_LANES)) fail("lanes must contain exactly the seven required status lanes");
  const issues = arrayOf(value.issues, "issues", (item, index) => {
    if (!isObject(item)) fail(`issues[${index}] must be an object`);
    const labels = arrayOf(item.labels, `issues[${index}].labels`, (label, labelIndex) =>
      readString(label, `issues[${index}].labels[${labelIndex}]`),
    );
    if (item.label_node_ids !== undefined && !isObject(item.label_node_ids))
      fail(`issues[${index}].label_node_ids must be an object`);
    const labelNodeIds =
      item.label_node_ids === undefined
        ? undefined
        : Object.fromEntries(
            Object.entries(item.label_node_ids as Obj).map(([label, nodeId]) => [
              label.toLowerCase(),
              readString(nodeId, `issues[${index}].label_node_ids.${label}`),
            ]),
          );
    if (
      labelNodeIds !== undefined &&
      Object.keys(labelNodeIds).some((label) => !labels.some((declared) => declared.toLowerCase() === label))
    )
      fail(`issues[${index}].label_node_ids must reference declared labels`);
    if (labelNodeIds !== undefined && new Set(Object.values(labelNodeIds)).size !== Object.keys(labelNodeIds).length)
      fail(`issues[${index}].label_node_ids must contain unique node IDs`);
    return {
      number: readNumber(item.number, `issues[${index}].number`),
      key: readString(item.key, `issues[${index}].key`),
      labels,
      ...(item.node_id === undefined ? {} : { node_id: readString(item.node_id, `issues[${index}].node_id`) }),
      ...(labelNodeIds === undefined ? {} : { label_node_ids: labelNodeIds }),
    };
  });
  if (new Set(issues.map((issue) => issue.number)).size !== issues.length) fail("issue numbers must be unique");
  if (new Set(issues.map((issue) => issue.key)).size !== issues.length) fail("issue keys must be unique");
  if (issues.some((issue) => new Set(issue.labels.map((label) => label.toLowerCase())).size !== issue.labels.length))
    fail("issue labels must be unique");
  const dependencies = arrayOf(value.dependencies, "dependencies", (item, index) => {
    if (!isObject(item)) fail(`dependencies[${index}] must be an object`);
    const kind = readString(item.kind, `dependencies[${index}].kind`);
    if (kind !== "blocked_by") fail(`dependencies[${index}].kind must be blocked_by`);
    return {
      source: readNumber(item.source, `dependencies[${index}].source`),
      target: readNumber(item.target, `dependencies[${index}].target`),
      kind: "blocked_by" as const,
    };
  });
  if (new Set(dependencies.map((edge) => `${edge.source}->${edge.target}:${edge.kind}`)).size !== dependencies.length)
    fail("dependencies must be unique");
  const issueNumbers = new Set(issues.map((issue) => issue.number));
  if (
    dependencies.some(
      (edge) => edge.source === edge.target || !issueNumbers.has(edge.source) || !issueNumbers.has(edge.target),
    )
  )
    fail("dependencies must reference distinct declared issues");
  const requiredLabels = arrayOf(value.required_labels, "required_labels", (item, index) =>
    readString(item, `required_labels[${index}]`),
  );
  if (new Set(requiredLabels.map((label) => label.toLowerCase())).size !== requiredLabels.length)
    fail("required_labels must be unique");
  const declaredLabels = new Set(issues.flatMap((issue) => issue.labels.map((label) => label.toLowerCase())));
  if (requiredLabels.some((label) => !declaredLabels.has(label.toLowerCase())))
    fail("required_labels must be declared by an issue");
  return {
    schema_version: "gh-project-plan.v20",
    target,
    lanes,
    issues,
    dependencies,
    required_labels: requiredLabels,
  };
}

function canonicalize(value: Json): Json {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (!isObject(value)) return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, canonicalize(value[key])]),
  );
}

function stable(value: Json): string {
  return JSON.stringify(canonicalize(value));
}

function digest(value: Json): string {
  return createHash("sha256").update(stable(value)).digest("hex");
}

function planDigest(plan: Plan): string {
  return digest(plan as unknown as Json);
}

function createIntentPath(): string | null {
  return EVIDENCE_DIR ? `${resolve(EVIDENCE_DIR)}/create-intent.v1.json` : null;
}

function createResponsePath(): string | null {
  return EVIDENCE_DIR ? `${resolve(EVIDENCE_DIR)}/create-response-identity.v1.json` : null;
}

async function loadCreateIntent(plan: Plan): Promise<CreateIntent | null> {
  const path = createIntentPath();
  if (!path) return null;
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
  const value = parseOutput<Json>(raw, `create intent ${path}`);
  if (
    !isObject(value) ||
    value.schema_version !== "project-create-intent.v1" ||
    typeof value.plan_digest !== "string" ||
    value.plan_digest !== planDigest(plan) ||
    !isObject(value.target) ||
    typeof value.client_mutation_id !== "string" ||
    value.client_mutation_id === "" ||
    typeof value.intent_timestamp !== "string" ||
    value.intent_timestamp === ""
  )
    fail("create intent is incomplete or does not match the plan");
  return {
    schema_version: "project-create-intent.v1",
    plan_digest: value.plan_digest,
    target: value.target,
    client_mutation_id: value.client_mutation_id,
    intent_timestamp: value.intent_timestamp,
  };
}

async function persistCreateIntent(plan: Plan): Promise<CreateIntent> {
  const path = createIntentPath();
  if (!path) throw new ReconciliationError("evidence directory is required before Project creation");
  const intent: CreateIntent = {
    schema_version: "project-create-intent.v1",
    plan_digest: planDigest(plan),
    target: plan.target,
    client_mutation_id: `project-create-${planDigest(plan).slice(0, 24)}-${Date.now()}`,
    intent_timestamp: new Date().toISOString(),
  };
  await mkdir(resolve(EVIDENCE_DIR), { recursive: true });
  await writeFile(path, `${JSON.stringify(intent, null, 2)}\n`, "utf8");
  return intent;
}

async function persistCreateResponse(identity: DurableCreateIdentity): Promise<void> {
  const path = createResponsePath();
  if (!path) throw new ReconciliationError("evidence directory is required for durable create identity");
  await mkdir(resolve(EVIDENCE_DIR), { recursive: true });
  await writeFile(
    path,
    `${JSON.stringify({ schema_version: "create-response-identity.v1", ...identity }, null, 2)}\n`,
    "utf8",
  );
}

function parseDurableCreateIdentity(value: Json, name: string): DurableCreateIdentity {
  if (!isObject(value)) fail(`${name} must be an object`);
  if (
    typeof value.plan_digest !== "string" ||
    !/^[a-f0-9]{64}$/.test(value.plan_digest) ||
    typeof value.client_mutation_id !== "string" ||
    value.client_mutation_id === "" ||
    typeof value.intent_timestamp !== "string" ||
    value.intent_timestamp === "" ||
    typeof value.response_timestamp !== "string" ||
    value.response_timestamp === "" ||
    ((typeof value.provider_request_id !== "string" || value.provider_request_id === "") &&
      (typeof value.provider_response_id !== "string" || value.provider_response_id === "")) ||
    typeof value.project_node_id !== "string" ||
    value.project_node_id === "" ||
    !Number.isSafeInteger(value.project_number) ||
    Number(value.project_number) <= 0 ||
    typeof value.response_digest !== "string" ||
    !/^[a-f0-9]{64}$/.test(value.response_digest)
  )
    fail(`${name} is incomplete`);
  return {
    plan_digest: value.plan_digest,
    client_mutation_id: value.client_mutation_id,
    intent_timestamp: value.intent_timestamp,
    response_timestamp: value.response_timestamp,
    ...(typeof value.provider_request_id === "string" && value.provider_request_id !== ""
      ? { provider_request_id: value.provider_request_id }
      : {}),
    ...(typeof value.provider_response_id === "string" && value.provider_response_id !== ""
      ? { provider_response_id: value.provider_response_id }
      : {}),
    project_node_id: value.project_node_id,
    project_number: Number(value.project_number),
    response_digest: value.response_digest,
  };
}

async function loadCreateResponse(plan: Plan, intent: CreateIntent | null): Promise<DurableCreateIdentity | null> {
  const path = createResponsePath();
  if (!path) return null;
  let raw: string;
  try {
    raw = await readFile(path, "utf8");
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw error;
  }
  const value = parseOutput<Json>(raw, `create response identity ${path}`);
  if (!isObject(value) || value.schema_version !== "create-response-identity.v1")
    fail("create response identity has an unsupported schema");
  if (!intent) fail("create response identity requires the persisted create intent");
  const identity = parseDurableCreateIdentity(value, "create response identity");
  if (identity.plan_digest !== planDigest(plan)) fail("create response identity does not match the plan");
  if (
    identity.client_mutation_id !== intent.client_mutation_id ||
    identity.intent_timestamp !== intent.intent_timestamp
  )
    fail("create response identity does not match the persisted create intent");
  return identity;
}

function verifyPersistedCreateIdentity(identity: DurableCreateIdentity | null, comparison: Comparison): void {
  if (!identity) {
    if (!DRY_RUN && comparison.parent_matches.length === 1)
      throw new ReconciliationError("exact target Project requires a persisted create identity before reuse");
    return;
  }
  if (comparison.parent_matches.length !== 1)
    throw new ReconciliationError("persisted create identity did not resolve to exactly one Project");
  const parent = comparison.parent_matches[0]?.parent as Obj | undefined;
  if (
    !parent ||
    parent.project_node_id !== identity.project_node_id ||
    parent.project_number !== String(identity.project_number)
  )
    throw new ReconciliationError("persisted create identity does not match the current Project identity");
}

function parseRetryAuthorization(value: Json, plan: Plan): RetryAuthorization {
  if (!isObject(value)) fail("retry authorization must be an object");
  if (value.schema_version !== "retry-authorization.v1") fail("retry authorization has an unsupported schema");
  if (value.authorized !== true) fail("retry authorization is not authorized");
  if (value.current_turn_only !== true) fail("retry authorization must be current-turn only");
  const owner = readString(value.owner, "retry authorization.owner");
  if (owner !== "external orchestrator") fail("retry authorization.owner must be external orchestrator");
  const expires = readString(value.expires, "retry authorization.expires");
  if (expires !== "end of current turn") fail("retry authorization has expired or ambiguous expiry");
  const authorizationPlanDigest = readString(value.plan_digest, "retry authorization.plan_digest");
  if (authorizationPlanDigest !== planDigest(plan)) fail("retry authorization does not match the plan");
  return {
    schema_version: "retry-authorization.v1",
    authorized: true,
    current_turn_only: true,
    owner,
    expires,
    plan_digest: authorizationPlanDigest,
  };
}

async function loadRetryAuthorization(plan: Plan): Promise<RetryAuthorization | null> {
  if (!RETRY_AUTHORIZATION_PATH) return null;
  return parseRetryAuthorization(
    parseOutput(
      await readFile(resolve(RETRY_AUTHORIZATION_PATH), "utf8"),
      `retry authorization ${RETRY_AUTHORIZATION_PATH}`,
    ),
    plan,
  );
}

function normalizeRepository(value: string): string {
  const trimmed = value
    .trim()
    .toLowerCase()
    .replace(/\/+$/, "")
    .replace(/\.git$/, "");
  const match = trimmed.match(/(?:https?:\/\/github\.com\/)?([^/]+\/[^/]+)$/);
  return match?.[1] ?? trimmed;
}

function normalizedProject(project: Project, plan: Plan): Obj {
  const owner = project.owner ?? { type: "User", login: plan.target.owner };
  const repository = project.repository ?? { name: "", nameWithOwner: "" };
  return {
    parent: {
      host: (project.host ?? plan.target.host).trim().toLowerCase(),
      owner_type: owner.type.trim(),
      owner_login: owner.login.trim().toLowerCase(),
      owner_id: owner.id ?? null,
      repository_name: repository.name.trim().toLowerCase(),
      repository_name_with_owner: normalizeRepository(repository.nameWithOwner),
      repository_id: repository.id ?? null,
      linkage_id: repository.linkage_id ?? null,
      project_number: String(project.number),
      project_node_id: project.id,
      title: project.title.trim(),
      key: (project.key ?? `${plan.target.owner}/${plan.target.repository}:${project.title}`).trim(),
    },
    fields: project.fields
      .map((field) => ({
        id: field.id,
        name: field.name.trim(),
        type: field.type.trim().toUpperCase(),
        ...(field.__typename === undefined ? {} : { __typename: field.__typename.trim() }),
        options: (field.options ?? []).map((option) => ({
          id: option.id,
          name: option.name.trim(),
          color: option.color,
          description: option.description,
        })),
      }))
      .sort((a, b) => a.id.localeCompare(b.id) || a.name.localeCompare(b.name)),
    items: project.items
      .map((item) => ({
        id: item.id,
        issue_id: item.issue.id ?? null,
        issue_number: String(item.issue.number),
        repository: normalizeRepository(item.issue.repository),
        labels: item.issue.labels.map((label) => label.trim().toLowerCase()).sort(),
      }))
      .sort((a, b) => a.id.localeCompare(b.id) || a.issue_number.localeCompare(b.issue_number)),
    labels: project.labels
      .map((label) => ({
        id: label.id,
        name: label.name.trim().toLowerCase(),
        repository: normalizeRepository(label.repository),
        issue_numbers: label.issue_numbers.map(String).sort(),
      }))
      .sort((a, b) => a.id.localeCompare(b.id) || a.name.localeCompare(b.name)),
    dependencies: project.dependencies
      .map((edge) => ({ id: edge.id, source: String(edge.source), target: String(edge.target), kind: edge.kind }))
      .sort(
        (a, b) => a.source.localeCompare(b.source) || a.target.localeCompare(b.target) || a.kind.localeCompare(b.kind),
      ),
  };
}

function expectedChildren(plan: Plan): Obj {
  return {
    lanes: plan.lanes,
    issues: plan.issues.map((issue) => ({
      number: String(issue.number),
      key: issue.key,
      labels: issue.labels,
      ...(issue.node_id === undefined ? {} : { node_id: issue.node_id }),
      ...(issue.label_node_ids === undefined ? {} : { label_node_ids: issue.label_node_ids }),
    })),
    labels: plan.required_labels,
    dependencies: plan.dependencies.map((edge) => ({
      source: String(edge.source),
      target: String(edge.target),
      kind: edge.kind,
    })),
  };
}

function validateSnapshot(value: Json, name: string): Snapshot {
  if (!isObject(value)) fail(`${name} must be an object`);
  if (
    !isObject(value.capabilities) ||
    typeof value.capabilities.project !== "boolean" ||
    typeof value.capabilities.repo !== "boolean"
  )
    fail(`${name}.capabilities must contain project and repo booleans`);
  if (
    typeof value.host !== "string" ||
    !isObject(value.owner) ||
    !isObject(value.repository) ||
    !Array.isArray(value.projects)
  )
    fail(`${name} has an incomplete top-level contract`);
  if (
    typeof value.owner.type !== "string" ||
    typeof value.owner.login !== "string" ||
    typeof value.repository.name !== "string" ||
    typeof value.repository.nameWithOwner !== "string"
  )
    fail(`${name} has malformed owner or repository identity`);
  const projects = value.projects.map((raw, projectIndex) => {
    if (
      !isObject(raw) ||
      !Number.isSafeInteger(raw.number) ||
      typeof raw.number !== "number" ||
      raw.number <= 0 ||
      typeof raw.id !== "string" ||
      raw.id === "" ||
      typeof raw.title !== "string" ||
      !isObject(raw.owner) ||
      typeof raw.owner.type !== "string" ||
      raw.owner.type === "" ||
      typeof raw.owner.login !== "string" ||
      raw.owner.login === "" ||
      !isObject(raw.repository) ||
      typeof raw.repository.name !== "string" ||
      raw.repository.name === "" ||
      typeof raw.repository.nameWithOwner !== "string" ||
      raw.repository.nameWithOwner === ""
    )
      fail(`${name}.projects[${projectIndex}] has malformed identity`);
    if (
      !Array.isArray(raw.fields) ||
      !Array.isArray(raw.items) ||
      !Array.isArray(raw.labels) ||
      !Array.isArray(raw.dependencies)
    )
      fail(`${name}.projects[${projectIndex}] has incomplete child collections`);
    const fields = raw.fields.map((field, fieldIndex) => {
      if (
        !isObject(field) ||
        typeof field.id !== "string" ||
        field.id === "" ||
        typeof field.name !== "string" ||
        typeof field.type !== "string" ||
        (field.__typename !== undefined && (typeof field.__typename !== "string" || field.__typename === ""))
      )
        fail(`${name}.projects[${projectIndex}].fields[${fieldIndex}] has malformed identity`);
      if (field.type.toUpperCase() === "SINGLE_SELECT" && !Array.isArray(field.options))
        fail(`${name}.projects[${projectIndex}].fields[${fieldIndex}].options is required`);
      if (field.options !== undefined && !Array.isArray(field.options))
        fail(`${name}.projects[${projectIndex}].fields[${fieldIndex}].options must be an array`);
      const options = (field.options ?? []).map((option, optionIndex) => {
        if (
          !isObject(option) ||
          typeof option.id !== "string" ||
          option.id === "" ||
          typeof option.name !== "string" ||
          option.name === "" ||
          typeof option.color !== "string" ||
          option.color === "" ||
          typeof option.description !== "string" ||
          option.description === ""
        )
          fail(
            `${name}.projects[${projectIndex}].fields[${fieldIndex}].options[${optionIndex}] has malformed identity`,
          );
        return { id: option.id, name: option.name, color: option.color, description: option.description };
      });
      return {
        id: field.id,
        name: field.name,
        type: field.type,
        ...(field.__typename === undefined ? {} : { __typename: field.__typename }),
        options,
      };
    });
    const items = raw.items.map((item, itemIndex) => {
      if (!isObject(item) || typeof item.id !== "string" || item.id === "" || !isObject(item.issue))
        fail(`${name}.projects[${projectIndex}].items[${itemIndex}] has malformed identity`);
      if (
        !Number.isSafeInteger(item.issue.number) ||
        typeof item.issue.number !== "number" ||
        item.issue.number <= 0 ||
        typeof item.issue.repository !== "string" ||
        item.issue.repository === "" ||
        !Array.isArray(item.issue.labels)
      )
        fail(`${name}.projects[${projectIndex}].items[${itemIndex}].issue is malformed`);
      if (typeof item.issue.id !== "string" || item.issue.id === "")
        fail(`${name}.projects[${projectIndex}].items[${itemIndex}].issue.id is required`);
      if (item.issue.labels.some((label) => typeof label !== "string" || label === ""))
        fail(`${name}.projects[${projectIndex}].items[${itemIndex}].issue.labels is malformed`);
      const itemLabels = item.issue.labels.map((label) => String(label));
      return {
        id: item.id,
        issue: {
          id: item.issue.id,
          number: item.issue.number,
          repository: item.issue.repository,
          labels: itemLabels,
        },
      };
    });
    const labels = raw.labels.map((label, labelIndex) => {
      if (
        !isObject(label) ||
        typeof label.id !== "string" ||
        label.id === "" ||
        typeof label.name !== "string" ||
        label.name === "" ||
        typeof label.repository !== "string" ||
        label.repository === "" ||
        !Array.isArray(label.issue_numbers)
      )
        fail(`${name}.projects[${projectIndex}].labels[${labelIndex}] is malformed`);
      if (
        label.issue_numbers.some((number) => typeof number !== "number" || !Number.isSafeInteger(number) || number <= 0)
      )
        fail(`${name}.projects[${projectIndex}].labels[${labelIndex}].issue_numbers is malformed`);
      return {
        id: label.id,
        name: label.name,
        repository: label.repository,
        issue_numbers: label.issue_numbers.map((number) => Number(number)),
      };
    });
    const dependencies = raw.dependencies.map((edge, edgeIndex) => {
      if (
        !isObject(edge) ||
        typeof edge.id !== "string" ||
        edge.id === "" ||
        typeof edge.source !== "number" ||
        !Number.isSafeInteger(edge.source) ||
        edge.source <= 0 ||
        typeof edge.target !== "number" ||
        !Number.isSafeInteger(edge.target) ||
        edge.target <= 0 ||
        edge.kind !== "blocked_by"
      )
        fail(`${name}.projects[${projectIndex}].dependencies[${edgeIndex}] is malformed`);
      return { id: edge.id, source: edge.source, target: edge.target, kind: "blocked_by" as const };
    });
    return {
      number: raw.number,
      id: raw.id,
      title: raw.title,
      ...(typeof raw.key === "string" ? { key: raw.key } : {}),
      ...(typeof raw.host === "string" ? { host: raw.host } : {}),
      owner: {
        type: raw.owner.type,
        login: raw.owner.login,
        ...(typeof raw.owner.id === "string" ? { id: raw.owner.id } : {}),
      },
      repository: {
        name: raw.repository.name,
        nameWithOwner: raw.repository.nameWithOwner,
        ...(typeof raw.repository.id === "string" ? { id: raw.repository.id } : {}),
        ...(typeof raw.repository.linkage_id === "string" ? { linkage_id: raw.repository.linkage_id } : {}),
      },
      fields,
      items,
      labels,
      dependencies,
    };
  });
  const inventoryValue = value.inventory;
  const inventory: Inventory =
    inventoryValue === undefined
      ? (() => {
          fail(`${name}.inventory is required`);
        })()
      : (() => {
          if (!isObject(inventoryValue)) fail(`${name}.inventory must be an object`);
          for (const key of ["open_pages", "closed_pages"]) {
            if (!Number.isSafeInteger(inventoryValue[key]) || Number(inventoryValue[key]) < 1)
              fail(`${name}.inventory.${key} must be a positive integer`);
          }
          if (
            typeof inventoryValue.open_complete !== "boolean" ||
            typeof inventoryValue.closed_complete !== "boolean" ||
            !Array.isArray(inventoryValue.open_cursors) ||
            !Array.isArray(inventoryValue.closed_cursors) ||
            !isObject(inventoryValue.open_termination) ||
            !isObject(inventoryValue.closed_termination) ||
            inventoryValue.open_termination.has_next_page !== false ||
            inventoryValue.closed_termination.has_next_page !== false ||
            inventoryValue.open_termination.end_cursor !== null ||
            inventoryValue.closed_termination.end_cursor !== null
          )
            fail(`${name}.inventory completeness flags must be boolean`);
          if (
            inventoryValue.open_cursors.some((cursor) => typeof cursor !== "string") ||
            inventoryValue.closed_cursors.some((cursor) => typeof cursor !== "string")
          )
            fail(`${name}.inventory cursors must be strings`);
          return {
            open_pages: Number(inventoryValue.open_pages),
            closed_pages: Number(inventoryValue.closed_pages),
            open_complete: inventoryValue.open_complete,
            closed_complete: inventoryValue.closed_complete,
            open_cursors: inventoryValue.open_cursors as string[],
            closed_cursors: inventoryValue.closed_cursors as string[],
            open_termination: { has_next_page: false, end_cursor: null },
            closed_termination: { has_next_page: false, end_cursor: null },
          };
        })();
  return {
    capabilities: { project: value.capabilities.project, repo: value.capabilities.repo },
    host: value.host,
    owner: {
      type: value.owner.type,
      login: value.owner.login,
      ...(typeof value.owner.id === "string" ? { id: value.owner.id } : {}),
    },
    repository: {
      name: value.repository.name,
      nameWithOwner: value.repository.nameWithOwner,
      ...(typeof value.repository.id === "string" ? { id: value.repository.id } : {}),
      ...(typeof value.repository.linkage_id === "string" ? { linkage_id: value.repository.linkage_id } : {}),
    },
    projects,
    inventory,
  };
}

function childIdentityFailures(project: Project): string[] {
  const failures: string[] = [];
  const duplicate = (values: string[], label: string) => {
    if (new Set(values).size !== values.length) failures.push(`duplicate_${label}`);
  };
  duplicate(
    project.fields.map((field) => field.id),
    "field_id",
  );
  duplicate(
    project.fields.map((field) => field.name.trim().toLowerCase()),
    "field_name",
  );
  for (const field of project.fields) {
    duplicate(field.options?.map((option) => option.id) ?? [], `option_id:${field.id}`);
    duplicate(field.options?.map((option) => option.name.trim().toLowerCase()) ?? [], `option_name:${field.id}`);
    if (field.type.trim().toUpperCase() === "SINGLE_SELECT") {
      if (!field.options) failures.push(`missing_options:${field.id}`);
      else if (
        field.options.some(
          (option) =>
            option.color.trim() === "" ||
            option.description.trim() === "" ||
            !/^[A-Z_]+$/.test(option.color.trim().toUpperCase()),
        )
      )
        failures.push(`malformed_option_metadata:${field.id}`);
    }
  }
  duplicate(
    project.items.map((item) => item.id),
    "item_id",
  );
  if (project.items.some((item) => !item.issue.id)) failures.push("missing_item_issue_node_id");
  duplicate(
    project.items.map(
      (item) => `${item.issue.id ?? "<missing>"}|${normalizeRepository(item.issue.repository)}#${item.issue.number}`,
    ),
    "issue_identity",
  );
  duplicate(
    project.labels.map((label) => label.id),
    "label_id",
  );
  duplicate(
    project.labels.map((label) => label.name.trim().toLowerCase()),
    "label_name",
  );
  const associations = project.labels.flatMap((label) =>
    label.issue_numbers.map(
      (issueNumber) =>
        `${label.id}|${label.name.trim().toLowerCase()}|${normalizeRepository(label.repository)}#${issueNumber}`,
    ),
  );
  duplicate(associations, "label_association");
  duplicate(
    project.dependencies.map((edge) => edge.id),
    "dependency_id",
  );
  duplicate(
    project.dependencies.map((edge) => `${edge.source}->${edge.target}:${edge.kind}`),
    "dependency",
  );
  return failures;
}

function compare(snapshot: Snapshot, plan: Plan): Comparison {
  const target = {
    host: plan.target.host,
    owner: plan.target.owner,
    repository: plan.target.repository,
    title: plan.target.title,
    key: plan.target.key,
  };
  const failures: string[] = [];
  if (!snapshot.inventory.open_complete || !snapshot.inventory.closed_complete)
    failures.push("incomplete_project_inventory");
  if (
    snapshot.inventory.open_pages < 1 ||
    snapshot.inventory.closed_pages < 1 ||
    snapshot.inventory.open_cursors.length < snapshot.inventory.open_pages ||
    snapshot.inventory.closed_cursors.length < snapshot.inventory.closed_pages
  )
    failures.push("missing_project_inventory_pagination");
  if (!snapshot.capabilities.project || !snapshot.capabilities.repo) failures.push("missing_capability");
  if (snapshot.host.trim().toLowerCase() !== plan.target.host) failures.push("wrong_host");
  if (snapshot.repository.nameWithOwner.trim().toLowerCase() !== `${plan.target.owner}/${plan.target.repository}`)
    failures.push("wrong_repository");
  const projects = snapshot.projects ?? [];
  if (new Set(projects.map((project) => project.id)).size !== projects.length)
    failures.push("duplicate_project_node_id");
  if (new Set(projects.map((project) => project.number)).size !== projects.length)
    failures.push("duplicate_project_number");
  const parentMatches = projects.filter((project) => {
    const identity = normalizedProject(project, plan).parent as Obj;
    return (
      identity.host === plan.target.host &&
      identity.owner_login === plan.target.owner &&
      identity.repository_name_with_owner === `${plan.target.owner}/${plan.target.repository}` &&
      identity.title === plan.target.title &&
      identity.key === plan.target.key
    );
  });
  const sameTitleWrongIdentity = projects.filter(
    (project) => project.title.trim() === plan.target.title && !parentMatches.includes(project),
  );
  if (sameTitleWrongIdentity.length > 0) failures.push("wrong_identity_or_linkage");
  if (parentMatches.length > 1) failures.push("duplicate_parent_identity");
  for (const project of parentMatches) failures.push(...childIdentityFailures(project));
  const missingChildren: string[] = [];
  let canonical: Obj = { target, projects: projects.map((project) => normalizedProject(project, plan)) };
  if (parentMatches.length === 1 && failures.length === 0) {
    const actual = normalizedProject(parentMatches[0], plan);
    const statusFields = (actual.fields as Obj[]).filter((field) => String(field.name).toLowerCase() === "status");
    if (statusFields.length > 1) failures.push("duplicate_status_field");
    const status = statusFields[0];
    const options = status?.options as Obj[] | undefined;
    if (!status) missingChildren.push("field:Status");
    else if (
      status.type !== "SINGLE_SELECT" ||
      (status.__typename !== undefined && status.__typename !== "ProjectV2SingleSelectField")
    )
      failures.push("wrong_status_field_type");
    else {
      if (!options) failures.push("missing_status_options");
      const optionNames = options?.map((option) => String(option.name)) ?? [];
      if (optionNames.some((name) => !plan.lanes.includes(name))) failures.push("wrong_status_lanes");
      if (new Set(optionNames).size !== optionNames.length) failures.push("duplicate_status_option_name");
      if (options && new Set(options.map((option) => String(option.id))).size !== options.length)
        failures.push("duplicate_status_option_id");
      if (optionNames.length > plan.lanes.length) failures.push("wrong_status_lane_count");
      if (optionNames.length === plan.lanes.length && JSON.stringify(optionNames) !== JSON.stringify(plan.lanes))
        failures.push("wrong_status_lane_order");
      for (const lane of plan.lanes) if (!optionNames.includes(lane)) missingChildren.push(`lane:${lane}`);
      for (const option of options ?? []) {
        if (
          typeof option.id !== "string" ||
          option.id === "" ||
          typeof option.color !== "string" ||
          option.color === "" ||
          typeof option.description !== "string" ||
          option.description === ""
        )
          failures.push("missing_status_option_metadata");
      }
    }
    const actualItems = actual.items as Obj[];
    const expectedIssueKeys = new Set(
      plan.issues.map((issue) => `${plan.target.owner}/${plan.target.repository}#${issue.number}`),
    );
    const actualIssueKeys = actualItems.map((item) => `${item.repository}#${item.issue_number}`);
    for (const actualIssueKey of actualIssueKeys)
      if (!expectedIssueKeys.has(actualIssueKey)) failures.push(`unexpected_issue_item:${actualIssueKey}`);
    for (const issue of plan.issues) {
      const matching = actualItems.filter(
        (item) =>
          item.issue_number === String(issue.number) &&
          item.repository === `${plan.target.owner}/${plan.target.repository}`,
      );
      if (matching.length > 1) failures.push(`duplicate_issue_item:${issue.number}`);
      if (matching.length === 0) {
        if (actualItems.some((item) => item.issue_number === String(issue.number)))
          failures.push(`wrong_issue_repository:${issue.number}`);
        missingChildren.push(`issue:${issue.number}`);
      } else if (!matching[0].issue_id || !matching[0].id) failures.push(`missing_issue_identity:${issue.number}`);
      else if (issue.node_id !== undefined && matching[0].issue_id !== issue.node_id)
        failures.push(`wrong_issue_node_id:${issue.number}`);
      else if (((matching[0].labels as string[]) ?? []).some((label) => typeof label !== "string"))
        failures.push(`malformed_issue_labels:${issue.number}`);
    }
    const actualLabels = actual.labels as Obj[];
    const expectedLabelNames = new Set(plan.required_labels.map((label) => label.toLowerCase()));
    for (const label of actualLabels) {
      if (!expectedLabelNames.has(String(label.name))) failures.push(`unexpected_label:${String(label.name)}`);
      if (label.repository !== `${plan.target.owner}/${plan.target.repository}`)
        failures.push(`wrong_label_repository:${String(label.name)}`);
    }
    for (const label of plan.required_labels) {
      const matches = actualLabels.filter((item) => item.name === label.toLowerCase());
      if (matches.length > 1) failures.push(`duplicate_label:${label}`);
      if (matches.length === 0) missingChildren.push(`label:${label}`);
      else {
        const expectedNodeId = plan.issues
          .flatMap((issue) => Object.entries(issue.label_node_ids ?? {}))
          .find(([name]) => name === label.toLowerCase())?.[1];
        if (expectedNodeId !== undefined && matches[0].id !== expectedNodeId)
          failures.push(`wrong_label_node_id:${label}`);
      }
    }
    const expectedAssociations = new Set(
      plan.issues.flatMap((issue) =>
        issue.labels.map(
          (label) => `${label.toLowerCase()}|${plan.target.owner}/${plan.target.repository}#${issue.number}`,
        ),
      ),
    );
    const actualAssociations = new Set(
      actualLabels.flatMap((label) =>
        (label.issue_numbers as string[]).map((issueNumber) => `${label.name}|${label.repository}#${issueNumber}`),
      ),
    );
    for (const association of actualAssociations)
      if (!expectedAssociations.has(association)) failures.push(`unexpected_label_association:${association}`);
    for (const association of expectedAssociations)
      if (!actualAssociations.has(association)) {
        const [label, issue] = association.split("|");
        const issueNumber = issue.split("#").at(-1);
        if (!label || !issueNumber) failures.push(`malformed_label_association:${association}`);
        else missingChildren.push(`label:${label}:issue:${issueNumber}`);
      }
    const actualEdges = actual.dependencies as Obj[];
    const expectedEdgeKeys = new Set(plan.dependencies.map((edge) => `${edge.source}->${edge.target}:${edge.kind}`));
    for (const edge of actualEdges) {
      const edgeKey = `${edge.source}->${edge.target}:${edge.kind}`;
      if (!expectedEdgeKeys.has(edgeKey)) failures.push(`unexpected_dependency:${edgeKey}`);
      if (typeof edge.id !== "string" || edge.id === "") failures.push(`missing_dependency_identity:${edgeKey}`);
    }
    for (const edge of expectedChildren(plan).dependencies as Obj[]) {
      const matching = actualEdges.filter(
        (item) => item.source === edge.source && item.target === edge.target && item.kind === edge.kind,
      );
      if (matching.length > 1) failures.push(`duplicate_dependency:${edge.source}->${edge.target}`);
      if (matching.length === 0) missingChildren.push(`dependency:${edge.source}->${edge.target}`);
    }
    if (failures.length === 0 && missingChildren.length === 0)
      canonical = { target, identity: actual, expected: expectedChildren(plan) };
  }
  const classification =
    failures.length > 0
      ? "hard_failure"
      : parentMatches.length !== 1 || missingChildren.length > 0
        ? "bootstrap_required"
        : "ready";
  const canonicalPayload = canonicalize({
    classification,
    target,
    parent_matches: parentMatches.map((project) => normalizedProject(project, plan)),
    missing_children: missingChildren,
    failures,
    canonical,
  }) as Obj;
  return {
    schema_version: "project-comparison.v1",
    classification,
    mutation_authorized: false,
    target,
    parent_matches: parentMatches.map((project) => normalizedProject(project, plan)),
    missing_children: missingChildren,
    failures,
    canonical: canonicalPayload,
    comparison_digest: digest(canonicalPayload),
    inventory: snapshot.inventory,
  };
}

function hardFailureComparison(plan: Plan, failures: string[]): Comparison {
  const target = { ...plan.target };
  const canonical = canonicalize({ classification: "hard_failure", target, failures }) as Obj;
  return {
    schema_version: "project-comparison.v1",
    classification: "hard_failure",
    mutation_authorized: false,
    target,
    parent_matches: [],
    missing_children: [],
    failures,
    canonical,
    comparison_digest: digest(canonical),
    inventory: {
      open_pages: 1,
      closed_pages: 1,
      open_complete: false,
      closed_complete: false,
      open_cursors: [],
      closed_cursors: [],
      open_termination: { has_next_page: false, end_cursor: null },
      closed_termination: { has_next_page: false, end_cursor: null },
    },
  };
}

async function run(command: string, args: string[]): Promise<string> {
  return await new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, { cwd: process.cwd(), env: process.env, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += String(chunk)));
    child.stderr.on("data", (chunk) => (stderr += String(chunk)));
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolvePromise(stdout) : reject(new Error(stderr.trim() || stdout.trim() || `${command} failed`)),
    );
  });
}

function liveGhEnvironment(): NodeJS.ProcessEnv {
  const configuredHost = (process.env.GH_HOST ?? "").trim().toLowerCase();
  if (configuredHost && configuredHost !== GITHUB_HOST) {
    throw new Error(`refusing live GitHub call: GH_HOST is '${configuredHost}', not '${GITHUB_HOST}'.`);
  }
  const configuredDir = (process.env.GH_CONFIG_DIR ?? "").trim();
  const allowedConfigDirs = new Set([resolve(homedir(), ".config/gh/personal"), resolve(homedir(), ".config/gh/work")]);
  if (!configuredDir || !allowedConfigDirs.has(resolve(configuredDir))) {
    throw new Error("refusing live GitHub call: GH_CONFIG_DIR is not a trusted profile configuration.");
  }
  return { ...process.env, GH_HOST: GITHUB_HOST, GH_CONFIG_DIR: resolve(configuredDir) };
}

async function runGh(args: string[]): Promise<string> {
  return await runWithEnvironment("gh", [...args, "--hostname", GITHUB_HOST], liveGhEnvironment());
}

async function runGhWithInput(args: string[], input: string): Promise<string> {
  return await runWithInputWithEnvironment("gh", [...args, "--hostname", GITHUB_HOST], input, liveGhEnvironment());
}

async function runWithEnvironment(command: string, args: string[], env: NodeJS.ProcessEnv): Promise<string> {
  return await new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, { cwd: process.cwd(), env, stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += String(chunk)));
    child.stderr.on("data", (chunk) => (stderr += String(chunk)));
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolvePromise(stdout) : reject(new Error(stderr.trim() || stdout.trim() || `${command} failed`)),
    );
  });
}

async function runWithInputWithEnvironment(
  command: string,
  args: string[],
  input: string,
  env: NodeJS.ProcessEnv,
): Promise<string> {
  return await new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, { cwd: process.cwd(), env, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += String(chunk)));
    child.stderr.on("data", (chunk) => (stderr += String(chunk)));
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolvePromise(stdout) : reject(new Error(stderr.trim() || stdout.trim() || `${command} failed`)),
    );
    child.stdin.write(input);
    child.stdin.end();
  });
}

async function runWithInput(command: string, args: string[], input: string): Promise<string> {
  return await new Promise((resolvePromise, reject) => {
    const child = spawn(command, args, { cwd: process.cwd(), env: process.env, stdio: ["pipe", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => (stdout += String(chunk)));
    child.stderr.on("data", (chunk) => (stderr += String(chunk)));
    child.on("error", reject);
    child.on("close", (code) =>
      code === 0 ? resolvePromise(stdout) : reject(new Error(stderr.trim() || stdout.trim() || `${command} failed`)),
    );
    child.stdin.write(input);
    child.stdin.end();
  });
}

function parseOutput<T>(output: string, name: string): T {
  try {
    return JSON.parse(output) as T;
  } catch (error) {
    fail(`${name} returned malformed JSON: ${message(error)}`);
  }
}

async function graphql<T>(payload: Obj, name: string): Promise<T> {
  const output = await runGhWithInput(["api", "graphql", "--input", "-"], JSON.stringify(payload));
  const value = parseOutput<Json>(output, name);
  if (!isObject(value) || !isObject(value.data)) fail(`${name} is missing GraphQL data`);
  if (value.errors !== undefined) fail(`${name} returned GraphQL errors: ${digest(value.errors)}`);
  return value as unknown as T;
}

function pageInfo(value: Json, name: string): { hasNextPage: boolean; endCursor: string | null } {
  if (!isObject(value) || typeof value.hasNextPage !== "boolean")
    fail(`${name} is missing pagination termination data`);
  if (value.endCursor !== null && typeof value.endCursor !== "string")
    fail(`${name}.endCursor must be a string or null`);
  if (value.hasNextPage && !value.endCursor) fail(`${name} hasNextPage without an endCursor`);
  return { hasNextPage: value.hasNextPage, endCursor: value.endCursor as string | null };
}

type GraphProject = {
  number: number;
  id: string;
  title: string;
  closed: boolean;
  owner: { __typename: string; login: string; id: string };
  repositories: { nodes: Array<{ id: string; nameWithOwner: string }> };
};

async function readProjectScope(
  plan: Plan,
  scope: "open" | "closed",
): Promise<{
  projects: GraphProject[];
  pages: number;
  cursors: string[];
  termination: { has_next_page: false; end_cursor: null };
}> {
  const projects: GraphProject[] = [];
  const cursors: string[] = [];
  const seenIds = new Set<string>();
  const seenNumbers = new Set<number>();
  let cursor: string | null = null;
  let terminated = false;
  for (let page = 1; page <= 10000; page += 1) {
    cursors.push(cursor ?? "<start>");
    const graph = await graphql<{
      data: {
        user: {
          projectsV2: {
            nodes: GraphProject[];
            pageInfo: { hasNextPage: boolean; endCursor: string | null };
          } | null;
        } | null;
      };
    }>(
      {
        query:
          "query($login:String!,$after:String,$query:String!){user(login:$login){projectsV2(first:100,after:$after,query:$query){nodes{number title id closed owner{__typename ... on User{login id} ... on Organization{login id}} repositories(first:100){nodes{id nameWithOwner}}} pageInfo{hasNextPage endCursor}}}}",
        variables: { login: plan.target.owner, after: cursor, query: scope === "closed" ? "is:closed" : "is:open" },
      },
      `Project ${scope} inventory page ${page}`,
    );
    const connection = graph.data.user?.projectsV2;
    if (!connection || !Array.isArray(connection.nodes))
      fail(`Project ${scope} inventory page ${page} is missing projects`);
    const termination = pageInfo(
      connection.pageInfo as unknown as Json,
      `Project ${scope} inventory page ${page}.pageInfo`,
    );
    if (connection.nodes.length === 0 && termination.hasNextPage)
      fail(`Project ${scope} inventory page ${page} has an ambiguous empty page`);
    for (const [projectIndex, project] of connection.nodes.entries()) {
      if (
        !project ||
        !Number.isSafeInteger(project.number) ||
        project.number <= 0 ||
        typeof project.id !== "string" ||
        project.id === "" ||
        typeof project.title !== "string" ||
        typeof project.closed !== "boolean" ||
        !project.owner ||
        typeof project.owner.__typename !== "string" ||
        project.owner.__typename === "" ||
        typeof project.owner.login !== "string" ||
        project.owner.login === "" ||
        typeof project.owner.id !== "string" ||
        project.owner.id === "" ||
        !project.repositories ||
        !Array.isArray(project.repositories.nodes)
      )
        fail(`Project ${scope} inventory page ${page} project ${projectIndex} has incomplete identity`);
      if (seenIds.has(project.id) || seenNumbers.has(project.number))
        fail(`Project ${scope} inventory returned duplicate Project identity`);
      seenIds.add(project.id);
      seenNumbers.add(project.number);
      for (const [repositoryIndex, repository] of project.repositories.nodes.entries()) {
        if (
          !repository ||
          typeof repository.id !== "string" ||
          repository.id === "" ||
          typeof repository.nameWithOwner !== "string" ||
          repository.nameWithOwner === ""
        )
          fail(`Project ${scope} inventory page ${page} repository ${repositoryIndex} has incomplete identity`);
      }
      if ((scope === "open" && project.closed) || (scope === "closed" && !project.closed))
        fail(`Project ${scope} inventory provider scope returned a Project from the opposite scope`);
      projects.push(project);
    }
    if (!termination.hasNextPage) {
      terminated = true;
      break;
    }
    if (termination.endCursor === cursor) fail(`Project ${scope} inventory page ${page} repeated its cursor`);
    cursor = termination.endCursor;
  }
  if (!terminated) fail(`Project ${scope} inventory did not provide termination evidence`);
  return {
    projects,
    pages: cursors.length,
    cursors,
    termination: { has_next_page: false, end_cursor: null },
  };
}

async function liveSnapshot(plan: Plan): Promise<Snapshot> {
  const openScope = await readProjectScope(plan, "open");
  const closedScope = await readProjectScope(plan, "closed");
  const graphProjects: GraphProject[] = [];
  const byId = new Map<string, GraphProject>();
  for (const project of [...openScope.projects, ...closedScope.projects]) {
    const existing = byId.get(project.id);
    if (
      existing &&
      (existing.number !== project.number ||
        existing.closed !== project.closed ||
        existing.title !== project.title ||
        existing.owner.id !== project.owner.id)
    )
      fail(`Project inventory returned conflicting identity for ${project.id}`);
    if (!existing) {
      byId.set(project.id, project);
      graphProjects.push(project);
    }
  }
  const inventory: Inventory = {
    open_pages: openScope.pages,
    closed_pages: closedScope.pages,
    open_complete: true,
    closed_complete: true,
    open_cursors: openScope.cursors,
    closed_cursors: closedScope.cursors,
    open_termination: openScope.termination,
    closed_termination: closedScope.termination,
  };
  const projects: Project[] = [];
  for (const raw of graphProjects) {
    const fieldsRaw = parseOutput<Json>(
      await runGh(["project", "field-list", String(raw.number), "--owner", plan.target.owner, "--format", "json"]),
      `Project ${raw.number} fields`,
    );
    if (!isObject(fieldsRaw) || !Array.isArray(fieldsRaw.fields))
      fail(`Project ${raw.number} fields response is missing fields`);
    for (const [fieldIndex, field] of fieldsRaw.fields.entries()) {
      if (
        !isObject(field) ||
        typeof field.id !== "string" ||
        field.id === "" ||
        typeof field.name !== "string" ||
        typeof field.type !== "string"
      )
        fail(`Project ${raw.number} fields[${fieldIndex}] has incomplete identity`);
      if (field.type.toUpperCase() === "SINGLE_SELECT" && !Array.isArray(field.options))
        fail(`Project ${raw.number} fields[${fieldIndex}] is missing options`);
      if (field.options !== undefined && !Array.isArray(field.options))
        fail(`Project ${raw.number} fields[${fieldIndex}] options are malformed`);
      for (const [optionIndex, option] of (field.options ?? []).entries()) {
        if (
          !isObject(option) ||
          typeof option.id !== "string" ||
          option.id === "" ||
          typeof option.name !== "string" ||
          option.name === "" ||
          typeof option.color !== "string" ||
          option.color === "" ||
          typeof option.description !== "string" ||
          option.description === ""
        )
          fail(`Project ${raw.number} field ${field.id} option ${optionIndex} has incomplete metadata`);
      }
    }
    const fields = fieldsRaw.fields as unknown as Field[];
    const items: Item[] = [];
    const labels: Label[] = [];
    const dependencies: Dependency[] = [];
    let itemCursor: string | null = null;
    let itemTerminated = false;
    for (let itemPage = 1; itemPage <= 10000; itemPage += 1) {
      const itemsGraph = await graphql<{
        data: {
          node: {
            items: {
              nodes: Array<{
                id: string;
                content: { id: string; number: number; repository: { nameWithOwner: string } } | null;
              }>;
              pageInfo: { hasNextPage: boolean; endCursor: string | null };
            } | null;
          } | null;
        };
      }>(
        {
          query:
            "query($id:ID!,$after:String){node(id:$id){... on ProjectV2{items(first:100,after:$after){nodes{id content{... on Issue{id number repository{nameWithOwner}}}} pageInfo{hasNextPage endCursor}}}}}",
          variables: { id: raw.id, after: itemCursor },
        },
        `Project ${raw.number} items page ${itemPage}`,
      );
      const itemsConnection = itemsGraph.data.node?.items;
      if (!itemsConnection || !Array.isArray(itemsConnection.nodes))
        fail(`Project ${raw.number} items response is missing items`);
      const termination = pageInfo(
        itemsConnection.pageInfo as unknown as Json,
        `Project ${raw.number} items page ${itemPage}.pageInfo`,
      );
      if (itemsConnection.nodes.length === 0 && termination.hasNextPage)
        fail(`Project ${raw.number} items page ${itemPage} has an ambiguous empty page`);
      for (const item of itemsConnection.nodes) {
        if (
          !item ||
          typeof item.id !== "string" ||
          item.id === "" ||
          !item.content ||
          typeof item.content.id !== "string" ||
          item.content.id === "" ||
          !Number.isSafeInteger(item.content.number) ||
          item.content.number <= 0 ||
          !item.content.repository ||
          typeof item.content.repository.nameWithOwner !== "string" ||
          item.content.repository.nameWithOwner === ""
        )
          fail(`Project ${raw.number} contains an item with incomplete issue identity`);
        const number = item.content.number;
        const issue = parseOutput<Json>(
          await runGh([
            "issue",
            "view",
            String(number),
            "--repo",
            normalizeRepository(item.content.repository.nameWithOwner),
            "--json",
            "id,labels",
          ]),
          `issue #${number}`,
        );
        if (!isObject(issue) || typeof issue.id !== "string" || issue.id === "" || !Array.isArray(issue.labels))
          fail(`issue #${number} response is missing id or labels`);
        const issueLabels = issue.labels.map((label, labelIndex) => {
          if (
            !isObject(label) ||
            typeof label.id !== "string" ||
            label.id === "" ||
            typeof label.name !== "string" ||
            label.name === ""
          )
            fail(`issue #${number} label ${labelIndex} has incomplete identity`);
          return label.name;
        });
        if (issue.id !== item.content.id) fail(`issue #${number} item identity does not match issue identity`);
        items.push({
          id: item.id,
          issue: {
            id: item.content.id,
            number,
            repository: item.content.repository.nameWithOwner,
            labels: issueLabels,
          },
        });
        for (const label of issue.labels as Json[]) {
          if (!isObject(label)) fail(`issue #${number} contains malformed label data`);
          const existing = labels.find((candidate) => candidate.id === label.id);
          if (existing) existing.issue_numbers.push(number);
          else
            labels.push({
              id: String(label.id),
              name: String(label.name),
              repository: item.content.repository.nameWithOwner,
              issue_numbers: [number],
            });
        }
        const operation = `issue #${number} dependencies`;
        let rawDependencies: string;
        try {
          rawDependencies = await runGh([
            "api",
            `repos/${plan.target.owner}/${plan.target.repository}/issues/${number}/dependencies/blocked_by`,
          ]);
        } catch (error) {
          throw new LiveReadError(operation, [`dependency_read_error:${operation}:${message(error)}`]);
        }
        let blockedBy: unknown;
        try {
          blockedBy = JSON.parse(rawDependencies) as unknown;
        } catch (error) {
          throw new LiveReadError(operation, [
            `dependency_read_malformed:${operation}:invalid_json:${message(error)}:digest=${digest(rawDependencies)}`,
          ]);
        }
        if (!Array.isArray(blockedBy))
          throw new LiveReadError(operation, [
            `dependency_read_malformed:${operation}:expected_array:digest=${digest(rawDependencies)}`,
          ]);
        for (const dependency of blockedBy) {
          if (
            !isObject(dependency) ||
            typeof dependency.id !== "string" ||
            dependency.id === "" ||
            typeof dependency.number !== "number" ||
            !Number.isSafeInteger(dependency.number) ||
            dependency.number <= 0
          )
            throw new LiveReadError(operation, [
              `dependency_read_missing_identity:${operation}:digest=${digest(rawDependencies)}`,
            ]);
          dependencies.push({ id: dependency.id, source: number, target: dependency.number, kind: "blocked_by" });
        }
      }
      if (!termination.hasNextPage) {
        itemTerminated = true;
        break;
      }
      if (termination.endCursor === itemCursor)
        fail(`Project ${raw.number} items page ${itemPage} repeated its cursor`);
      itemCursor = termination.endCursor;
    }
    if (!itemTerminated) fail(`Project ${raw.number} items did not provide termination evidence`);
    const graphProject = raw;
    const linkedRepository = graphProject.repositories?.nodes?.find(
      (repository) =>
        normalizeRepository(repository.nameWithOwner) === `${plan.target.owner}/${plan.target.repository}`,
    );
    projects.push({
      number: raw.number,
      id: raw.id,
      title: raw.title,
      host: plan.target.host,
      owner: {
        type: graphProject.owner?.__typename ?? "User",
        login: graphProject.owner?.login ?? plan.target.owner,
        id: graphProject.owner?.id,
      },
      repository: linkedRepository
        ? { name: plan.target.repository, nameWithOwner: linkedRepository.nameWithOwner, id: linkedRepository.id }
        : null,
      fields,
      items,
      labels,
      dependencies,
    });
  }
  return {
    capabilities: { project: true, repo: true },
    host: plan.target.host,
    owner: { type: "User", login: plan.target.owner },
    repository: { name: plan.target.repository, nameWithOwner: `${plan.target.owner}/${plan.target.repository}` },
    projects,
    inventory,
  };
}

async function loadFixture(
  path: string,
): Promise<{ state: Snapshot; fail_operations: string[]; second_read_inconsistent: boolean }> {
  const raw = parseOutput<Json & { fail_operations?: Json }>(await readFile(resolve(path), "utf8"), `fixture ${path}`);
  const state = validateSnapshot(raw, `fixture ${path}`);
  const failOperations = isObject(raw) && Array.isArray(raw.fail_operations) ? raw.fail_operations : [];
  if (failOperations.some((operation) => typeof operation !== "string" || operation.trim() === ""))
    fail("fixture fail_operations must contain non-empty strings");
  return {
    state,
    fail_operations: failOperations as string[],
    second_read_inconsistent: isObject(raw) && raw.second_read_inconsistent === true,
  };
}

async function saveFixture(
  path: string,
  fixture: { state: Snapshot; fail_operations?: string[]; second_read_inconsistent?: boolean },
): Promise<void> {
  const value = {
    ...fixture.state,
    ...(fixture.fail_operations && fixture.fail_operations.length > 0
      ? { fail_operations: fixture.fail_operations }
      : {}),
    ...(fixture.second_read_inconsistent ? { second_read_inconsistent: true } : {}),
  };
  await writeFile(resolve(path), `${JSON.stringify(canonicalize(value as unknown as Json), null, 2)}\n`, "utf8");
}

async function applyFixture(
  plan: Plan,
  fixture: { state: Snapshot; fail_operations: string[] },
  journal: JournalEntry[],
  persistedCreateIdentity: DurableCreateIdentity | null,
): Promise<void> {
  const failOnce = (operation: string): void => {
    journal.push({ operation, status: "failed", error: "fixture-injected failure" });
    const index = fixture.fail_operations.indexOf(operation);
    if (index >= 0) fixture.fail_operations.splice(index, 1);
    throw new Error(`fixture-injected failure: ${operation}`);
  };
  let project = fixture.state.projects.find(
    (candidate) => candidate.title === plan.target.title && candidate.key === plan.target.key,
  );
  if (!project) {
    const priorIntent = await loadCreateIntent(plan);
    if (priorIntent) throw new ReconciliationError("ambiguous create identity blocks fixture creation or retry");
    const createIntent = await persistCreateIntent(plan);
    if (fixture.fail_operations.includes("create_project")) failOnce("create_project");
    const number = Math.max(0, ...fixture.state.projects.map((candidate) => candidate.number)) + 1;
    project = {
      number,
      id: `fixture-project-${number}`,
      title: plan.target.title,
      key: plan.target.key,
      host: plan.target.host,
      owner: fixture.state.owner,
      repository: fixture.state.repository,
      fields: [
        {
          id: "fixture-status",
          name: "Status",
          type: "SINGLE_SELECT",
          options: plan.lanes.map((name, index) => ({
            id: `fixture-lane-${index + 1}`,
            name,
            color: STATUS_COLORS[index]!,
            description: `Execution lane: ${name}`,
          })),
        },
      ],
      items: [],
      labels: [],
      dependencies: [],
    };
    fixture.state.projects.push(project);
    journal.push({
      operation: "create_project",
      status: "applied",
      identifier: project.id,
      project_number: project.number,
    });
    const fixtureResponse = {
      project_node_id: project.id,
      project_number: project.number,
      title: project.title,
    };
    const createEntry = journal[journal.length - 1];
    createEntry.durable_identity = {
      plan_digest: planDigest(plan),
      client_mutation_id: createIntent.client_mutation_id,
      intent_timestamp: createIntent.intent_timestamp,
      response_timestamp: new Date().toISOString(),
      provider_request_id: "fixture-request",
      provider_response_id: "fixture-response",
      project_node_id: project.id,
      project_number: project.number,
      response_digest: digest(fixtureResponse),
    };
    if (EVIDENCE_DIR) await persistCreateResponse(createEntry.durable_identity);
  } else {
    if (!persistedCreateIdentity)
      throw new ReconciliationError("exact target Project requires a persisted create identity before reuse");
    if (
      project.id !== persistedCreateIdentity.project_node_id ||
      project.number !== persistedCreateIdentity.project_number
    )
      throw new ReconciliationError("persisted create identity does not match the fixture Project");
    journal.push({ operation: "reuse_project", status: "applied", identifier: project.id });
  }
  let status = project.fields.find((field) => field.name === "Status");
  if (!status) {
    status = { id: "fixture-status", name: "Status", type: "SINGLE_SELECT", options: [] };
    project.fields.push(status);
  }
  const existingOptions = status.options ?? [];
  const options = plan.lanes.map((lane, index) => {
    const existing = existingOptions.find((option) => option.name === lane);
    if (existing) return existing;
    if (fixture.fail_operations.includes(`lane:${lane}`)) failOnce(`lane:${lane}`);
    journal.push({ operation: `lane:${lane}`, status: "applied" });
    return {
      id: `fixture-lane-${index + 1}`,
      name: lane,
      color: STATUS_COLORS[index]!,
      description: `Execution lane: ${lane}`,
    };
  });
  if (JSON.stringify(options) !== JSON.stringify(existingOptions)) {
    status.options = options;
    if (!journal.some((entry) => entry.operation === "update_status")) {
      journal.push({ operation: "update_status", status: "applied", identifier: status.id });
    }
  }
  for (const issue of plan.issues) {
    if (!project.items.some((item) => item.issue.number === issue.number)) {
      if (fixture.fail_operations.includes(`issue:${issue.number}`)) failOnce(`issue:${issue.number}`);
      project.items.push({
        id: `fixture-item-${issue.number}`,
        issue: {
          id: issue.node_id ?? `fixture-issue-${issue.number}`,
          number: issue.number,
          repository: `${plan.target.owner}/${plan.target.repository}`,
          labels: issue.labels,
        },
      });
      journal.push({
        operation: `issue:${issue.number}`,
        status: "applied",
        identifier: `fixture-item-${issue.number}`,
      });
    }
    for (const label of issue.labels) {
      let existing = project.labels.find((candidate) => candidate.name.toLowerCase() === label.toLowerCase());
      if (!existing) {
        existing = {
          id: issue.label_node_ids?.[label.toLowerCase()] ?? `fixture-label-${project.labels.length + 1}`,
          name: label,
          repository: `${plan.target.owner}/${plan.target.repository}`,
          issue_numbers: [],
        };
        project.labels.push(existing);
      }
      if (!existing.issue_numbers.includes(issue.number)) existing.issue_numbers.push(issue.number);
    }
  }
  for (const label of plan.required_labels) {
    if (!project.labels.some((candidate) => candidate.name.toLowerCase() === label.toLowerCase())) {
      project.labels.push({
        id: `fixture-label-${project.labels.length + 1}`,
        name: label,
        repository: `${plan.target.owner}/${plan.target.repository}`,
        issue_numbers: [],
      });
    }
  }
  for (const edge of plan.dependencies) {
    if (
      !project.dependencies.some(
        (candidate) =>
          candidate.source === edge.source && candidate.target === edge.target && candidate.kind === edge.kind,
      )
    ) {
      if (fixture.fail_operations.includes(`dependency:${edge.source}->${edge.target}`))
        failOnce(`dependency:${edge.source}->${edge.target}`);
      project.dependencies.push({
        id: `fixture-dependency-${edge.source}-${edge.target}`,
        ...edge,
      });
      journal.push({ operation: `dependency:${edge.source}->${edge.target}`, status: "applied" });
    }
  }
}

async function readLiveComparison(plan: Plan): Promise<Comparison> {
  return compare(await liveSnapshot(plan), plan);
}

function requireSelectedParent(comparison: Comparison, projectId: string, projectNumber: number, group: string): Obj {
  if (comparison.failures.length > 0)
    throw new ReconciliationError(`live ${group} read is unsafe: ${comparison.failures.join(",")}`);
  if (comparison.parent_matches.length !== 1)
    throw new ReconciliationError(`live ${group} read did not return exactly one selected Project`);
  const parent = comparison.parent_matches[0].parent as Obj;
  if (parent.project_node_id !== projectId || parent.project_number !== String(projectNumber))
    throw new ReconciliationError(`live ${group} read changed selected Project identity`);
  return comparison.parent_matches[0];
}

function hasUnsafeCreateJournalEntry(journal: JournalEntry[]): boolean {
  return journal.some(
    (entry) => entry.operation === "create_project" && (entry.status === "failed" || !entry.durable_identity),
  );
}

async function applyLive(
  plan: Plan,
  before: Comparison,
  journal: JournalEntry[],
  persistedCreateIdentity: DurableCreateIdentity | null,
): Promise<void> {
  let projectNumber: number;
  let projectId: string;
  let createdProject = false;
  const priorCreateIntent = await loadCreateIntent(plan);
  if (before.parent_matches.length === 1) {
    const parent = before.parent_matches[0].parent as Obj;
    if (!persistedCreateIdentity)
      throw new ReconciliationError("exact target Project requires a persisted create identity before reuse");
    if (
      parent.project_node_id !== persistedCreateIdentity.project_node_id ||
      parent.project_number !== String(persistedCreateIdentity.project_number)
    )
      throw new ReconciliationError("persisted create identity does not match the selected Project");
    projectNumber = Number(parent.project_number);
    projectId = String(parent.project_node_id);
    journal.push({
      operation: "reuse_project",
      status: "skipped",
      identifier: projectId,
      project_number: projectNumber,
    });
  } else {
    if (persistedCreateIdentity || priorCreateIntent || RETRY > 0)
      throw new ReconciliationError("ambiguous create identity blocks Project creation or retry");
    const createIntent = await persistCreateIntent(plan);
    let createOutput = "";
    let created: Partial<{
      number: number;
      id: string;
      client_mutation_id: string;
      response_timestamp: string;
      provider_request_id: string;
      provider_response_id: string;
      response_digest: string;
    }>;
    try {
      createOutput = await runGh([
        "project",
        "create",
        "--owner",
        plan.target.owner,
        "--title",
        plan.target.title,
        "--format",
        "json",
      ]);
      created = parseOutput<
        Partial<{
          number: number;
          id: string;
          client_mutation_id: string;
          response_timestamp: string;
          provider_request_id: string;
          provider_response_id: string;
          response_digest: string;
        }>
      >(createOutput, "project create");
    } catch (error) {
      journal.push({ operation: "create_project", status: "failed", error: safeError(error) });
      throw error;
    }
    if (
      !Number.isSafeInteger(created.number) ||
      Number(created.number) <= 0 ||
      typeof created.id !== "string" ||
      created.id === "" ||
      typeof created.client_mutation_id !== "string" ||
      created.client_mutation_id === "" ||
      created.client_mutation_id !== createIntent.client_mutation_id ||
      typeof created.response_timestamp !== "string" ||
      created.response_timestamp === "" ||
      ((typeof created.provider_request_id !== "string" || created.provider_request_id === "") &&
        (typeof created.provider_response_id !== "string" || created.provider_response_id === "")) ||
      typeof created.response_digest !== "string" ||
      !/^[a-f0-9]{64}$/.test(created.response_digest)
    ) {
      journal.push({
        operation: "create_project",
        status: "failed",
        identifier: typeof created.id === "string" ? created.id : undefined,
        project_number: Number.isSafeInteger(created.number) ? created.number : undefined,
        error: `project create returned incomplete durable identity; response_digest=${digest(createOutput)}`,
      });
      throw new ReconciliationError("project create returned incomplete durable identity");
    }
    projectNumber = Number(created.number);
    projectId = created.id;
    createdProject = true;
    const durableIdentity: DurableCreateIdentity = {
      plan_digest: planDigest(plan),
      client_mutation_id: created.client_mutation_id,
      intent_timestamp: createIntent.intent_timestamp,
      response_timestamp: created.response_timestamp,
      ...(created.provider_request_id ? { provider_request_id: created.provider_request_id } : {}),
      ...(created.provider_response_id ? { provider_response_id: created.provider_response_id } : {}),
      project_node_id: projectId,
      project_number: projectNumber,
      response_digest: created.response_digest,
    };
    await persistCreateResponse(durableIdentity);
    journal.push({
      operation: "create_project",
      status: "applied",
      identifier: projectId,
      project_number: projectNumber,
      durable_identity: durableIdentity,
    });
    const snapshot = await liveSnapshot(plan);
    const selected = snapshot.projects.filter((project) => project.id === projectId);
    const sameTarget = snapshot.projects.filter(
      (project) => project.title.trim() === plan.target.title && (project.key ?? plan.target.key) === plan.target.key,
    );
    if (selected.length !== 1 || sameTarget.length !== 1)
      throw new ReconciliationError("fresh project read found missing or ambiguous created Project identity");
    if (selected[0].number !== projectNumber)
      throw new ReconciliationError("fresh project read changed created Project number");
  }

  if (createdProject) {
    await runGh([
      "project",
      "link",
      String(projectNumber),
      "--owner",
      plan.target.owner,
      "--repo",
      `${plan.target.owner}/${plan.target.repository}`,
    ]);
    journal.push({
      operation: "link_repository",
      status: "applied",
      identifier: `${plan.target.owner}/${plan.target.repository}`,
    });
  } else {
    journal.push({
      operation: "link_repository",
      status: "skipped",
      identifier: `${plan.target.owner}/${plan.target.repository}`,
    });
  }

  let current = requireSelectedParent(await readLiveComparison(plan), projectId, projectNumber, "status");
  const statusFields = (current.fields as Obj[]).filter((field) => String(field.name).toLowerCase() === "status");
  if (statusFields.length > 1) throw new ReconciliationError("live status field identity is ambiguous");
  const status = statusFields[0];
  if (!status) {
    await runGh([
      "project",
      "field-create",
      String(projectNumber),
      "--owner",
      plan.target.owner,
      "--name",
      "Status",
      "--data-type",
      "SINGLE_SELECT",
      "--single-select-options",
      plan.lanes.join(","),
    ]);
    journal.push({ operation: "create_status", status: "applied" });
  } else if (
    status.type !== "SINGLE_SELECT" ||
    (status.__typename !== undefined && status.__typename !== "ProjectV2SingleSelectField")
  ) {
    throw new ReconciliationError("live Status field has an unsupported field type");
  } else if (
    JSON.stringify((status.options as Obj[]).map((option) => String(option.name))) !== JSON.stringify(plan.lanes)
  ) {
    const existing = (status.options as Obj[]).map((option) => ({
      id: option.id,
      name: option.name,
      color: String(option.color),
      description: String(option.description),
    }));
    const options = plan.lanes.map((name, index) => ({
      ...(existing.find((option) => option.name === name) ?? {}),
      name,
      color: existing.find((option) => option.name === name)?.color ?? STATUS_COLORS[index]!,
      description: existing.find((option) => option.name === name)?.description ?? `Execution lane: ${name}`,
    }));
    const mutation =
      "mutation($input:UpdateProjectV2FieldInput!){updateProjectV2Field(input:$input){projectV2Field{... on ProjectV2SingleSelectField{id name dataType options{id name color description}}}}}";
    const mutationResult = await graphql<{
      data: {
        updateProjectV2Field: {
          projectV2Field: {
            id: string;
            name: string;
            dataType: string;
            options: Array<{ id: string; name: string; color: string; description: string }>;
          } | null;
        } | null;
      };
    }>(
      {
        query: mutation,
        variables: { input: { fieldId: status.id, singleSelectOptions: options } },
      },
      "Status field update",
    );
    const updatedField = mutationResult.data.updateProjectV2Field?.projectV2Field;
    if (
      !updatedField ||
      updatedField.id !== status.id ||
      updatedField.name !== "Status" ||
      updatedField.dataType !== "SINGLE_SELECT" ||
      !Array.isArray(updatedField.options) ||
      updatedField.options.length !== plan.lanes.length ||
      updatedField.options.some(
        (option, index) =>
          typeof option.id !== "string" ||
          option.id === "" ||
          (options[index]?.id !== undefined && option.id !== options[index]?.id) ||
          option.name !== options[index]?.name ||
          option.color !== options[index]?.color ||
          option.description !== options[index]?.description,
      )
    )
      throw new ReconciliationError("Status field update returned incomplete GraphQL data");
    journal.push({ operation: "update_status", status: "applied", identifier: String(status.id) });
  }
  current = requireSelectedParent(await readLiveComparison(plan), projectId, projectNumber, "status-after");

  const actualItems = current.items as Obj[];
  const missingIssues = plan.issues.filter(
    (issue) =>
      !actualItems.some(
        (item) =>
          item.issue_number === String(issue.number) &&
          item.repository === `${plan.target.owner}/${plan.target.repository}`,
      ),
  );
  for (const issue of missingIssues) {
    const issueUrl = `https://${plan.target.host}/${plan.target.owner}/${plan.target.repository}/issues/${issue.number}`;
    await runGh([
      "project",
      "item-add",
      String(projectNumber),
      "--owner",
      plan.target.owner,
      "--url",
      issueUrl,
      "--format",
      "json",
    ]);
    journal.push({ operation: `issue:${issue.number}`, status: "applied", identifier: issueUrl });
  }
  current = requireSelectedParent(await readLiveComparison(plan), projectId, projectNumber, "items-after");

  const actualLabels = current.labels as Obj[];
  for (const issue of plan.issues) {
    for (const label of issue.labels) {
      const existing = actualLabels.find((candidate) => candidate.name === label.toLowerCase());
      if (!existing) {
        await runGh([
          "label",
          "create",
          label,
          "--repo",
          `${plan.target.owner}/${plan.target.repository}`,
          "--force",
          "--color",
          "BFD4F2",
        ]);
      }
      if (!existing || !(existing.issue_numbers as string[]).includes(String(issue.number))) {
        await runGh([
          "issue",
          "edit",
          String(issue.number),
          "--repo",
          `${plan.target.owner}/${plan.target.repository}`,
          "--add-label",
          label,
        ]);
        journal.push({ operation: `label:${label}:issue:${issue.number}`, status: "applied" });
      }
    }
  }
  current = requireSelectedParent(await readLiveComparison(plan), projectId, projectNumber, "labels-after");

  const actualEdges = current.dependencies as Obj[];
  for (const edge of plan.dependencies) {
    if (
      !actualEdges.some(
        (candidate) =>
          candidate.source === String(edge.source) &&
          candidate.target === String(edge.target) &&
          candidate.kind === edge.kind,
      )
    ) {
      await runGh([
        "api",
        "--method",
        "POST",
        `repos/${plan.target.owner}/${plan.target.repository}/issues/${edge.source}/dependencies/blocked_by`,
        "-f",
        `issue_id=${edge.target}`,
      ]);
      journal.push({ operation: `dependency:${edge.source}->${edge.target}`, status: "applied" });
    }
  }
  requireSelectedParent(await readLiveComparison(plan), projectId, projectNumber, "dependencies-after");
}

async function writeEvidence(
  dir: string,
  result: Obj,
  comparison: Comparison,
  journal: JournalEntry[],
  planPath: string,
): Promise<void> {
  const root = resolve(dir);
  await mkdir(root, { recursive: true });
  const resultPath = `${root}/project-result.v1.json`;
  const comparisonPath = `${root}/project-comparison.v1.json`;
  const journalPath = `${root}/mutation-journal.v1.json`;
  const safeJournal = journal.map((entry) => {
    const safe = redactText(JSON.stringify(entry));
    return parseOutput<JournalEntry>(safe.value, "redacted journal entry");
  });
  const safeResult = parseOutput<Obj>(redactText(JSON.stringify(result)).value, "redacted result");
  await writeFile(resultPath, `${JSON.stringify(safeResult, null, 2)}\n`);
  await writeFile(comparisonPath, `${JSON.stringify(comparison, null, 2)}\n`);
  await writeFile(
    journalPath,
    `${JSON.stringify({ schema_version: "mutation-journal.v1", status: result.status, entries: safeJournal }, null, 2)}\n`,
  );
  const digests = {
    schema_version: "test-digests.v1",
    status: result.status,
    live_vs_fixture: FIXTURE_PATH ? "fixture" : "live",
    files: Object.fromEntries(
      await Promise.all(
        [planPath, resultPath, comparisonPath, journalPath].map(async (path) => [
          path,
          createHash("sha256")
            .update(await readFile(path))
            .digest("hex"),
        ]),
      ),
    ),
  };
  await writeFile(`${root}/test-digests.v1.json`, `${JSON.stringify(digests, null, 2)}\n`);
}

function evidenceFields(
  status: string,
  retryAuthorization: RetryAuthorization | null,
  secondReadConsistency: boolean,
  redaction: RedactionState = { secret_status: "clean", redaction_status: "clean" },
): Obj {
  const effectiveRedaction = runtimeRedactionObserved
    ? { secret_status: "detected" as const, redaction_status: "redacted" as const }
    : redaction;
  const retryAuthorized = RETRY > 0 && retryAuthorization?.authorized === true;
  return {
    retry_authorized: retryAuthorized,
    retry_authorization: retryAuthorized
      ? {
          schema_version: retryAuthorization.schema_version,
          authorized: retryAuthorization.authorized,
          current_turn_only: retryAuthorization.current_turn_only,
          owner: retryAuthorization.owner,
          expires: retryAuthorization.expires,
          plan_digest: retryAuthorization.plan_digest,
        }
      : null,
    lane_state: status,
    secret_status: effectiveRedaction.secret_status,
    redaction_status: effectiveRedaction.redaction_status,
    second_read_consistency: secondReadConsistency,
    secret_redaction_status: effectiveRedaction.redaction_status,
    live_vs_fixture_classification: {
      live: FIXTURE_PATH ? "blocked" : "executed",
      fixture: FIXTURE_PATH ? "executed" : "not_run",
    },
  };
}

async function main(): Promise<void> {
  if (!PLAN_PATH) fail("--plan is required");
  const plan = parsePlan(parseOutput(await readFile(resolve(PLAN_PATH), "utf8"), `plan ${PLAN_PATH}`));
  let retryAuthorization: RetryAuthorization | null = null;
  const authorizationFailures: string[] = [];
  if (RETRY > 0) {
    try {
      retryAuthorization = await loadRetryAuthorization(plan);
    } catch (error) {
      authorizationFailures.push(`retry_authorization_invalid:${message(error)}`);
    }
  }
  if (RETRY > 0 && !retryAuthorization && authorizationFailures.length === 0)
    authorizationFailures.push("retry_authorization_missing");
  const journal: JournalEntry[] = [];
  let persistedCreateIntent: CreateIntent | null = null;
  let persistedCreateIdentity: DurableCreateIdentity | null = null;
  try {
    persistedCreateIntent = await loadCreateIntent(plan);
    persistedCreateIdentity = await loadCreateResponse(plan, persistedCreateIntent);
  } catch (error) {
    journal.push({ operation: "load_create_evidence", status: "failed", error: safeError(error) });
    authorizationFailures.push("create_evidence_read_error");
  }
  let snapshot: Snapshot;
  let fixture: { state: Snapshot; fail_operations: string[]; second_read_inconsistent: boolean } | undefined;
  let before: Comparison;
  try {
    if (FIXTURE_PATH) {
      fixture = await loadFixture(FIXTURE_PATH);
      snapshot = fixture.state;
    } else snapshot = await liveSnapshot(plan);
    before = compare(snapshot, plan);
  } catch (error) {
    const failures =
      error instanceof LiveReadError
        ? error.evidence.map((entry) => redactText(entry).value)
        : [`snapshot_read_error:${safeError(error)}`];
    const comparison = hardFailureComparison(plan, failures);
    const result: Obj = {
      schema_version: "project-result.v1",
      status: "hard_failure",
      live_vs_fixture: FIXTURE_PATH ? "fixture" : "live",
      mutation_authorized: false,
      target: plan.target,
      comparison_digest: comparison.comparison_digest,
      second_read: null,
      missing_children: [],
      failures,
      partial_failure: null,
      partial_project_ids: [],
      create_intent: null,
      durable_create_identity: null,
      retry_count: RETRY,
      journal_entries: 0,
      ...evidenceFields("hard_failure", retryAuthorization, false, redactionState({ failures })),
      inventory: comparison.inventory,
    };
    const serializedResult = redactText(JSON.stringify(result));
    const serializedRedaction: RedactionState = serializedResult.redacted
      ? { secret_status: "detected", redaction_status: "redacted" }
      : { secret_status: "clean", redaction_status: "clean" };
    const safeResult = {
      ...parseOutput<Obj>(serializedResult.value, "serialized result"),
      secret_status: serializedRedaction.secret_status,
      redaction_status: serializedRedaction.redaction_status,
      secret_redaction_status: serializedRedaction.redaction_status,
    };
    if (EVIDENCE_DIR) await writeEvidence(EVIDENCE_DIR, safeResult, comparison, journal, resolve(PLAN_PATH));
    process.stdout.write(`${JSON.stringify(safeResult)}\n`);
    process.exitCode = 1;
    return;
  }
  let status: "ready" | "bootstrap_required" | "incomplete" | "hard_failure" = before.classification;
  let partialFailure: string | null = null;
  const runtimeFailures: string[] = [];
  runtimeFailures.push(...authorizationFailures);
  try {
    verifyPersistedCreateIdentity(persistedCreateIdentity, before);
  } catch (error) {
    runtimeFailures.push(`reconciliation_error:${safeError(error)}`);
  }
  if (before.classification === "bootstrap_required" && !DRY_RUN && runtimeFailures.length === 0) {
    if (CONFIRM !== "APPLY") fail("bootstrap_required requires --confirm APPLY; no mutation performed");
    if (fixture) {
      for (let attempt = 0; attempt <= RETRY; attempt += 1) {
        try {
          await applyFixture(plan, fixture, journal, persistedCreateIdentity);
          await saveFixture(FIXTURE_PATH, fixture);
          partialFailure = null;
          break;
        } catch (error) {
          partialFailure = safeError(error);
          await saveFixture(FIXTURE_PATH, fixture);
          if (attempt === RETRY) break;
          if (!retryAuthorization) {
            partialFailure = "retry authorization is required before another attempt";
            break;
          }
          if (hasUnsafeCreateJournalEntry(journal)) {
            partialFailure = "durable create identity is incomplete before retry";
            break;
          }
          journal.push({ operation: `retry:${attempt + 1}`, status: "planned" });
        }
      }
      if (partialFailure) {
        status = "incomplete";
      }
    } else {
      for (let attempt = 0; attempt <= RETRY; attempt += 1) {
        try {
          const currentBefore = await readLiveComparison(plan);
          if (currentBefore.classification === "hard_failure") {
            runtimeFailures.push(...currentBefore.failures);
            status = "hard_failure";
            break;
          }
          if (hasUnsafeCreateJournalEntry(journal)) {
            partialFailure = "ambiguous create identity blocks retry";
            break;
          }
          await applyLive(plan, currentBefore, journal, persistedCreateIdentity);
          partialFailure = null;
          break;
        } catch (error) {
          if (error instanceof LiveReadError || error instanceof ReconciliationError) {
            runtimeFailures.push(
              ...(error instanceof LiveReadError
                ? error.evidence.map((entry) => redactText(entry).value)
                : [`reconciliation_error:${safeError(error)}`]),
            );
            status = "hard_failure";
            partialFailure = safeError(error);
            break;
          }
          partialFailure = safeError(error);
          if (attempt === RETRY) break;
          if (!retryAuthorization) {
            partialFailure = "retry authorization is required before another attempt";
            break;
          }
          if (hasUnsafeCreateJournalEntry(journal)) {
            partialFailure = "durable create identity is incomplete before retry";
            break;
          }
          journal.push({ operation: `retry:${attempt + 1}`, status: "planned" });
        }
      }
      if (partialFailure && status !== "hard_failure") {
        status = "incomplete";
      }
    }
  }
  if (before.classification === "ready") {
    journal.push({ operation: "converged", status: "skipped" });
  }
  if (partialFailure) journal.push({ operation: "partial_failure", status: "failed", error: partialFailure });
  let after: Comparison | null = null;
  let finalComparison: Comparison | null = null;
  let secondReadConsistency = false;
  if (
    status === "ready" ||
    status === "incomplete" ||
    (before.classification === "bootstrap_required" && !DRY_RUN && !partialFailure)
  ) {
    try {
      after = compare(fixture ? fixture.state : await liveSnapshot(plan), plan);
      const consistencyRead = compare(fixture ? fixture.state : await liveSnapshot(plan), plan);
      finalComparison = consistencyRead;
      runtimeFailures.push(...after.failures, ...consistencyRead.failures);
      secondReadConsistency =
        !fixture?.second_read_inconsistent &&
        after.classification !== "hard_failure" &&
        consistencyRead.classification !== "hard_failure" &&
        consistencyRead.comparison_digest === after.comparison_digest;
      if (!secondReadConsistency) runtimeFailures.push("inconsistent_second_reads");
    } catch (error) {
      if (error instanceof LiveReadError)
        runtimeFailures.push(...error.evidence.map((entry) => redactText(entry).value));
      partialFailure = partialFailure ?? safeError(error);
    }
  }
  if (runtimeFailures.length > 0) status = "hard_failure";
  else if (!partialFailure && after) status = after.classification;
  try {
    persistedCreateIntent = await loadCreateIntent(plan);
  } catch {
    persistedCreateIntent = null;
  }
  const resultFailures = [...new Set([...before.failures, ...runtimeFailures])];
  const durableCreateIdentity =
    persistedCreateIdentity ??
    journal.find((entry) => entry.operation === "create_project" && entry.durable_identity)?.durable_identity ??
    null;
  const result: Obj = {
    schema_version: "project-result.v1",
    status,
    live_vs_fixture: FIXTURE_PATH ? "fixture" : "live",
    mutation_authorized:
      CONFIRM === "APPLY" &&
      !DRY_RUN &&
      before.classification === "bootstrap_required" &&
      runtimeFailures.length === 0 &&
      status !== "hard_failure",
    target: plan.target,
    comparison_digest: before.comparison_digest,
    second_read: after
      ? {
          classification: after.classification,
          comparison_digest: after.comparison_digest,
          converged: after.classification === "ready",
        }
      : null,
    missing_children: (finalComparison ?? after ?? before).missing_children,
    failures: resultFailures,
    partial_failure: partialFailure,
    partial_project_ids: journal
      .filter((entry) => entry.operation === "create_project" && entry.identifier)
      .map((entry) => ({ id: String(entry.identifier), number: entry.project_number ?? null })),
    retry_count: RETRY,
    journal_entries: journal.length,
    create_intent: persistedCreateIntent,
    durable_create_identity: durableCreateIdentity,
    ...evidenceFields(
      status,
      retryAuthorization,
      secondReadConsistency,
      redactionState({ failures: resultFailures, partial_failure: partialFailure, journal }),
    ),
    inventory: (finalComparison ?? after ?? before).inventory,
  };
  const serializedResult = redactText(JSON.stringify(result));
  const serializedRedaction: RedactionState = serializedResult.redacted
    ? { secret_status: "detected", redaction_status: "redacted" }
    : { secret_status: "clean", redaction_status: "clean" };
  const safeResult = {
    ...parseOutput<Obj>(serializedResult.value, "serialized result"),
    secret_status: serializedRedaction.secret_status,
    redaction_status: serializedRedaction.redaction_status,
    secret_redaction_status: serializedRedaction.redaction_status,
  };
  if (EVIDENCE_DIR)
    await writeEvidence(EVIDENCE_DIR, safeResult, finalComparison ?? after ?? before, journal, resolve(PLAN_PATH));
  process.stdout.write(`${JSON.stringify(safeResult)}\n`);
  if (status === "hard_failure" || status === "incomplete") process.exitCode = 1;
}

await main().catch((error) => {
  process.stderr.write(`error: ${message(error)}\n`);
  process.exitCode = 1;
});
