#!/usr/bin/env bun
//MISE description="Preview markdown with gh-markdown-preview and auto-clean stale/duplicate servers."
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE arg "[file]" help="Markdown file to preview; when omitted, select one from the search directory with fzf."
//USAGE flag "--dir <directory>" help="Directory to recursively search for Markdown files when [file] is omitted." default="."
//USAGE flag "--host <host>" help="Preview host" default="localhost"
//USAGE flag "--port <port>" help="Preview port (default: stable per file in 3333-3532)"
//USAGE flag "--open" help="Open preview URL in browser (focus existing Chrome tab first when already running)."
//USAGE flag "--refresh" help="Refresh matching open Chrome tabs for the preview."
//USAGE flag "--reconcile" help="Reconcile preview state: stop stale/duplicate servers and exit."
//USAGE flag "--kill-all" help="Stop all running gh markdown-preview servers and exit."
//USAGE flag "--list" help="List running preview servers and exit."
//USAGE flag "--format <format>" help="Output format for --list: json or markdown." default="json"

import { mkdir, readFile, stat, writeFile } from "node:fs/promises";
import { basename, relative, resolve } from "node:path";
import { spawn } from "node:child_process";

interface PreviewInstance {
  file: string;
  host: string;
  port: number;
  pid: number;
  launcherPid?: number;
  startedAt: string;
}

interface PreviewServerListEntry {
  docTitle: string;
  sourceUrl: string;
  browserUrl: string;
}

type PreviewListFormat = "json" | "markdown";

type PreviewProcessKind = "launcher" | "server";

interface RunningPreviewProcess {
  pid: number;
  kind: PreviewProcessKind;
  file: string;
  host: string;
  port: number;
}

interface ChromeFocusResult {
  status: "focused" | "not_found" | "not_running" | "unsupported" | "error";
  detail?: string;
}

interface ChromeRefreshResult {
  status: "refreshed" | "not_found" | "not_running" | "unsupported" | "error";
  count?: number;
  detail?: string;
}

const STATE_DIR = resolve("tmp/md-preview");
const STATE_FILE = resolve(STATE_DIR, "instances.json");
const PORT_BASE = 3333;
const PORT_SPAN = 200;
const START_TIMEOUT_MS = 12_000;
const START_RETRY_MS = 250;
const NO_RUNNING_PREVIEWS_MESSAGE = "No running preview servers found.";
function env(name: string): string | undefined {
  const value = process.env[name];
  if (!value) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

function flag(name: string, cliFlag: string): boolean {
  const value = env(name);
  if (value !== undefined) {
    const normalized = value.toLowerCase();
    return normalized === "true" || normalized === "1" || normalized === "yes" || normalized === "on";
  }
  return process.argv.includes(cliFlag);
}

function firstPositionalArg(): string | undefined {
  const args = process.argv.slice(2);
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i]!;
    if (arg === "--dir" || arg === "--host" || arg === "--port" || arg === "--format") {
      i += 1;
      continue;
    }
    if (arg === "--open" || arg === "--kill-all" || arg === "--reconcile" || arg === "--list") continue;
    if (arg.startsWith("-")) continue;
    return arg;
  }
  return undefined;
}

function relativeToCwd(path: string): string {
  return relative(process.cwd(), path).replaceAll("\\", "/");
}

function buildPreviewServerList(instances: PreviewInstance[]): PreviewServerListEntry[] {
  return instances.map((instance) => ({
    docTitle: basename(instance.file, ".md"),
    sourceUrl: relativeToCwd(instance.file),
    browserUrl: `http://${instance.host}:${instance.port}/`,
  }));
}

function stablePortForFile(filePath: string): number {
  let hash = 2166136261;
  for (let i = 0; i < filePath.length; i += 1) {
    hash ^= filePath.charCodeAt(i);
    hash = Math.imul(hash, 16777619);
  }
  const offset = Math.abs(hash >>> 0) % PORT_SPAN;
  return PORT_BASE + offset;
}

