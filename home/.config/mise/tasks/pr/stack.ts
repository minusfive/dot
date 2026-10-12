#!/usr/bin/env bun
//MISE description="Create a GitHub stack from pull requests."
//MISE dir="{{cwd}}"
//MISE quiet=true
//USAGE arg "<pull-requests>..." help="Pull request numbers from bottom to top"
//USAGE flag "--dry-run" help="Show the request without creating the stack"

import { resolveUpstreamContext } from "../../utils/git.js";

export {};

type StackResponse = {
  number: number;
  url: string;
  base?: {
    ref?: string;
  };
  pull_requests?: Array<{
    number: number;
    base?: {
      ref?: string;
    };
    head?: {
      ref?: string;
    };
  }>;
};

const DRY_RUN = process.argv.includes("--dry-run");

function pullRequestNumbers(): number[] {
  return process.argv
    .slice(2)
    .filter((arg) => arg !== "--" && !arg.startsWith("-"))
    .map((arg) => Number(arg));
}

async function run(command: string, args: string[], input?: string): Promise<string> {
  const proc = Bun.spawn([command, ...args], {
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
    throw new Error(stderr.trim() || stdout.trim() || `${command} ${args.join(" ")} failed`);
  }
  return stdout;
}

function stackSummary(stack: StackResponse): Record<string, unknown> {
  return {
    number: stack.number,
    url: stack.url,
    base: stack.base?.ref,
    pull_requests: stack.pull_requests?.map((pullRequest) => ({
      number: pullRequest.number,
      base: pullRequest.base?.ref,
      head: pullRequest.head?.ref,
    })),
  };
}

function stackPullRequestNumbers(stack: StackResponse): number[] {
  return stack.pull_requests?.map((pullRequest) => pullRequest.number) ?? [];
}

async function main(): Promise<void> {
  const pullRequests = pullRequestNumbers();
  if (pullRequests.length < 2) {
    throw new Error("provide at least two pull request numbers from bottom to top");
  }
  if (pullRequests.some((number) => !Number.isSafeInteger(number) || number < 1)) {
    throw new Error("pull request numbers must be positive integers");
  }
  if (new Set(pullRequests).size !== pullRequests.length) {
    throw new Error("pull request numbers must be unique");
  }

  const { hostname, owner, repo } = resolveUpstreamContext();
  const endpoint = `repos/${owner}/${repo}/stacks`;
  const payload = JSON.stringify({ pull_requests: pullRequests });

  // GitHub documents stack creation through this REST endpoint.
  // The gh-stack extension can fail in its separate GraphQL pull request path.
  if (DRY_RUN) {
    console.log(
      JSON.stringify(
        {
          endpoint,
          method: "POST",
          payload: JSON.parse(payload),
        },
        null,
        2,
      ),
    );
    return;
  }

  const existingResponse = await run("gh", [
    "api",
    "--hostname",
    hostname,
    `${endpoint}?pull_request=${pullRequests[0]}`,
  ]);
  const existingStacks = JSON.parse(existingResponse) as StackResponse[];
  const existingStack = existingStacks[0];
  if (existingStack) {
    const existingPullRequests = stackPullRequestNumbers(existingStack);
    if (
      existingPullRequests.length === pullRequests.length &&
      existingPullRequests.every((number, index) => number === pullRequests[index])
    ) {
      console.log(JSON.stringify({ created: false, ...stackSummary(existingStack) }, null, 2));
      return;
    }
    throw new Error(
      `pull request #${pullRequests[0]} is already in stack #${existingStack.number} with pull requests ${existingPullRequests.join(", ")}`,
    );
  }

  const response = await run(
    "gh",
    ["api", "--hostname", hostname, "--method", "POST", endpoint, "--input", "-"],
    payload,
  );
  const stack = JSON.parse(response) as StackResponse;
  console.log(JSON.stringify(stackSummary(stack), null, 2));
}

void main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
