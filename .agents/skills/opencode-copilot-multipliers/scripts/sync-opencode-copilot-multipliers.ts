#!/usr/bin/env bun

import { join } from "node:path";

const DEFAULT_URL = "https://raw.githubusercontent.com/github/docs/main/data/tables/copilot/model-multipliers.yml";
const OPENCODE_CONFIG_FILE = "opencode.jsonc";

type MultiplierRow = {
  name?: unknown;
  multiplier_paid?: unknown;
};

type CopilotConfig = {
  provider?: {
    "github-copilot"?: {
      models?: Record<string, { name?: string } & Record<string, unknown>>;
    };
  };
} & Record<string, unknown>;

type SourceModel = {
  displayName: string;
  normalizedName: string;
  id: string;
  paid: string;
};

const normalize = (value: string): string => {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
};

const stripSuffix = (value: string): string => {
  return value.replace(/\s*\[[^\]]*\]\s*$/, "").trim();
};

const toModelId = (value: string): string => {
  return value
    .toLowerCase()
    .replace(/["']/g, "")
    .replace(/[^a-z0-9.]+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
};

const paidLabel = (value: unknown): string | null => {
  if (typeof value === "number") {
    return `${String(value).replace(/\.0+$/, "")}x`;
  }

  if (typeof value === "string") {
    const maybeNumber = Number(value);
    if (!Number.isNaN(maybeNumber)) {
      return `${String(maybeNumber).replace(/\.0+$/, "")}x`;
    }
    return null;
  }

  return null;
};

const toSourceModels = (rawRows: unknown): SourceModel[] => {
  if (!Array.isArray(rawRows)) {
    throw new Error("Invalid multiplier payload: expected YAML list");
  }

  const sourceModels: SourceModel[] = [];

  for (const rawRow of rawRows) {
    if (!rawRow || typeof rawRow !== "object") continue;
    const row = rawRow as MultiplierRow;

    if (typeof row.name !== "string") continue;
    const displayName = row.name.trim();
    if (displayName.length === 0) continue;

    const label = paidLabel(row.multiplier_paid);
    if (!label) continue;

    const id = toModelId(displayName);
    if (id.length === 0) continue;

    sourceModels.push({
      displayName,
      normalizedName: normalize(displayName),
      id,
      paid: label,
    });
  }

  if (sourceModels.length === 0) {
    throw new Error("No paid model multipliers parsed from source");
  }

  return sourceModels;
};

const getConfigPath = (): string => {
  const xdgConfigHome = Bun.env.XDG_CONFIG_HOME?.trim();
  if (!xdgConfigHome) {
    throw new Error("XDG_CONFIG_HOME environment variable is required");
  }

  return join(xdgConfigHome, "opencode", OPENCODE_CONFIG_FILE);
};

const parseConfig = (source: string): CopilotConfig => {
  try {
    const parsed = Bun.JSONC.parse(source);
    if (!parsed || typeof parsed !== "object") {
      throw new Error("root is not an object");
    }
    return parsed as CopilotConfig;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSONC config: ${message}`);
  }
};

const formatOutput = (value: CopilotConfig): string => {
  return `${JSON.stringify(value, null, 2)}\n`;
};

const main = async () => {
  if (process.argv.length > 2) {
    throw new Error("This script does not accept arguments");
  }

  const configPath = getConfigPath();
  const configFile = Bun.file(configPath);

  if (!(await configFile.exists())) {
    throw new Error(`Config file not found: ${configPath}`);
  }

  const [multiplierResponse, rawConfigText] = await Promise.all([fetch(DEFAULT_URL), configFile.text()]);

  if (!multiplierResponse.ok) {
    throw new Error(`Failed to fetch multipliers (${multiplierResponse.status} ${multiplierResponse.statusText})`);
  }

  const yamlText = await multiplierResponse.text();
  const multiplierRows = Bun.YAML.parse(yamlText);
  const sourceModels = toSourceModels(multiplierRows);
  const sourceByNormalized = new Map<string, SourceModel>();
  const sourceById = new Map<string, SourceModel>();

  for (const sourceModel of sourceModels) {
    if (!sourceByNormalized.has(sourceModel.normalizedName)) {
      sourceByNormalized.set(sourceModel.normalizedName, sourceModel);
    }
    if (!sourceById.has(sourceModel.id)) {
      sourceById.set(sourceModel.id, sourceModel);
    }
  }

  const config = parseConfig(rawConfigText);
  const models = config.provider?.["github-copilot"]?.models;

  if (!models || typeof models !== "object") {
    throw new Error("Missing provider.github-copilot.models in config");
  }

  const entries = Object.entries(models);
  const changes: Array<{ id: string; before: string; after: string }> = [];
  const additions: Array<{ id: string; after: string }> = [];
  const removals: Array<{ id: string; current: string }> = [];
  const matchedNormalizedNames = new Set<string>();

  for (const [id, model] of entries) {
    if (!model || typeof model !== "object") continue;

    const currentName = typeof model.name === "string" ? model.name : "";
    const baseName = stripSuffix(currentName);
    const sourceModel = sourceByNormalized.get(normalize(baseName)) ?? sourceById.get(id);

    if (!sourceModel) {
      removals.push({ id, current: currentName });
      continue;
    }

    matchedNormalizedNames.add(sourceModel.normalizedName);

    const nextName = `${baseName} [${sourceModel.paid}]`;
    if (nextName !== currentName) {
      changes.push({ id, before: currentName, after: nextName });
    }
  }

  const seenAddedIds = new Set<string>();
  for (const sourceModel of sourceModels) {
    if (matchedNormalizedNames.has(sourceModel.normalizedName)) continue;
    if (Object.hasOwn(models, sourceModel.id)) continue;
    if (seenAddedIds.has(sourceModel.id)) continue;

    seenAddedIds.add(sourceModel.id);
    additions.push({
      id: sourceModel.id,
      after: `${sourceModel.displayName} [${sourceModel.paid}]`,
    });
  }

  console.log(`Config: ${configPath}`);
  console.log(`Source: ${DEFAULT_URL}`);
  console.log(
    `Models: total=${entries.length} matched=${entries.length - removals.length} changed=${changes.length} added=${additions.length} removed=${removals.length}`,
  );

  const tableRows = [
    ...changes.map((change) => ({
      action: "update",
      id: change.id,
      before: change.before,
      after: change.after,
    })),
    ...additions.map((addition) => ({
      action: "add",
      id: addition.id,
      before: "(missing override)",
      after: addition.after,
    })),
    ...removals.map((removal) => ({
      action: "remove",
      id: removal.id,
      before: removal.current,
      after: "(provider default)",
    })),
  ].sort((a, b) => {
    const order: Record<string, number> = { update: 0, add: 1, remove: 2 };
    const actionOrder = order[a.action] - order[b.action];
    if (actionOrder !== 0) return actionOrder;
    return a.id.localeCompare(b.id);
  });

  if (tableRows.length > 0) {
    console.log("\nPlanned changes:");
    console.table(tableRows);
  } else {
    console.log("\nNo planned changes.");
  }

  if (tableRows.length === 0) {
    return;
  }

  for (const change of changes) {
    const model = models[change.id];
    if (!model || typeof model !== "object") continue;
    model.name = change.after;
  }

  for (const item of removals) {
    delete models[item.id];
  }

  for (const item of additions) {
    models[item.id] = { name: item.after };
  }

  await Bun.write(configFile, formatOutput(config));
  console.log("\nApplied changes.");
};

await main();