function parsePort(raw: string): number {
  const port = Number.parseInt(raw, 10);
  if (!Number.isFinite(port) || port <= 0 || port > 65535) {
    throw new Error(`invalid --port value: ${raw}`);
  }
  return port;
}

function parseListFormat(raw: string | undefined): PreviewListFormat {
  const normalized = (raw ?? "json").trim().toLowerCase();
  if (normalized === "json" || normalized === "markdown") return normalized;
  throw new Error(`invalid --format value: ${raw ?? "(empty)"}. Expected one of: json, markdown`);
}

async function listMarkdownFiles(root: string, directory: string): Promise<string[]> {
  const proc = (() => {
    try {
      return Bun.spawn(["fd", "-e", "md", "--type", "f", ".", directory], {
        cwd: root,
        stdout: "pipe",
        stderr: "pipe",
      });
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === "ENOENT") {
        throw new Error(
          "fd is required to select a markdown file automatically. Install fd or pass [file] explicitly.",
        );
      }
      throw error;
    }
  })();

  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);

  if (exitCode !== 0 && exitCode !== 1) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    throw new Error(`failed to enumerate Markdown files under ${directory}: ${detail}`);
  }

  return stdoutText
    .split("\n")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);
}

async function pickMarkdownFile(root: string, directory: string): Promise<string | undefined> {
  const directoryPath = resolve(root, directory);
  let directoryStats;
  try {
    directoryStats = await stat(directoryPath);
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT") {
      throw new Error(`Markdown search directory does not exist: ${directoryPath}`);
    }
    throw error;
  }

  if (!directoryStats.isDirectory()) {
    throw new Error(`Markdown search path is not a directory: ${directoryPath}`);
  }

  const candidates = await listMarkdownFiles(root, directory);
  if (candidates.length === 0) {
    throw new Error(`no Markdown files found under ${relativeToCwd(directoryPath) || "."}`);
  }

  const proc = (() => {
    try {
      return Bun.spawn(["fzf", "--prompt", "markdown> ", "--height", "40%", "--reverse"], {
        cwd: root,
        stdin: "pipe",
        stdout: "pipe",
        stderr: "pipe",
      });
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === "ENOENT") {
        throw new Error(
          "fzf is required to select a markdown file automatically. Install fzf or pass [file] explicitly.",
        );
      }
      throw error;
    }
  })();

  proc.stdin.write(`${candidates.join("\n")}\n`);
  proc.stdin.end();

  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);

  if (exitCode === 1 || exitCode === 130) return undefined;
  if (exitCode !== 0) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    throw new Error(`failed to select markdown file with fzf: ${detail}`);
  }

  const selected = stdoutText.trim();
  if (!selected) return undefined;
  return resolve(root, selected);
}

async function loadInstances(): Promise<PreviewInstance[]> {
  try {
    const raw = await readFile(STATE_FILE, "utf8");
    const parsed = JSON.parse(raw) as { instances?: PreviewInstance[] };
    if (!parsed || !Array.isArray(parsed.instances)) return [];
    return parsed.instances.filter(
      (instance) =>
        !!instance &&
        typeof instance.file === "string" &&
        typeof instance.host === "string" &&
        Number.isFinite(instance.port) &&
        Number.isFinite(instance.pid) &&
        (instance.launcherPid === undefined || Number.isFinite(instance.launcherPid)),
    );
  } catch (error) {
    const code = (error as NodeJS.ErrnoException).code;
    if (code === "ENOENT") return [];
    throw error;
  }
}

async function saveInstances(instances: PreviewInstance[]): Promise<void> {
  await mkdir(STATE_DIR, { recursive: true });
  const payload = JSON.stringify({ instances }, null, 2);
  await writeFile(STATE_FILE, `${payload}\n`, "utf8");
}

async function isPidAlive(pid: number): Promise<boolean> {
  const proc = Bun.spawn(["kill", "-0", String(pid)], {
    stdout: "ignore",
    stderr: "ignore",
  });
  const exitCode = await proc.exited;
  return exitCode === 0;
}

