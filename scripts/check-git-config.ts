#!/usr/bin/env bun

import { lstatSync, readFileSync } from "node:fs";
import { join } from "node:path";

type GitResult = {
  status: number;
  stdout: string;
};

type DomainLoadResult = {
  domains: string[];
  error: "invalid" | "duplicate" | "empty" | "missing" | "";
  errorLine: number;
};

const decoder = new TextDecoder();

function decode(value: Uint8Array | null): string {
  return value ? decoder.decode(value) : "";
}

function runGit(repoRoot: string, args: string[]): GitResult {
  const result = Bun.spawnSync(["git", ...args], {
    cwd: repoRoot,
    stdin: "ignore",
    stdout: "pipe",
    stderr: "ignore",
  });
  return {
    status: result.exitCode,
    stdout: decode(result.stdout),
  };
}

function normalizeDomain(value: string): string | undefined {
  const host = value.toLowerCase().replace(/\.$/, "");
  if (!host || host.length > 253) return undefined;
  if (/^(0x[0-9a-f]+|\d+)(\.(0x[0-9a-f]+|\d+)){0,3}$/.test(host))
    return undefined;
  if (
    !/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)*$/.test(
      host,
    )
  ) {
    return undefined;
  }
  if (host.split(".").some((label) => label.length > 63)) return undefined;
  return host;
}

function loadDomains(path: string): DomainLoadResult {
  let contents: string;
  try {
    contents = readFileSync(path, "utf8");
  } catch {
    return { domains: [], error: "missing", errorLine: 0 };
  }

  const domains: string[] = [];
  const seen = new Set<string>();
  const lines = contents.split(/\r?\n/);
  for (const [index, rawLine] of lines.entries()) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const host = normalizeDomain(line);
    if (!host) return { domains, error: "invalid", errorLine: index + 1 };
    if (seen.has(host))
      return { domains, error: "duplicate", errorLine: index + 1 };
    seen.add(host);
    domains.push(host);
  }

  if (domains.length === 0) return { domains, error: "empty", errorLine: 0 };
  return { domains, error: "", errorLine: 0 };
}

function domainMatches(domains: string[], value: string): boolean {
  const host = normalizeDomain(value);
  if (!host) return false;
  return domains.some(
    (domain) => host === domain || host.endsWith(`.${domain}`),
  );
}

function hostFromUrl(value: string): string | undefined {
  let authority = "";
  let path = "";

  if (value.startsWith("https://")) {
    const rest = value.slice("https://".length);
    authority = rest.split("/", 1)[0] ?? "";
    path = rest.includes("/") ? `/${rest.slice(rest.indexOf("/") + 1)}` : "";
  } else if (value.startsWith("ssh://git@")) {
    const rest = value.slice("ssh://git@".length);
    authority = rest.split("/", 1)[0] ?? "";
    path = rest.includes("/") ? `/${rest.slice(rest.indexOf("/") + 1)}` : "";
  } else if (value.startsWith("git@") && value.includes(":")) {
    const rest = value.slice("git@".length);
    authority = rest.slice(0, rest.indexOf(":"));
    path = rest.slice(rest.indexOf(":") + 1);
    if (path) return undefined;
    return normalizeDomain(authority);
  } else {
    return undefined;
  }

  if (!authority || authority.includes("@") || authority.includes(":"))
    return undefined;
  if (path && path !== "/") return undefined;
  return normalizeDomain(authority);
}

function configScopeUrl(key: string, section: string): string | undefined {
  if (!key.startsWith(`${section}.`)) return undefined;
  const scope = key.slice(section.length + 1);
  const match = scope.match(/^(https:\/\/[^/]+)(\/.*)?\.([a-z][a-z0-9-]*)$/);
  if (!match) return undefined;
  const path = match[2] ?? "";
  if (path && path !== "/") return undefined;
  return `${match[1]}${path}`;
}

function includeIsAllowed(key: string, value: string): boolean {
  return new Set([
    "include.path:~/.config/delta/themes/catppuccin.gitconfig",
    "includeif.gitdir:~/dev/work/.path:~/dev/work/.gitconfig",
    "includeif.gitdir:~/Notes/Work/.path:~/dev/work/.gitconfig",
    "includeif.gitdir:~/dev/personal/.path:~/dev/personal/.gitconfig",
    "includeif.gitdir:~/Notes/Personal/.path:~/dev/personal/.gitconfig",
  ]).has(`${key}:${value}`);
}

