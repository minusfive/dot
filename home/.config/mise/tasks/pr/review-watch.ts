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
  author?: { login?: string };
  submittedAt?: string;
  state?: string;
  body?: string;
};

type Check = {
  name?: string;
  status?: string;
  conclusion?: string;
  context?: string;
  state?: string;
};

type ReviewComment = {
  user?: { login?: string };
  created_at?: string;
  body?: string;
  path?: string;
  line?: number;
  html_url?: string;
};

type PullRequest = {
  number: number;
  state: string;
  mergedAt?: string;
  closedAt?: string;
  headRefName?: string;
  reviewDecision?: string;
  reviews?: Review[];
  statusCheckRollup?: Check[];
};

type WatchEntry = {
  number: number;
  addedAt: string;
  lastSeenAt?: string;
};

type WatchState = {
  version: 1;
  repository: string;
  pull_requests: WatchEntry[];
};

type CommentKind = "pulls" | "issues";

type CommentCollection = {
  comments: ReviewComment[];
  pages: number;
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
      "number,state,mergedAt,closedAt,headRefName,reviewDecision,reviews,statusCheckRollup",
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
  if (typeof pullRequest.state !== "string") {
    throw new Error(`${description}: response has an invalid state`);
  }
  if (pullRequest.reviews !== undefined && !Array.isArray(pullRequest.reviews)) {
    throw new Error(`${description}: reviews is not an array`);
  }
  if (pullRequest.statusCheckRollup !== undefined && !Array.isArray(pullRequest.statusCheckRollup)) {
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

function validateWatchEntry(value: unknown, stateFile: string): value is WatchEntry {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const entry = value as Partial<WatchEntry>;
  const number = entry.number;
  if (typeof number !== "number" || !Number.isSafeInteger(number) || number <= 0 || !isValidTimestamp(entry.addedAt)) {
    throw new Error(`invalid watch state: ${stateFile}`);
  }
  if (entry.lastSeenAt !== undefined && !isValidTimestamp(entry.lastSeenAt)) {
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
    return {
      version: 1,
      repository,
      pull_requests: parsed.pull_requests.filter((entry): entry is WatchEntry => validateWatchEntry(entry, stateFile)),
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
  };
  console.log(`${payload.action ?? "watch"} ${payload.repository ?? ""}`.trim());
  for (const entry of payload.pull_requests ?? []) {
    console.log(JSON.stringify(entry));
  }
}

async function acquireLock(stateFile: string): Promise<() => Promise<void>> {
  const lockDirectory = `${stateFile}.lock`;
  await mkdir(dirname(stateFile), { recursive: true });
  let created = false;
  try {
    await mkdir(lockDirectory);
    created = true;
    await writeFile(join(lockDirectory, "owner"), `${process.pid}\n`, "utf8");
  } catch (error) {
    if (created) await rm(lockDirectory, { recursive: true, force: true });
    if (error instanceof Error && error.message.includes("EEXIST")) {
      throw new Error(`watch state is locked: ${stateFile}`);
    }
    throw error;
  }
  return async () => {
    await rm(lockDirectory, { recursive: true, force: true });
  };
}

function warning(warnings: string[], message: string): void {
  warnings.push(message);
}

function newReviews(
  reviews: Review[],
  cutoff: string,
  number: number,
  warnings: string[],
): Array<Record<string, unknown>> {
  return reviews.flatMap((review, index) => {
    if (!isValidTimestamp(review.submittedAt)) {
      warning(warnings, `PR #${number} review ${index + 1} has a missing or malformed submittedAt timestamp; ignored`);
      return [];
    }
    if (timestampValue(review.submittedAt) <= timestampValue(cutoff)) return [];
    return [
      {
        author: review.author?.login,
        submitted_at: review.submittedAt,
        state: review.state,
        summary: (review.body ?? "").split("\n").find(Boolean) ?? "",
      },
    ];
  });
}

function newComments(
  comments: ReviewComment[],
  cutoff: string,
  number: number,
  kind: CommentKind,
  warnings: string[],
): Array<Record<string, unknown>> {
  return comments.flatMap((comment, index) => {
    if (!isValidTimestamp(comment.created_at)) {
      warning(
        warnings,
        `PR #${number} ${kind === "pulls" ? "inline" : "issue"} comment ${index + 1} has a missing or malformed created_at timestamp; ignored`,
      );
      return [];
    }
    if (timestampValue(comment.created_at) <= timestampValue(cutoff)) return [];
    if (kind === "pulls") {
      return [
        {
          author: comment.user?.login,
          created_at: comment.created_at,
          path: comment.path,
          line: comment.line,
          body: comment.body,
          url: comment.html_url,
        },
      ];
    }
    return [
      {
        author: comment.user?.login,
        created_at: comment.created_at,
        body: comment.body,
        url: comment.html_url,
      },
    ];
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
      if (numbers.length === 0) throw new Error(`${ACTION} requires at least one pull request number`);
      const nextState: WatchState = {
        version: 1,
        repository,
        pull_requests: [...state.pull_requests],
      };
      if (ACTION === "add") {
        for (const number of numbers) {
          const pullRequest = await getPullRequest(repository, number);
          if (pullRequest.state !== "OPEN") throw new Error(`pull request #${number} is not open`);
          if (!nextState.pull_requests.some((entry) => entry.number === number)) {
            nextState.pull_requests.push({ number, addedAt: new Date().toISOString() });
          }
        }
      } else {
        nextState.pull_requests = nextState.pull_requests.filter((entry) => !numbers.includes(entry.number));
      }
      nextState.pull_requests.sort((left, right) => left.number - right.number);
      const payload = {
        action: ACTION,
        repository,
        state_file: stateFile,
        watch_empty: nextState.pull_requests.length === 0,
        warnings: [],
        pull_requests: nextState.pull_requests,
      };
      await saveState(stateFile, nextState);
      emit(payload);
      return;
    }

    if (ACTION === "list") {
      emit({
        action: "list",
        repository,
        state_file: stateFile,
        watch_empty: state.pull_requests.length === 0,
        warnings: [],
        pull_requests: state.pull_requests,
      });
      return;
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
      const reviews = newReviews(pullRequest.reviews ?? [], cutoff, entry.number, warnings);
      const inlineComments = newComments(inlineCollection.comments, cutoff, entry.number, "pulls", warnings);
      const issueComments = newComments(issueCollection.comments, cutoff, entry.number, "issues", warnings);
      const checks = checksFor(pullRequest);
      const failedChecks = hasFailedChecks(checks);
      const pendingChecks = hasPendingChecks(checks);
      const hasNewActivity = reviews.length > 0 || inlineComments.length > 0 || issueComments.length > 0;
      openEntries.push({ ...entry, lastSeenAt: now });
      results.push({
        number: entry.number,
        state: pullRequest.state,
        head: pullRequest.headRefName,
        review_decision: pullRequest.reviewDecision,
        new_reviews: reviews,
        new_inline_comments: inlineComments,
        new_issue_comments: issueComments,
        checks,
        inline_comments_pages: inlineCollection.pages,
        issue_comments_pages: issueCollection.pages,
        has_new_activity: hasNewActivity,
        has_failed_checks: failedChecks,
        action_required:
          hasNewActivity || failedChecks || pendingChecks || pullRequest.reviewDecision === "CHANGES_REQUESTED",
      });
    }

    const nextState: WatchState = {
      version: 1,
      repository,
      pull_requests: openEntries,
    };
    const payload = {
      action: "poll",
      repository,
      state_file: stateFile,
      watch_empty: openEntries.length === 0,
      warnings,
      pull_requests: results,
    };
    await saveState(stateFile, nextState);
    emit(payload);
  } finally {
    if (releaseLock) await releaseLock();
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