async function listListeningPids(port: number): Promise<number[]> {
  const proc = Bun.spawn(["lsof", "-ti", `tcp:${port}`, "-sTCP:LISTEN"], {
    stdout: "pipe",
    stderr: "pipe",
  });

  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);

  if (exitCode !== 0 && exitCode !== 1) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    throw new Error(`failed to inspect port ${port}: ${detail}`);
  }

  const pids = stdoutText
    .split(/\s+/)
    .map((value) => Number.parseInt(value, 10))
    .filter((value) => Number.isFinite(value) && value > 0);

  return [...new Set(pids)];
}

function processKey(file: string, port: number): string {
  return `${file}\u0000${port}`;
}

function isInWorktree(root: string, filePath: string): boolean {
  const rel = relative(root, filePath);
  return rel === "" || (!rel.startsWith("..") && !rel.startsWith("../") && !rel.startsWith("..\\"));
}

function parseRunningPreviewProcess(pid: number, command: string): RunningPreviewProcess | null {
  const isServer = /(^|[\\/])gh-markdown-preview(?:\s|$)/.test(command);
  const isLauncher = /\bgh\s+markdown-preview\b/.test(command);
  if (!isServer && !isLauncher) return null;

  const portMatch = command.match(/(?:^|\s)--port\s+(\d+)(?:\s|$)/);
  const fileMatch = command.match(/(?:^|\s)--port\s+\d+\s+(.+)$/);
  if (!portMatch || !fileMatch) return null;

  const port = Number.parseInt(portMatch[1]!, 10);
  if (!Number.isFinite(port) || port <= 0 || port > 65535) return null;

  const file = resolve(fileMatch[1]!.trim());
  const host = command.match(/(?:^|\s)--host\s+(\S+)(?:\s|$)/)?.[1] ?? "localhost";

  return {
    pid,
    kind: isServer ? "server" : "launcher",
    file,
    host,
    port,
  };
}

async function listRunningPreviewProcesses(): Promise<RunningPreviewProcess[]> {
  const proc = Bun.spawn(["ps", "-Ao", "pid=,command="], {
    stdout: "pipe",
    stderr: "pipe",
  });
  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);
  if (exitCode !== 0) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    throw new Error(`failed to inspect running processes: ${detail}`);
  }

  const processes: RunningPreviewProcess[] = [];
  for (const line of stdoutText.split("\n")) {
    const match = line.trim().match(/^(\d+)\s+(.+)$/);
    if (!match) continue;
    const pid = Number.parseInt(match[1]!, 10);
    const command = match[2]!;
    if (!Number.isFinite(pid) || pid <= 0 || pid === process.pid) continue;
    const parsed = parseRunningPreviewProcess(pid, command);
    if (parsed) processes.push(parsed);
  }

  return processes;
}

async function stopPid(pid: number): Promise<boolean> {
  const proc = Bun.spawn(["kill", String(pid)], {
    stdout: "ignore",
    stderr: "pipe",
  });
  const stderrText = proc.stderr ? await new Response(proc.stderr).text() : "";
  const exitCode = await proc.exited;

  if (exitCode === 0) return true;
  if (stderrText.includes("No such process")) return false;
  throw new Error(`failed to stop PID ${pid}: ${stderrText.trim() || `exit code ${exitCode}`}`);
}

