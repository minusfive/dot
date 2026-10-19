#!/usr/bin/env bun
//MISE description="Synchronize and verify an open pull request after a push."
//MISE dir="{{cwd}}"
//MISE quiet=true
//MISE depends=["gh:auth:login"]
//USAGE flag "--title <title>" help="Pull request title derived from the complete change set"
//USAGE flag "--body-file <path>" help="File containing the pull request body derived from the complete change set"
//USAGE flag "--change-set-file <path>" help="Optional newline-delimited complete changed-path manifest"
//USAGE flag "--pr-number <number>" help="Open pull request number (default: current branch pull request)"
//USAGE flag "--dry-run" help="Show the synchronization plan without changing the pull request"

import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolveUpstreamContext } from "../../utils/git.js";

export {};

const WORKING_DIRECTORY = process.cwd();
const TITLE = (process.env.usage_title ?? "").trim();
const BODY_FILE = (process.env.usage_body_file ?? "").trim();
const CHANGE_SET_FILE = (process.env.usage_change_set_file ?? "").trim();
const PR_NUMBER = (process.env.usage_pr_number ?? "").trim();
const DRY_RUN = process.env.usage_dry_run === "true";

type PullRequest = {
  number: number;
  title: string;
  body: string;
  state: string;
  headRefName: string;
  headRefOid: string;
  baseRefName: string;
  baseRefOid: string;
};

async function run(command: string, args: string[], input?: string): Promise<string> {
  const proc = Bun.spawn([command, ...args], {
    cwd: WORKING_DIRECTORY,
    env: process.env,
    stdin: input === undefined ? "ignore" : "pipe",
    stderr: "pipe",
    stdout: "pipe",
  });
  if (input !== undefined) {
    const stdin = proc.stdin;
    if (!stdin) {
      throw new Error(`${command} did not provide a writable standard input`);
    }
    stdin.write(input);
    await stdin.end();
  }
  const exitCode = await proc.exited;
  const stdout = await new Response(proc.stdout).text();
  const stderr = await new Response(proc.stderr).text();
  if (exitCode !== 0) {
    const detail = stderr.trim() || stdout.trim() || "no error details";
    throw new Error(`${command} ${args.join(" ")} failed: ${detail}`);
  }
  return stdout;
}

async function gitValue(args: string[]): Promise<string> {
  return (await run("git", args)).trim();
}

async function getPullRequest(repository: string, selector: string): Promise<PullRequest> {
  const args = [
    "pr",
    "view",
    "--repo",
    repository,
    selector,
    "--json",
    "number,title,body,state,headRefName,headRefOid,baseRefName,baseRefOid",
  ];
  return JSON.parse(await run("gh", args)) as PullRequest;
}

function canonicalizeFileList(value: string): string[] {
  return [
    ...new Set(
      value
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter(Boolean),
    ),
  ].sort();
}

function fingerprintFileList(files: string[]): string {
  return createHash("sha256")
    .update(`${files.join("\n")}\n`)
    .digest("hex");
}

function canonicalizeBody(value: string): string {
  return value.replaceAll("\r\n", "\n").replace(/\n+$/, "");
}

async function getPullRequestFiles(hostname: string, repositoryPath: string, number: number): Promise<string[]> {
  return canonicalizeFileList(
    await run("gh", [
      "api",
      "--hostname",
      hostname,
      "--paginate",
      `repos/${repositoryPath}/pulls/${number}/files`,
      "--jq",
      ".[].filename",
    ]),
  );
}

async function getPullRequestCommits(hostname: string, repositoryPath: string, number: number): Promise<string[]> {
  return (
    await run("gh", [
      "api",
      "--hostname",
      hostname,
      "--paginate",
      `repos/${repositoryPath}/pulls/${number}/commits`,
      "--jq",
      ".[].sha",
    ])
  )
    .trim()
    .split(/\r?\n/)
    .filter(Boolean);
}

async function getLocalFiles(baseRef: string): Promise<string[]> {
  return canonicalizeFileList(await run("git", ["diff", "--name-only", `${baseRef}...HEAD`]));
}

async function getLocalCommits(baseRef: string): Promise<string[]> {
  return (await gitValue(["rev-list", "--reverse", `${baseRef}..HEAD`])).split(/\r?\n/).filter(Boolean);
}

function compareLists(label: string, expected: string[], received: string[]): void {
  if (expected.join("\n") !== received.join("\n")) {
    throw new Error(
      `${label} does not match: expected ${expected.length} entries (${fingerprintFileList(expected)}), received ${received.length} entries (${fingerprintFileList(received)})`,
    );
  }
}

