#!/usr/bin/env bun
//MISE description="Create or remove a git worktree"
//MISE alias="gwt"
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE arg "[name]" help="Branch-like name for the worktree, or ALL_CLOSED_PRS with --delete"
//USAGE flag "-d --delete" help="Delete a worktree; use ALL_CLOSED_PRS to delete all closed PR worktrees"
//USAGE flag "-p --pull-request <pull-request>" help="Create a worktree from an open PR, or target PR worktrees with --delete"

import { spawn, spawnSync } from "child_process";
import { existsSync, readFileSync } from "fs";
import { resolve } from "path";
import { resolveUpstreamContext } from "../../utils/git.js";

type WorktreeEntry = {
  name: string;
  path: string;
  branch: string;
};

type PullRequestListItem = {
  number: number;
  title: string;
  branch: string;
};

type PullRequestState = "open" | "closed";

const ALL_CLOSED_PRS_KEYWORD = "ALL_CLOSED_PRS";

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

function ensureInsideGitRepo(): void {
  const result = spawnSync("git", ["rev-parse", "--is-inside-work-tree"], { encoding: "utf-8" });
  if (result.status !== 0 || result.stdout.trim() !== "true") {
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
  const result = spawnSync("mise", ["tasks", "info", task], { stdio: "ignore" });
  return result.status === 0;
}

function isValidName(name: string): boolean {
  return /^[a-zA-Z0-9._/-]+$/.test(name);
}

function shellQuote(value: string): string {
  return `'${value.replaceAll("'", "'\\''")}'`;
}

function parseWorktreeList(repoRoot: string): WorktreeEntry[] {
  const output = runCapture("git", ["worktree", "list", "--porcelain"]);
  const lines = output.split("\n");
  const worktrees: WorktreeEntry[] = [];

  let currentPath = "";
  let currentBranch = "";

  const flush = () => {
    if (!currentPath || currentPath === repoRoot) {
      currentPath = "";
      currentBranch = "";
      return;
    }
    const name = currentPath.split("/").filter(Boolean).at(-1) ?? currentPath;
    worktrees.push({
      name,
      path: currentPath,
      branch: currentBranch,
    });
    currentPath = "";
    currentBranch = "";
  };

  for (const line of lines) {
    if (line.startsWith("worktree ")) {
      currentPath = line.slice("worktree ".length);
      continue;
    }
    if (line.startsWith("branch ")) {
      currentBranch = line.slice("branch ".length).replace(/^refs\/heads\//, "");
      continue;
    }
    if (line.trim() === "") {
      flush();
    }
  }
  flush();

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
  const output = (result.stdout ?? "").trim();
  if (!output) return undefined;
  return output
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
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

function getPullRequestState(hostname: string, owner: string, repo: string, prNumber: number): PullRequestState {
  const output = runCapture("gh", ["api", "--hostname", hostname, `/repos/${owner}/${repo}/pulls/${prNumber}`]);
  const parsed = JSON.parse(output) as { state?: unknown };
  const state = parsed.state;
  if (state !== "open" && state !== "closed") {
    throw new Error(`could not resolve state for PR #${prNumber}.`);
  }
  return state;
}

function removeWorktree(name: string): void {
  if (!isValidName(name)) {
    throw new Error(
      `invalid worktree name '${name}'. Use only alphanumeric characters, dots, hyphens, underscores, and slashes.`,
    );
  }
  const worktreePath = `../${name}`;
  console.log(`Removing worktree: ${worktreePath} ...`);
  runInherit("git", ["worktree", "remove", worktreePath]);
  console.log("Done.");
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

function parseSelectedWorktreePaths(selectedLines: string[]): string[] {
  const uniquePaths = new Set<string>();
  for (const selectedLine of selectedLines) {
    const selectedPath = selectedLine.split("\t")[1]?.trim();
    if (!selectedPath) {
      throw new Error("could not resolve selected worktree path.");
    }
    uniquePaths.add(selectedPath);
  }
  return [...uniquePaths];
}

async function removeWorktreePaths(selectedPaths: string[]): Promise<void> {
  console.log(`Removing ${selectedPaths.length} worktree(s) ...`);

  const removalResults = await Promise.allSettled(
    selectedPaths.map(async (selectedPath) => {
      await removeWorktreeByPath(selectedPath);
      return selectedPath;
    }),
  );

  let failedCount = 0;
  for (const [index, result] of removalResults.entries()) {
    const selectedPath = selectedPaths[index];
    if (!selectedPath) {
      throw new Error("could not resolve selected worktree path.");
    }

    if (result.status === "fulfilled") {
      console.log(`Removed: ${selectedPath}`);
      continue;
    }

    failedCount += 1;
    console.error(`Failed: ${selectedPath}`);
    console.error(`  ${getErrorMessage(result.reason)}`);
  }

  if (failedCount > 0) {
    throw new Error(`failed to remove ${failedCount} of ${selectedPaths.length} selected worktree(s).`);
  }

  console.log("Done.");
}

async function runDeleteFlow(name: string): Promise<void> {
  if (name) {
    removeWorktree(name);
    return;
  }

  const repoRoot = runCapture("git", ["rev-parse", "--show-toplevel"]).trim();
  const worktrees = parseWorktreeList(repoRoot);
  if (worktrees.length === 0) {
    console.log("No removable worktrees found.");
    return;
  }

  const lines = [
    `All closed PRs\t${ALL_CLOSED_PRS_KEYWORD}\t`,
    ...worktrees.map((entry) => `${entry.name}\t${entry.path}\t${entry.branch}`),
  ];
  const previewCommand = `if [ ${shellQuote("{2}")} = ${shellQuote(ALL_CLOSED_PRS_KEYWORD)} ]; then echo 'Delete all worktrees for closed pull requests.'; else git -C ${shellQuote("{2}")} log --oneline --color --graph -20 2>/dev/null; fi`;

  const selectedLines = commandExists("fzf")
    ? pickLineWithFzf(lines, "Select worktree(s) to remove: ", previewCommand, { multi: true })
    : (() => {
        const selected = pickLineFromPrompt(lines);
        return selected ? [selected] : undefined;
      })();

  if (!selectedLines || selectedLines.length === 0) {
    console.log("No worktree selected.");
    return;
  }

  const selectedAllClosedPrs = selectedLines.some((line) => line.split("\t")[1]?.trim() === ALL_CLOSED_PRS_KEYWORD);
  if (selectedAllClosedPrs) {
    await runDeleteClosedPrWorktreesFlow();
    return;
  }

  const selectedPaths = parseSelectedWorktreePaths(selectedLines);
  await removeWorktreePaths(selectedPaths);
}

async function runDeleteClosedPrWorktreesFlow(): Promise<void> {
  ensureCommand("gh", `${ALL_CLOSED_PRS_KEYWORD} delete mode`);

  const repoRoot = runCapture("git", ["rev-parse", "--show-toplevel"]).trim();
  const worktrees = parseWorktreeList(repoRoot);
  const prWorktrees = worktrees
    .map((entry) => ({ entry, prNumber: parsePrNumberFromWorktreeName(entry.name) }))
    .filter((value): value is { entry: WorktreeEntry; prNumber: number } => value.prNumber !== undefined);

  if (prWorktrees.length === 0) {
    console.log("No PR worktrees found.");
    return;
  }

  const context = resolveUpstreamContext();
  const { hostname, owner, repo } = context;
  if (!hostname || !owner || !repo) {
    throw new Error("resolve-upstream returned incomplete repository context.");
  }

  const closedPrPaths = new Set<string>();
  for (const prWorktree of prWorktrees) {
    const state = getPullRequestState(hostname, owner, repo, prWorktree.prNumber);
    if (state === "closed") {
      closedPrPaths.add(prWorktree.entry.path);
    }
  }

  const selectedPaths = [...closedPrPaths];
  if (selectedPaths.length === 0) {
    console.log("No worktrees found for closed pull requests.");
    return;
  }

  console.log(`Found ${selectedPaths.length} worktree(s) for closed pull requests.`);
  await removeWorktreePaths(selectedPaths);
}

async function runDeletePullRequestWorktreesFlow(pullRequestSelector: string): Promise<void> {
  const repoRoot = runCapture("git", ["rev-parse", "--show-toplevel"]).trim();
  const worktrees = parseWorktreeList(repoRoot);
  const prWorktrees = worktrees
    .map((entry) => ({ entry, prNumber: parsePrNumberFromWorktreeName(entry.name) }))
    .filter((value): value is { entry: WorktreeEntry; prNumber: number } => value.prNumber !== undefined);

  if (prWorktrees.length === 0) {
    console.log("No PR worktrees found.");
    return;
  }

  if (isAllClosedPrsKeyword(pullRequestSelector)) {
    await runDeleteClosedPrWorktreesFlow();
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
    ...prWorktrees.map((entry) => `${entry.entry.name}\t${entry.entry.path}\t${entry.entry.branch}`),
  ];
  const previewCommand = `if [ ${shellQuote("{2}")} = ${shellQuote(ALL_CLOSED_PRS_KEYWORD)} ]; then echo 'Delete all worktrees for closed pull requests.'; else git -C ${shellQuote("{2}")} log --oneline --color --graph -20 2>/dev/null; fi`;

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

  const selectedAllClosedPrs = selectedLines.some((line) => line.split("\t")[1]?.trim() === ALL_CLOSED_PRS_KEYWORD);
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

  let selectedPr = prNumberOverride;

  if (!selectedPr) {
    ensureCommand("fzf", "--pull-request mode without PR number");
    const prs = getOpenPullRequests(hostname, owner, repo);
    if (prs.length === 0) {
      console.log(`No open pull requests found for ${owner}/${repo}.`);
      return;
    }

    const lines = prs.map((pr) => `#${pr.number} ${pr.title}\t${pr.number}\t${pr.branch}`);
    const previewCommand = `gh pr view ${shellQuote("{2}")} 2>/dev/null | head -40`;
    const selected = pickLineWithFzf(lines, "Select PR worktree: ", previewCommand)?.[0];

    if (!selected) {
      console.log("No PR selected.");
      return;
    }

    selectedPr = selected.split("\t")[1] ?? "";
  }

  selectedPr = normalizePrNumber(selectedPr);
  const repoRoot = runCapture("git", ["rev-parse", "--show-toplevel"]).trim();
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
  runInherit("gh", ["pr", "checkout", selectedPr]);
  const hasMiseConfig =
    existsSync(resolve(resolvedWorktreePath, "mise.toml")) || existsSync(resolve(resolvedWorktreePath, ".mise.toml"));
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
    existsSync(resolve(resolvedWorktreePath, "mise.toml")) || existsSync(resolve(resolvedWorktreePath, ".mise.toml"));
  process.chdir(worktreePath);
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
  const deleteFlag = process.env["usage_delete"] === "true";
  const pullRequestRaw = (process.env["usage_pull_request"] ?? "").trim();
  const pullRequest = pullRequestRaw.length > 0 && pullRequestRaw !== "false";
  const name = (process.env["usage_name"] ?? "").trim();
  const pullRequestSelector = pullRequestRaw === "true" ? "pick" : pullRequestRaw;
  const deleteAllClosedFromName = isAllClosedPrsKeyword(name);
  const deleteAllClosedFromPullRequest = pullRequest && isAllClosedPrsKeyword(pullRequestSelector);

  if (pullRequest && name && !deleteFlag) {
    throw new Error("do not provide [name] with --pull-request; pass the PR number to --pull-request.");
  }
  if (deleteFlag && pullRequest && name) {
    throw new Error("do not provide [name] with --delete and --pull-request.");
  }
  if (!deleteFlag && (deleteAllClosedFromName || deleteAllClosedFromPullRequest)) {
    throw new Error(`${ALL_CLOSED_PRS_KEYWORD} can only be used with --delete.`);
  }

  if (deleteFlag) {
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
      throw new Error(`${ALL_CLOSED_PRS_KEYWORD} can only be used with --delete.`);
    }
    const prNumber = pullRequestSelector === "pick" ? "" : normalizeOptionalPrNumber(pullRequestSelector);
    runPullRequestFlow(prNumber);
    return;
  }
  runCreateFlow(name);
}

void runMain().catch((error) => {
  console.error(`Error: ${getErrorMessage(error)}`);
  process.exit(1);
});