async function reconcilePreviewInstances(
  root: string,
  instances: PreviewInstance[],
  options?: { quiet?: boolean },
): Promise<PreviewInstance[]> {
  const quiet = options?.quiet ?? false;
  const existingByKey = new Map<string, PreviewInstance>();
  for (const instance of instances) {
    existingByKey.set(processKey(instance.file, instance.port), instance);
  }

  let running = (await listRunningPreviewProcesses()).filter((process) => isInWorktree(root, process.file));

  const fileExistsCache = new Map<string, boolean>();
  const fileExists = async (file: string): Promise<boolean> => {
    const cached = fileExistsCache.get(file);
    if (cached !== undefined) return cached;
    const exists = await Bun.file(file).exists();
    fileExistsCache.set(file, exists);
    return exists;
  };

  const serverByFile = new Map<string, RunningPreviewProcess[]>();
  const keyHasServer = new Set<string>();
  for (const process of running) {
    if (process.kind !== "server") continue;
    const key = processKey(process.file, process.port);
    keyHasServer.add(key);
    const list = serverByFile.get(process.file) ?? [];
    list.push(process);
    serverByFile.set(process.file, list);
  }

  const keysToStop = new Set<string>();
  for (const [file, servers] of serverByFile.entries()) {
    if (!(await fileExists(file))) {
      for (const server of servers) {
        keysToStop.add(processKey(server.file, server.port));
      }
      if (!quiet) {
        console.log(`[md:preview] stopping stale preview for missing file: ${relativeToCwd(file)}`);
      }
      continue;
    }

    if (servers.length > 1) {
      servers.sort((a, b) => a.pid - b.pid);
      for (const duplicate of servers.slice(1)) {
        keysToStop.add(processKey(duplicate.file, duplicate.port));
      }
      const duplicatePorts = servers.slice(1).map((server) => server.port);
      if (!quiet) {
        console.log(
          `[md:preview] stopping duplicate preview for ${relativeToCwd(file)} on port(s): ${duplicatePorts.join(", ")}`,
        );
      }
    }
  }

  for (const process of running) {
    if (process.kind !== "launcher") continue;
    const key = processKey(process.file, process.port);
    if (!keyHasServer.has(key)) keysToStop.add(key);
  }

  if (keysToStop.size > 0) {
    const pidsToStop = new Set<number>();
    for (const process of running) {
      const key = processKey(process.file, process.port);
      if (keysToStop.has(key)) pidsToStop.add(process.pid);
    }
    for (const pid of [...pidsToStop].sort((a, b) => a - b)) {
      if (!(await isPidAlive(pid))) continue;
      await stopPid(pid);
    }
    running = (await listRunningPreviewProcesses()).filter((process) => isInWorktree(root, process.file));
  }

  const servers = running
    .filter((process) => process.kind === "server")
    .sort((a, b) => {
      if (a.file !== b.file) return a.file.localeCompare(b.file);
      return a.pid - b.pid;
    });

  const liveInstances: PreviewInstance[] = [];
  const seenFiles = new Set<string>();
  const now = new Date().toISOString();
  for (const server of servers) {
    if (!(await fileExists(server.file))) continue;
    if (seenFiles.has(server.file)) continue;
    seenFiles.add(server.file);

    const key = processKey(server.file, server.port);
    const previous = existingByKey.get(key);
    liveInstances.push({
      file: server.file,
      host: server.host,
      port: server.port,
      pid: server.pid,
      launcherPid: previous?.launcherPid,
      startedAt: previous?.startedAt ?? now,
    });
  }

  return liveInstances;
}

async function waitForPreviewReady(host: string, port: number): Promise<boolean> {
  const url = `http://${host}:${port}/`;
  const deadline = Date.now() + START_TIMEOUT_MS;

  while (Date.now() < deadline) {
    try {
      const response = await fetch(url, {
        method: "HEAD",
        signal: AbortSignal.timeout(1500),
      });
      if (response.status < 500) return true;
    } catch {
      // server still booting
    }
    await Bun.sleep(START_RETRY_MS);
  }
  return false;
}

async function openInDefaultBrowser(url: string): Promise<void> {
  const command =
    process.platform === "darwin"
      ? ["open", url]
      : process.platform === "linux"
        ? ["xdg-open", url]
        : process.platform === "win32"
          ? ["cmd", "/c", "start", "", url]
          : null;

  if (!command) {
    throw new Error(`unsupported platform for --open: ${process.platform}`);
  }

  const proc = Bun.spawn(command, { stdout: "ignore", stderr: "pipe" });
  const stderrText = proc.stderr ? await new Response(proc.stderr).text() : "";
  const exitCode = await proc.exited;
  if (exitCode !== 0) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    throw new Error(`failed to open browser: ${detail}`);
  }
}

