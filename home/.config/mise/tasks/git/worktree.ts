#!/usr/bin/env bun
//MISE description="Create, report, or remove a git worktree"
//MISE alias="gwt"
//MISE dir="{{cwd}}"
//USAGE arg "[name]" help="Branch-like name for the worktree; --delete also offers ALL_CLOSED_PRS and ALL_STALE_WORKTREES"
//USAGE flag "-c --closed-prs" help="Report worktrees for closed PRs; combine with --delete to apply removal"
//USAGE flag "-d --delete" help="Apply a removal; use with --stale or --closed-prs"
//USAGE flag "-p --pull-request <pull-request>" help="Create a worktree from an open PR, or target PR worktrees with --delete"
//USAGE flag "-r --release <path>" help="Mark a registered worktree released without removing it"
//USAGE flag "-s --stale" help="Report stale worktrees; combine with --delete to apply removal"

import { spawn, spawnSync } from "child_process";
import { createHash } from "crypto";
import { existsSync, readFileSync, realpathSync } from "fs";
import { createInterface } from "readline";
import { resolve } from "path";
import { resolveUpstreamContext } from "../../utils/git.js";

type WorktreeEntry = {
  name: string;
  path: string;
  branch: string;
};

type PorcelainEntry = {
  path: string;
  head: string;
  branch: string;
  detached: boolean;
  bare: boolean;
  locked: boolean;
  prunable: boolean;
  parseError?: string;
};

type MetadataRecord = {
  id: string;
  path: string;
  registeredAt: string;
  lastSeenAt: string;
  leaseUntil: string;
  releasedAt: string;
  ref: string;
  head: string;
  state: "active" | "released";
  fingerprint: string;
  releasePendingAt?: string;
  releaseRecoveryFailed?: string;
};

type StaleRow = {
  label: "ELIGIBLE" | "QUARANTINE" | "UNKNOWN";
  path: string;
  id: string;
  ref: string;
  reason: string;
  entry?: PorcelainEntry;
  record?: MetadataRecord;
  prState?: string;
};

type PullRequestListItem = {
  number: number;
  title: string;
  branch: string;
};

type PullRequestInventory = {
  ok: boolean;
  open: PullRequestListItem[];
  closed: PullRequestListItem[];
  error?: string;
};

type ClosedPrRow = {
  label: "ELIGIBLE" | "QUARANTINE" | "UNKNOWN";
  path: string;
  id: string;
  ref: string;
  reason: string;
  entry?: PorcelainEntry;
  record?: MetadataRecord;
  prState?: PullRequestState;
};

const ALL_CLOSED_PRS_KEYWORD = "ALL_CLOSED_PRS";
const ALL_STALE_WORKTREES_KEYWORD = "ALL_STALE_WORKTREES";
const STALE_NAMESPACE = "worktree.cleanup.v1.";
const REQUIRED_METADATA_FIELDS = [
  "path",
  "registeredAt",
  "lastSeenAt",
  "leaseUntil",
  "releasedAt",
  "ref",
  "head",
  "state",
] as const;

class TaskExitError extends Error {
  readonly code: number;

  constructor(code: number, message: string) {
    super(message);
    this.code = code;
  }
}

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function runCapture(command: string, args: string[], cwd?: string): string {
  const result = spawnSync(command, args, { encoding: "utf-8", cwd });
  if (result.status !== 0) {
    const stderr = result.stderr?.trim();
    const stdout = result.stdout?.trim();
    throw new Error(stderr || stdout || `${command} ${args.join(" ")} failed`);
  }
  return result.stdout ?? "";
}

/** Run a Git or helper command while retaining its exit result. */
function runCaptureResult(command: string, args: string[], cwd?: string, options?: { maxBuffer?: number }) {
  return spawnSync(command, args, { encoding: "utf-8", cwd, ...options });
}

