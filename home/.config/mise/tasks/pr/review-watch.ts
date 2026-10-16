#!/usr/bin/env bun
//MISE description="Poll watched pull requests and remove merged or closed entries."
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE arg "<action>" help="Watch action: add, remove, list, or poll"
//USAGE arg "[pull-requests]..." help="Pull request numbers for add or remove"
//USAGE flag "--state-file <path>" help="Watch state file path"
//USAGE flag "--format <format>" help="Output format: json or text" default="json"

import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
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
    .map((value) => Number(value))
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

async function getPullRequest(repository: string, number: number): Promise<PullRequest> {
  return JSON.parse(
    await run("gh", [
      "pr",
      "view",
      String(number),
      "--repo",
      repository,
      "--json",
      "number,state,mergedAt,closedAt,headRefName,reviewDecision,reviews,statusCheckRollup",
    ]),
  ) as PullRequest;
}

async function getReviewComments(
  hostname: string,
  owner: string,
  repo: string,
  number: number,
  kind: "pulls" | "issues",
): Promise<ReviewComment[]> {
  const path = `repos/${owner}/${repo}/${kind}/${number}/comments`;
  const output = await run("gh", ["api", "--hostname", hostname, "--paginate", "--slurp", path, "--jq", "add"]);
  try {
    const comments = JSON.parse(output) as unknown;
    if (!Array.isArray(comments)) throw new Error("response is not an array");
    return comments as ReviewComment[];
  } catch (error) {
    throw new Error(
      `could not parse review comments for ${path}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

async function loadState(repository: string, stateFile: string): Promise<WatchState> {
  try {
    const parsed = JSON.parse(await readFile(stateFile, "utf8")) as Partial<WatchState>;
    if (parsed.version !== 1 || parsed.repository !== repository || !Array.isArray(parsed.pull_requests)) {
      throw new Error(`invalid watch state: ${stateFile}`);
    }
    return {
      version: 1,
      repository,
      pull_requests: parsed.pull_requests.filter(
        (entry): entry is WatchEntry => Number.isSafeInteger(entry?.number) && entry.number > 0,
      ),
    };
  } catch (error) {
    if (error instanceof Error && "code" in error && (error as NodeJS.ErrnoException).code === "ENOENT") {
      return { version: 1, repository, pull_requests: [] };
    }
    throw error;
  }
}

async function saveState(stateFile: string, state: WatchState): Promise<void> {
  await mkdir(dirname(stateFile), { recursive: true });
  await writeFile(stateFile, `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

function emit(value: unknown): void {
  if (FORMAT === "json") {
    console.log(JSON.stringify(value, null, 2));
    return;
  }
  if (FORMAT !== "text") throw new Error(`unsupported --format value: ${FORMAT}`);
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
  try {
    await mkdir(lockDirectory);
    await writeFile(join(lockDirectory, "owner"), `${process.pid}\n`, "utf8");
  } catch {
    throw new Error(`watch state is locked: ${stateFile}`);
  }
  return async () => {
    await rm(lockDirectory, { recursive: true, force: true });
  };
}

async function main(): Promise<void> {
  if (!["add", "remove", "list", "poll"].includes(ACTION)) {
    throw new Error("action must be add, remove, list, or poll");
  }
  const { hostname, owner, repo } = resolveUpstreamContext();
  const repository = `${hostname}/${owner}/${repo}`;
  const stateFile = getStateFile();
  const releaseLock = await acquireLock(stateFile);
  try {
    const state = await loadState(repository, stateFile);
    const numbers = parseNumbers();

    if (ACTION === "add" || ACTION === "remove") {
      if (numbers.length === 0) throw new Error(`${ACTION} requires at least one pull request number`);
      if (ACTION === "add") {
        for (const number of numbers) {
          const pullRequest = await getPullRequest(repository, number);
          if (pullRequest.state !== "OPEN") throw new Error(`pull request #${number} is not open`);
          if (!state.pull_requests.some((entry) => entry.number === number)) {
            state.pull_requests.push({ number, addedAt: new Date().toISOString() });
          }
        }
      } else {
        state.pull_requests = state.pull_requests.filter((entry) => !numbers.includes(entry.number));
      }
      state.pull_requests.sort((left, right) => left.number - right.number);
      await saveState(stateFile, state);
    }

    if (ACTION === "list") {
      emit({ repository, state_file: stateFile, pull_requests: state.pull_requests });
      return;
    }

    if (ACTION === "add" || ACTION === "remove") {
      emit({ action: ACTION, repository, state_file: stateFile, pull_requests: state.pull_requests });
      return;
    }

    const now = new Date().toISOString();
    const openEntries: WatchEntry[] = [];
    const results: Array<Record<string, unknown>> = [];
    for (const entry of state.pull_requests) {
      const pullRequest = await getPullRequest(repository, entry.number);
      if (pullRequest.state !== "OPEN" || pullRequest.mergedAt || pullRequest.closedAt) {
        results.push({ number: entry.number, state: pullRequest.state, removed: true });
        continue;
      }
      const previous = entry.lastSeenAt;
      const newReviews = (pullRequest.reviews ?? []).filter(
        (review) => review.submittedAt && (!previous || review.submittedAt > previous),
      );
      const checks = (pullRequest.statusCheckRollup ?? []).map((check) => ({
        name: check.name,
        status: check.status,
        conclusion: check.conclusion,
      }));
      openEntries.push({ ...entry, lastSeenAt: now });
      const [inlineComments, issueComments] = await Promise.all([
        getReviewComments(hostname, owner, repo, entry.number, "pulls"),
        getReviewComments(hostname, owner, repo, entry.number, "issues"),
      ]);
      const newInlineComments = inlineComments.filter(
        (comment) => comment.created_at && (!previous || comment.created_at > previous),
      );
      const newIssueComments = issueComments.filter(
        (comment) => comment.created_at && (!previous || comment.created_at > previous),
      );
      results.push({
        number: entry.number,
        state: pullRequest.state,
        head: pullRequest.headRefName,
        review_decision: pullRequest.reviewDecision,
        new_reviews: newReviews.map((review) => ({
          author: review.author?.login,
          submitted_at: review.submittedAt,
          state: review.state,
          summary: (review.body ?? "").split("\n").find(Boolean) ?? "",
        })),
        new_inline_comments: newInlineComments.map((comment) => ({
          author: comment.user?.login,
          created_at: comment.created_at,
          path: comment.path,
          line: comment.line,
          body: comment.body,
          url: comment.html_url,
        })),
        new_issue_comments: newIssueComments.map((comment) => ({
          author: comment.user?.login,
          created_at: comment.created_at,
          body: comment.body,
          url: comment.html_url,
        })),
        checks,
      });
    }
    state.pull_requests = openEntries;
    await saveState(stateFile, state);
    emit({
      action: "poll",
      repository,
      state_file: stateFile,
      pull_requests: results,
      watch_empty: openEntries.length === 0,
    });
  } finally {
    await releaseLock();
  }
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