async function focusExistingChromeTab(url: string): Promise<ChromeFocusResult> {
  if (process.platform !== "darwin") {
    return { status: "unsupported" };
  }
  const targetOrigin = new URL(url).origin;

  const script = String.raw`on run argv
set targetOrigin to item 1 of argv

if application "Google Chrome" is not running then
  return "NOT_RUNNING"
end if

tell application "Google Chrome"
  repeat with w from 1 to (count of windows)
    repeat with t from 1 to (count of tabs of window w)
      set u to URL of tab t of window w
      if u is not missing value then
        if (offset of targetOrigin in u) is 1 then
          set active tab index of window w to t
          set index of window w to 1
          activate
          return "FOCUSED"
        end if
      end if
    end repeat
  end repeat
end tell

return "NOT_FOUND"
end run
`;

  const proc = Bun.spawn(["osascript", "-", targetOrigin], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
  });
  proc.stdin.write(script);
  proc.stdin.end();

  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);

  if (exitCode !== 0) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    return { status: "error", detail: `failed to focus Chrome tab: ${detail}` };
  }

  const result = stdoutText.trim();
  if (result === "FOCUSED") return { status: "focused" };
  if (result === "NOT_FOUND") return { status: "not_found" };
  if (result === "NOT_RUNNING") return { status: "not_running" };

  return {
    status: "error",
    detail: `unexpected Chrome focus result: ${result || "(empty output)"}`,
  };
}

async function refreshExistingChromeTabs(url: string): Promise<ChromeRefreshResult> {
  if (process.platform !== "darwin") {
    return { status: "unsupported" };
  }
  const targetOrigin = new URL(url).origin;

  const script = String.raw`on run argv
set targetOrigin to item 1 of argv

if application "Google Chrome" is not running then
  return "NOT_RUNNING"
end if

set refreshedCount to 0

tell application "Google Chrome"
  repeat with w from 1 to (count of windows)
    repeat with t from 1 to (count of tabs of window w)
      set u to URL of tab t of window w
      if u is not missing value then
        if (offset of targetOrigin in u) is 1 then
          reload tab t of window w
          set refreshedCount to refreshedCount + 1
        end if
      end if
    end repeat
  end repeat
end tell

if refreshedCount is 0 then
  return "NOT_FOUND"
end if

return refreshedCount as text
end run
`;

  const proc = Bun.spawn(["osascript", "-", targetOrigin], {
    stdin: "pipe",
    stdout: "pipe",
    stderr: "pipe",
  });
  proc.stdin.write(script);
  proc.stdin.end();

  const stdoutPromise = proc.stdout ? new Response(proc.stdout).text() : Promise.resolve("");
  const stderrPromise = proc.stderr ? new Response(proc.stderr).text() : Promise.resolve("");
  const [exitCode, stdoutText, stderrText] = await Promise.all([proc.exited, stdoutPromise, stderrPromise]);

  if (exitCode !== 0) {
    const detail = stderrText.trim() || `exit code ${exitCode}`;
    return {
      status: "error",
      detail: `failed to refresh Chrome tabs: ${detail}`,
    };
  }

  const result = stdoutText.trim();
  if (result === "NOT_FOUND") return { status: "not_found" };
  if (result === "NOT_RUNNING") return { status: "not_running" };
  const count = Number.parseInt(result, 10);
  if (Number.isInteger(count) && count > 0) {
    return { status: "refreshed", count };
  }

  return {
    status: "error",
    detail: `unexpected Chrome refresh result: ${result || "(empty output)"}`,
  };
}