function runInherit(command: string, args: string[], cwd?: string): void {
  const result = spawnSync(command, args, { stdio: "inherit", cwd });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed`);
  }
}

function commandExists(command: string): boolean {
  const result = spawnSync("which", [command], { stdio: "ignore" });
  return result.status === 0;
}

/** Accept both linked worktrees and bare Git repositories as task roots. */
function ensureInsideGitRepo(): void {
  const result = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], {
    encoding: "utf-8",
  });
  const bare = spawnSync("git", ["rev-parse", "--is-bare-repository"], {
    encoding: "utf-8",
  });
  if (
    (result.status !== 0 || result.stdout?.trim() !== "true") &&
    (bare.status !== 0 || bare.stdout?.trim() !== "true")
  ) {
    throw new Error(
      `not inside a git working tree (cwd: ${process.cwd()}). cd into a git checkout before running this task.`,
    );
  }
}

function ensureCommand(command: string, reason: string): void {
  if (!commandExists(command)) {
    throw new Error(`${command} is required for ${reason}.`);
  }
}

function miseTaskExists(task: string): boolean {
  const result = spawnSync("mise", ["tasks", "info", task], {
    stdio: "ignore",
  });
  return result.status === 0;
}

function isValidName(name: string): boolean {
  return /^[a-zA-Z0-9._/-]+$/.test(name);
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

/** Resolve a path without changing literal POSIX backslashes. */
function canonicalPath(pathLike: string): string {
  const absolutePath = resolve(pathLike);
  const normalize = (value: string): string => (process.platform === "win32" ? value.replaceAll("\\", "/") : value);
  try {
    const nativeRealpath = (
      realpathSync as typeof realpathSync & {
        native?: (path: string) => string;
      }
    ).native;
    return normalize(nativeRealpath ? nativeRealpath(absolutePath) : realpathSync(absolutePath));
  } catch {
    return normalize(absolutePath);
  }
}

function worktreeId(path: string): string {
  return createHash("sha256").update(path, "utf8").digest("hex");
}

function timestampNow(): string {
  return new Date().toISOString();
}

function isTimestamp(value: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)) return false;
  const parsed = Date.parse(value);
  return Number.isFinite(parsed) && new Date(parsed).toISOString() === value;
}

function isValidStaleId(value: string): boolean {
  return /^[0-9a-f]{64}$/.test(value);
}

function isValidWorktreeRef(value: string): boolean {
  return /^refs\/heads\/[^\s]+$/.test(value) && !value.includes("..") && !value.includes("@{");
}

function isValidWorktreeHead(value: string): boolean {
  return /^[0-9a-f]{40}(?:[0-9a-f]{24})?$/.test(value);
}

/** Read every local Git config value, including configured empty values. */
function configGetAll(key: string): string[] {
  const result = runCaptureResult("git", ["config", "--local", "--get-all", key]);
  if (result.status !== 0) return [];
  const output = String(result.stdout ?? "");
  const withoutFinalDelimiter = output.endsWith("\n") ? output.slice(0, -1) : output;
  return withoutFinalDelimiter === "" && output === "" ? [] : withoutFinalDelimiter.split("\n");
}

function configSet(key: string, value: string): void {
  const result = runCaptureResult("git", ["config", "--local", "--replace-all", key, value]);
  if (result.status !== 0) {
    throw new Error(String(result.stderr ?? "").trim() || `could not write git config key ${key}`);
  }
}

function metadataFingerprint(record: Omit<MetadataRecord, "fingerprint">): string {
  return JSON.stringify(REQUIRED_METADATA_FIELDS.map((field) => [field, record[field]]));
}

/** Parse and validate the Git-local worktree cleanup registry. */
function parseMetadataRecords(): {
  valid: MetadataRecord[];
  invalid: Array<{ id: string; path: string; reason: string }>;
  duplicateIds: Set<string>;
} {
  const result = runCaptureResult("git", ["config", "--local", "--null", "--get-regexp", `^${STALE_NAMESPACE}`]);
  if (result.status !== 0 && result.status !== 1) {
    throw new Error(String(result.stderr ?? "").trim() || "could not read worktree cleanup metadata");
  }

  const fields = new Map<string, Map<string, string[]>>();
  const output = String(result.stdout ?? "");
  const fieldsOutput = output.includes("\0") ? output.split("\0") : output.split("\n");
  for (const fieldOutput of fieldsOutput) {
    if (!fieldOutput) continue;
    const separator = fieldOutput.indexOf(output.includes("\0") ? "\n" : " ");
    if (separator <= 0) continue;
    const normalizedKey = fieldOutput.slice(0, separator);
    const value = fieldOutput.slice(separator + 1);
    if (!normalizedKey) continue;
    const suffix = normalizedKey.slice(STALE_NAMESPACE.length);
    const dot = suffix.indexOf(".");
    if (dot <= 0) continue;
    const id = suffix.slice(0, dot);
    const field = suffix.slice(dot + 1);
    const normalizedField = field.toLowerCase();
    const idFields = fields.get(id) ?? new Map<string, string[]>();
    idFields.set(normalizedField, [...(idFields.get(normalizedField) ?? []), value]);
    fields.set(id, idFields);
  }

  const valid: MetadataRecord[] = [];
  const invalid: Array<{ id: string; path: string; reason: string }> = [];
  const duplicateIds = new Set<string>();
  const seenPaths = new Map<string, string>();

  for (const [id, idFields] of fields) {
    const value = (field: string) => idFields.get(field.toLowerCase()) ?? [];
    const path = value("path")[0] ?? "";
    const invalidReason = (reason: string) => invalid.push({ id, path, reason });
    if (!isValidStaleId(id)) {
      invalidReason("invalid metadata id");
      continue;
    }
    if (REQUIRED_METADATA_FIELDS.some((field) => value(field).length !== 1)) {
      invalidReason("missing or duplicate metadata field");
      continue;
    }
    const record = {
      id,
      path,
      registeredAt: value("registeredAt")[0] ?? "",
      lastSeenAt: value("lastSeenAt")[0] ?? "",
      leaseUntil: value("leaseUntil")[0] ?? "",
      releasedAt: value("releasedAt")[0] ?? "",
      ref: value("ref")[0] ?? "",
      head: value("head")[0] ?? "",
      state: value("state")[0] as "active" | "released",
      releasePendingAt: value("releasePendingAt")[0],
      releaseRecoveryFailed: value("releaseRecoveryFailed")[0],
    };
    if (value("releasePendingAt").length > 1 || value("releaseRecoveryFailed").length > 1) {
      invalidReason("duplicate release recovery metadata");
      continue;
    }
    if (canonicalPath(record.path) !== record.path || worktreeId(record.path) !== id) {
      invalidReason("metadata path or id mismatch");
      continue;
    }
    if (
      !isTimestamp(record.registeredAt) ||
      !isTimestamp(record.lastSeenAt) ||
      !isTimestamp(record.leaseUntil) ||
      (record.releasedAt !== "" && !isTimestamp(record.releasedAt)) ||
      (record.releasePendingAt !== undefined && record.releasePendingAt !== "" && !isTimestamp(record.releasePendingAt))
    ) {
      invalidReason("invalid metadata timestamp");
      continue;
    }
    if (!isValidWorktreeRef(record.ref) || !isValidWorktreeHead(record.head)) {
      invalidReason("invalid metadata ref or HEAD");
      continue;
    }
    if (!["active", "released"].includes(record.state)) {
      invalidReason("invalid metadata state");
      continue;
    }
    if (
      record.releaseRecoveryFailed ||
      record.releasePendingAt ||
      (record.state === "active" && record.releasedAt !== "") ||
      (record.state === "released" && !record.releasedAt)
    ) {
      invalidReason("inconsistent metadata state");
      continue;
    }
    const existingPath = seenPaths.get(record.path);
    if (existingPath && existingPath !== id) {
      duplicateIds.add(existingPath);
      duplicateIds.add(id);
      invalidReason("duplicate metadata path");
      continue;
    }
    seenPaths.set(record.path, id);
    const complete = { ...record, fingerprint: "" };
    valid.push({ ...complete, fingerprint: metadataFingerprint(complete) });
  }

  const pathsById = new Map<string, Set<string>>();
  for (const record of valid) {
    const paths = pathsById.get(record.id) ?? new Set<string>();
    paths.add(record.path);
    pathsById.set(record.id, paths);
  }
  for (const [id, paths] of pathsById) {
    if (paths.size > 1) duplicateIds.add(id);
  }

  return { valid, invalid, duplicateIds };
}

/** Register a newly created or intentionally reused worktree. */
function registerWorktree(path: string, ref: string, head: string, reuseExisting = false): void {
  if (!isValidWorktreeRef(ref) || !isValidWorktreeHead(head)) {
    throw new Error("cannot register worktree with an empty or malformed ref or HEAD.");
  }
  const canonical = canonicalPath(path);
  const id = worktreeId(canonical);
  const now = timestampNow();
  const records = parseMetadataRecords();
  const existing = records.valid.find((record) => record.id === id && record.path === canonical);
  const reused = reuseExisting && existing?.state === "active" && existing.ref === ref && existing.head === head;
  const record = {
    id,
    path: canonical,
    registeredAt: reused ? existing.registeredAt : now,
    lastSeenAt: now,
    leaseUntil: reused ? existing.leaseUntil : now,
    releasedAt: "",
    ref,
    head,
    state: "active",
  } satisfies Omit<MetadataRecord, "fingerprint">;
  for (const field of REQUIRED_METADATA_FIELDS) {
    configSet(`${STALE_NAMESPACE}${id}.${field}`, record[field]);
  }
}

/** Remove all values for an optional Git-local recovery key. */
function configUnsetAll(key: string): void {
  const result = runCaptureResult("git", ["config", "--local", "--unset-all", key]);
  if (result.status !== 0 && result.status !== 5) {
    throw new Error(String(result.stderr ?? "").trim() || `could not remove git config key ${key}`);
  }
}

/** Compare a release candidate with its captured active or released record. */
function releaseRecordMatches(
  candidate: MetadataRecord | undefined,
  expected: MetadataRecord,
  released: boolean,
): boolean {
  if (!candidate || candidate.path !== expected.path || candidate.id !== expected.id) return false;
  if (
    candidate.registeredAt !== expected.registeredAt ||
    candidate.lastSeenAt !== expected.lastSeenAt ||
    candidate.leaseUntil !== expected.leaseUntil ||
    candidate.ref !== expected.ref ||
    candidate.head !== expected.head
  ) {
    return false;
  }
  if (released) {
    return candidate.state === "released" && isTimestamp(candidate.releasedAt);
  }
  return candidate.state === "active" && candidate.releasedAt === "";
}

/** Restore the complete active record after an interrupted release. */
function restoreReleaseRecord(record: MetadataRecord): void {
  for (const field of REQUIRED_METADATA_FIELDS) {
    configSet(`${STALE_NAMESPACE}${record.id}.${field}`, record[field]);
  }
  configUnsetAll(`${STALE_NAMESPACE}${record.id}.releasePendingAt`);
  configUnsetAll(`${STALE_NAMESPACE}${record.id}.releaseRecoveryFailed`);
}

/** Commit a release through recoverable metadata transitions. */
function writeRelease(record: MetadataRecord, now = timestampNow()): void {
  if (
    record.state !== "active" ||
    record.releasedAt !== "" ||
    record.releasePendingAt ||
    record.releaseRecoveryFailed
  ) {
    throw new Error("release metadata is not in a valid active state; manual recovery is required.");
  }

  const namespace = `${STALE_NAMESPACE}${record.id}`;
  try {
    configSet(`${namespace}.releasePendingAt`, now);
    configSet(`${namespace}.releasedAt`, now);
    configSet(`${namespace}.state`, "released");
    configUnsetAll(`${namespace}.releasePendingAt`);
    configUnsetAll(`${namespace}.releaseRecoveryFailed`);
    const records = parseMetadataRecords();
    const completed = records.valid.find((candidate) => candidate.id === record.id);
    if (!releaseRecordMatches(completed, record, true)) {
      throw new Error("released metadata did not match the captured record.");
    }
  } catch (error) {
    let restored = false;
    try {
      const current = parseMetadataRecords().valid.find((candidate) => candidate.id === record.id);
      if (releaseRecordMatches(current, record, true)) return;
      restoreReleaseRecord(record);
      const restoredRecord = parseMetadataRecords().valid.find((candidate) => candidate.id === record.id);
      restored = releaseRecordMatches(restoredRecord, record, false);
    } catch {
      restored = false;
    }
    if (!restored) {
      try {
        configSet(`${namespace}.releaseRecoveryFailed`, "manual-recovery-required");
      } catch {
        // The original write error is the useful failure when config is unavailable.
      }
      throw new Error(`release metadata recovery failed; manual recovery is required: ${getErrorMessage(error)}`);
    }
    throw error;
  }
}

function readStaleAfterDays(): { value: number; error?: string } {
  const configuredValues = configGetAll("worktree.cleanup.staleAfterDays");
  if (configuredValues.length === 0) return { value: 30 };
  if (configuredValues.length !== 1) return { value: 30, error: "invalid staleAfterDays configuration" };
  const configured = configuredValues[0] ?? "";
  if (!/^\d+$/.test(configured)) return { value: 30, error: "invalid staleAfterDays configuration" };
  const value = Number.parseInt(configured, 10);
  if (!Number.isInteger(value) || value < 1 || value > 3650) {
    return { value: 30, error: "invalid staleAfterDays configuration" };
  }
  return { value };
}

/** Parse NUL-framed Git worktree inventory without losing path bytes. */
function parsePorcelainWorktrees(output: string): PorcelainEntry[] {
  const entries: PorcelainEntry[] = [];
  let current: Partial<PorcelainEntry> | undefined;
  const errors: string[] = [];
  const flush = () => {
    if (!current) return;
    const path = String(current.path ?? "");
    if (!path) {
      entries.push({
        path: "",
        head: "",
        branch: "",
        detached: false,
        bare: false,
        locked: false,
        prunable: false,
        parseError: "missing worktree marker",
      });
    } else {
      entries.push({
        path,
        head: String(current.head ?? ""),
        branch: String(current.branch ?? ""),
        detached: Boolean(current.detached),
        bare: Boolean(current.bare),
        locked: Boolean(current.locked),
        prunable: Boolean(current.prunable),
        parseError: errors.length > 0 ? errors.join("; ") : undefined,
      });
    }
    current = undefined;
    errors.length = 0;
  };

  const nulFramed = output.includes("\0");
  const records = nulFramed ? output.split("\0\0") : output.split("\n\n");
  for (const record of records) {
    if (!record) {
      flush();
      continue;
    }
    const fields = nulFramed ? record.split("\0") : record.split("\n");
    for (const field of fields) {
      if (!field) continue;
      const separator = field.indexOf(" ");
      const marker = separator < 0 ? field : field.slice(0, separator);
      const value = separator < 0 ? "" : field.slice(separator + 1);
      if (marker === "worktree") {
        if (current?.path !== undefined) errors.push("duplicate worktree marker");
        current ??= {};
        try {
          current.path = value.startsWith('"') && value.endsWith('"') ? JSON.parse(value) : value;
        } catch {
          errors.push("invalid quoted worktree path");
          current.path = value;
        }
      } else {
        current ??= {};
        switch (marker) {
          case "HEAD":
            if (current.head !== undefined) errors.push("duplicate HEAD marker");
            current.head = value;
            break;
          case "branch":
            if (current.branch !== undefined) errors.push("duplicate branch marker");
            current.branch = value;
            break;
          case "detached":
            current.detached = true;
            break;
          case "bare":
            current.bare = true;
            break;
          case "locked":
            current.locked = true;
            break;
          case "prunable":
            current.prunable = true;
            break;
          default:
            errors.push(`unknown marker ${marker}`);
            break;
        }
      }
    }
    flush();
  }
  if (!nulFramed) flush();
  return entries;
}

/** Read the detailed Git worktree inventory. */
function parseDetailedWorktrees(): { entries: PorcelainEntry[]; error?: string } {
  const result = runCaptureResult("git", ["worktree", "list", "--porcelain", "-z"]);
  if (result.status !== 0) {
    return { entries: [], error: String(result.stderr ?? "").trim() || "git worktree list failed" };
  }
  return { entries: parsePorcelainWorktrees(String(result.stdout ?? "")) };
}

/** Resolve the current and main checkout roots from Git inventory. */
function currentRepositoryPaths(entries?: PorcelainEntry[]): { current: string; common: string } {
  const inventory = entries ?? parseDetailedWorktrees().entries;
  const currentResult = runCaptureResult("git", ["rev-parse", "--show-toplevel"]);
  const current =
    currentResult.status === 0 && String(currentResult.stdout ?? "").trim()
      ? canonicalPath(String(currentResult.stdout).trim())
      : "";
  const mainEntry = inventory[0];
  const common = mainEntry?.path ? canonicalPath(mainEntry.path) : "";
  return { current, common };
}

/** Convert Git worktree inventory into the legacy deletion menu shape. */
function parseWorktreeList(repoRoot: string): WorktreeEntry[] {
  const worktrees: WorktreeEntry[] = [];
  const output = runCapture("git", ["worktree", "list", "--porcelain", "-z"]);
  for (const entry of parsePorcelainWorktrees(output)) {
    const path = canonicalPath(entry.path);
    if (!path || path === canonicalPath(repoRoot) || entry.bare) continue;
    const name = path.split("/").filter(Boolean).at(-1) ?? path;
    worktrees.push({
      name,
      path,
      branch: entry.branch.replace(/^refs\/heads\//, ""),
    });
  }
  return worktrees;
}

function resolveWorktreePath(pathLike: string): string {
  return resolve(process.cwd(), pathLike);
}

function findWorktreeByPath(entries: WorktreeEntry[], targetPath: string): WorktreeEntry | undefined {
  return entries.find((entry) => resolve(entry.path) === targetPath);
}

function isGitStatusClean(cwd: string): boolean {
  const status = runCapture("git", ["status", "--porcelain"], cwd);
  return status.trim().length === 0;
}

function pickLineWithFzf(
  lines: string[],
  prompt: string,
  previewCommand: string,
  options?: { multi?: boolean },
): string[] | undefined {
  const fzfArgs = [
    "--height",
    "~100%",
    "--layout",
    "reverse",
    "--border",
    "--prompt",
    prompt,
    "--delimiter",
    "\t",
    "--with-nth",
    "1",
    "--preview",
    previewCommand,
  ];

  if (options?.multi) {
    fzfArgs.push("--multi");
  }

  const result = spawnSync("fzf", fzfArgs, {
    input: `${lines.join("\n")}\n`,
    encoding: "utf-8",
    stdio: ["pipe", "pipe", "inherit"],
  });

  if (result.status !== 0) return undefined;
  return splitFzfOutput(result.stdout ?? "");
}

function pickLineFromPrompt(lines: string[]): string | undefined {
  console.log("Available worktrees:");
  lines.forEach((line, index) => {
    const [name] = line.split("\t");
    console.log(`${index + 1}. ${name ?? ""}`);
  });
  process.stdout.write("\nEnter number to remove: ");
  const input = readFileSync(0, "utf-8").trim();
  const choice = Number.parseInt(input, 10);
  if (!Number.isFinite(choice) || choice < 1 || choice > lines.length) return undefined;
  return lines[choice - 1];
}

function getOpenPullRequests(hostname: string, owner: string, repo: string): PullRequestListItem[] {
  const output = runCapture("gh", [
    "api",
    "--hostname",
    hostname,
    "--jq",
    "[.[] | {number: .number, title: .title, head: {ref: .head.ref}}]",
    `/repos/${owner}/${repo}/pulls?state=open&per_page=100`,
  ]);
  const parsed = JSON.parse(output) as Array<Record<string, unknown>>;
  const prs: PullRequestListItem[] = [];

  for (const pr of parsed) {
    const number = pr["number"];
    if (typeof number !== "number") continue;
    const title = String(pr["title"] ?? "")
      .replaceAll("\t", " ")
      .trim();
    const head = pr["head"] as { ref?: unknown } | undefined;
    const branch = String(head?.ref ?? "")
      .replaceAll("\t", " ")
      .trim();
    prs.push({ number, title, branch });
  }

  return prs;
}

function getClosedPullRequests(hostname: string, owner: string, repo: string): PullRequestListItem[] {
  const output = runCapture("gh", [
    "api",
    "--hostname",
    hostname,
    "--jq",
    "[.[] | {number: .number, title: .title, head: {ref: .head.ref}}]",
    `/repos/${owner}/${repo}/pulls?state=closed&per_page=100`,
  ]);
  const parsed = JSON.parse(output) as Array<Record<string, unknown>>;
  const prs: PullRequestListItem[] = [];

  for (const pr of parsed) {
    const number = pr["number"];
    if (typeof number !== "number") continue;
    const title = String(pr["title"] ?? "")
      .replaceAll("\t", " ")
      .trim();
    const head = pr["head"] as { ref?: unknown } | undefined;
    const branch = String(head?.ref ?? "")
      .replaceAll("\t", " ")
      .trim();
    prs.push({ number, title, branch });
  }

  return prs;
}

type PullRequestState = "conflict" | "open" | "unavailable" | "closed_or_merged" | "not_found";

/** Approve only normalized GitHub hosts listed in Git-local configuration. */
function isApprovedGitHubHostname(hostname: string): boolean {
  const normalize = (value: string): string | undefined => {
    const normalized = value.trim().toLowerCase().replace(/\.$/, "");
    if (
      !normalized ||
      normalized.includes("/") ||
      normalized.includes(":") ||
      normalized.includes("*") ||
      /^[\d.]+$/.test(normalized) ||
      !/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(normalized)
    ) {
      return undefined;
    }
    return normalized;
  };
  const trusted = configGetAll("worktree.cleanup.trustedGitHubHost");
  if (trusted.length === 0 || trusted.some((value) => !normalize(value))) return false;
  const normalizedHostname = normalize(hostname);
  return normalizedHostname !== undefined && trusted.some((value) => normalize(value) === normalizedHostname);
}

/** Fetch the projected open or closed pull request history. */
function queryPullRequests(
  hostname: string,
  owner: string,
  repo: string,
  state: "open" | "closed",
): {
  ok: boolean;
  items: PullRequestListItem[];
} {
  const result = runCaptureResult(
    "gh",
    [
      "api",
      "--paginate",
      "--hostname",
      hostname,
      "--jq",
      ".[] | {number: .number, title: .title, head: {ref: .head.ref}}",
      `/repos/${owner}/${repo}/pulls?state=${state}&per_page=100`,
    ],
    undefined,
    { maxBuffer: 16 * 1024 * 1024 },
  );
  if (result.status !== 0) return { ok: false, items: [] };
  try {
    const pages = String(result.stdout ?? "")
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => JSON.parse(line) as unknown)
      .flatMap((page) => (Array.isArray(page) ? page : [page]));
    const items: PullRequestListItem[] = [];
    for (const item of pages) {
      if (!item || typeof item !== "object" || typeof item.number !== "number") {
        return { ok: false, items: [] };
      }
      const head = item.head;
      if (!head || typeof head !== "object" || typeof head.ref !== "string" || !head.ref) {
        return { ok: false, items: [] };
      }
      items.push({
        number: item.number,
        title: typeof item.title === "string" ? item.title : "",
        branch: head.ref,
      });
    }
    return { ok: true, items };
  } catch {
    return { ok: false, items: [] };
  }
}

/** Discover one trusted-host pull request snapshot for an inventory. */
function discoverPullRequestInventory(): PullRequestInventory {
  try {
    const context = resolveUpstreamContext();
    const { hostname, owner, repo } = context;
    if (!hostname || !owner || !repo) {
      return { ok: false, open: [], closed: [], error: "incomplete GitHub repository context" };
    }
    if (!isApprovedGitHubHostname(hostname)) {
      return { ok: false, open: [], closed: [], error: "untrusted GitHub host" };
    }
    const open = queryPullRequests(hostname, owner, repo, "open");
    const closed = queryPullRequests(hostname, owner, repo, "closed");
    if (!open.ok || !closed.ok) {
      return { ok: false, open: open.items, closed: closed.items, error: "GitHub pull request discovery failed" };
    }
    return { ok: true, open: open.items, closed: closed.items };
  } catch {
    return { ok: false, open: [], closed: [], error: "GitHub pull request discovery failed" };
  }
}

/** Classify a branch using one already-discovered pull request snapshot. */
function getPullRequestState(branch: string, inventory: PullRequestInventory): PullRequestState {
  if (!branch || !inventory.ok) return inventory.ok ? "not_found" : "unavailable";
  const openMatches = inventory.open.filter((item) => item.branch === branch);
  const closedMatches = inventory.closed.filter((item) => item.branch === branch);
  if (openMatches.length > 0 && closedMatches.length > 0) return "conflict";
  if (openMatches.length > 1 || closedMatches.length > 1) return "conflict";
  if (openMatches.length > 0) return "open";
  if (closedMatches.length > 0) return "closed_or_merged";
  return "not_found";
}

/** Return whether a canonical path is a protected root or descendant. */
function isPathWithin(path: string, root: string): boolean {
  return Boolean(root) && (path === root || path.startsWith(`${root}/`));
}

/** Identify the protected checkout root containing a candidate path. */
function isProtectedPath(path: string, roots: { current: string; common: string }): string | undefined {
  if (isPathWithin(path, roots.common)) return "repository root";
  if (isPathWithin(path, roots.current)) return "current worktree";
  return undefined;
}

function releaseAfterRemoval(record: MetadataRecord): void {
  if (record.state === "released" && isTimestamp(record.releasedAt)) return;
  writeRelease(record);
}

function pullRequestInventoryError(inventory: PullRequestInventory): string {
  return inventory.error ?? "GitHub pull request discovery failed";
}

/** Associate a candidate with one specific closed pull request. */
function associatedClosedPullRequest(
  path: string,
  branch: string,
  inventory: PullRequestInventory,
): { pr?: PullRequestListItem; state: PullRequestState; reason?: string } {
  const name = path.split("/").filter(Boolean).at(-1) ?? "";
  const prNumber = parsePrNumberFromWorktreeName(name);
  const openByNumber = prNumber ? inventory.open.filter((item) => item.number === prNumber) : [];
  const openByBranch = inventory.open.filter((item) => item.branch === branch);
  if (openByNumber.length > 0 || openByBranch.length > 0) {
    return { state: "open", reason: "open pull request" };
  }
  const closedByNumber = prNumber ? inventory.closed.filter((item) => item.number === prNumber) : [];
  const closedByBranch = inventory.closed.filter((item) => item.branch === branch);
  const candidates = prNumber !== undefined ? closedByNumber : closedByBranch;
  const unique = candidates.filter(
    (item, index, items) => items.findIndex((candidate) => candidate.number === item.number) === index,
  );
  if (unique.length === 0) return { state: "not_found", reason: "worktree has no specific closed pull request" };
  if (unique.length > 1) return { state: "conflict", reason: "conflicting closed pull request association" };
  const pr = unique[0];
  if (!pr) return { state: "not_found", reason: "worktree has no specific closed pull request" };
  if (prNumber !== undefined && pr.number !== prNumber) {
    return { state: "conflict", reason: "worktree name does not match closed pull request" };
  }
  if (pr.branch !== branch) return { state: "conflict", reason: "worktree branch does not match closed pull request" };
  return { pr, state: "closed_or_merged" };
}

function protectedValues(key: string): Set<string> {
  return new Set(
    configGetAll(key)
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function refIsProtected(ref: string, head: string): boolean {
  const refs = protectedValues("worktree.cleanup.protectedRef");
  const commits = protectedValues("worktree.cleanup.protectedCommit");
  const shortRef = ref.replace(/^refs\/heads\//, "");
  return [...refs].some((value) => value === ref || value === shortRef) || commits.has(head);
}

function staleRowSort(a: StaleRow, b: StaleRow): number {
  const left = `${a.path}\0${a.id}\0${a.label}`;
  const right = `${b.path}\0${b.id}\0${b.label}`;
  return left < right ? -1 : left > right ? 1 : 0;
}

/** Classify one worktree against metadata, safety, age, and PR state. */
function rowForEntry(
  entry: PorcelainEntry,
  protectedRoots: { current: string; common: string },
  records: ReturnType<typeof parseMetadataRecords>,
  evaluationNow: string,
  staleAfterDays: number,
  staleConfigError?: string,
  prInventory: PullRequestInventory = { ok: true, open: [], closed: [] },
): StaleRow {
  const path = entry.path ? canonicalPath(entry.path) : "";
  const id = path ? worktreeId(path) : "";
  const record = records.valid.find((candidate) => candidate.path === path && candidate.id === id);
  const invalidRecord = records.invalid.find((candidate) => candidate.path === path);
  const quarantine = (reason: string): StaleRow => ({
    label: "QUARANTINE",
    path,
    id,
    ref: entry.branch,
    reason,
    entry,
    record,
  });
  const unknown = (reason: string): StaleRow => ({
    label: "UNKNOWN",
    path,
    id,
    ref: entry.branch,
    reason,
    entry,
    record,
  });

  if (entry.parseError) return unknown(entry.parseError);
  if (staleConfigError) return unknown(staleConfigError);
  if (!path) return unknown("missing worktree path");
  if (!entry.head || !isValidWorktreeHead(entry.head)) return unknown("missing or malformed HEAD");
  if (entry.bare) return quarantine("bare worktree");
  if (entry.detached && entry.branch) return unknown("detached worktree has a branch marker");
  if (!entry.detached && !isValidWorktreeRef(entry.branch)) return unknown("missing or malformed branch ref");
  const protectedPath = isProtectedPath(path, protectedRoots);
  if (protectedPath) return quarantine(protectedPath);
  if (entry.detached) return quarantine("detached worktree");
  if (entry.locked) return quarantine("locked worktree");
  if (entry.prunable) return quarantine("prunable worktree");
  if (!existsSync(path)) return quarantine("missing worktree path");
  if (invalidRecord?.reason === "inconsistent metadata state") {
    return quarantine("release metadata recovery required");
  }
  if (invalidRecord || records.duplicateIds.has(id)) return unknown(invalidRecord?.reason ?? "duplicate metadata");
  if (!record) return unknown("missing metadata");
  if (record.releaseRecoveryFailed || (record.releasePendingAt && record.state !== "released")) {
    return quarantine("release metadata recovery required");
  }
  if (record.head !== entry.head) return quarantine("HEAD changed");
  if (record.ref !== entry.branch) return quarantine("ref changed");
  if (refIsProtected(record.ref, record.head)) return quarantine("protected ref or commit");

  let clean = false;
  try {
    clean = isGitStatusClean(path);
  } catch {
    return unknown("status command error");
  }
  if (!clean) return quarantine("dirty worktree");

  const registeredAt = Date.parse(record.registeredAt);
  const evaluationTime = Date.parse(evaluationNow);
  const age = evaluationTime - registeredAt;
  const stale =
    age >= staleAfterDays * 86400000 && (Date.parse(record.leaseUntil) <= evaluationTime || record.releasedAt !== "");
  if (!stale) return quarantine("not stale");

  const prState = getPullRequestState(record.ref.replace(/^refs\/heads\//, ""), prInventory);
  if (prState === "open" || prState === "unavailable" || prState === "conflict") {
    return {
      ...quarantine(`${prState} pull request`),
      prState,
    };
  }
  return {
    label: "ELIGIBLE",
    path,
    id,
    ref: record.ref,
    reason: prState === "closed_or_merged" ? "closed_or_merged pull request" : "not_found pull request",
    entry,
    record,
    prState,
  };
}

/** Build the deterministic stale-worktree report. */
function classifyStaleWorktrees(evaluationNow: string, targetPath?: string): { rows: StaleRow[]; error?: string } {
  const detailed = parseDetailedWorktrees();
  const paths = currentRepositoryPaths(detailed.entries);
  const records = parseMetadataRecords();
  const threshold = readStaleAfterDays();
  if (detailed.error) {
    return {
      rows: [
        {
          label: "UNKNOWN",
          path: paths.current,
          id: worktreeId(paths.current),
          ref: "",
          reason: detailed.error,
        },
      ],
      error: detailed.error,
    };
  }
  const prInventory = discoverPullRequestInventory();
  const rows = detailed.entries
    .map((entry) => rowForEntry(entry, paths, records, evaluationNow, threshold.value, threshold.error, prInventory))
    .filter((row) => !targetPath || row.path === targetPath);
  const listedPaths = new Set(rows.map((row) => row.path).filter(Boolean));
  for (const invalid of records.invalid) {
    if (invalid.path && !listedPaths.has(invalid.path)) {
      rows.push({
        label: "UNKNOWN",
        path: invalid.path,
        id: invalid.id,
        ref: "",
        reason: invalid.reason,
      });
    }
  }
  return { rows: rows.sort(staleRowSort) };
}

function printStaleReport(rows: StaleRow[]): void {
  for (const row of rows) {
    console.log([row.label, row.path, row.id, row.ref, row.reason].join("\t"));
  }
}

function printNoEligibleSummary(rows: StaleRow[]): void {
  const quarantineCount = rows.filter((row) => row.label === "QUARANTINE").length;
  const unknownCount = rows.filter((row) => row.label === "UNKNOWN").length;
  console.log(`No eligible stale worktrees found: ${quarantineCount} quarantine, ${unknownCount} unknown.`);
  for (const row of rows) {
    console.log(`${row.label}: ${row.path}: ${row.reason}`);
  }
}

function closedPrRowSort(a: ClosedPrRow, b: ClosedPrRow): number {
  const left = `${a.path}\0${a.id}\0${a.label}`;
  const right = `${b.path}\0${b.id}\0${b.label}`;
  return left < right ? -1 : left > right ? 1 : 0;
}

/** Build the deterministic closed-pull-request report. */
function classifyClosedPrWorktrees(
  targetPath?: string,
  providedInventory?: PullRequestInventory,
): { rows: ClosedPrRow[]; error?: string } {
  const detailed = parseDetailedWorktrees();
  const paths = currentRepositoryPaths(detailed.entries);
  if (detailed.error) {
    return {
      rows: [
        {
          label: "UNKNOWN",
          path: paths.current,
          id: worktreeId(paths.current),
          ref: "",
          reason: detailed.error,
        },
      ],
      error: detailed.error,
    };
  }

  const inventory = providedInventory ?? discoverPullRequestInventory();
  if (!inventory.ok) {
    return { rows: [], error: pullRequestInventoryError(inventory) };
  }
  const records = parseMetadataRecords();
  const rows: ClosedPrRow[] = [];

  for (const entry of detailed.entries) {
    const path = entry.path ? canonicalPath(entry.path) : "";
    if (targetPath && path !== targetPath) continue;
    const id = path ? worktreeId(path) : "";
    let record = records.valid.find((candidate) => candidate.path === path && candidate.id === id);
    const invalidRecord = records.invalid.find((candidate) => candidate.path === path);
    const branch = entry.branch.replace(/^refs\/heads\//, "");
    const prNumber = parsePrNumberFromWorktreeName(path.split("/").filter(Boolean).at(-1) ?? "");
    const openByNumber = prNumber ? inventory.open.filter((item) => item.number === prNumber) : [];
    const openByBranch = inventory.open.filter((item) => item.branch === branch);
    const hasHint =
      prNumber !== undefined ||
      inventory.closed.some((item) => item.branch === branch) ||
      openByNumber.length > 0 ||
      openByBranch.length > 0;
    if (!hasHint) continue;

    const quarantine = (reason: string, prState?: PullRequestState): void => {
      rows.push({ label: "QUARANTINE", path, id, ref: entry.branch, reason, entry, record, prState });
    };
    const unknown = (reason: string, prState?: PullRequestState): void => {
      rows.push({ label: "UNKNOWN", path, id, ref: entry.branch, reason, entry, record, prState });
    };

    if (openByNumber.length > 0 || openByBranch.length > 0) {
      quarantine("open pull request", "open");
      continue;
    }
    const association = associatedClosedPullRequest(path, entry.branch.replace(/^refs\/heads\//, ""), inventory);
    if (association.state === "not_found") {
      quarantine(association.reason ?? "worktree has no specific closed pull request", "not_found");
      continue;
    }
    if (association.state === "conflict") {
      quarantine(association.reason ?? "conflicting closed pull request association", "conflict");
      continue;
    }
    const closedPr = association.pr;
    if (!closedPr) {
      quarantine("worktree has no specific closed pull request", "not_found");
      continue;
    }
    if (entry.parseError) {
      unknown(entry.parseError, "unavailable");
      continue;
    }
    if (!path) {
      unknown("missing worktree path", "unavailable");
      continue;
    }
    if (!entry.head || !isValidWorktreeHead(entry.head)) {
      unknown("missing or malformed HEAD", "unavailable");
      continue;
    }
    if (entry.detached && entry.branch) {
      unknown("detached worktree has a branch marker", "conflict");
      continue;
    }
    if (!entry.detached && !isValidWorktreeRef(entry.branch)) {
      unknown("missing or malformed branch ref", "unavailable");
      continue;
    }
    const protectedPath = isProtectedPath(path, paths);
    if (protectedPath) {
      quarantine(protectedPath, "closed_or_merged");
      continue;
    }
    if (invalidRecord?.reason === "inconsistent metadata state") {
      quarantine("release metadata recovery required", "unavailable");
      continue;
    }
    if (invalidRecord || records.duplicateIds.has(id)) {
      unknown(invalidRecord?.reason ?? "duplicate metadata", "unavailable");
      continue;
    }
    if (entry.bare) {
      quarantine("bare worktree", "closed_or_merged");
      continue;
    }
    if (entry.detached) {
      quarantine("detached worktree", "closed_or_merged");
      continue;
    }
    if (entry.locked) {
      quarantine("locked worktree", "closed_or_merged");
      continue;
    }
    if (entry.prunable) {
      quarantine("prunable worktree", "closed_or_merged");
      continue;
    }
    if (!existsSync(path)) {
      quarantine("missing worktree path", "closed_or_merged");
      continue;
    }
    if (refIsProtected(entry.branch, entry.head)) {
      quarantine("protected ref or commit", "closed_or_merged");
      continue;
    }

    let clean = false;
    try {
      clean = isGitStatusClean(path);
    } catch {
      unknown("status command error", "unavailable");
      continue;
    }
    if (!clean) {
      quarantine("dirty worktree", "closed_or_merged");
      continue;
    }
    if (!record) {
      try {
        registerWorktree(path, entry.branch, entry.head);
        record = parseMetadataRecords().valid.find((candidate) => candidate.path === path && candidate.id === id);
      } catch {
        record = undefined;
      }
      if (!record) {
        unknown("could not enroll worktree metadata", "unavailable");
        continue;
      }
    }
    if (record.releaseRecoveryFailed || (record.releasePendingAt && record.state !== "released")) {
      quarantine("release metadata recovery required", "unavailable");
      continue;
    }
    if (record.head !== entry.head) {
      quarantine("HEAD changed", "conflict");
      continue;
    }
    if (record.ref !== entry.branch) {
      quarantine("ref changed", "conflict");
      continue;
    }
    rows.push({
      label: "ELIGIBLE",
      path,
      id,
      ref: entry.branch,
      reason: `closed pull request #${closedPr.number}`,
      entry,
      record,
      prState: "closed_or_merged",
    });
  }

  return { rows: rows.sort(closedPrRowSort) };
}