function main(): number {
  const repoResult = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], {
    stdin: "ignore",
    stdout: "pipe",
    stderr: "ignore",
  });
  if (repoResult.exitCode !== 0) {
    console.error("error: Git config checker must run inside a Git repository");
    return 1;
  }

  const repoRoot = decode(repoResult.stdout).trim();
  const manifest = "home/dev/personal/.domains";
  const manifestPath = join(repoRoot, manifest);
  const manifestStatus = runGit(repoRoot, [
    "ls-files",
    "--error-unmatch",
    "--",
    manifest,
  ]);
  let errorCount = 0;

  try {
    const manifestStat = lstatSync(manifestPath);
    if (
      manifestStatus.status !== 0 ||
      !manifestStat.isFile() ||
      manifestStat.isSymbolicLink()
    ) {
      console.error(
        "git-config-check: tracked personal domain manifest is missing or is a symlink",
      );
      return 1;
    }
  } catch {
    console.error(
      "git-config-check: tracked personal domain manifest is missing or is a symlink",
    );
    return 1;
  }

  const domainResult = loadDomains(manifestPath);
  if (domainResult.error) {
    switch (domainResult.error) {
      case "invalid":
        console.error(
          `git-config-check: personal domain manifest has an invalid hostname at line ${domainResult.errorLine}`,
        );
        break;
      case "duplicate":
        console.error(
          `git-config-check: personal domain manifest has a duplicate hostname at line ${domainResult.errorLine}`,
        );
        break;
      case "empty":
        console.error(
          "git-config-check: personal domain manifest has no hostnames",
        );
        break;
      default:
        console.error(
          "git-config-check: personal domain manifest is missing or unreadable",
        );
    }
    errorCount += 1;
  }

  const filesResult = runGit(repoRoot, [
    "ls-files",
    "-z",
    "--",
    "*.gitconfig",
    "home/.config/git/config",
  ]);
  if (filesResult.status !== 0) {
    console.error(
      "git-config-check: could not enumerate tracked Git config files",
    );
    return 1;
  }

  for (const file of filesResult.stdout.split("\0").filter(Boolean)) {
    const filePath = join(repoRoot, file);
    try {
      const fileStat = lstatSync(filePath);
      if (fileStat.isSymbolicLink() || !fileStat.isFile()) {
        console.error(
          `git-config-check: tracked .gitconfig: Git config source setting is not allowed`,
        );
        errorCount += 1;
        continue;
      }
    } catch {
      console.error(
        `git-config-check: tracked .gitconfig: Git config source setting is not allowed`,
      );
      errorCount += 1;
      continue;
    }

    const configResult = runGit(repoRoot, [
      "config",
      "--null",
      "--list",
      "--file",
      file,
    ]);
    if (configResult.status !== 0) {
      const source =
        file === "home/.config/git/config"
          ? "home/.config/git/config"
          : "tracked .gitconfig";
      console.error(
        `git-config-check: ${source}: invalid Git config setting is not allowed`,
      );
      errorCount += 1;
      continue;
    }

    for (const record of configResult.stdout.split("\0").filter(Boolean)) {
      const separator = record.indexOf("\n");
      const key = separator === -1 ? record : record.slice(0, separator);
      const value = separator === -1 ? "true" : record.slice(separator + 1);
      const source =
        file === "home/.config/git/config"
          ? "home/.config/git/config"
          : "tracked .gitconfig";

      switch (key) {
        case "include.path":
        case "user.name":
        case "user.email":
        case "user.signingkey":
          if (key === "include.path" && includeIsAllowed(key, value)) break;
          console.error(
            `git-config-check: ${source}: ${key === "include.path" ? "include" : "identity"} setting is not allowed`,
          );
          errorCount += 1;
          break;
        default:
          if (key.startsWith("includeif.") && key.endsWith(".path")) {
            if (!includeIsAllowed(key, value)) {
              console.error(
                `git-config-check: ${source}: include setting is not allowed`,
              );
              errorCount += 1;
            }
            break;
          }
          if (
            key.startsWith("remote.") &&
            (key.endsWith(".url") || key.endsWith(".pushurl"))
          ) {
            console.error(
              `git-config-check: ${source}: remote URL setting is not allowed`,
            );
            errorCount += 1;
            break;
          }
          if (key.startsWith("credential.")) {
            const scopeUrl = configScopeUrl(key, "credential");
            const host = scopeUrl ? hostFromUrl(scopeUrl) : undefined;
            if (
              !scopeUrl ||
              !host ||
              !domainMatches(domainResult.domains, host)
            ) {
              console.error(
                `git-config-check: ${source}: credential setting is not allowed`,
              );
              errorCount += 1;
              break;
            }
            const attribute = key.slice(key.lastIndexOf(".") + 1).toLowerCase();
            if (attribute === "usehttppath") {
              if (
                !/^(true|false|yes|no|on|off|1|0)$/.test(value.toLowerCase())
              ) {
                console.error(
                  `git-config-check: ${source}: credential setting is not allowed`,
                );
                errorCount += 1;
              }
            } else {
              console.error(
                `git-config-check: ${source}: ${attribute === "username" ? "identity" : "credential"} setting is not allowed`,
              );
              errorCount += 1;
            }
            break;
          }
          if (key.startsWith("http.")) {
            const scopeUrl = configScopeUrl(key, "http");
            const host = scopeUrl ? hostFromUrl(scopeUrl) : undefined;
            if (
              !scopeUrl ||
              !host ||
              !domainMatches(domainResult.domains, host)
            ) {
              console.error(
                `git-config-check: ${source}: HTTP setting is not allowed`,
              );
              errorCount += 1;
              break;
            }
            const attribute = key.slice(key.lastIndexOf(".") + 1).toLowerCase();
            const valid =
              (attribute === "sslverify" &&
                /^(true|yes|on|1)$/.test(value.toLowerCase())) ||
              (attribute === "followredirects" &&
                /^(true|false|yes|no|on|off|1|0)$/.test(value.toLowerCase())) ||
              (["lowspeedlimit", "lowspeedtime", "postbuffer"].includes(
                attribute,
              ) &&
                /^\d+$/.test(value));
            if (!valid) {
              console.error(
                `git-config-check: ${source}: HTTP setting is not allowed`,
              );
              errorCount += 1;
            }
            break;
          }
          if (
            key.startsWith("url.") &&
            (key.endsWith(".insteadof") || key.endsWith(".pushinsteadof"))
          ) {
            const target = key
              .slice(4)
              .replace(/\.(?:insteadof|pushinsteadof)$/, "");
            if (
              !domainMatches(domainResult.domains, hostFromUrl(target) ?? "") ||
              !domainMatches(domainResult.domains, hostFromUrl(value) ?? "")
            ) {
              console.error(
                `git-config-check: ${source}: URL rewrite setting is not allowed`,
              );
              errorCount += 1;
            }
          }
      }
    }
  }

  if (errorCount > 0) return 1;
  console.log("Git config policy passed.");
  return 0;
}

process.exitCode = main();
