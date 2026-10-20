#!/usr/bin/env bun
//MISE description="Sync a GitHub-rebased stacked pull request branch."
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE flag "--pr-number <number>" help="Open pull request number (default: current branch pull request)"
//USAGE flag "--dry-run" help="Show the sync plan without changing the branch"

import { ensureGitHubAuth, resolveUpstreamContext } from "../../utils/git.js";

export {};

type PullRequest = {
  number: number;
  state: string;
  headRefName: string;
  headRefOid: string;
  baseRefName: string;
  baseRefOid: string;
};

type StackMembership = {
  number: number;
  position: number;
  size: number;
  base?: {
    ref?: string;
  };
};

const PR_NUMBER = (process.env.usage_pr_number ?? "").trim();
const DRY_RUN = process.env.usage_dry_run === "true";

async function run(command: string, args: string[]): Promise<string> {
  const proc = Bun.spawn([command, ...args], {
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

async function gitValue(args: string[]): Promise<string> {
  return (await run("git", args)).trim();
}

async function getPullRequest(repository: string, selector: string): Promise<PullRequest> {
  return JSON.parse(
    await run("gh", [
      "pr",
      "view",
      "--repo",
      repository,
      selector,
      "--json",
      "number,state,headRefName,headRefOid,baseRefName,baseRefOid",
    ]),
  ) as PullRequest;
}

async function main(): Promise<void> {
  const { hostname, owner, repo, remote } = resolveUpstreamContext();
  ensureGitHubAuth(hostname);
  const repository = `${hostname}/${owner}/${repo}`;
  const branch = await gitValue(["rev-parse", "--abbrev-ref", "HEAD"]);
  if (branch === "HEAD") {
    throw new Error("cannot sync a detached HEAD");
  }

  const pullRequest = await getPullRequest(repository, PR_NUMBER || branch);
  if (pullRequest.state !== "OPEN") {
    throw new Error(`pull request #${pullRequest.number} is not open`);
  }
  if (pullRequest.headRefName !== branch) {
    throw new Error(`pull request #${pullRequest.number} points to ${pullRequest.headRefName}, not ${branch}`);
  }

  const remoteRef = `refs/remotes/${remote}/${branch}`;
  if (DRY_RUN) {
    console.log(
      JSON.stringify(
        {
          pull_request: pullRequest.number,
          fetch: `${remote} +refs/heads/${branch}:${remoteRef}`,
          reset: `git reset --keep ${remoteRef}`,
          expected_head: pullRequest.headRefOid,
          base: pullRequest.baseRefName,
        },
        null,
        2,
      ),
    );
    return;
  }

  const beforeStatus = await run("git", ["status", "--porcelain"]);
  // Fetch the GitHub-rebased head, then preserve local changes with reset --keep.
  // reset --keep stops instead of overwriting a conflicting dirty file.
  await run("git", ["fetch", remote, `+refs/heads/${branch}:${remoteRef}`]);
  const remoteHead = await gitValue(["rev-parse", "--verify", remoteRef]);
  if (remoteHead !== pullRequest.headRefOid) {
    throw new Error(
      `remote ${remoteRef} is ${remoteHead}, but pull request #${pullRequest.number} is ${pullRequest.headRefOid}`,
    );
  }

  await run("git", ["reset", "--keep", remoteRef]);
  const localHead = await gitValue(["rev-parse", "HEAD"]);
  if (localHead !== remoteHead) {
    throw new Error(`local branch remains at ${localHead}; expected ${remoteHead}`);
  }

  const stack = JSON.parse(
    await run("gh", [
      "api",
      "--hostname",
      hostname,
      `repos/${owner}/${repo}/pulls/${pullRequest.number}`,
      "--jq",
      ".stack",
    ]),
  ) as StackMembership | null;
  if (!stack) {
    throw new Error(`pull request #${pullRequest.number} is not part of a remote stack`);
  }

  console.log(
    JSON.stringify(
      {
        pull_request: pullRequest.number,
        branch,
        base: pullRequest.baseRefName,
        head: localHead,
        stack: {
          number: stack.number,
          position: stack.position,
          size: stack.size,
          base: stack.base?.ref,
        },
        preserved_uncommitted_changes: beforeStatus.trim().length > 0,
      },
      null,
      2,
    ),
  );
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