function printNoClosedPrSummary(rows: ClosedPrRow[]): void {
  const quarantineCount = rows.filter((row) => row.label === "QUARANTINE").length;
  const unknownCount = rows.filter((row) => row.label === "UNKNOWN").length;
  console.log(`No eligible closed-PR worktrees found: ${quarantineCount} quarantine, ${unknownCount} unknown.`);
  for (const row of rows) {
    console.log(`${row.label}: ${row.path}: ${row.reason}`);
  }
}

function removeWorktree(name: string): void {
  if (!isValidName(name)) {
    throw new Error(
      `invalid worktree name '${name}'. Use only alphanumeric characters, dots, hyphens, underscores, and slashes.`,
    );
  }
  const worktreePath = `../${name}`;
  console.log(`Removing worktree: ${worktreePath} ...`);
  stopLocalPitchforkDaemons(resolveWorktreePath(worktreePath));
  runInherit("git", ["worktree", "remove", worktreePath]);
  cleanPrunedPitchforkDaemons();
  console.log("Done.");
}

function stopLocalPitchforkDaemons(worktreePath: string): void {
  if (!commandExists("pitchfork") || !existsSync(worktreePath)) return;
  console.log(`Stopping Pitchfork daemons for ${worktreePath} ...`);
  runInherit("pitchfork", ["stop", "--local"], worktreePath);
}