async function choosePort(filePath: string, instances: PreviewInstance[], requestedPort?: number): Promise<number> {
  if (requestedPort !== undefined) {
    const listeners = await listListeningPids(requestedPort);
    if (listeners.length > 0) {
      throw new Error(`port ${requestedPort} is already in use by PID(s): ${listeners.join(", ")}`);
    }
    return requestedPort;
  }

  const preferred = stablePortForFile(filePath);
  const reserved = new Set(instances.map((instance) => instance.port));
  for (let offset = 0; offset < PORT_SPAN; offset += 1) {
    const candidate = PORT_BASE + ((preferred - PORT_BASE + offset) % PORT_SPAN);
    if (reserved.has(candidate)) continue;
    const listeners = await listListeningPids(candidate);
    if (listeners.length === 0) return candidate;
  }

  throw new Error(`no available preview ports in ${PORT_BASE}-${PORT_BASE + PORT_SPAN - 1}`);
}

async function stopAllPreviewServers(instances: PreviewInstance[]): Promise<void> {
  const pids = new Set<number>(instances.map((instance) => instance.pid));
  for (const process of await listRunningPreviewProcesses()) {
    pids.add(process.pid);
  }

  let stopped = 0;
  for (const pid of [...pids].sort((a, b) => a - b)) {
    if (!(await isPidAlive(pid))) continue;
    if (await stopPid(pid)) {
      stopped += 1;
      console.log(`[md:preview] stopped PID ${pid}`);
    }
  }

  await saveInstances([]);
  console.log(`[md:preview] stopped ${stopped} preview server(s)`);
}

async function startPreviewServer(
  filePath: string,
  host: string,
  port: number,
): Promise<{ listenerPid: number; launcherPid: number }> {
  await ensureMarkdownPreviewExtension();

  const child = spawn(
    "gh",
    ["markdown-preview", "--disable-auto-open", "--host", host, "--port", String(port), filePath],
    {
      detached: true,
      stdio: "ignore",
    },
  );
  child.unref();

  const pid = child.pid;
  if (typeof pid !== "number" || !Number.isFinite(pid) || pid <= 0) {
    throw new Error("failed to start markdown preview process");
  }

  const ready = await waitForPreviewReady(host, port);
  if (!ready) {
    await stopPid(pid);
    throw new Error(`preview server failed to start on http://${host}:${port}/`);
  }

  const listeners = (await listListeningPids(port)).sort((a, b) => a - b);
  const listenerPid = listeners[0];
  if (!listenerPid) {
    await stopPid(pid);
    throw new Error(`preview listener did not bind on port ${port}`);
  }

  return { listenerPid, launcherPid: pid };
}

async function ensureMarkdownPreviewExtension(): Promise<void> {
  const proc = (() => {
    try {
      return Bun.spawn(["gh", "markdown-preview", "--help"], {
        stdout: "ignore",
        stderr: "pipe",
      });
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code === "ENOENT") {
        throw new Error("gh is required. Install it, then run: gh extension install yusukebe/gh-markdown-preview");
      }
      throw error;
    }
  })();

  const stderrText = proc.stderr ? await new Response(proc.stderr).text() : "";
  const exitCode = await proc.exited;
  if (exitCode === 0) return;

  const detail = stderrText.trim() || `exit code ${exitCode}`;
  throw new Error(
    `gh markdown-preview is required (${detail}). Install it with: gh extension install yusukebe/gh-markdown-preview`,
  );
}

