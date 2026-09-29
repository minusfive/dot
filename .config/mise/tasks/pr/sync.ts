#!/usr/bin/env bun
//MISE description="Synchronize and verify an open pull request after a push."
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE flag "--title <title>" help="Pull request title derived from the complete change set"
//USAGE flag "--body-file <path>" help="File containing the pull request body derived from the complete change set"
//USAGE flag "--change-set-file <path>" help="Newline-delimited complete changed-path manifest"
//USAGE flag "--pr-number <number>" help="Open pull request number (default: current branch pull request)"
//USAGE flag "--dry-run" help="Show the synchronization plan without changing the pull request"

import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";

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

async function getPullRequest(number?: string): Promise<PullRequest> {
  const args = ["pr", "view", ...(number ? [number] : []), "--json", "number,title,body,state,headRefName,headRefOid"];
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

async function getPullRequestFiles(number: number): Promise<string[]> {
  return canonicalizeFileList(await run("gh", ["pr", "diff", String(number), "--name-only"]));
}

async function main(): Promise<void> {
  if (!TITLE) {
    throw new Error("a non-empty --title is required");
  }
  if (!BODY_FILE) {
    throw new Error("a --body-file is required");
  }
  if (!CHANGE_SET_FILE) {
    throw new Error("a --change-set-file is required");
  }

  const body = await readFile(BODY_FILE, "utf8");
  if (!body.trim()) {
    throw new Error(`pull request body file is empty: ${BODY_FILE}`);
  }
  const manifest = canonicalizeFileList(await readFile(CHANGE_SET_FILE, "utf8"));
  if (manifest.length === 0) {
    throw new Error(`change-set manifest is empty: ${CHANGE_SET_FILE}`);
  }

  const branch = await gitValue(["rev-parse", "--abbrev-ref", "HEAD"]);
  if (branch === "HEAD") {
    throw new Error("cannot synchronize a pull request from a detached HEAD");
  }

  const localHead = await gitValue(["rev-parse", "HEAD"]);
  const pullRequest = await getPullRequest(PR_NUMBER || undefined);

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

  const serverFiles = await getPullRequestFiles(pullRequest.number);
  if (serverFiles.length === 0) {
    throw new Error(`pull request #${pullRequest.number} has no changed files`);
  }
  if (serverFiles.join("\n") !== manifest.join("\n")) {
    throw new Error(
      `change-set manifest does not match pull request #${pullRequest.number}: expected ${serverFiles.length} files (${fingerprintFileList(serverFiles)}), received ${manifest.length} files (${fingerprintFileList(manifest)})`,
    );
  }

  if (DRY_RUN) {
    console.log(
      `PR #${pullRequest.number}: would update title and body, then verify head ${localHead} and ${serverFiles.length} changed files (${fingerprintFileList(serverFiles)})`,
    );
    return;
  }

  await run("gh", ["pr", "edit", String(pullRequest.number), "--title", TITLE, "--body-file", "-"], body);

  const verified = await getPullRequest(String(pullRequest.number));
  const verifiedFiles = await getPullRequestFiles(pullRequest.number);
  const mismatches = [
    verified.state === "OPEN" ? undefined : `state=${verified.state}`,
    verified.headRefName === branch ? undefined : `branch=${verified.headRefName}`,
    verified.headRefOid === localHead ? undefined : `head=${verified.headRefOid}`,
    verified.title === TITLE ? undefined : "title",
    canonicalizeBody(verified.body) === canonicalizeBody(body) ? undefined : "body",
    verifiedFiles.join("\n") === manifest.join("\n") ? undefined : "change-set manifest",
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