function cleanPrunedPitchforkDaemons(): void {
  if (!commandExists("pitchfork")) {
    console.log("Pitchfork is not installed; skipping daemon cleanup.");
    return;
  }
  console.log("Cleaning Pitchfork registrations for deleted directories ...");
  runInherit("pitchfork", ["clean", "--prune"]);
}

function parsePrNumberFromWorktreeName(name: string): number | undefined {
  const match = /^pr-(\d+)$/.exec(name);
  if (!match?.[1]) return undefined;
  const prNumber = Number.parseInt(match[1], 10);
  if (!Number.isInteger(prNumber) || prNumber <= 0) return undefined;
  return prNumber;
}

function isAllClosedPrsKeyword(value: string): boolean {
  return value.trim() === ALL_CLOSED_PRS_KEYWORD;
}

function isAllStaleWorktreesKeyword(value: string): boolean {
  return value.trim() === ALL_STALE_WORKTREES_KEYWORD;
}

function removeWorktreeByPath(path: string): Promise<void> {
  return new Promise((resolvePromise, rejectPromise) => {
    const child = spawn("git", ["worktree", "remove", path], {
      stdio: ["ignore", "pipe", "pipe"],
    });

    let stdout = "";
    let stderr = "";

    child.stdout?.on("data", (chunk: string | Buffer) => {
      stdout += chunk.toString();
    });
    child.stderr?.on("data", (chunk: string | Buffer) => {
      stderr += chunk.toString();
    });
    child.on("error", rejectPromise);
    child.on("close", (code) => {
      if (code === 0) {
        resolvePromise();
        return;
      }

      const message = stderr.trim() || stdout.trim() || `git worktree remove ${path} failed`;
      rejectPromise(new Error(message));
    });
  });
}

