import { spawnSync } from "child_process";

export type ResolvedContext = {
  hostname: string;
  owner: string;
  repo: string;
  remote: string;
  remoteUrl: string;
};

type CliOptions = {
  remoteOverride?: string;
};

function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

function runGit(args: string[]): string {
  const result = spawnSync("git", args, { encoding: "utf-8" });
  if (result.status !== 0) {
    const stderr = result.stderr?.trim();
    const stdout = result.stdout?.trim();
    throw new Error(stderr || stdout || `git ${args.join(" ")} failed`);
  }
  return result.stdout ?? "";
}

function toOwnerRepo(pathname: string | undefined): { owner: string; repo: string } | undefined {
  if (!pathname) return undefined;
  const cleaned = pathname.replace(/^\/+/, "").replace(/\.git$/, "");
  const segments = cleaned.split("/").filter(Boolean);
  if (segments.length < 2) return undefined;
  const owner = segments.at(-2);
  const repo = segments.at(-1);
  if (!owner || !repo) return undefined;
  return { owner, repo };
}

function parseRemoteUrl(remoteUrl: string): { hostname: string; owner: string; repo: string } | undefined {
  if (remoteUrl.includes("://")) {
    try {
      const parsed = new URL(remoteUrl);
      const ownerRepo = toOwnerRepo(parsed.pathname);
      if (!ownerRepo) return undefined;
      return { hostname: parsed.hostname, owner: ownerRepo.owner, repo: ownerRepo.repo };
    } catch {
      return undefined;
    }
  }

  const scpMatch = remoteUrl.match(/^(?:[^@]+@)?(?<hostname>[^:]+):(?<path>.+)$/);
  if (!scpMatch) return undefined;
  const groups = scpMatch.groups;
  if (!groups?.["hostname"]) return undefined;
  const ownerRepo = toOwnerRepo(groups["path"]);
  if (!ownerRepo) return undefined;
  return { hostname: groups["hostname"], owner: ownerRepo.owner, repo: ownerRepo.repo };
}

function listFetchRemotes(): Map<string, string> {
  const remoteOutput = runGit(["remote", "-v"]);
  const remotes = new Map<string, string>();
  for (const line of remoteOutput.split("\n")) {
    const match = line.match(/^(?<remote>\S+)\s+(?<url>\S+)\s+\(fetch\)$/);
    if (!match) continue;
    const groups = match.groups;
    if (!groups?.["remote"] || !groups?.["url"]) continue;
    remotes.set(groups["remote"], groups["url"]);
  }
  return remotes;
}

function chooseRemote(remotes: Map<string, string>, remoteOverride?: string): string {
  const sorted = [...remotes.keys()].sort((a, b) => a.localeCompare(b));
  if (sorted.length === 0) throw new Error("No git remotes found");

  if (remoteOverride) {
    if (!remotes.has(remoteOverride)) throw new Error(`Remote "${remoteOverride}" does not exist`);
    return remoteOverride;
  }

  if (remotes.has("upstream")) return "upstream";
  if (remotes.has("origin")) return "origin";

  const first = sorted[0];
  if (!first) throw new Error("No git remotes found");
  return first;
}

export function resolveUpstreamContext(options: CliOptions = {}): ResolvedContext {
  const remotes = listFetchRemotes();
  const remote = chooseRemote(remotes, options.remoteOverride);
  const remoteUrl = remotes.get(remote);
  if (!remoteUrl) throw new Error(`Remote "${remote}" has no fetch URL`);

  const parsed = parseRemoteUrl(remoteUrl);
  if (!parsed) throw new Error(`Could not parse remote URL "${remoteUrl}"`);

  return { hostname: parsed.hostname, owner: parsed.owner, repo: parsed.repo, remote, remoteUrl };
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {};
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--remote") {
      const remoteName = argv[i + 1];
      if (typeof remoteName === "string" && remoteName.length > 0) {
        options.remoteOverride = remoteName;
        i += 1;
        continue;
      }
    }
    if (typeof arg === "string") throw new Error(`Unknown or incomplete option "${arg}"`);
    throw new Error("Unknown or incomplete option");
  }
  return options;
}

export function runResolveUpstreamCli(argv: string[]): void {
  try {
    const resolved = resolveUpstreamContext(parseArgs(argv));
    console.log(JSON.stringify(resolved, null, 2));
  } catch (error) {
    console.error(`Error: ${getErrorMessage(error)}`);
    process.exit(1);
  }
}

if (import.meta.main) {
  runResolveUpstreamCli(process.argv.slice(2));
}
