#!/usr/bin/env bun
//MISE description="Poll watched pull requests and remove merged or closed entries."
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE arg "<action>" help="Watch action: add, remove, list, or poll"
//USAGE arg "[pull-requests]..." help="Pull request numbers for add or remove"
//USAGE flag "--state-file <path>" help="Watch state file path"
//USAGE flag "--format <format>" help="Output format: json or text" default="json"

import { randomUUID } from "node:crypto";
import { mkdir, readFile, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { homedir } from "node:os";
import { resolveUpstreamContext } from "../../utils/git.js";

export {};

type Review = {
  id?: number | string;
  node_id?: string;
  author?: { login?: string };
  submittedAt?: string;
  state?: string;
  body?: string;
  url?: string;
  html_url?: string;
};

type Check = {
  name?: string;
  status?: string;
  conclusion?: string;
  context?: string;
  state?: string;
};

type ReviewComment = {
  id?: number | string;
  node_id?: string;
  pull_request_review_id?: number | string;
  in_reply_to_id?: number | string;
  thread_id?: number | string;
  isResolved?: boolean;
  resolved?: boolean;
  user?: { login?: string };
  created_at?: string;
  body?: string;
  path?: string;
  line?: number;
  start_line?: number;
  start_side?: string;
  side?: string;
  html_url?: string;
};

type PullRequest = {
  number: number;
  state: string;
  mergedAt?: string;
  closedAt?: string;
  headRefName?: string;
  headRefOid?: string;
  reviewDecision?: string;
  reviews?: Review[];
  statusCheckRollup?: Check[];
};

type WatchEntry = {
  number: number;
  addedAt: string;
  lastSeenAt?: string;
  seen?: {
    reviews: string[];
    inline_comments: string[];
    issue_comments: string[];
  };
  head?: string;
  graceChecks?: number;
  graceComplete?: boolean;
};

type PollPayload = {
  action: "poll";
  repository: string;
  state_file: string;
  watch_empty: boolean;
  scheduler_should_stop: boolean;
  warnings: string[];
  pull_requests: Array<Record<string, unknown>>;
};

type AddPayload = {
  action: "add" | "remove";
  repository: string;
  state_file: string;
  watch_empty: boolean;
  warnings: string[];
  pull_requests: WatchEntry[];
  reconciliation: Array<Record<string, unknown>>;
};

type PendingPoll = {
  payload: PollPayload;
  next_pull_requests: WatchEntry[];
};

type PendingAdd = {
  payload: AddPayload;
  next_pull_requests: WatchEntry[];
  requested_numbers: number[];
};

type WatchState = {
  version: 1;
  repository: string;
  pull_requests: WatchEntry[];
  pending_poll?: PendingPoll;
  pending_add?: PendingAdd;
};

type CommentKind = "pulls" | "issues";

type CommentCollection = {
  comments: ReviewComment[];
  pages: number;
};

type LockOwner = {
  pid: number;
  identity: string;
  identity_version: 2 | "legacy" | "unknown";
};

type LockSnapshot = {
  raw: string;
  stale: boolean;
};

const ACTION = (process.env.usage_action ?? "").trim();
const PULL_REQUESTS = (process.env.usage_pull_requests ?? "").trim();
const STATE_FILE = (process.env.usage_state_file ?? "").trim();
const FORMAT = (process.env.usage_format ?? "json").trim();

function getStateFile(): string {
  if (STATE_FILE) return resolve(STATE_FILE);
  const stateHome = process.env.XDG_STATE_HOME || join(homedir(), ".local", "state");
  return join(stateHome, "dot", "pr-review-watch.json");
}

function parseNumbers(): number[] {
  return PULL_REQUESTS.split(/\s+/)
    .filter(Boolean)
    .map((value) => {
      const unquoted =
        (value.startsWith("'") && value.endsWith("'")) || (value.startsWith('"') && value.endsWith('"'))
          ? value.slice(1, -1)
          : value;
      return Number(unquoted);
    })
    .filter((value) => Number.isSafeInteger(value) && value > 0);
}

async function run(command: string, args: string[]): Promise<string> {
  const proc = Bun.spawn([command, ...args], {
    cwd: process.cwd(),
    env: process.env,
    stderr: "pipe",
    stdout: "pipe",
  });
  const exitCode = await proc.exited;
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  if (exitCode !== 0) {
    throw new Error(stderr.trim() || stdout.trim() || `${command} ${args.join(" ")} failed`);
  }
  return stdout;
}

function parseJson<T>(output: string, description: string): T {
  try {
    return JSON.parse(output) as T;
  } catch (error) {
    throw new Error(`${description}: invalid JSON: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function getPullRequest(repository: string, number: number): Promise<PullRequest> {
  const description = `pull request #${number} metadata`;
  let output: string;
  try {
    output = await run("gh", [
      "pr",
      "view",
      String(number),
      "--repo",
      repository,
      "--json",
      "number,state,mergedAt,closedAt,headRefName,headRefOid,reviewDecision,reviews,statusCheckRollup",
    ]);
  } catch (error) {
    throw new Error(`${description} failed: ${error instanceof Error ? error.message : String(error)}`);
  }
  const value = parseJson<unknown>(output, description);
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`${description}: response is not an object`);
  }
  const pullRequest = value as PullRequest;
  if (!Number.isSafeInteger(pullRequest.number) || pullRequest.number !== number) {
    throw new Error(`${description}: response has an invalid number`);
  }
  if (!["OPEN", "CLOSED", "MERGED"].includes(pullRequest.state)) {
    throw new Error(`${description}: response has an invalid state`);
  }
  if (!Array.isArray(pullRequest.reviews)) {
    throw new Error(`${description}: reviews is not an array`);
  }
  if (!Array.isArray(pullRequest.statusCheckRollup)) {
    throw new Error(`${description}: statusCheckRollup is not an array`);
  }
  return pullRequest;
}

function commentEndpoint(hostname: string, owner: string, repo: string, number: number, kind: CommentKind): string {
  return `repos/${owner}/${repo}/${kind}/${number}/comments`;
}

async function getReviewComments(
  hostname: string,
  owner: string,
  repo: string,
  number: number,
  kind: CommentKind,
): Promise<CommentCollection> {
  const path = commentEndpoint(hostname, owner, repo, number, kind);
  const description = `${kind === "pulls" ? "inline" : "issue"} comments for PR #${number} (${path})`;
  let output: string;
  try {
    output = await run("gh", ["api", "--hostname", hostname, "--paginate", "--slurp", path]);
  } catch (error) {
    throw new Error(`${description} failed: ${error instanceof Error ? error.message : String(error)}`);
  }

  const value = parseJson<unknown>(output, description);
  if (!Array.isArray(value)) {
    throw new Error(`${description}: response is not an array of pages`);
  }

  const comments: ReviewComment[] = [];
  for (let pageIndex = 0; pageIndex < value.length; pageIndex += 1) {
    const page = value[pageIndex];
    if (!Array.isArray(page)) {
      throw new Error(`${description}: page ${pageIndex + 1} is not an array`);
    }
    for (let itemIndex = 0; itemIndex < page.length; itemIndex += 1) {
      const item = page[itemIndex];
      if (!item || typeof item !== "object" || Array.isArray(item)) {
        throw new Error(`${description}: page ${pageIndex + 1} item ${itemIndex + 1} is not an object`);
      }
      comments.push(item as ReviewComment);
    }
  }
  return { comments, pages: value.length };
}

function isValidTimestamp(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0 && Number.isFinite(Date.parse(value));
}

function timestampValue(value: string): number {
  return Date.parse(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function validateWatchEntry(value: unknown, stateFile: string): value is WatchEntry {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  const entry = value as Partial<WatchEntry>;
  const number = entry.number;
  if (typeof number !== "number" || !Number.isSafeInteger(number) || number <= 0 || !isValidTimestamp(entry.addedAt)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (entry.lastSeenAt !== undefined && !isValidTimestamp(entry.lastSeenAt)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (entry.head !== undefined && (typeof entry.head !== "string" || entry.head.trim().length === 0)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (entry.seen !== undefined) {
    if (
      !entry.seen ||
      !Array.isArray(entry.seen.reviews) ||
      !Array.isArray(entry.seen.inline_comments) ||
      !Array.isArray(entry.seen.issue_comments) ||
      ![...entry.seen.reviews, ...entry.seen.inline_comments, ...entry.seen.issue_comments].every(
        (id) => typeof id === "string" && id.length > 0,
      )
    ) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  if (
    entry.graceChecks !== undefined &&
    (!Number.isSafeInteger(entry.graceChecks) || entry.graceChecks < 0 || entry.graceChecks > 4)
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (entry.graceComplete !== undefined && typeof entry.graceComplete !== "boolean") {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  return true;
}

function validatePollResult(value: unknown, stateFile: string): asserts value is Record<string, unknown> {
  if (!isObject(value)) throw new Error(`invalid watch state: ${stateFile}`);
  if (!Number.isSafeInteger(value.number) || (value.number as number) <= 0 || typeof value.state !== "string") {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  for (const key of ["new_reviews", "new_inline_comments", "new_issue_comments", "checks"]) {
    if (!Array.isArray(value[key])) throw new Error(`invalid watch state: ${stateFile}`);
    if (!(value[key] as unknown[]).every(isObject)) throw new Error(`invalid watch state: ${stateFile}`);
  }
  for (const key of ["inline_comments_pages", "issue_comments_pages"]) {
    if (!Number.isSafeInteger(value[key]) || (value[key] as number) < 0) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  for (const key of ["has_new_activity", "has_failed_checks", "action_required"]) {
    if (typeof value[key] !== "boolean") throw new Error(`invalid watch state: ${stateFile}`);
  }
  for (const key of ["has_pending_checks", "grace_complete", "keep_watching", "removed"]) {
    if (value[key] !== undefined && typeof value[key] !== "boolean") {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  if (value.removed === true && typeof value.reason !== "string") {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
}

function validatePayloadHeader(
  value: unknown,
  action: "add" | "poll",
  repository: string,
  stateFile: string,
): asserts value is Record<string, unknown> {
  if (
    !isObject(value) ||
    value.action !== action ||
    value.repository !== repository ||
    value.state_file !== stateFile
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (typeof value.watch_empty !== "boolean" || !Array.isArray(value.warnings)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (!(value.warnings as unknown[]).every((warning) => typeof warning === "string")) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
}

function validatePendingPoll(
  value: unknown,
  activePullRequests: WatchEntry[],
  repository: string,
  stateFile: string,
): value is PendingPoll {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  const pending = value as Partial<PendingPoll>;
  if (!pending.payload || typeof pending.payload !== "object" || !Array.isArray(pending.next_pull_requests)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  validatePayloadHeader(pending.payload, "poll", repository, stateFile);
  if (typeof pending.payload.scheduler_should_stop !== "boolean" || !Array.isArray(pending.payload.pull_requests)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  const resultNumbers = new Set<number>();
  for (const result of pending.payload.pull_requests) {
    validatePollResult(result, stateFile);
    const number = (result as Record<string, unknown>).number as number;
    if (resultNumbers.has(number)) throw new Error(`invalid watch state: ${stateFile}`);
    resultNumbers.add(number);
  }
  const nextNumbers = new Set<number>();
  for (const entry of pending.next_pull_requests) {
    validateWatchEntry(entry, stateFile);
    if (nextNumbers.has(entry.number)) throw new Error(`invalid watch state: ${stateFile}`);
    nextNumbers.add(entry.number);
  }
  for (const number of resultNumbers) {
    const result = pending.payload.pull_requests.find((item) => (item as Record<string, unknown>).number === number) as
      Record<string, unknown> | undefined;
    if (result?.removed !== true && !nextNumbers.has(number)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  for (const number of nextNumbers) {
    const result = pending.payload.pull_requests.find((item) => (item as Record<string, unknown>).number === number) as
      Record<string, unknown> | undefined;
    if (!result || result.removed === true) throw new Error(`invalid watch state: ${stateFile}`);
  }
  const activeNumbers = new Set(activePullRequests.map((entry) => entry.number));
  for (const number of activeNumbers) {
    const result = pending.payload.pull_requests.find((item) => (item as Record<string, unknown>).number === number) as
      Record<string, unknown> | undefined;
    if (!result && !nextNumbers.has(number)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
    if (result?.removed === true && nextNumbers.has(number)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  if (pending.payload.watch_empty !== (pending.next_pull_requests.length === 0)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (
    pending.payload.scheduler_should_stop &&
    pending.next_pull_requests.some((entry) => entry.graceComplete !== true)
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  return true;
}

function validatePendingAdd(value: unknown, repository: string, stateFile: string): value is PendingAdd {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  const pending = value as Partial<PendingAdd>;
  if (
    !pending.payload ||
    typeof pending.payload !== "object" ||
    !Array.isArray(pending.next_pull_requests) ||
    !Array.isArray(pending.requested_numbers)
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (!pending.requested_numbers.every((number) => Number.isSafeInteger(number) && number > 0)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (
    pending.requested_numbers.length === 0 ||
    new Set(pending.requested_numbers).size !== pending.requested_numbers.length
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (pending.payload.action !== "add") {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  validatePayloadHeader(pending.payload, "add", repository, stateFile);
  if (!Array.isArray(pending.payload.pull_requests) || !Array.isArray(pending.payload.reconciliation)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (!(pending.payload.reconciliation as unknown[]).every(isObject)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  const requestedNumbers = new Set(pending.requested_numbers);
  const nextNumbers = new Set<number>();
  for (const entry of pending.next_pull_requests) {
    validateWatchEntry(entry, stateFile);
    if (nextNumbers.has(entry.number)) throw new Error(`invalid watch state: ${stateFile}`);
    nextNumbers.add(entry.number);
  }
  const payloadNumbers = new Set<number>();
  for (const entry of pending.payload.pull_requests) {
    validateWatchEntry(entry, stateFile);
    if (payloadNumbers.has(entry.number)) throw new Error(`invalid watch state: ${stateFile}`);
    payloadNumbers.add(entry.number);
  }
  if (
    payloadNumbers.size !== nextNumbers.size ||
    [...payloadNumbers].some((number) => !nextNumbers.has(number)) ||
    [...nextNumbers].some((number) => !payloadNumbers.has(number))
  ) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  for (const number of requestedNumbers) {
    if (!nextNumbers.has(number)) throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (pending.payload.watch_empty !== (pending.next_pull_requests.length === 0)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  return true;
}

async function loadState(repository: string, stateFile: string): Promise<WatchState> {
  try {
    const parsed = parseJson<Partial<WatchState>>(await readFile(stateFile, "utf8"), `watch state ${stateFile}`);
    if (parsed.version !== 1 || parsed.repository !== repository || !Array.isArray(parsed.pull_requests)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
    const pullRequests: WatchEntry[] = [];
    for (const entry of parsed.pull_requests) {
      if (!validateWatchEntry(entry, stateFile)) {
        throw new Error(`invalid watch state: ${stateFile}`);
      }
      pullRequests.push(entry);
    }
    if (parsed.pending_poll !== undefined) {
      validatePendingPoll(parsed.pending_poll, pullRequests, repository, stateFile);
    }
    if (parsed.pending_add !== undefined) {
      validatePendingAdd(parsed.pending_add, repository, stateFile);
    }
    if (parsed.pending_poll !== undefined && parsed.pending_add !== undefined) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
    return {
      version: 1,
      repository,
      pull_requests: pullRequests,
      pending_poll: parsed.pending_poll,
      pending_add: parsed.pending_add,
    };
  } catch (error) {
    if (error instanceof Error && "code" in error && (error as NodeJS.ErrnoException).code === "ENOENT") {
      return { version: 1, repository, pull_requests: [] };
    }
    throw error;
  }
}

async function saveState(stateFile: string, state: WatchState): Promise<void> {
  if (state.version !== 1 || !state.repository || !Array.isArray(state.pull_requests)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  for (const entry of state.pull_requests) {
    if (!validateWatchEntry(entry, stateFile)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
  }
  if (state.pending_poll !== undefined) {
    validatePendingPoll(state.pending_poll, state.pull_requests, state.repository, stateFile);
  }
  if (state.pending_add !== undefined) {
    validatePendingAdd(state.pending_add, state.repository, stateFile);
  }
  if (state.pending_poll !== undefined && state.pending_add !== undefined) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  await mkdir(dirname(stateFile), { recursive: true });
  const temporaryFile = `${stateFile}.tmp.${process.pid}.${randomUUID()}`;
  try {
    await writeFile(temporaryFile, `${JSON.stringify(state, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
    await rename(temporaryFile, stateFile);
  } catch (error) {
    await rm(temporaryFile, { force: true });
    throw error;
  }
}

function validateFormat(): void {
  if (FORMAT !== "json" && FORMAT !== "text") {
    throw new Error(`unsupported --format value: ${FORMAT}`);
  }
}

function emit(value: unknown): void {
  if (FORMAT === "json") {
    console.log(JSON.stringify(value, null, 2));
    return;
  }
  const payload = value as {
    action?: string;
    repository?: string;
    pull_requests?: Array<Record<string, unknown>>;
    reconciliation?: Array<Record<string, unknown>>;
  };
  console.log(`${payload.action ?? "watch"} ${payload.repository ?? ""}`.trim());
  for (const entry of payload.pull_requests ?? []) {
    console.log(JSON.stringify(entry));
  }
  for (const entry of payload.reconciliation ?? []) {
    console.log(JSON.stringify({ reconciliation: entry }));
  }
}

function isErrno(error: unknown, code: string): boolean {
  return error instanceof Error && "code" in error && (error as NodeJS.ErrnoException).code === code;
}

async function processIdentity(pid: number): Promise<string | undefined> {
  const inspection = await inspectProcess(pid);
  return inspection.state === "alive" ? inspection.identity : undefined;
}

async function inspectProcess(
  pid: number,
): Promise<{ state: "alive"; identity: string } | { state: "dead" | "unknown" }> {
  const proc = Bun.spawn(["ps", "-p", String(pid), "-o", "lstart="], {
    cwd: process.cwd(),
    env: { ...process.env, LC_ALL: "C", LANG: "C", TZ: "UTC" },
    stderr: "pipe",
    stdout: "pipe",
  });
  const exitCode = await proc.exited;
  const stdout = (await new Response(proc.stdout).text()).trim();
  const stderr = (await new Response(proc.stderr).text()).trim();
  if (exitCode === 0 && stdout) return { state: "alive", identity: stdout };
  if (
    exitCode === 1 &&
    !stdout &&
    (!stderr || /(?:no such process|does not exist|process id too large|invalid process)/i.test(stderr))
  ) {
    return { state: "dead" };
  }
  return { state: "unknown" };
}

function parseLockOwner(raw: string): LockOwner | undefined {
  try {
    const value = JSON.parse(raw) as Partial<LockOwner>;
    const pid = value.pid;
    if (
      typeof pid !== "number" ||
      !Number.isSafeInteger(pid) ||
      pid <= 0 ||
      typeof value.identity !== "string" ||
      value.identity.trim().length === 0
    ) {
      return undefined;
    }
    const identityVersion =
      value.identity_version === 2 ? 2 : value.identity_version === undefined ? "legacy" : "unknown";
    return { pid, identity: value.identity, identity_version: identityVersion };
  } catch {
    return undefined;
  }
}

function ownerPid(raw: string): number | undefined {
  const match = raw.match(/"pid"\s*:\s*(\d+)/);
  const value = match?.[1] ?? raw.trim();
  if (!/^\d+$/.test(value)) return undefined;
  const pid = Number(value);
  return Number.isSafeInteger(pid) && pid > 0 ? pid : undefined;
}

async function readLockOwner(lockDirectory: string): Promise<LockOwner | undefined> {
  try {
    return parseLockOwner(await readFile(join(lockDirectory, "owner"), "utf8"));
  } catch (error) {
    if (isErrno(error, "ENOENT")) return undefined;
    throw error;
  }
}

function sameLockOwner(left: LockOwner, right: LockOwner): boolean {
  return left.pid === right.pid && left.identity === right.identity;
}

async function lockSnapshot(lockDirectory: string): Promise<LockSnapshot | undefined> {
  let raw: string;
  try {
    raw = await readFile(join(lockDirectory, "owner"), "utf8");
  } catch (error) {
    if (isErrno(error, "ENOENT") || isErrno(error, "ENOTDIR")) return undefined;
    throw error;
  }
  const owner = parseLockOwner(raw);
  const pid = owner?.pid ?? ownerPid(raw);
  if (pid === undefined) return { raw, stale: false };
  const inspection = await inspectProcess(pid);
  if (inspection.state === "dead") return { raw, stale: true };
  if (inspection.state !== "alive" || owner === undefined || owner.identity_version !== 2) {
    return { raw, stale: false };
  }
  return { raw, stale: inspection.identity !== owner.identity };
}

async function acquireLock(stateFile: string): Promise<() => Promise<void>> {
  const lockDirectory = `${stateFile}.lock`;
  const ownerIdentity = await processIdentity(process.pid);
  if (!ownerIdentity) {
    throw new Error("unable to identify the review-watch process for lock ownership");
  }
  const owner: LockOwner = { pid: process.pid, identity: ownerIdentity, identity_version: 2 };
  await mkdir(dirname(stateFile), { recursive: true });
  for (;;) {
    let created = false;
    try {
      await mkdir(lockDirectory);
      created = true;
      await writeFile(join(lockDirectory, "owner"), `${JSON.stringify(owner)}\n`, "utf8");
      break;
    } catch (error) {
      if (created) await rm(lockDirectory, { recursive: true, force: true });
      if (!isErrno(error, "EEXIST")) throw error;
      const observed = await lockSnapshot(lockDirectory);
      if (!observed?.stale) {
        throw new Error(`watch state is locked: ${stateFile}`);
      }
      const quarantineDirectory = `${lockDirectory}.stale.${process.pid}.${randomUUID()}`;
      try {
        await rename(lockDirectory, quarantineDirectory);
      } catch (quarantineError) {
        if (isErrno(quarantineError, "ENOENT") || isErrno(quarantineError, "ENOTDIR")) continue;
        throw quarantineError;
      }

      const claimed = await lockSnapshot(quarantineDirectory);
      if (claimed?.raw === observed.raw && claimed.stale) {
        await rm(quarantineDirectory, { recursive: true, force: true });
        continue;
      }

      try {
        await rename(quarantineDirectory, lockDirectory);
      } catch (restoreError) {
        if (!isErrno(restoreError, "EEXIST") && !isErrno(restoreError, "ENOENT")) throw restoreError;
      }
    }
  }
  return async () => {
    const currentOwner = await readLockOwner(lockDirectory);
    if (currentOwner && sameLockOwner(currentOwner, owner)) {
      await rm(lockDirectory, { recursive: true, force: true });
    }
  };
}

function activityId(value: { id?: number | string; node_id?: string }, fallback: string): string {
  if (value.id !== undefined) return String(value.id);
  if (value.node_id) return value.node_id;
  return fallback;
}

function reviewId(review: Review, index: number): string {
  return activityId(
    review,
    `review:${review.submittedAt ?? "unknown"}:${review.author?.login ?? "unknown"}:${review.body ?? ""}:${index}`,
  );
}

function commentId(comment: ReviewComment, index: number): string {
  return activityId(
    comment,
    `comment:${comment.created_at ?? "unknown"}:${comment.user?.login ?? "unknown"}:${comment.body ?? ""}:${index}`,
  );
}

function pullRequestHead(pullRequest: PullRequest): string | undefined {
  return pullRequest.headRefOid ?? pullRequest.headRefName;
}

function isPendingReview(review: Review): boolean {
  return review.state?.toUpperCase() === "PENDING" && review.submittedAt == null;
}

function latestSubmittedReviews(reviews: Review[]): Review[] {
  const latest = new Map<string, { review: Review; index: number }>();
  for (const [index, review] of reviews.entries()) {
    if (isPendingReview(review)) continue;
    const reviewer = review.author?.login ?? `review:${review.id ?? index}`;
    const current = latest.get(reviewer);
    if (
      !current ||
      timestampValue(review.submittedAt as string) > timestampValue(current.review.submittedAt as string) ||
      (timestampValue(review.submittedAt as string) === timestampValue(current.review.submittedAt as string) &&
        index > current.index)
    ) {
      latest.set(reviewer, { review, index });
    }
  }
  return [...latest.values()].map(({ review }) => review);
}

function hasUnresolvedReviewState(reviews: Review[]): boolean {
  return latestSubmittedReviews(reviews).some((review) => review.state?.toUpperCase() === "CHANGES_REQUESTED");
}

function formatReview(review: Review, index: number): Record<string, unknown> {
  return {
    id: review.id,
    node_id: review.node_id,
    author: review.author?.login,
    submitted_at: review.submittedAt,
    state: review.state,
    body: review.body ?? "",
    url: review.url ?? review.html_url,
    summary: (review.body ?? "").split("\n").find(Boolean) ?? "",
    activity_id: reviewId(review, index),
  };
}

type ResolutionCollection = {
  values: Array<boolean | null>;
  warnings: string[];
};

function resolutionQuery(): string {
  return `
    query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $cursor) {
            nodes {
              id
              isResolved
              comments(first: 100) {
                nodes { id fullDatabaseId }
                pageInfo { hasNextPage endCursor }
              }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }
  `;
}

function threadCommentsQuery(): string {
  return `
    query($id: ID!, $cursor: String) {
      node(id: $id) {
        ... on PullRequestReviewThread {
          isResolved
          comments(first: 100, after: $cursor) {
            nodes { id fullDatabaseId }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }
  `;
}

async function reviewThreadResolutions(
  hostname: string,
  owner: string,
  repo: string,
  number: number,
): Promise<{ byComment: Map<string, boolean>; warnings: string[] }> {
  const byComment = new Map<string, boolean>();
  const warnings: string[] = [];
  const requestedOuterCursors = new Set<string>();
  let cursor: string | undefined;
  try {
    for (;;) {
      if (cursor !== undefined) {
        if (requestedOuterCursors.has(cursor)) {
          warnings.push(`PR #${number} review thread resolution pagination repeated a cursor; stopping conservatively`);
          break;
        }
        requestedOuterCursors.add(cursor);
      }
      const args = [
        "api",
        "--hostname",
        hostname,
        "graphql",
        "-f",
        `query=${resolutionQuery()}`,
        "-F",
        `owner=${owner}`,
        "-F",
        `name=${repo}`,
        "-F",
        `number=${number}`,
      ];
      if (cursor) args.push("-f", `cursor=${cursor}`);
      const output = await run("gh", args);
      const value = parseJson<unknown>(output, "review comment thread resolution");
      const repository = isObject(value) && isObject(value.data) ? value.data.repository : undefined;
      const pullRequest = isObject(repository) ? repository.pullRequest : undefined;
      const reviewThreads = isObject(pullRequest) ? pullRequest.reviewThreads : undefined;
      const nodes = isObject(reviewThreads) ? reviewThreads.nodes : undefined;
      const pageInfo = isObject(reviewThreads) ? reviewThreads.pageInfo : undefined;
      if (
        !Array.isArray(nodes) ||
        !isObject(pageInfo) ||
        typeof pageInfo.hasNextPage !== "boolean" ||
        (pageInfo.endCursor !== null && typeof pageInfo.endCursor !== "string")
      ) {
        warnings.push(`PR #${number} review thread resolution lookup returned an invalid response`);
        break;
      }
      for (const node of nodes) {
        if (
          !isObject(node) ||
          typeof node.id !== "string" ||
          typeof node.isResolved !== "boolean" ||
          !isObject(node.comments)
        ) {
          warnings.push(`PR #${number} review thread resolution was unavailable`);
          continue;
        }
        const comments = node.comments.nodes;
        const commentsPageInfo = node.comments.pageInfo;
        if (
          !Array.isArray(comments) ||
          !isObject(commentsPageInfo) ||
          typeof commentsPageInfo.hasNextPage !== "boolean" ||
          (commentsPageInfo.endCursor !== null && typeof commentsPageInfo.endCursor !== "string")
        ) {
          warnings.push(`PR #${number} review thread resolution returned an invalid response`);
          continue;
        }
        const addComments = (items: unknown[], resolved: boolean): void => {
          for (const comment of items) {
            if (!isObject(comment)) continue;
            if (
              (typeof comment.fullDatabaseId === "string" || typeof comment.fullDatabaseId === "number") &&
              String(comment.fullDatabaseId).length > 0
            ) {
              byComment.set(String(comment.fullDatabaseId), resolved);
            }
            if (typeof comment.id === "string" && comment.id.length > 0) {
              byComment.set(comment.id, resolved);
            }
          }
        };
        addComments(comments, node.isResolved);
        const requestedCommentCursors = new Set<string>();
        let commentCursor = typeof commentsPageInfo.endCursor === "string" ? commentsPageInfo.endCursor : undefined;
        let commentHasNextPage = commentsPageInfo.hasNextPage;
        while (commentHasNextPage) {
          if (!commentCursor) {
            warnings.push(`PR #${number} review thread comment pagination was unavailable`);
            break;
          }
          if (requestedCommentCursors.has(commentCursor)) {
            warnings.push(`PR #${number} review thread comment pagination repeated a cursor; stopping conservatively`);
            break;
          }
          requestedCommentCursors.add(commentCursor);
          const output = await run("gh", [
            "api",
            "--hostname",
            hostname,
            "graphql",
            "-f",
            `query=${threadCommentsQuery()}`,
            "-F",
            `id=${node.id}`,
            "-f",
            `cursor=${commentCursor}`,
          ]);
          const value = parseJson<unknown>(output, "review comment thread resolution");
          const thread = isObject(value) && isObject(value.data) ? value.data.node : undefined;
          const threadComments = isObject(thread) ? thread.comments : undefined;
          const threadNodes = isObject(threadComments) ? threadComments.nodes : undefined;
          const threadPageInfo = isObject(threadComments) ? threadComments.pageInfo : undefined;
          if (
            !isObject(thread) ||
            typeof thread.isResolved !== "boolean" ||
            !Array.isArray(threadNodes) ||
            !isObject(threadPageInfo) ||
            typeof threadPageInfo.hasNextPage !== "boolean" ||
            (threadPageInfo.endCursor !== null && typeof threadPageInfo.endCursor !== "string")
          ) {
            warnings.push(`PR #${number} review thread resolution returned an invalid response`);
            break;
          }
          addComments(threadNodes, thread.isResolved);
          commentHasNextPage = threadPageInfo.hasNextPage;
          if (!commentHasNextPage) break;
          commentCursor = typeof threadPageInfo.endCursor === "string" ? threadPageInfo.endCursor : undefined;
        }
      }
      if (!pageInfo.hasNextPage) break;
      if (typeof pageInfo.endCursor !== "string" || pageInfo.endCursor.length === 0) {
        warnings.push(`PR #${number} review thread resolution pagination was unavailable`);
        break;
      }
      cursor = pageInfo.endCursor;
    }
  } catch {
    warnings.push(`PR #${number} review thread batch resolution lookup failed`);
  }
  return { byComment, warnings };
}

async function commentResolutions(
  hostname: string,
  owner: string,
  repo: string,
  comments: ReviewComment[],
  number: number,
): Promise<ResolutionCollection> {
  const values = comments.map(() => null as boolean | null);
  const lookups: Array<{ index: number; comment: ReviewComment }> = [];
  for (const [index, comment] of comments.entries()) {
    if (typeof (comment.isResolved ?? comment.resolved) === "boolean") {
      values[index] = (comment.isResolved ?? comment.resolved) as boolean;
    } else if (comment.node_id) {
      lookups.push({ index, comment });
    }
  }
  const warnings: string[] = [];
  if (lookups.length === 0) return { values, warnings };
  const resolutions = await reviewThreadResolutions(hostname, owner, repo, number);
  warnings.push(...resolutions.warnings);
  for (const { index, comment } of lookups) {
    const keys = [comment.id, comment.node_id].filter((value): value is string | number => value !== undefined);
    const resolution = keys.map((key) => resolutions.byComment.get(String(key))).find((value) => value !== undefined);
    if (resolution === undefined && resolutions.warnings.length === 0) {
      warnings.push(`PR #${number} review thread ${commentId(comment, index)} resolution was unavailable`);
    } else {
      values[index] = resolution ?? null;
    }
  }
  return { values, warnings };
}

function formatComment(
  comment: ReviewComment,
  index: number,
  kind: CommentKind,
  resolution: boolean | null,
): Record<string, unknown> {
  return {
    id: comment.id,
    node_id: comment.node_id,
    pull_request_review_id: comment.pull_request_review_id,
    in_reply_to_id: comment.in_reply_to_id,
    thread_id: comment.thread_id,
    is_resolved: resolution,
    author: comment.user?.login,
    created_at: comment.created_at,
    path: comment.path,
    line: comment.line,
    start_line: comment.start_line,
    start_side: comment.start_side,
    side: comment.side,
    body: comment.body ?? "",
    url: comment.html_url,
    activity_id: `${kind}:${commentId(comment, index)}`,
  };
}

function validateReview(review: unknown, number: number, index: number): boolean {
  if (!review || typeof review !== "object" || Array.isArray(review)) {
    throw new Error(`PR #${number} review ${index + 1} is malformed`);
  }
  const value = review as Review;
  if (value.body !== undefined && typeof value.body !== "string") {
    throw new Error(`PR #${number} review ${index + 1} has a malformed body`);
  }
  if (isPendingReview(value)) return false;
  if (!isValidTimestamp(value.submittedAt)) {
    throw new Error(`PR #${number} review ${index + 1} has a missing or malformed submittedAt timestamp`);
  }
  return true;
}

function validateComment(
  comment: unknown,
  number: number,
  kind: CommentKind,
  index: number,
): asserts comment is ReviewComment {
  if (!comment || typeof comment !== "object" || Array.isArray(comment)) {
    throw new Error(`PR #${number} ${kind === "pulls" ? "inline" : "issue"} comment ${index + 1} is malformed`);
  }
  const value = comment as ReviewComment;
  if (!isValidTimestamp(value.created_at)) {
    throw new Error(
      `PR #${number} ${kind === "pulls" ? "inline" : "issue"} comment ${index + 1} has a missing or malformed created_at timestamp`,
    );
  }
  if (value.body !== undefined && typeof value.body !== "string") {
    throw new Error(`PR #${number} ${kind === "pulls" ? "inline" : "issue"} comment ${index + 1} has a malformed body`);
  }
}

function newReviews(
  reviews: Review[],
  cutoff: string,
  number: number,
  seen: Set<string>,
): Array<Record<string, unknown>> {
  return reviews.flatMap((review, index) => {
    if (!validateReview(review, number, index)) return [];
    const id = reviewId(review, index);
    const submittedAt = review.submittedAt as string;
    if (seen.has(id) || (seen.size === 0 && timestampValue(submittedAt) <= timestampValue(cutoff))) return [];
    return [formatReview(review, index)];
  });
}

function newComments(
  comments: ReviewComment[],
  cutoff: string,
  number: number,
  kind: CommentKind,
  seen: Set<string>,
  resolutions: Array<boolean | null>,
): Array<Record<string, unknown>> {
  return comments.flatMap((comment, index) => {
    validateComment(comment, number, kind, index);
    const id = commentId(comment, index);
    const createdAt = comment.created_at as string;
    if (seen.has(`${kind}:${id}`) || (seen.size === 0 && timestampValue(createdAt) <= timestampValue(cutoff)))
      return [];
    return [formatComment(comment, index, kind, resolutions[index] ?? null)];
  });
}

function checksFor(pullRequest: PullRequest): Array<Record<string, unknown>> {
  return (pullRequest.statusCheckRollup ?? []).map((check) => ({
    name: check.name ?? check.context,
    status: check.status ?? check.state,
    conclusion: check.conclusion,
  }));
}

function hasFailedChecks(checks: Array<Record<string, unknown>>): boolean {
  return checks.some((check) => {
    const conclusion = typeof check.conclusion === "string" ? check.conclusion.toUpperCase() : "";
    const status = typeof check.status === "string" ? check.status.toUpperCase() : "";
    return (
      (conclusion.length > 0 && !["SUCCESS", "SKIPPED", "NEUTRAL"].includes(conclusion)) ||
      ["FAILURE", "ERROR"].includes(status)
    );
  });
}

function hasPendingChecks(checks: Array<Record<string, unknown>>): boolean {
  return checks.some((check) => {
    const status = typeof check.status === "string" ? check.status.toUpperCase() : "";
    return ["EXPECTED", "IN_PROGRESS", "PENDING", "QUEUED", "REQUESTED", "WAITING"].includes(status);
  });
}

function seenFor(
  reviews: Review[],
  inlineComments: ReviewComment[],
  issueComments: ReviewComment[],
): WatchEntry["seen"] {
  return {
    reviews: reviews.filter((review, index) => validateReview(review, 0, index)).map(reviewId),
    inline_comments: inlineComments.map((comment, index) => `pulls:${commentId(comment, index)}`),
    issue_comments: issueComments.map((comment, index) => `issues:${commentId(comment, index)}`),
  };
}

function mergeSeen(previous: WatchEntry["seen"], current: WatchEntry["seen"]): WatchEntry["seen"] {
  return {
    reviews: [...new Set([...(previous?.reviews ?? []), ...(current?.reviews ?? [])])],
    inline_comments: [...new Set([...(previous?.inline_comments ?? []), ...(current?.inline_comments ?? [])])],
    issue_comments: [...new Set([...(previous?.issue_comments ?? []), ...(current?.issue_comments ?? [])])],
  };
}

async function reconciliationFor(
  hostname: string,
  owner: string,
  repo: string,
  pullRequest: PullRequest,
  inlineCollection: CommentCollection,
  issueCollection: CommentCollection,
  number: number,
): Promise<Record<string, unknown>> {
  const reviews = pullRequest.reviews ?? [];
  const inlineComments = inlineCollection.comments;
  const issueComments = issueCollection.comments;
  const formattedReviews = reviews.flatMap((review, index) => {
    return validateReview(review, number, index) ? [formatReview(review, index)] : [];
  });
  const inlineResolution = await commentResolutions(hostname, owner, repo, inlineComments, number);
  const inlineResolutions = inlineResolution.values;
  const issueResolutions = issueComments.map(() => null as boolean | null);
  const formattedInlineComments = inlineComments.map((comment, index) => {
    validateComment(comment, number, "pulls", index);
    return formatComment(comment, index, "pulls", inlineResolutions[index] ?? null);
  });
  const formattedIssueComments = issueComments.map((comment, index) => {
    validateComment(comment, number, "issues", index);
    return formatComment(comment, index, "issues", issueResolutions[index] ?? null);
  });
  const checks = checksFor(pullRequest);
  const failedChecks = hasFailedChecks(checks);
  const pendingChecks = hasPendingChecks(checks);
  const hasNewActivity =
    formattedReviews.length > 0 || formattedInlineComments.length > 0 || formattedIssueComments.length > 0;
  const hasUnresolvedActivity =
    hasUnresolvedReviewState(reviews) || inlineResolutions.some((resolution) => resolution !== true);
  return {
    number,
    state: pullRequest.state,
    head: pullRequest.headRefName,
    head_oid: pullRequest.headRefOid,
    review_decision: pullRequest.reviewDecision,
    reviews: formattedReviews,
    inline_comments: formattedInlineComments,
    issue_comments: formattedIssueComments,
    checks,
    inline_comments_pages: inlineCollection.pages,
    issue_comments_pages: issueCollection.pages,
    has_failed_checks: failedChecks,
    has_pending_checks: pendingChecks,
    has_new_activity: hasNewActivity,
    resolution_warnings: inlineResolution.warnings,
    action_required:
      hasNewActivity || hasUnresolvedActivity || failedChecks || pendingChecks || hasUnresolvedReviewState(reviews),
  };
}

function graceState(entry: WatchEntry, clean: boolean, headChanged: boolean): WatchEntry {
  const graceChecks = headChanged ? 0 : clean ? Math.min((entry.graceChecks ?? 0) + 1, 4) : 0;
  return {
    ...entry,
    graceChecks,
    graceComplete: graceChecks >= 4,
  };
}

function replayPollPayload(payload: PollPayload): PollPayload {
  if (!payload.scheduler_should_stop) return payload;
  return {
    ...payload,
    scheduler_should_stop: false,
    warnings: [...payload.warnings, "replayed poll cannot safely stop the scheduler"],
  };
}

function sameNumbers(left: number[], right: number[]): boolean {
  const sortedLeft = [...left].sort((a, b) => a - b);
  const sortedRight = [...right].sort((a, b) => a - b);
  return sortedLeft.length === sortedRight.length && sortedLeft.every((number, index) => number === sortedRight[index]);
}

async function main(): Promise<void> {
  if (!["add", "remove", "list", "poll"].includes(ACTION)) {
    throw new Error("action must be add, remove, list, or poll");
  }
  validateFormat();
  const { hostname, owner, repo } = resolveUpstreamContext();
  const repository = `${hostname}/${owner}/${repo}`;
  const stateFile = getStateFile();
  let releaseLock: (() => Promise<void>) | undefined;
  try {
    releaseLock = await acquireLock(stateFile);
    const state = await loadState(repository, stateFile);
    const numbers = parseNumbers();

    if (ACTION === "add" || ACTION === "remove") {
      if (state.pending_add) {
        if (ACTION !== "add" || numbers.length === 0 || !sameNumbers(numbers, state.pending_add.requested_numbers)) {
          throw new Error("a staged add must be acknowledged before changing watch state");
        }
        emit(state.pending_add.payload);
        await saveState(stateFile, {
          version: 1,
          repository,
          pull_requests: state.pending_add.next_pull_requests,
        });
        return;
      }
      if (numbers.length === 0) throw new Error(`${ACTION} requires at least one pull request number`);
      if (state.pending_poll) {
        throw new Error("a staged poll must be acknowledged before changing watch state");
      }
      const nextState: WatchState = {
        version: 1,
        repository,
        pull_requests: [...state.pull_requests],
      };
      const reconciliation: Array<Record<string, unknown>> = [];
      const warnings: string[] = [];
      const watchStartedAt = new Date().toISOString();
      if (ACTION === "add") {
        for (const number of numbers) {
          if (nextState.pull_requests.some((entry) => entry.number === number)) continue;
          const pullRequest = await getPullRequest(repository, number);
          if (pullRequest.state !== "OPEN") throw new Error(`pull request #${number} is not open`);
          const [inlineCollection, issueCollection] = await Promise.all([
            getReviewComments(hostname, owner, repo, number, "pulls"),
            getReviewComments(hostname, owner, repo, number, "issues"),
          ]);
          reconciliation.push(
            await reconciliationFor(hostname, owner, repo, pullRequest, inlineCollection, issueCollection, number),
          );
          const resolutionWarnings = reconciliation.at(-1)?.resolution_warnings;
          if (Array.isArray(resolutionWarnings))
            warnings.push(...resolutionWarnings.filter((warning) => typeof warning === "string"));
          nextState.pull_requests.push({
            number,
            addedAt: watchStartedAt,
            lastSeenAt: watchStartedAt,
            head: pullRequestHead(pullRequest),
            seen: seenFor(pullRequest.reviews ?? [], inlineCollection.comments, issueCollection.comments),
            graceChecks: 0,
            graceComplete: false,
          });
        }
      } else {
        nextState.pull_requests = nextState.pull_requests.filter((entry) => !numbers.includes(entry.number));
      }
      nextState.pull_requests.sort((left, right) => left.number - right.number);
      const payload: AddPayload = {
        action: ACTION,
        repository,
        state_file: stateFile,
        watch_empty: nextState.pull_requests.length === 0,
        warnings,
        pull_requests: nextState.pull_requests,
        reconciliation,
      };
      if (ACTION === "add") {
        await saveState(stateFile, {
          version: 1,
          repository,
          pull_requests: state.pull_requests,
          pending_add: {
            payload,
            next_pull_requests: nextState.pull_requests,
            requested_numbers: numbers,
          },
        });
        if (process.env.PR_REVIEW_WATCH_TEST_CRASH_AFTER_STAGE === "1") {
          process.kill(process.pid, "SIGKILL");
        }
        if (process.env.PR_REVIEW_WATCH_TEST_INTERRUPT_AFTER_STAGE === "1") {
          throw new Error("simulated interruption after staged add");
        }
      } else {
        await saveState(stateFile, nextState);
      }
      emit(payload);
      if (ACTION === "add") {
        await saveState(stateFile, nextState);
      }
      return;
    }

    if (ACTION === "list") {
      const visiblePullRequests =
        state.pending_add?.next_pull_requests ?? state.pending_poll?.next_pull_requests ?? state.pull_requests;
      emit({
        action: "list",
        repository,
        state_file: stateFile,
        watch_empty: visiblePullRequests.length === 0,
        warnings: [],
        pull_requests: visiblePullRequests,
        pending_acknowledgment: state.pending_add
          ? { action: "add", requested_numbers: state.pending_add.requested_numbers }
          : state.pending_poll
            ? { action: "poll" }
            : null,
      });
      return;
    }

    if (state.pending_poll) {
      emit(replayPollPayload(state.pending_poll.payload));
      await saveState(stateFile, {
        version: 1,
        repository,
        pull_requests: state.pending_poll.next_pull_requests,
      });
      return;
    }
    if (state.pending_add) {
      throw new Error("a staged add must be acknowledged before polling");
    }

    const now = new Date().toISOString();
    const warnings: string[] = [];
    const openEntries: WatchEntry[] = [];
    const results: Array<Record<string, unknown>> = [];
    for (const entry of state.pull_requests) {
      const pullRequest = await getPullRequest(repository, entry.number);
      const isMerged = Boolean(pullRequest.mergedAt) || pullRequest.state === "MERGED";
      const isClosed = !isMerged && (pullRequest.state !== "OPEN" || Boolean(pullRequest.closedAt));
      if (isMerged || isClosed) {
        results.push({
          number: entry.number,
          state: pullRequest.state,
          head: pullRequest.headRefName,
          review_decision: pullRequest.reviewDecision,
          removed: true,
          reason: isMerged ? "merged" : "closed",
          new_reviews: [],
          new_inline_comments: [],
          new_issue_comments: [],
          checks: [],
          inline_comments_pages: 0,
          issue_comments_pages: 0,
          has_new_activity: false,
          has_failed_checks: false,
          action_required: false,
        });
        continue;
      }

      const cutoff = entry.lastSeenAt ?? entry.addedAt;
      const [inlineCollection, issueCollection] = await Promise.all([
        getReviewComments(hostname, owner, repo, entry.number, "pulls"),
        getReviewComments(hostname, owner, repo, entry.number, "issues"),
      ]);
      const seenReviews = new Set(entry.seen?.reviews ?? []);
      const seenInlineComments = new Set(entry.seen?.inline_comments ?? []);
      const seenIssueComments = new Set(entry.seen?.issue_comments ?? []);
      const inlineResolution = await commentResolutions(hostname, owner, repo, inlineCollection.comments, entry.number);
      const inlineResolutions = inlineResolution.values;
      const issueResolutions = issueCollection.comments.map(() => null as boolean | null);
      warnings.push(...inlineResolution.warnings);
      const reviews = newReviews(pullRequest.reviews ?? [], cutoff, entry.number, seenReviews);
      const inlineComments = newComments(
        inlineCollection.comments,
        cutoff,
        entry.number,
        "pulls",
        seenInlineComments,
        inlineResolutions,
      );
      const issueComments = newComments(
        issueCollection.comments,
        cutoff,
        entry.number,
        "issues",
        seenIssueComments,
        issueResolutions,
      );
      const checks = checksFor(pullRequest);
      const failedChecks = hasFailedChecks(checks);
      const pendingChecks = hasPendingChecks(checks);
      const hasNewActivity = reviews.length > 0 || inlineComments.length > 0 || issueComments.length > 0;
      const hasUnresolvedActivity =
        hasUnresolvedReviewState(pullRequest.reviews ?? []) ||
        inlineResolutions.some((resolution) => resolution !== true);
      const currentHead = pullRequestHead(pullRequest);
      const headChanged = entry.head !== undefined && entry.head !== currentHead;
      const clean =
        pullRequest.reviewDecision === "APPROVED" &&
        !hasNewActivity &&
        !hasUnresolvedActivity &&
        !failedChecks &&
        !pendingChecks &&
        !headChanged;
      const currentSeen = seenFor(pullRequest.reviews ?? [], inlineCollection.comments, issueCollection.comments);
      const nextEntry = graceState(
        {
          ...entry,
          lastSeenAt: now,
          head: currentHead,
          seen: mergeSeen(entry.seen, currentSeen),
        },
        clean,
        headChanged,
      );
      openEntries.push(nextEntry);
      results.push({
        number: entry.number,
        state: pullRequest.state,
        head: pullRequest.headRefName,
        head_oid: pullRequest.headRefOid,
        review_decision: pullRequest.reviewDecision,
        new_reviews: reviews,
        new_inline_comments: inlineComments,
        new_issue_comments: issueComments,
        checks,
        inline_comments_pages: inlineCollection.pages,
        issue_comments_pages: issueCollection.pages,
        has_new_activity: hasNewActivity,
        has_failed_checks: failedChecks,
        has_pending_checks: pendingChecks,
        resolution_warnings: inlineResolution.warnings,
        head_changed: headChanged,
        has_unresolved_activity: hasUnresolvedActivity,
        grace_checks: nextEntry.graceChecks ?? 0,
        grace_complete: nextEntry.graceComplete === true,
        keep_watching: nextEntry.graceComplete !== true,
        action_required:
          hasNewActivity ||
          hasUnresolvedActivity ||
          headChanged ||
          failedChecks ||
          pendingChecks ||
          hasUnresolvedReviewState(pullRequest.reviews ?? []),
      });
    }

    const nextState: WatchState = {
      version: 1,
      repository,
      pull_requests: openEntries,
    };
    const payload: PollPayload = {
      action: "poll",
      repository,
      state_file: stateFile,
      watch_empty: openEntries.length === 0,
      scheduler_should_stop: openEntries.every((entry) => entry.graceComplete === true),
      warnings,
      pull_requests: results,
    };
    await saveState(stateFile, {
      version: 1,
      repository,
      pull_requests: state.pull_requests,
      pending_poll: {
        payload,
        next_pull_requests: nextState.pull_requests,
      },
    });
    emit(payload);
    await saveState(stateFile, nextState);
  } finally {
    if (releaseLock) await releaseLock();
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