function encodeFzfField(value: string): string {
  return value.replaceAll("\\", "\\\\").replaceAll("\t", "\\t").replaceAll("\n", "\\n");
}

function decodeFzfField(value: string): string {
  let decoded = "";
  for (let index = 0; index < value.length; index += 1) {
    const character = value[index];
    if (character !== "\\") {
      decoded += character;
      continue;
    }
    const next = value[index + 1];
    if (next === "t") decoded += "\t";
    else if (next === "n") decoded += "\n";
    else if (next === "\\") decoded += "\\";
    else decoded += next ?? "";
    index += 1;
  }
  return decoded;
}

function fzfPreviewPathSetup(): string {
  return `__fzf_path="$(printf '%bX' {s2})"; __fzf_path="\${__fzf_path%X}"; `;
}

function splitFzfOutput(output: string): string[] {
  const withoutFinalDelimiter = output.endsWith("\n") ? output.slice(0, -1) : output;
  return withoutFinalDelimiter ? withoutFinalDelimiter.split("\n").filter((line) => line.length > 0) : [];
}

function parseSelectedWorktreePaths(selectedLines: string[]): string[] {
  const uniquePaths = new Set<string>();
  for (const selectedLine of selectedLines) {
    const encodedPath = selectedLine.split("\t")[1] ?? "";
    const selectedPath = decodeFzfField(encodedPath);
    if (selectedPath.length === 0) {
      throw new Error("could not resolve selected worktree path.");
    }
    uniquePaths.add(selectedPath);
  }
  return [...uniquePaths];
}