async function main(): Promise<void> {
  const root = resolve(process.env.usage_root ?? ".");
  const killAll = flag("usage_kill_all", "--kill-all");
  const reconcileOnly = flag("usage_reconcile", "--reconcile");
  const listOnly = flag("usage_list", "--list");
  const listFormat = parseListFormat(env("usage_format"));
  const shouldOpen = flag("usage_open", "--open");
  const shouldRefresh = flag("usage_refresh", "--refresh");
  const host = env("usage_host") ?? "localhost";
  const portRaw = env("usage_port");
  const requestedPort = portRaw ? parsePort(portRaw) : undefined;

  const existing = await loadInstances();
  const liveInstances = await reconcilePreviewInstances(root, existing, {
    quiet: listOnly,
  });
  await saveInstances(liveInstances);

  if (killAll) {
    await stopAllPreviewServers(liveInstances);
    return;
  }

  if (reconcileOnly) {
    console.log(`[md:preview] reconciled ${liveInstances.length} active preview server(s)`);
    return;
  }

  if (listOnly) {
    const servers = buildPreviewServerList(liveInstances);
    if (servers.length === 0) {
      console.log(NO_RUNNING_PREVIEWS_MESSAGE);
      return;
    }
    if (listFormat === "markdown") {
      console.log(servers.map((server) => `- [${server.docTitle}](${server.browserUrl})`).join("\n"));
      return;
    }
    console.log(JSON.stringify(servers, null, 2));
    return;
  }

  const fileArg = env("usage_file") ?? firstPositionalArg();
  const directory = env("usage_dir") ?? ".";
  const filePath = fileArg ? resolve(fileArg) : await pickMarkdownFile(root, directory);
  if (!filePath) {
    console.error("[md:preview] no markdown file selected.");
    process.exit(2);
  }
  if (!(await Bun.file(filePath).exists())) {
    console.error(`[md:preview] file does not exist: ${filePath}`);
    process.exit(2);
  }

  const existingInstance = liveInstances.find((instance) => instance.file === filePath);
  if (existingInstance) {
    const url = `http://${existingInstance.host}:${existingInstance.port}/`;
    console.log(`[md:preview] already running for ${relativeToCwd(filePath)} at ${url} (PID ${existingInstance.pid})`);

    if (shouldRefresh) {
      const refreshResult = await refreshExistingChromeTabs(url);
      if (refreshResult.status === "refreshed") {
        console.log(`[md:preview] refreshed ${refreshResult.count} Chrome tab(s) for ${url}`);
      } else if (refreshResult.status === "not_found") {
        console.log(`[md:preview] no open Chrome tabs found for ${url}`);
      } else if (refreshResult.status === "not_running") {
        console.log("[md:preview] Google Chrome is not running");
      } else if (refreshResult.status === "unsupported") {
        console.log(`[md:preview] Chrome tab refresh is unsupported on ${process.platform}`);
      } else if (refreshResult.detail) {
        console.error(`[md:preview] ${refreshResult.detail}`);
      }
    }

    if (shouldOpen) {
      const focusResult = await focusExistingChromeTab(url);
      if (focusResult.status === "focused") {
        console.log(`[md:preview] focused existing Chrome tab for ${url}`);
        return;
      }

      if (focusResult.status === "error" && focusResult.detail) {
        console.error(`[md:preview] ${focusResult.detail}`);
      }

      try {
        await openInDefaultBrowser(url);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[md:preview] ${message}`);
      }
    }

    return;
  }

  const port = await choosePort(filePath, liveInstances, requestedPort);
  const started = await startPreviewServer(filePath, host, port);
  const url = `http://${host}:${port}/`;

  liveInstances.push({
    file: filePath,
    host,
    port,
    pid: started.listenerPid,
    launcherPid: started.launcherPid,
    startedAt: new Date().toISOString(),
  });
  await saveInstances(liveInstances);

  console.log(`[md:preview] previewing ${relativeToCwd(filePath)} at ${url} (PID ${started.listenerPid})`);
  console.log("[md:preview] stop all preview servers with: mise run md:preview -- --kill-all");

  if (shouldRefresh) {
    const refreshResult = await refreshExistingChromeTabs(url);
    if (refreshResult.status === "refreshed") {
      console.log(`[md:preview] refreshed ${refreshResult.count} Chrome tab(s) for ${url}`);
    } else if (refreshResult.status === "not_found") {
      console.log(`[md:preview] no open Chrome tabs found for ${url}`);
    } else if (refreshResult.status === "not_running") {
      console.log("[md:preview] Google Chrome is not running");
    } else if (refreshResult.status === "unsupported") {
      console.log(`[md:preview] Chrome tab refresh is unsupported on ${process.platform}`);
    } else if (refreshResult.detail) {
      console.error(`[md:preview] ${refreshResult.detail}`);
    }
  }

  if (shouldOpen) {
    try {
      await openInDefaultBrowser(url);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[md:preview] ${message}`);
    }
  }
}

await main().catch((error) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`[md:preview] ${message}`);
  process.exit(1);
});