async function main(): Promise<void> {
  if (!TITLE) {
    throw new Error("a non-empty --title is required");
  }
  if (!BODY_FILE) {
    throw new Error("a --body-file is required");
  }
  const { hostname, owner, repo, remote } = resolveUpstreamContext();
  const repository = `${hostname}/${owner}/${repo}`;
  const repositoryPath = `${owner}/${repo}`;
  const body = await readFile(BODY_FILE, "utf8");
  if (!body.trim()) {
    throw new Error(`pull request body file is empty: ${BODY_FILE}`);
  }
  const manifest = CHANGE_SET_FILE ? canonicalizeFileList(await readFile(CHANGE_SET_FILE, "utf8")) : undefined;
  if (manifest && manifest.length === 0) {
    throw new Error(`change-set manifest is empty: ${CHANGE_SET_FILE}`);
  }

  const branch = await gitValue(["rev-parse", "--abbrev-ref", "HEAD"]);
  if (branch === "HEAD") {
    throw new Error("cannot synchronize a pull request from a detached HEAD");
  }

  const localHead = await gitValue(["rev-parse", "HEAD"]);
  const pullRequest = await getPullRequest(repository, PR_NUMBER || branch);

  if (pullRequest.state !== "OPEN") {
    throw new Error(`pull request #${pullRequest.number} is not open`);
  }
  if (pullRequest.headRefName !== branch) {
    throw new Error(`pull request #${pullRequest.number} points to ${pullRequest.headRefName}, not ${branch}`);
  }
  if (pullRequest.headRefOid !== localHead) {
    throw new Error(
      `pull request #${pullRequest.number} is at ${pullRequest.headRefOid}, but local HEAD is ${localHead}; push first`,
    );
  }

  const upstreamRef = await gitValue(["rev-parse", "--symbolic-full-name", "@{upstream}"]);
  const upstreamHead = await gitValue(["rev-parse", "--verify", upstreamRef]);
  if (upstreamHead !== localHead) {
    throw new Error(
      `local HEAD is ${localHead}, but its upstream branch ${upstreamRef} is ${upstreamHead}; push or fetch first`,
    );
  }

  const baseRef = `refs/remotes/${remote}/${pullRequest.baseRefName}`;
  const localBase = await gitValue(["rev-parse", "--verify", baseRef]);
  if (localBase !== pullRequest.baseRefOid) {
    throw new Error(
      `local ${baseRef} is at ${localBase}, but pull request #${pullRequest.number} base is ${pullRequest.baseRefOid}; fetch the upstream base first`,
    );
  }

  try {
    await run("git", ["merge-base", "--is-ancestor", baseRef, "HEAD"]);
  } catch {
    throw new Error(`local base ${baseRef} is not an ancestor of local HEAD ${localHead}`);
  }

  const localCommits = await getLocalCommits(baseRef);
  const upstreamCommits = await getPullRequestCommits(hostname, repositoryPath, pullRequest.number);
  compareLists("local commit history and pull request commit history", upstreamCommits, localCommits);

  const localFiles = await getLocalFiles(baseRef);
  if (localFiles.length === 0) {
    throw new Error(`local diff from ${baseRef} to HEAD has no changed files`);
  }
  if (manifest) {
    compareLists("change-set manifest and local diff", localFiles, manifest);
  }

  const serverFiles = await getPullRequestFiles(hostname, repositoryPath, pullRequest.number);
  if (serverFiles.length === 0) {
    throw new Error(`pull request #${pullRequest.number} has no changed files`);
  }
  compareLists("local diff and pull request files", localFiles, serverFiles);

  if (DRY_RUN) {
    console.log(
      `PR #${pullRequest.number}: would update title and body, then verify base ${localBase}, head ${localHead}, ${localCommits.length} commits, and ${localFiles.length} changed files (${fingerprintFileList(localFiles)})`,
    );
    return;
  }

  await run(
    "gh",
    ["pr", "edit", "--repo", repository, String(pullRequest.number), "--title", TITLE, "--body-file", "-"],
    body,
  );

  const verified = await getPullRequest(repository, String(pullRequest.number));
  const verifiedFiles = await getPullRequestFiles(hostname, repositoryPath, pullRequest.number);
  const mismatches = [
    verified.state === "OPEN" ? undefined : `state=${verified.state}`,
    verified.headRefName === branch ? undefined : `branch=${verified.headRefName}`,
    verified.headRefOid === localHead ? undefined : `head=${verified.headRefOid}`,
    verified.title === TITLE ? undefined : "title",
    canonicalizeBody(verified.body) === canonicalizeBody(body) ? undefined : "body",
    verified.baseRefName === pullRequest.baseRefName ? undefined : `base branch=${verified.baseRefName}`,
    verified.baseRefOid === localBase ? undefined : "base commit",
    verifiedFiles.join("\n") === localFiles.join("\n") ? undefined : "change-set manifest",
  ].filter((value): value is string => value !== undefined);
  if (mismatches.length > 0) {
    throw new Error(`pull request #${pullRequest.number} did not match after update: ${mismatches.join(", ")}`);
  }

  console.log(
    `PR #${pullRequest.number}: title, body, head commit, and ${verifiedFiles.length} changed files are synchronized (${fingerprintFileList(verifiedFiles)})`,
  );
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