async function removeWorktreePaths(selectedPaths: string[]): Promise<void> {
  console.log(`Removing ${selectedPaths.length} worktree(s) ...`);

  for (const selectedPath of selectedPaths) {
    stopLocalPitchforkDaemons(selectedPath);
  }

  const removalResults = await Promise.allSettled(
    selectedPaths.map(async (selectedPath) => {
      await removeWorktreeByPath(selectedPath);
      return selectedPath;
    }),
  );

  let failedCount = 0;
  const removedPaths: string[] = [];
  for (const [index, result] of removalResults.entries()) {
    const selectedPath = selectedPaths[index];
    if (!selectedPath) {
      throw new Error("could not resolve selected worktree path.");
    }

    if (result.status === "fulfilled") {
      removedPaths.push(selectedPath);
      console.log(`Removed: ${selectedPath}`);
      continue;
    }

    failedCount += 1;
    console.error(`Failed: ${selectedPath}`);
    console.error(`  ${getErrorMessage(result.reason)}`);
  }

  if (removedPaths.length > 0) {
    cleanPrunedPitchforkDaemons();
  }

  if (failedCount > 0) {
    throw new Error(`failed to remove ${failedCount} of ${selectedPaths.length} selected worktree(s).`);
  }

  console.log("Done.");
}

function pickStaleRows(rows: StaleRow[]): StaleRow[] {
  const lines = [
    [ALL_STALE_WORKTREES_KEYWORD, ALL_STALE_WORKTREES_KEYWORD, "", "", "all eligible stale worktrees"].join("\t"),
    ...rows.map((row) => [row.label, encodeFzfField(row.path), row.id, row.ref, row.reason].join("\t")),
  ];
  const previewCommand =
    fzfPreviewPathSetup() +
    `if [ "$__fzf_path" = ${shellQuote(ALL_STALE_WORKTREES_KEYWORD)} ]; then ` +
    `echo 'all eligible stale worktrees'; ` +
    `elif [ {1} != 'ELIGIBLE' ]; then echo {5}; ` +
    `else git -C "$__fzf_path" log --oneline --color --graph -20 2>/dev/null; fi`;
  const result = spawnSync(
    "fzf",
    [
      "--height",
      "~100%",
      "--layout",
      "reverse",
      "--border",
      "--prompt",
      "Select stale worktree(s) to remove: ",
      "--delimiter",
      "\t",
      "--with-nth",
      "1,2,4,5",
      "--preview",
      previewCommand,
      "--multi",
    ],
    {
      input: `${lines.join("\n")}\n`,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "inherit"],
    },
  );
  const selectedLines = splitFzfOutput(String(result.stdout ?? ""));
  if (result.status !== 0 || selectedLines.length === 0) {
    throw new TaskExitError(130, "Cancelled; no worktrees removed.");
  }

  const selected = selectedLines.map((line) => line.split("\t")).filter((fields) => fields.length >= 5);
  if (selected.some((fields) => fields[0] !== "ELIGIBLE" && fields[1] !== ALL_STALE_WORKTREES_KEYWORD)) {
    throw new TaskExitError(2, "A quarantine or unknown worktree cannot be applied.");
  }
  if (selected.some((fields) => fields[1] === ALL_STALE_WORKTREES_KEYWORD)) {
    return rows.filter((row) => row.label === "ELIGIBLE");
  }
  const selectedIds = new Set(selected.map((fields) => fields[2]).filter(Boolean));
  return rows.filter((row) => row.label === "ELIGIBLE" && selectedIds.has(row.id));
}

function pickClosedPrRows(rows: ClosedPrRow[]): ClosedPrRow[] {
  const lines = [
    `All closed PRs\t${ALL_CLOSED_PRS_KEYWORD}\t\t\tall eligible closed-PR worktrees`,
    ...rows.map((row) => [row.label, encodeFzfField(row.path), row.id, row.ref, row.reason].join("\t")),
  ];
  const previewCommand =
    fzfPreviewPathSetup() +
    `if [ "$__fzf_path" = ${shellQuote(ALL_CLOSED_PRS_KEYWORD)} ]; then ` +
    `echo 'all eligible closed-PR worktrees'; ` +
    `elif [ {1} != 'ELIGIBLE' ]; then echo {5}; ` +
    `else git -C "$__fzf_path" log --oneline --color --graph -20 2>/dev/null; fi`;
  const result = spawnSync(
    "fzf",
    [
      "--height",
      "~100%",
      "--layout",
      "reverse",
      "--border",
      "--prompt",
      "Select closed-PR worktree(s) to remove: ",
      "--delimiter",
      "\t",
      "--with-nth",
      "1,2,4,5",
      "--preview",
      previewCommand,
      "--multi",
    ],
    {
      input: `${lines.join("\n")}\n`,
      encoding: "utf-8",
      stdio: ["pipe", "pipe", "inherit"],
    },
  );
  const selectedLines = splitFzfOutput(String(result.stdout ?? ""));
  if (result.status !== 0 || selectedLines.length === 0) {
    throw new TaskExitError(130, "Cancelled; no worktrees removed.");
  }

  const selected = selectedLines
    .map((line) => {
      const fields = line.split("\t");
      if (fields[1] === ALL_CLOSED_PRS_KEYWORD) {
        return [fields[0] ?? "", ALL_CLOSED_PRS_KEYWORD, "", "", "all eligible closed-PR worktrees"];
      }
      return fields;
    })
    .filter((fields) => fields.length >= 5);
  if (selected.some((fields) => fields[0] !== "ELIGIBLE" && fields[1] !== ALL_CLOSED_PRS_KEYWORD)) {
    throw new TaskExitError(2, "A quarantine or unknown worktree cannot be applied.");
  }
  if (selected.some((fields) => fields[1] === ALL_CLOSED_PRS_KEYWORD)) {
    return rows.filter((row) => row.label === "ELIGIBLE");
  }
  const selectedIds = new Set(selected.map((fields) => fields[2]).filter(Boolean));
  return rows.filter((row) => row.label === "ELIGIBLE" && selectedIds.has(row.id));
}

function askConfirmation(count: number): Promise<boolean> {
  const readline = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((resolvePromise) => {
    readline.question(`Apply removal to ${count} eligible worktree(s)? [y/N] `, (answer) => {
      readline.close();
      resolvePromise(/^(?:y|yes)$/i.test(answer.trim()));
    });
  });
}

function samePorcelainState(left: PorcelainEntry | undefined, right: PorcelainEntry | undefined): boolean {
  if (!left || !right) return false;
  return (
    left.path === right.path &&
    left.head === right.head &&
    left.branch === right.branch &&
    left.detached === right.detached &&
    left.bare === right.bare &&
    left.locked === right.locked &&
    left.prunable === right.prunable &&
    left.parseError === right.parseError
  );
}

/** Run report-first closed-PR cleanup with per-candidate revalidation. */
async function runClosedPrFlow(apply: boolean, selectedKeyword = ""): Promise<void> {
  const initial = classifyClosedPrWorktrees();
  printStaleReport(initial.rows);
  if (initial.error) throw new Error(initial.error);
  const eligible = initial.rows.filter((row) => row.label === "ELIGIBLE");
  if (initial.rows.length === 0) {
    console.log("No closed-PR worktrees found.");
    return;
  }
  if (eligible.length === 0) {
    printNoClosedPrSummary(initial.rows);
    return;
  }
  if (!apply) return;
  if (process.stdin.isTTY !== true || process.stdout.isTTY !== true) {
    throw new TaskExitError(2, "Closed-PR worktree apply requires an interactive TTY.");
  }
  if (selectedKeyword !== ALL_CLOSED_PRS_KEYWORD) {
    ensureCommand("fzf", "--closed-prs apply mode");
  }
  const selected = selectedKeyword === ALL_CLOSED_PRS_KEYWORD ? eligible : pickClosedPrRows(initial.rows);
  if (selected.length === 0) {
    throw new TaskExitError(130, "Cancelled; no worktrees removed.");
  }
  if (!(await askConfirmation(selected.length))) return;

  let failures = 0;
  let metadataFailures = 0;
  let removed = 0;
  for (const candidate of selected) {
    const fresh = classifyClosedPrWorktrees(candidate.path);
    if (fresh.error) throw new Error(fresh.error);
    const current = fresh.rows.find((row) => row.id === candidate.id && row.path === candidate.path);
    if (
      !current ||
      current.label !== "ELIGIBLE" ||
      current.ref !== candidate.ref ||
      current.prState !== candidate.prState ||
      current.record?.fingerprint !== candidate.record?.fingerprint ||
      !samePorcelainState(current.entry, candidate.entry)
    ) {
      console.error(`Skipped: ${candidate.path} (worktree changed during apply).`);
      continue;
    }
    let gitRemoved = false;
    try {
      stopLocalPitchforkDaemons(candidate.path);
      await removeWorktreeByPath(candidate.path);
      removed += 1;
      gitRemoved = true;
      if (!candidate.record) throw new Error("missing metadata during release");
      releaseAfterRemoval(candidate.record);
      console.log(`Removed: ${candidate.path}`);
    } catch (error) {
      failures += 1;
      if (gitRemoved) {
        metadataFailures += 1;
        console.error(`Removed: ${candidate.path}`);
        console.error("Failed to release metadata.");
      } else {
        console.error(`Failed: ${candidate.path}`);
      }
      console.error(`  ${getErrorMessage(error)}`);
    }
  }
  if (removed > 0) cleanPrunedPitchforkDaemons();
  if (failures > 0) {
    const failureSummary =
      metadataFailures > 0
        ? `failed to process ${failures} of ${selected.length} selected worktree(s); ` +
          `${metadataFailures} release metadata update(s) failed.`
        : `failed to remove ${failures} of ${selected.length} selected worktree(s).`;
    throw new TaskExitError(1, failureSummary);
  }
  console.log(`Removed ${removed} worktree(s).`);
}

/** Run report-first stale cleanup with per-candidate revalidation. */
async function runStaleFlow(apply: boolean, selectedKeyword = ""): Promise<void> {
  const evaluationNow = timestampNow();
  const initial = classifyStaleWorktrees(evaluationNow);
  printStaleReport(initial.rows);
  if (initial.error) throw new Error(initial.error);
  const eligible = initial.rows.filter((row) => row.label === "ELIGIBLE");
  if (initial.rows.length === 0) {
    console.log("No stale worktrees found.");
    return;
  }
  if (eligible.length === 0) {
    printNoEligibleSummary(initial.rows);
    return;
  }
  if (!apply) return;
  if (process.stdin.isTTY !== true || process.stdout.isTTY !== true) {
    throw new TaskExitError(2, "Stale worktree apply requires an interactive TTY.");
  }
  if (selectedKeyword !== ALL_STALE_WORKTREES_KEYWORD) {
    ensureCommand("fzf", "--stale apply mode");
  }
  const selected = selectedKeyword === ALL_STALE_WORKTREES_KEYWORD ? eligible : pickStaleRows(initial.rows);
  if (selected.length === 0) {
    throw new TaskExitError(130, "Cancelled; no worktrees removed.");
  }
  if (!(await askConfirmation(selected.length))) return;

  let failures = 0;
  let metadataFailures = 0;
  let removed = 0;
  for (const candidate of selected) {
    const fresh = classifyStaleWorktrees(timestampNow(), candidate.path);
    if (fresh.error) {
      throw new Error(fresh.error);
    }
    const current = fresh.rows.find((row) => row.id === candidate.id && row.path === candidate.path);
    if (
      !current ||
      current.label !== "ELIGIBLE" ||
      current.ref !== candidate.ref ||
      current.prState !== candidate.prState ||
      current.record?.fingerprint !== candidate.record?.fingerprint ||
      !samePorcelainState(current.entry, candidate.entry)
    ) {
      console.error(`Skipped: ${candidate.path} (worktree changed during apply).`);
      continue;
    }
    let gitRemoved = false;
    try {
      stopLocalPitchforkDaemons(candidate.path);
      await removeWorktreeByPath(candidate.path);
      removed += 1;
      gitRemoved = true;
      if (!candidate.record) throw new Error("missing metadata during release");
      releaseAfterRemoval(candidate.record);
      console.log(`Removed: ${candidate.path}`);
    } catch (error) {
      failures += 1;
      if (gitRemoved) {
        metadataFailures += 1;
        console.error(`Removed: ${candidate.path}`);
        console.error("Failed to release metadata.");
      } else {
        console.error(`Failed: ${candidate.path}`);
      }
      console.error(`  ${getErrorMessage(error)}`);
    }
  }
  if (removed > 0) {
    cleanPrunedPitchforkDaemons();
  }
  if (failures > 0) {
    const failureSummary =
      metadataFailures > 0
        ? `failed to process ${failures} of ${selected.length} selected worktree(s); ` +
          `${metadataFailures} release metadata update(s) failed.`
        : `failed to remove ${failures} of ${selected.length} selected worktree(s).`;
    throw new TaskExitError(1, failureSummary);
  }
  console.log(`Removed ${removed} worktree(s).`);
}

async function runReleaseFlow(pathLike: string): Promise<void> {
  if (!pathLike) throw new Error("--release requires a worktree path.");
  const target = canonicalPath(pathLike);
  const detailed = parseDetailedWorktrees();
  if (detailed.error) throw new Error(detailed.error);
  const entry = detailed.entries.find((candidate) => canonicalPath(candidate.path) === target);
  if (!entry || entry.parseError) throw new Error(`worktree path '${pathLike}' is not registered.`);
  const records = parseMetadataRecords();
  const record = records.valid.find((candidate) => candidate.path === target && candidate.id === worktreeId(target));
  if (!record) throw new Error(`worktree path '${pathLike}' has no valid cleanup metadata.`);
  writeRelease(record);
  console.log(`Released metadata for ${target}.`);
}

async function runDeleteFlow(name: string): Promise<void> {
  if (name) {
    removeWorktree(name);
    return;
  }

  const repoRoot = currentRepositoryPaths().current;
  if (!repoRoot) {
    console.log("No removable worktrees found.");
    return;
  }
  const worktrees = parseWorktreeList(repoRoot);
  if (worktrees.length === 0) {
    console.log("No removable worktrees found.");
    return;
  }

  const lines = [
    `All stale worktrees\t${ALL_STALE_WORKTREES_KEYWORD}\t`,
    `All closed PRs\t${ALL_CLOSED_PRS_KEYWORD}\t`,
    ...worktrees.map(
      (entry) => `${encodeFzfField(entry.name)}\t${encodeFzfField(entry.path)}\t${encodeFzfField(entry.branch)}`,
    ),
  ];
  const previewCommand =
    fzfPreviewPathSetup() +
    `if [ "$__fzf_path" = ${shellQuote(ALL_STALE_WORKTREES_KEYWORD)} ]; then ` +
    `echo 'Report and remove all eligible stale worktrees.'; ` +
    `elif [ "$__fzf_path" = ${shellQuote(ALL_CLOSED_PRS_KEYWORD)} ]; then ` +
    `echo 'Delete all worktrees for closed pull requests.'; ` +
    `else git -C "$__fzf_path" log --oneline --color --graph -20 2>/dev/null; fi`;

  const selectedLines = commandExists("fzf")
    ? pickLineWithFzf(lines, "Select worktree(s) to remove: ", previewCommand, {
        multi: true,
      })
    : (() => {
        const selected = pickLineFromPrompt(lines);
        return selected ? [selected] : undefined;
      })();

  if (!selectedLines || selectedLines.length === 0) {
    console.log("No worktree selected.");
    return;
  }

  const selectedAllStaleWorktrees = selectedLines.some((line) => line.split("\t")[1] === ALL_STALE_WORKTREES_KEYWORD);
  if (selectedAllStaleWorktrees) {
    await runStaleFlow(true, ALL_STALE_WORKTREES_KEYWORD);
    return;
  }

  const selectedAllClosedPrs = selectedLines.some((line) => line.split("\t")[1] === ALL_CLOSED_PRS_KEYWORD);
  if (selectedAllClosedPrs) {
    await runDeleteClosedPrWorktreesFlow();
    return;
  }

  const selectedPaths = parseSelectedWorktreePaths(selectedLines);
  await removeWorktreePaths(selectedPaths);
}

async function runDeleteClosedPrWorktreesFlow(): Promise<void> {
  await runClosedPrFlow(true, ALL_CLOSED_PRS_KEYWORD);
}

async function runDeletePullRequestWorktreesFlow(pullRequestSelector: string): Promise<void> {
  if (isAllClosedPrsKeyword(pullRequestSelector)) {
    await runDeleteClosedPrWorktreesFlow();
    return;
  }

  const repoRoot = currentRepositoryPaths().current;
  if (!repoRoot) {
    console.log("No PR worktrees found.");
    return;
  }
  const worktrees = parseWorktreeList(repoRoot);
  const prWorktrees = worktrees
    .map((entry) => ({
      entry,
      prNumber: parsePrNumberFromWorktreeName(entry.name),
    }))
    .filter((value): value is { entry: WorktreeEntry; prNumber: number } => value.prNumber !== undefined);

  if (prWorktrees.length === 0) {
    console.log("No PR worktrees found.");
    return;
  }

  const prNumberOverride =
    pullRequestSelector && pullRequestSelector !== "pick" ? normalizePrNumber(pullRequestSelector) : "";

  if (prNumberOverride) {
    const selectedPaths = prWorktrees
      .filter((entry) => String(entry.prNumber) === prNumberOverride)
      .map((entry) => entry.entry.path);
    if (selectedPaths.length === 0) {
      console.log(`No PR worktree found for #${prNumberOverride}.`);
      return;
    }
    await removeWorktreePaths(selectedPaths);
    return;
  }

  const lines = [
    `All closed PRs\t${ALL_CLOSED_PRS_KEYWORD}\t`,
    ...prWorktrees.map(
      (entry) =>
        `${encodeFzfField(entry.entry.name)}\t${encodeFzfField(entry.entry.path)}\t${encodeFzfField(
          entry.entry.branch,
        )}`,
    ),
  ];
  const previewCommand =
    fzfPreviewPathSetup() +
    `if [ "$__fzf_path" = ${shellQuote(ALL_CLOSED_PRS_KEYWORD)} ]; then ` +
    `echo 'Delete all worktrees for closed pull requests.'; ` +
    `else git -C "$__fzf_path" log --oneline --color --graph -20 2>/dev/null; fi`;

  const selectedLines = commandExists("fzf")
    ? pickLineWithFzf(lines, "Select PR worktree(s) to remove: ", previewCommand, { multi: true })
    : (() => {
        const selected = pickLineFromPrompt(lines);
        return selected ? [selected] : undefined;
      })();

  if (!selectedLines || selectedLines.length === 0) {
    console.log("No worktree selected.");
    return;
  }

  const selectedAllClosedPrs = selectedLines.some((line) => line.split("\t")[1] === ALL_CLOSED_PRS_KEYWORD);
  if (selectedAllClosedPrs) {
    await runDeleteClosedPrWorktreesFlow();
    return;
  }

  const selectedPaths = parseSelectedWorktreePaths(selectedLines);
  await removeWorktreePaths(selectedPaths);
}

function normalizePrNumber(value: string): string {
  if (!/^\d+$/.test(value)) {
    throw new Error(`invalid PR number '${value}'.`);
  }
  return value;
}

function normalizeOptionalPrNumber(value: string): string {
  if (!value) return "";
  return normalizePrNumber(value);
}

function runPullRequestFlow(prNumberOverride: string): void {
  ensureCommand("gh", "--pull-request mode");

  const context = resolveUpstreamContext();
  const { hostname, owner, repo } = context;
  if (!hostname || !owner || !repo) {
    throw new Error("resolve-upstream returned incomplete repository context.");
  }
  const repository = `${hostname}/${owner}/${repo}`;

  let selectedPr = prNumberOverride;

  if (!selectedPr) {
    ensureCommand("fzf", "--pull-request mode without PR number");
    const prs = getOpenPullRequests(hostname, owner, repo);
    if (prs.length === 0) {
      console.log(`No open pull requests found for ${owner}/${repo}.`);
      return;
    }

    const lines = prs.map((pr) => `#${pr.number} ${pr.title}\t${pr.number}\t${pr.branch}`);
    const previewCommand = `gh pr view --repo ${shellQuote(repository)} ${shellQuote("{2}")} 2>/dev/null | head -40`;
    const selected = pickLineWithFzf(lines, "Select PR worktree: ", previewCommand)?.[0];

    if (!selected) {
      console.log("No PR selected.");
      return;
    }

    selectedPr = selected.split("\t")[1] ?? "";
  }

  selectedPr = normalizePrNumber(selectedPr);
  const repoRoot = currentRepositoryPaths().current;
  if (!repoRoot) throw new Error("cannot create a pull-request worktree from a bare repository.");
  const worktrees = parseWorktreeList(repoRoot);
  const worktreePath = `../pr-${selectedPr}`;
  const resolvedWorktreePath = resolveWorktreePath(worktreePath);
  const existingWorktree = findWorktreeByPath(worktrees, resolvedWorktreePath);

  if (existsSync(resolvedWorktreePath)) {
    if (!existingWorktree) {
      throw new Error(`worktree path '${worktreePath}' already exists but is not a registered git worktree.`);
    }
    if (!isGitStatusClean(resolvedWorktreePath)) {
      throw new Error(`worktree '${worktreePath}' has uncommitted changes; clean it before rerunning.`);
    }
    console.log(`Reusing worktree: ${worktreePath} ...`);
    process.chdir(resolvedWorktreePath);
  } else {
    console.log(`Creating worktree: ${worktreePath} ...`);
    runInherit("git", ["worktree", "add", worktreePath]);
    process.chdir(worktreePath);
  }

  console.log(`Checking out PR #${selectedPr} ...`);
  runInherit("gh", ["pr", "checkout", "--repo", repository, selectedPr]);
  registerWorktree(
    resolvedWorktreePath,
    runCapture("git", ["symbolic-ref", "-q", "HEAD"]).trim(),
    runCapture("git", ["rev-parse", "HEAD"]).trim(),
    Boolean(existingWorktree),
  );
  const hasMiseConfig =
    existsSync(resolve(resolvedWorktreePath, "mise.toml")) ||
    existsSync(resolve(resolvedWorktreePath, ".mise.toml")) ||
    existsSync(resolve(resolvedWorktreePath, ".mise/config.toml"));
  if (hasMiseConfig) {
    console.log("Trusting mise configuration ...");
    runInherit("mise", ["trust"]);
    if (miseTaskExists("setup")) {
      console.log("Running setup ...");
      runInherit("mise", ["setup"]);
    }
  }
  console.log("\nWorktree ready. To switch to it, run:");
  console.log(`  cd ${worktreePath}`);
}

function runCreateFlow(name: string): void {
  if (!name) {
    throw new Error("worktree name is required (or use --delete)");
  }
  if (!isValidName(name)) {
    throw new Error(
      `invalid worktree name '${name}'. Use only alphanumeric characters, dots, hyphens, underscores, and slashes.`,
    );
  }
  const worktreePath = `../${name}`;
  const resolvedWorktreePath = resolveWorktreePath(worktreePath);
  console.log(`Creating worktree: ${worktreePath} ...`);
  runInherit("git", ["worktree", "add", worktreePath]);
  const hasMiseConfig =
    existsSync(resolve(resolvedWorktreePath, "mise.toml")) ||
    existsSync(resolve(resolvedWorktreePath, ".mise.toml")) ||
    existsSync(resolve(resolvedWorktreePath, ".mise/config.toml"));
  process.chdir(worktreePath);
  registerWorktree(
    resolvedWorktreePath,
    runCapture("git", ["symbolic-ref", "-q", "HEAD"]).trim(),
    runCapture("git", ["rev-parse", "HEAD"]).trim(),
  );
  if (hasMiseConfig) {
    console.log("Trusting mise configuration ...");
    runInherit("mise", ["trust"]);
    if (miseTaskExists("setup")) {
      console.log("Running setup ...");
      runInherit("mise", ["setup"]);
    }
  }
  console.log("\nWorktree ready. To switch to it, run:");
  console.log(`  cd ${worktreePath}`);
}

async function runMain(): Promise<void> {
  ensureInsideGitRepo();
  const closedPrsFlag = process.env["usage_closed_prs"] === "true";
  const deleteFlag = process.env["usage_delete"] === "true";
  const staleFlag = process.env["usage_stale"] === "true";
  const releasePath = (process.env["usage_release"] ?? "").trim();
  const pullRequestRaw = (process.env["usage_pull_request"] ?? "").trim();
  const pullRequest = pullRequestRaw.length > 0 && pullRequestRaw !== "false";
  const name = (process.env["usage_name"] ?? "").trim();
  const pullRequestSelector = pullRequestRaw === "true" ? "pick" : pullRequestRaw;
  const deleteAllClosedFromName = isAllClosedPrsKeyword(name);
  const deleteAllStaleFromName = isAllStaleWorktreesKeyword(name);
  const deleteAllClosedFromPullRequest = pullRequest && isAllClosedPrsKeyword(pullRequestSelector);

  if (closedPrsFlag && (staleFlag || releasePath || pullRequest || name)) {
    throw new TaskExitError(2, "--closed-prs cannot be combined with a name, --stale, --release, or --pull-request.");
  }
  if (releasePath && (staleFlag || deleteFlag || pullRequest || name)) {
    throw new TaskExitError(2, "--release cannot be combined with a name, --stale, --delete, or --pull-request.");
  }
  if (releasePath) {
    await runReleaseFlow(releasePath);
    return;
  }
  if (staleFlag && (pullRequest || name)) {
    throw new TaskExitError(2, "--stale cannot be combined with a name or --pull-request.");
  }
  if (pullRequest && name && !deleteFlag) {
    throw new TaskExitError(2, "do not provide [name] with --pull-request; pass the PR number to --pull-request.");
  }
  if (deleteFlag && pullRequest && name) {
    throw new TaskExitError(2, "do not provide [name] with --delete and --pull-request.");
  }
  if (!deleteFlag && (deleteAllClosedFromName || deleteAllStaleFromName || deleteAllClosedFromPullRequest)) {
    const keyword = deleteAllStaleFromName ? ALL_STALE_WORKTREES_KEYWORD : ALL_CLOSED_PRS_KEYWORD;
    throw new TaskExitError(2, `${keyword} can only be used with --delete.`);
  }

  if (closedPrsFlag) {
    await runClosedPrFlow(deleteFlag);
    return;
  }

  if (staleFlag) {
    await runStaleFlow(deleteFlag);
    return;
  }
  if (deleteFlag) {
    if (deleteAllStaleFromName) {
      await runStaleFlow(true, ALL_STALE_WORKTREES_KEYWORD);
      return;
    }
    if (deleteAllClosedFromName) {
      await runDeleteClosedPrWorktreesFlow();
      return;
    }
    if (pullRequest) {
      await runDeletePullRequestWorktreesFlow(pullRequestSelector);
      return;
    }
    await runDeleteFlow(name);
    return;
  }
  if (pullRequest) {
    if (isAllClosedPrsKeyword(pullRequestSelector)) {
      throw new TaskExitError(2, `${ALL_CLOSED_PRS_KEYWORD} can only be used with --delete.`);
    }
    const prNumber = pullRequestSelector === "pick" ? "" : normalizeOptionalPrNumber(pullRequestSelector);
    runPullRequestFlow(prNumber);
    return;
  }
  runCreateFlow(name);
}

void runMain().catch((error) => {
  console.error(`Error: ${getErrorMessage(error)}`);
  process.exit(error instanceof TaskExitError ? error.code : 1);
});
