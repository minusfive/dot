#!/usr/bin/env bun
//MISE description="Validate skill evaluation specs and repository-local workspaces"
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE flag "--base-path <path>" help="Directory to validate; defaults to the current project root"
//USAGE flag "--skills-path <path>" help="Skill source directory; defaults to .agents/skills"

import { readdirSync, lstatSync, readFileSync, realpathSync } from "node:fs";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { spawnSync } from "node:child_process";

type JsonValue = undefined | null | boolean | number | string | JsonValue[] | { [key: string]: JsonValue };
type JsonObject = { [key: string]: JsonValue };

type Context = {
  projectRoot: string;
  basePath: string;
  skillsPath: string;
  taskSourceDir: string;
  migrationSources: string[];
  migrationTargets: string[];
  legacyPreparationSkills: string[];
  primarySkillRoot: string;
  alternateSkillRoots: string[];
  workspaceSkillRoots: string[];
};

class ValidationError extends Error {}

function isMissingError(error: unknown): boolean {
  return (error as NodeJS.ErrnoException).code === "ENOENT";
}

function die(message: string): never {
  throw new ValidationError(message);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function pathExists(path: string): boolean {
  try {
    lstatSync(path);
    return true;
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function isSymlink(path: string): boolean {
  try {
    return lstatSync(path).isSymbolicLink();
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function isPhysicalDirectory(path: string): boolean {
  try {
    const stat = lstatSync(path);
    return stat.isDirectory() && !stat.isSymbolicLink();
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function isRegularFile(path: string): boolean {
  try {
    const stat = lstatSync(path);
    return stat.isFile() && !stat.isSymbolicLink();
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function isFollowedRegularFile(path: string): boolean {
  try {
    return lstatSync(realpathSync(path)).isFile();
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function isFollowedDirectory(path: string): boolean {
  try {
    return lstatSync(realpathSync(path)).isDirectory();
  } catch (error) {
    if (isMissingError(error)) return false;
    throw error;
  }
}

function entries(path: string): string[] {
  try {
    return readdirSync(path)
      .sort()
      .map((entry) => join(path, entry));
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") return [];
    throw error;
  }
}

function physicalDirectories(path: string): string[] {
  return entries(path).filter(isPhysicalDirectory);
}

function displayPath(path: string, basePath: string): string {
  const displayed = relative(basePath, path);
  return displayed === "" ? "." : displayed;
}

function readJson(path: string, context: Context): JsonValue {
  try {
    return JSON.parse(readFileSync(path, "utf8")) as JsonValue;
  } catch {
    die(`invalid JSON: ${displayPath(path, context.basePath)}`);
  }
}

function object(value: JsonValue): JsonObject | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? (value as JsonObject) : undefined;
}

function keys(value: JsonValue): string[] {
  const record = object(value);
  return record ? Object.keys(record).sort() : [];
}

function sameKeys(value: JsonValue, expected: string[]): boolean {
  const actual = keys(value);
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}

function isString(value: JsonValue): value is string {
  return typeof value === "string";
}

function isArray(value: JsonValue): value is JsonValue[] {
  return Array.isArray(value);
}

function isRecord(value: JsonValue): value is JsonObject {
  return object(value) !== undefined;
}

function isPositiveName(value: JsonValue): value is string {
  return isString(value) && /^[a-z][a-z0-9-]*$/.test(value);
}

function isStringArray(value: JsonValue, nonEmpty: boolean): value is string[] {
  return isArray(value) && (!nonEmpty || value.length > 0) && value.every((entry) => isString(entry));
}

function isAllowedStringArray(value: JsonValue, pattern: RegExp, nonEmpty: boolean): value is string[] {
  return (
    isArray(value) && (!nonEmpty || value.length > 0) && value.every((entry) => isString(entry) && pattern.test(entry))
  );
}

function unique(values: string[]): boolean {
  return new Set(values).size === values.length;
}

function valueAsString(value: JsonValue): string {
  if (value === null) return "null";
  if (typeof value === "string") return value;
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return String(value);
  return JSON.stringify(value);
}

function jsonEqual(left: JsonValue, right: JsonValue): boolean {
  if (left === right) return true;
  if (Array.isArray(left) && Array.isArray(right)) {
    return left.length === right.length && left.every((value, index) => jsonEqual(value, right[index]));
  }
  const leftObject = object(left);
  const rightObject = object(right);
  if (!leftObject || !rightObject) return false;
  const leftKeys = Object.keys(leftObject).sort();
  const rightKeys = Object.keys(rightObject).sort();
  return (
    leftKeys.length === rightKeys.length &&
    leftKeys.every((key, index) => key === rightKeys[index] && jsonEqual(leftObject[key], rightObject[key]))
  );
}

function jqAlternative(value: JsonValue | undefined, fallback: JsonValue): JsonValue {
  return value === undefined || value === null || value === false ? fallback : value;
}

function runGit(args: string[]): string {
  const result = spawnSync("git", args, { encoding: "utf8" });
  if (result.status !== 0) return "";
  return result.stdout.trim();
}

function resolveDirectory(pathValue: string, projectRoot: string, errorText: string): string {
  const candidate = isAbsolute(pathValue) ? pathValue : join(projectRoot, pathValue);
  try {
    return realpathSync(candidate);
  } catch {
    die(errorText);
  }
}

function findSkillRoots(basePath: string): string[] {
  const found: string[] = [];
  const visit = (directory: string): void => {
    if (!isPhysicalDirectory(directory)) return;
    if (basename(directory) === "skills" && basename(dirname(directory)) === ".agents") {
      found.push(directory);
    }
    for (const child of entries(directory)) {
      if (isPhysicalDirectory(child)) visit(child);
    }
  };
  visit(basePath);
  return found.sort();
}

function isMigrationSource(context: Context, name: string): boolean {
  return context.migrationSources.includes(name);
}

function isLegacyPreparationSkill(context: Context, name: string): boolean {
  return context.legacyPreparationSkills.includes(name);
}

function resolveWorkspaceSkill(context: Context, name: string): string {
  let resolved = name;
  while (true) {
    const index = context.migrationSources.indexOf(resolved);
    if (index < 0) return resolved;
    resolved = context.migrationTargets[index]!;
  }
}

function rejectDuplicateSkillNames(context: Context): void {
  for (let firstIndex = 0; firstIndex < context.workspaceSkillRoots.length; firstIndex += 1) {
    const firstRoot = context.workspaceSkillRoots[firstIndex]!;
    for (let secondIndex = firstIndex + 1; secondIndex < context.workspaceSkillRoots.length; secondIndex += 1) {
      const secondRoot = context.workspaceSkillRoots[secondIndex]!;
      for (const skillDir of physicalDirectories(firstRoot)) {
        const duplicateDir = join(secondRoot, basename(skillDir));
        if (!isPhysicalDirectory(duplicateDir)) continue;
        die(
          `duplicate skill name across skill roots: ${basename(skillDir)}; found in ` +
            `${displayPath(skillDir, context.basePath)} and ${displayPath(duplicateDir, context.basePath)}; ` +
            "remove one skill or rename one before validating evaluation specs",
        );
      }
    }
  }
}

function validateEvaluationSpec(context: Context, skillDir: string, skill: string, spec: string): JsonObject {
  const evalsDir = join(skillDir, "evals");
  if (!isPhysicalDirectory(evalsDir)) die(`${skill}/evals must be a physical directory`);
  if (!isRegularFile(spec)) die(`${skill}/evals/evals.json must be a regular local file`);

  const extra = entries(evalsDir).find((path) => basename(path) !== "evals.json");
  if (extra) die(`${skill}/evals may contain only evals.json`);

  const parsed = readJson(spec, context);
  const value = object(parsed);
  const evals = value?.evals;
  const valid =
    sameKeys(parsed, ["evals", "skill_name"]) &&
    value?.skill_name === skill &&
    isArray(evals) &&
    evals.length > 0 &&
    evals.every((entry) => {
      const evaluation = object(entry);
      if (!evaluation) return false;
      if (
        Object.keys(evaluation).some((key) => !["assertions", "expected_output", "files", "id", "prompt"].includes(key))
      ) {
        return false;
      }
      if (!isPositiveName(evaluation.id) || !isString(evaluation.prompt) || evaluation.prompt.length === 0)
        return false;
      if (!isString(evaluation.expected_output) || evaluation.expected_output.length === 0) return false;
      if (
        evaluation.assertions !== undefined &&
        evaluation.assertions !== null &&
        !isStringArray(evaluation.assertions, true)
      )
        return false;
      if (evaluation.files !== undefined && evaluation.files !== null && !isStringArray(evaluation.files, false))
        return false;
      return true;
    }) &&
    unique(evals.map((entry) => String(object(entry)?.id)));
  if (!valid) die(`invalid evaluation spec: ${displayPath(spec, context.basePath)}`);
  return value!;
}

function validateEvidenceFile(context: Context, workspaceRoot: string, referencedFile: string): void {
  const prefix = `${displayPath(workspaceRoot, context.basePath)}/${referencedFile}`;
  if (isAbsolute(referencedFile) || referencedFile.includes("\\")) {
    die(`evidence path must be relative: ${prefix}`);
  }
  if (
    referencedFile === "." ||
    referencedFile === ".." ||
    referencedFile.startsWith("./") ||
    referencedFile.includes("/./") ||
    referencedFile.endsWith("/.") ||
    referencedFile.startsWith("../") ||
    referencedFile.includes("/../") ||
    referencedFile.endsWith("/..")
  ) {
    die(`evidence path is not canonical: ${prefix}`);
  }
  let expectedRoot: string;
  let canonicalPath: string;
  try {
    expectedRoot = realpathSync(workspaceRoot);
  } catch {
    die(`could not resolve evidence workspace: ${displayPath(workspaceRoot, context.basePath)}`);
  }
  try {
    canonicalPath = realpathSync(join(workspaceRoot, referencedFile));
  } catch {
    die(`could not resolve evidence path: ${prefix}`);
  }
  if (canonicalPath !== expectedRoot && !canonicalPath.startsWith(`${expectedRoot}${sep}`)) {
    die(`evidence path escapes its workspace: ${prefix}`);
  }
  if (!isRegularFile(canonicalPath)) {
    die(`materialized report references a missing or symlinked evidence file: ${prefix}`);
  }
}

function validateMaterializedMetadata(
  context: Context,
  configurationDir: string,
  skill: string,
  caseId: string,
  configuration: string,
): { timing: JsonObject; grading: JsonObject } {
  const timingPath = join(configurationDir, "timing.json");
  const gradingPath = join(configurationDir, "grading.json");
  const timingValue = readJson(timingPath, context);
  const gradingValue = readJson(gradingPath, context);
  const timing = object(timingValue);
  const grading = object(gradingValue);
  const runId = timing?.run_id;
  const validTiming =
    sameKeys(timingValue, [
      "case_id",
      "configuration",
      "duration_ms",
      "ended_at",
      "evidence_files",
      "harness_identity",
      "output_files",
      "redaction_status",
      "result",
      "run_id",
      "skill_identity",
      "spec_id",
      "started_at",
      "status",
      "total_tokens",
    ]) &&
    timing?.case_id === caseId &&
    timing?.configuration === configuration &&
    isString(runId) &&
    /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(runId) &&
    timing?.spec_id === `${skill}/evals/evals.json` &&
    timing?.skill_identity === skill &&
    isString(timing?.harness_identity) &&
    timing.harness_identity.length > 0 &&
    timing.harness_identity.length <= 192 &&
    ["completed", "failed", "cancelled", "blocked"].includes(String(timing?.status)) &&
    ["passed", "failed", "cancelled", "blocked"].includes(String(timing?.result)) &&
    isString(timing?.started_at) &&
    timing.started_at.length >= 20 &&
    timing.started_at.length <= 64 &&
    isString(timing?.ended_at) &&
    timing.ended_at.length >= 20 &&
    timing.ended_at.length <= 64 &&
    typeof timing?.duration_ms === "number" &&
    Number.isInteger(timing.duration_ms) &&
    timing.duration_ms >= 0 &&
    typeof timing?.total_tokens === "number" &&
    Number.isInteger(timing.total_tokens) &&
    timing.total_tokens >= 0 &&
    ["clean", "redacted"].includes(String(timing?.redaction_status)) &&
    isAllowedStringArray(timing?.output_files, /^[A-Za-z0-9._/-]+$/, true) &&
    isAllowedStringArray(timing?.evidence_files, /^[A-Za-z0-9._/-]+$/, false);
  if (!validTiming) die(`invalid materialized timing report: ${displayPath(timingPath, context.basePath)}`);

  const validGrading =
    sameKeys(gradingValue, [
      "assertion_results",
      "case_id",
      "configuration",
      "redaction_status",
      "result",
      "run_id",
      "status",
    ]) &&
    grading?.case_id === caseId &&
    grading?.configuration === configuration &&
    isString(grading?.run_id) &&
    grading.run_id.length > 0 &&
    grading.run_id.length <= 128 &&
    ["completed", "failed", "cancelled", "blocked"].includes(String(grading?.status)) &&
    ["passed", "failed", "cancelled", "blocked"].includes(String(grading?.result)) &&
    ["clean", "redacted"].includes(String(grading?.redaction_status)) &&
    isArray(grading?.assertion_results) &&
    grading.assertion_results.every((entry) => {
      const assertion = object(entry);
      return (
        sameKeys(entry, ["evidence", "id", "status"]) &&
        isString(assertion?.id) &&
        /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(assertion.id) &&
        ["passed", "failed", "blocked"].includes(String(assertion?.status)) &&
        isAllowedStringArray(assertion?.evidence, /^[A-Za-z0-9._/-]+$/, true)
      );
    });
  if (!validGrading) die(`invalid materialized grading report: ${displayPath(gradingPath, context.basePath)}`);
  if (timing.run_id !== grading?.run_id) {
    die(`materialized timing and grading run IDs do not match: ${displayPath(configurationDir, context.basePath)}`);
  }
  return { timing, grading: grading! };
}

function validateMaterializedConfig(
  context: Context,
  configurationDir: string,
  skill: string,
  caseId: string,
  configuration: string,
): void {
  const { timing, grading } = validateMaterializedMetadata(context, configurationDir, skill, caseId, configuration);
  for (const referencedFile of [...(timing.output_files as string[]), ...(timing.evidence_files as string[])]) {
    validateEvidenceFile(context, configurationDir, referencedFile);
  }
  for (const assertion of grading.assertion_results as JsonValue[]) {
    for (const referencedFile of object(assertion)?.evidence as string[]) {
      validateEvidenceFile(context, configurationDir, referencedFile);
    }
  }
}

function retiredConfigIsIncomplete(context: Context, configurationDir: string): boolean {
  const outputDir = join(configurationDir, "outputs");
  const evidenceDir = join(configurationDir, "evidence");
  let incomplete = false;
  if (pathExists(outputDir)) {
    if (!isPhysicalDirectory(outputDir)) {
      die(`retired historical output directory is not physical: ${displayPath(outputDir, context.basePath)}`);
    }
    const timing = object(readJson(join(configurationDir, "timing.json"), context))!;
    for (const referencedFile of timing.output_files as string[]) {
      validateEvidenceFile(context, configurationDir, referencedFile);
    }
  } else {
    incomplete = true;
  }
  if (pathExists(evidenceDir)) {
    if (!isPhysicalDirectory(evidenceDir)) {
      die(`retired historical evidence directory is not physical: ${displayPath(evidenceDir, context.basePath)}`);
    }
    const timing = object(readJson(join(configurationDir, "timing.json"), context))!;
    const grading = object(readJson(join(configurationDir, "grading.json"), context))!;
    for (const referencedFile of timing.evidence_files as string[]) {
      validateEvidenceFile(context, configurationDir, referencedFile);
    }
    for (const assertion of grading.assertion_results as JsonValue[]) {
      for (const referencedFile of object(assertion)?.evidence as string[]) {
        validateEvidenceFile(context, configurationDir, referencedFile);
      }
    }
  } else {
    incomplete = true;
  }
  return incomplete;
}

function validateRetiredHistoricalIteration(
  context: Context,
  iterationDir: string,
  manifestIds: string[],
  skill: string,
  iteration: string,
): void {
  let completeMaterialized = true;
  for (const caseName of manifestIds) {
    const caseEntry = join(iterationDir, caseName);
    if (!isPhysicalDirectory(caseEntry)) {
      die(`missing retired historical evaluation case directory: ${displayPath(caseEntry, context.basePath)}`);
    }
    for (const configuration of ["with_skill", "old_skill"]) {
      const configurationDir = join(caseEntry, configuration);
      if (!isPhysicalDirectory(configurationDir)) {
        die(`missing retired historical evaluation configuration: ${displayPath(configurationDir, context.basePath)}`);
      }
      for (const extra of ["timing.json", "grading.json"]) {
        const path = join(configurationDir, extra);
        if (!isRegularFile(path)) die(`missing retired historical metadata: ${displayPath(path, context.basePath)}`);
        readJson(path, context);
      }
      validateMaterializedMetadata(context, configurationDir, skill, caseName, configuration);
      if (retiredConfigIsIncomplete(context, configurationDir)) completeMaterialized = false;
    }
  }
  if (completeMaterialized) {
    die(
      `retired historical evaluation iteration is complete; remove the retired marker: ${displayPath(iterationDir, context.basePath)}`,
    );
  }
}

function validateMaterializedReports(context: Context, iterationDir: string, skill: string, iteration: string): void {
  for (const report of ["benchmark.json", "feedback.json", "grading-summary.json"]) {
    const reportPath = join(iterationDir, report);
    const value = readJson(reportPath, context);
    const reportValue = object(value);
    const provenance = object(reportValue?.provenance);
    const run = object(reportValue?.run);
    const valid =
      reportValue?.skill_name === skill &&
      valueAsString(reportValue?.iteration) === iteration &&
      sameKeys(reportValue?.provenance ?? null, ["harness_identity", "skill_identity", "spec_id"]) &&
      provenance?.spec_id === `${skill}/evals/evals.json` &&
      provenance?.skill_identity === skill &&
      isString(provenance?.harness_identity) &&
      provenance.harness_identity.length > 0 &&
      provenance.harness_identity.length <= 192 &&
      sameKeys(reportValue?.run ?? null, [
        "duration_ms",
        "ended_at",
        "evidence_files",
        "output_files",
        "redaction_status",
        "result",
        "run_id",
        "started_at",
        "status",
      ]) &&
      isString(run?.run_id) &&
      /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/.test(run.run_id) &&
      ["completed", "failed", "cancelled", "blocked"].includes(String(run?.status)) &&
      ["passed", "failed", "cancelled", "blocked"].includes(String(run?.result)) &&
      isString(run?.started_at) &&
      run.started_at.length >= 20 &&
      run.started_at.length <= 64 &&
      isString(run?.ended_at) &&
      run.ended_at.length >= 20 &&
      run.ended_at.length <= 64 &&
      typeof run?.duration_ms === "number" &&
      Number.isInteger(run.duration_ms) &&
      run.duration_ms >= 0 &&
      ["clean", "redacted"].includes(String(run?.redaction_status)) &&
      isAllowedStringArray(run?.output_files, /^[A-Za-z0-9._/-]+$/, true) &&
      isAllowedStringArray(run?.evidence_files, /^[A-Za-z0-9._/-]+$/, false);
    if (!valid) die(`invalid materialized report: ${displayPath(reportPath, context.basePath)}`);
    for (const referencedFile of [...(run!.output_files as string[]), ...(run!.evidence_files as string[])]) {
      validateEvidenceFile(context, iterationDir, referencedFile);
    }
  }
}

function validatePreparationReports(context: Context, iterationDir: string, skill: string, iteration: string): void {
  const benchmarkPath = join(iterationDir, "benchmark.json");
  const benchmark = object(readJson(benchmarkPath, context));
  if (
    !sameKeys(benchmark, ["delta", "iteration", "run_summary", "skill_name"]) ||
    benchmark?.skill_name !== skill ||
    valueAsString(benchmark?.iteration) !== iteration ||
    !jsonEqual(benchmark?.run_summary, {}) ||
    !jsonEqual(benchmark?.delta, {})
  ) {
    die(`preparation benchmark contains fabricated execution data: ${displayPath(benchmarkPath, context.basePath)}`);
  }

  const feedbackPath = join(iterationDir, "feedback.json");
  const feedback = object(readJson(feedbackPath, context));
  if (
    !sameKeys(feedback, ["human_review", "iteration", "limitations", "recommendation", "skill_name"]) ||
    feedback?.skill_name !== skill ||
    valueAsString(feedback?.iteration) !== iteration ||
    !jsonEqual(feedback?.human_review, []) ||
    !jsonEqual(feedback?.limitations, []) ||
    feedback?.recommendation !== "hold"
  ) {
    die(`preparation feedback contains fabricated execution data: ${displayPath(feedbackPath, context.basePath)}`);
  }

  const gradingPath = join(iterationDir, "grading-summary.json");
  const grading = object(readJson(gradingPath, context));
  if (
    !sameKeys(grading, ["cases", "iteration", "skill_name"]) ||
    grading?.skill_name !== skill ||
    valueAsString(grading?.iteration) !== iteration ||
    !jsonEqual(grading?.cases, {})
  ) {
    die(
      `preparation grading summary contains fabricated execution data: ${displayPath(gradingPath, context.basePath)}`,
    );
  }
}

function validatePreparationConfig(context: Context, configurationDir: string): void {
  const timingPath = join(configurationDir, "timing.json");
  const timing = object(readJson(timingPath, context));
  if (
    !sameKeys(timing, ["duration_ms", "total_tokens"]) ||
    timing?.duration_ms !== null ||
    timing?.total_tokens !== null
  ) {
    die(`preparation timing report contains fabricated execution data: ${displayPath(timingPath, context.basePath)}`);
  }
  const gradingPath = join(configurationDir, "grading.json");
  const grading = object(readJson(gradingPath, context));
  if (
    !sameKeys(grading, ["assertion_results", "summary"]) ||
    !jsonEqual(grading?.assertion_results, []) ||
    !jsonEqual(grading?.summary, { passed: 0, failed: 0, total: 0, pass_rate: 0 })
  ) {
    die(`preparation grading report contains fabricated execution data: ${displayPath(gradingPath, context.basePath)}`);
  }
}

function isLegacyPreparationSummary(context: Context, iterationDir: string): boolean {
  const benchmark = object(readJson(join(iterationDir, "benchmark.json"), context));
  const benchmarkKeys = [
    ["delta", "iteration", "run_summary", "skill_name"],
    ["delta", "iteration", "run_summary", "skill_name", "version"],
    ["calculation_note", "delta", "iteration", "run_summary", "runs_per_case", "skill_name", "version"],
    ["calculation_note", "iteration", "metrics", "runs_per_case", "skill_name", "version"],
  ];
  if (
    !benchmarkKeys.some((expected) => sameKeys(benchmark, expected)) ||
    (benchmark?.version !== undefined && benchmark.version !== 1) ||
    typeof benchmark?.iteration !== "number" ||
    !Number.isInteger(benchmark.iteration) ||
    benchmark.iteration <= 0 ||
    !isString(benchmark?.skill_name) ||
    benchmark.skill_name.length === 0 ||
    !isRecord(jqAlternative(benchmark?.run_summary, benchmark?.metrics ?? null)) ||
    !isRecord(jqAlternative(benchmark?.delta, {}))
  )
    return false;

  const feedback = object(readJson(join(iterationDir, "feedback.json"), context));
  const feedbackKeys = [
    ["human_review", "iteration", "limitations", "recommendation", "skill_name"],
    ["iteration", "skill_name", "summary", "telemetry", "version", "workspace"],
    ["iteration", "skill_name", "summary", "telemetry", "version"],
    ["human_review", "iteration", "recommendation", "skill_name", "version"],
  ];
  if (
    !feedbackKeys.some((expected) => sameKeys(feedback, expected)) ||
    (feedback?.version !== undefined && feedback.version !== 1) ||
    typeof feedback?.iteration !== "number" ||
    !Number.isInteger(feedback.iteration) ||
    feedback.iteration <= 0 ||
    !isString(feedback?.skill_name) ||
    feedback.skill_name.length === 0
  )
    return false;

  const grading = object(readJson(join(iterationDir, "grading-summary.json"), context));
  const gradingKeys = [
    ["cases", "iteration", "skill_name"],
    ["cases", "iteration", "skill_name", "summary", "version"],
    ["calculation_note", "cases", "delta", "iteration", "run_summary", "skill_name", "version"],
    ["cases", "iteration", "runs_per_case", "skill_name", "version"],
    ["cases", "evidence_note", "iteration", "runs_per_case", "skill_name", "version"],
  ];
  return (
    gradingKeys.some((expected) => sameKeys(grading, expected)) &&
    (grading?.version === undefined || grading.version === 1) &&
    typeof grading?.iteration === "number" &&
    Number.isInteger(grading.iteration) &&
    grading.iteration > 0 &&
    isString(grading?.skill_name) &&
    grading.skill_name.length > 0 &&
    isRecord(grading?.cases as JsonValue)
  );
}

function assertNoWorkspaceSymlinks(path: string): void {
  for (const child of entries(path)) {
    if (isSymlink(child)) die(`evaluation workspaces must not contain symlinks`);
    if (isPhysicalDirectory(child)) assertNoWorkspaceSymlinks(child);
  }
}

function findLegacyArtifact(root: string, predicate: (path: string) => boolean): string | undefined {
  for (const child of entries(root)) {
    if (predicate(child)) return child;
    if (isPhysicalDirectory(child)) {
      const found = findLegacyArtifact(child, predicate);
      if (found) return found;
    }
  }
  return undefined;
}

function loadMigration(context: Context, migrationMap: string): void {
  if (!pathExists(migrationMap)) return;
  if (!isRegularFile(migrationMap)) {
    die(`historical skill migration map must be a regular local file: ${displayPath(migrationMap, context.basePath)}`);
  }
  const parsed = readJson(migrationMap, context);
  const value = object(parsed);
  const validTopLevel =
    (sameKeys(parsed, ["renames", "version"]) || sameKeys(parsed, ["legacy_preparation", "renames", "version"])) &&
    value?.version === 1 &&
    isArray(value?.renames) &&
    value.renames.every((entry) => {
      const rename = object(entry);
      return (
        sameKeys(entry, ["from", "to"]) &&
        isPositiveName(rename?.from) &&
        isPositiveName(rename?.to) &&
        rename.from !== rename.to
      );
    }) &&
    unique(value.renames.map((entry) => String(object(entry)?.from))) &&
    unique(value.renames.map((entry) => String(object(entry)?.to)));
  if (!validTopLevel) die(`invalid historical skill migration map: ${displayPath(migrationMap, context.basePath)}`);

  const legacy = value.legacy_preparation;
  if (legacy !== undefined) {
    const legacyValue = object(legacy);
    if (
      !sameKeys(legacy, ["skills", "version"]) ||
      legacyValue?.version !== 1 ||
      !isStringArray(legacyValue?.skills, true) ||
      !legacyValue.skills.every((skill) => /^[a-z][a-z0-9-]*$/.test(skill)) ||
      !unique(legacyValue.skills)
    ) {
      die(`invalid historical skill migration map: ${displayPath(migrationMap, context.basePath)}`);
    }
    context.legacyPreparationSkills = legacyValue.skills;
  }
  const renames = value.renames as JsonValue[];
  context.migrationSources = renames.map((entry) => String(object(entry)?.from));
  context.migrationTargets = renames.map((entry) => String(object(entry)?.to));

  for (const source of context.migrationSources) {
    const visited = new Set<string>();
    let resolved = source;
    while (true) {
      if (visited.has(resolved)) die(`historical skill migration map contains a cycle at: ${resolved}`);
      visited.add(resolved);
      const index = context.migrationSources.indexOf(resolved);
      if (index < 0) break;
      resolved = context.migrationTargets[index]!;
    }
  }
}

function main(): void {
  const projectRoot = runGit(["rev-parse", "--show-toplevel"]);
  if (!projectRoot) die("this task must be run inside a git repository");

  const usageBasePath = process.env.usage_base_path ?? "";
  const usageSkillsPath = process.env.usage_skills_path ?? "";
  const basePath = resolveDirectory(
    usageBasePath || projectRoot,
    projectRoot,
    `base path '${usageBasePath || "."}' does not exist`,
  );
  const skillsPath = resolveDirectory(
    isAbsolute(usageSkillsPath) ? usageSkillsPath : join(basePath, usageSkillsPath || ".agents/skills"),
    projectRoot,
    `skills path '${usageSkillsPath || ".agents/skills"}' does not exist`,
  );
  const context: Context = {
    projectRoot,
    basePath,
    skillsPath,
    taskSourceDir: import.meta.dir,
    migrationSources: [],
    migrationTargets: [],
    legacyPreparationSkills: [],
    primarySkillRoot: skillsPath,
    alternateSkillRoots: [],
    workspaceSkillRoots: [skillsPath],
  };

  for (const root of findSkillRoots(basePath)) {
    if (!context.workspaceSkillRoots.includes(root)) {
      context.workspaceSkillRoots.push(root);
      context.alternateSkillRoots.push(root);
    }
  }
  rejectDuplicateSkillNames(context);

  const sourceMigrationMap = join(context.taskSourceDir, "migration-map.json");
  const externalMigrationMap = join(basePath, "home/.config/mise/tasks/ai/skills/evals/migration-map.json");
  let migrationMap = "";
  if (basePath === projectRoot || basePath === join(projectRoot, "home")) {
    migrationMap = sourceMigrationMap;
  } else if (pathExists(externalMigrationMap)) {
    migrationMap = externalMigrationMap;
  }
  if (migrationMap) loadMigration(context, migrationMap);

  for (const source of context.migrationSources) {
    const resolved = resolveWorkspaceSkill(context, source);
    const activeExists = context.workspaceSkillRoots.some((root) =>
      isRegularFile(join(root, resolved, "evals/evals.json")),
    );
    if (!activeExists) die(`historical skill migration target has no active evaluation spec: ${resolved}`);
  }

  for (const skillDir of physicalDirectories(context.primarySkillRoot)) {
    const skill = basename(skillDir);
    if (isMigrationSource(context, skill)) die(`active skill uses historical name: ${skill}`);
    const evalsDir = join(skillDir, "evals");
    if (!isFollowedDirectory(evalsDir)) continue;
    validateEvaluationSpec(context, skillDir, skill, join(evalsDir, "evals.json"));
  }

  if (context.workspaceSkillRoots.length === 0) {
    die("skills path does not contain a skill root");
  }

  const activeSkills = new Set<string>();
  for (const skillRoot of context.workspaceSkillRoots) {
    for (const skillDir of physicalDirectories(skillRoot)) {
      const skill = basename(skillDir);
      if (isMigrationSource(context, skill)) die(`active skill uses historical name: ${skill}`);
      if (isFollowedRegularFile(join(skillDir, "evals/evals.json"))) activeSkills.add(skill);
    }
  }

  for (const migrationSource of context.migrationSources) {
    const resolved = resolveWorkspaceSkill(context, migrationSource);
    if (!activeSkills.has(resolved)) {
      die(`historical skill migration target has no active evaluation spec: ${resolved}`);
    }
  }

  const workspaceDir = join(basePath, ".agents/eval-workspaces");
  if (!pathExists(workspaceDir)) {
    console.log("Skill evaluation specs are valid. No repository-local workspaces found.");
    return;
  }
  if (!isPhysicalDirectory(workspaceDir)) {
    die(`evaluation workspace root must be a physical directory: ${displayPath(workspaceDir, basePath)}`);
  }
  assertNoWorkspaceSymlinks(workspaceDir);
  const legacyTiming = findLegacyArtifact(
    workspaceDir,
    (path) => isRegularFile(path) && basename(dirname(path)) === "outputs" && /^timing-.*\.json$/.test(basename(path)),
  );
  if (legacyTiming)
    die(`legacy timing artifact must be replaced by timing.json: ${displayPath(legacyTiming, basePath)}`);
  const legacyConfig = findLegacyArtifact(
    workspaceDir,
    (path) => isPhysicalDirectory(path) && ["with_change", "old_version"].includes(basename(path)),
  );
  if (legacyConfig) die(`legacy evaluation configuration directory: ${displayPath(legacyConfig, basePath)}`);

  for (const workspaceSkill of physicalDirectories(workspaceDir)) {
    const workspaceSkillName = basename(workspaceSkill);
    const resolvedSkill = resolveWorkspaceSkill(context, workspaceSkillName);
    const historicalWorkspace = isMigrationSource(context, workspaceSkillName);
    let primarySpec = "";
    let alternateSpec = "";
    let matchedWorkspaceSkill = false;
    for (const skillRoot of [context.primarySkillRoot, ...context.alternateSkillRoots]) {
      const candidate = join(skillRoot, resolvedSkill, "evals/evals.json");
      if (!pathExists(candidate)) continue;
      matchedWorkspaceSkill = true;
      validateEvaluationSpec(context, join(skillRoot, resolvedSkill), resolvedSkill, candidate);
      if (skillRoot === context.primarySkillRoot) primarySpec = candidate;
      else if (!alternateSpec) alternateSpec = candidate;
    }
    if (!matchedWorkspaceSkill) {
      die(`workspace has no matching skill spec; historical skill migration map is required: ${workspaceSkillName}`);
    }
    const spec = primarySpec || alternateSpec;
    if (!spec) die(`workspace has no selectable skill spec: ${workspaceSkillName}`);
    const specValue = validateEvaluationSpec(context, dirname(dirname(spec)), resolvedSkill, spec);
    const expectedIds = (specValue.evals as JsonValue[]).map((entry) => String(object(entry)?.id));

    for (const workspaceEntry of entries(workspaceSkill)) {
      const entryName = basename(workspaceEntry);
      if (!isPhysicalDirectory(workspaceEntry))
        die(`invalid evaluation workspace entry: ${displayPath(workspaceEntry, basePath)}`);
      if (entryName === "discoverability") {
        for (const extra of ["queries.json", "results.json"]) {
          const path = join(workspaceEntry, extra);
          if (!isRegularFile(path)) die(`missing ${displayPath(path, basePath)}`);
          readJson(path, context);
        }
        for (const extra of entries(workspaceEntry)) {
          if (!["queries.json", "results.json"].includes(basename(extra))) {
            die(`invalid discoverability entry: ${displayPath(extra, basePath)}`);
          }
        }
      } else if (!entryName.startsWith("iteration-")) {
        die(`invalid evaluation workspace entry: ${displayPath(workspaceEntry, basePath)}`);
      }
    }

    let currentIteration = 0;
    for (const workspaceEntry of entries(workspaceSkill)) {
      const caseName = basename(workspaceEntry);
      if (!caseName.startsWith("iteration-")) continue;
      if (!isPhysicalDirectory(workspaceEntry))
        die(`invalid workspace directory: ${displayPath(workspaceSkill, basePath)}/${caseName}`);
      if (!/^iteration-[1-9][0-9]*$/.test(caseName))
        die(`invalid workspace directory: ${displayPath(workspaceSkill, basePath)}/${caseName}`);
      const manifestPath = join(workspaceEntry, "manifest.json");
      if (!isRegularFile(manifestPath)) die(`missing ${displayPath(manifestPath, basePath)}`);
      const manifest = object(readJson(manifestPath, context));
      if (manifest?.state === "historical" && manifest.history_reason === "retired-materialized-incomplete") continue;
      currentIteration = Math.max(currentIteration, Number(caseName.slice("iteration-".length)));
    }

    for (const iterationDir of entries(workspaceSkill)) {
      if (!basename(iterationDir).startsWith("iteration-")) continue;
      const iterationName = basename(iterationDir);
      if (!isPhysicalDirectory(iterationDir))
        die(`invalid workspace directory: ${displayPath(workspaceSkill, basePath)}/${iterationName}`);
      if (!/^iteration-[1-9][0-9]*$/.test(iterationName))
        die(`invalid workspace directory: ${displayPath(workspaceSkill, basePath)}/${iterationName}`);
      const iterationNumber = iterationName.slice("iteration-".length);
      const manifestPath = join(iterationDir, "manifest.json");
      if (!isRegularFile(manifestPath)) die(`missing ${displayPath(manifestPath, basePath)}`);
      const manifest = object(readJson(manifestPath, context));
      const manifestIds = manifest?.case_ids;
      const manifestValid =
        manifest?.version === 1 &&
        manifest?.skill_name === workspaceSkillName &&
        valueAsString(manifest?.iteration) === iterationNumber &&
        isAllowedStringArray(manifestIds, /^[a-z][a-z0-9-]*$/, true) &&
        unique(manifestIds) &&
        (manifest?.state === undefined ||
          (isString(manifest.state) && ["historical", "preparation", "materialized"].includes(manifest.state))) &&
        (manifest?.history_reason === undefined ||
          (manifest.history_reason === "retired-materialized-incomplete" && manifest.state === "historical"));
      if (!manifestValid) die(`invalid evaluation manifest: ${displayPath(manifestPath, basePath)}`);
      const ids = manifestIds as string[];
      const iterationState = isString(manifest?.state) ? manifest.state : "";
      const historyReason = isString(manifest?.history_reason) ? manifest.history_reason : "";
      const isCurrentIteration = Number(iterationNumber) === currentIteration;
      const isPreparationIteration = iterationState === "preparation";
      const isMaterializedIteration = iterationState === "materialized";
      let caseArtifactPresent = false;
      let historicalIteration = false;
      let retiredHistoricalIteration = false;
      let legacyPreparationIteration = false;

      for (const extra of ["benchmark.json", "feedback.json", "grading-summary.json"]) {
        const reportPath = join(iterationDir, extra);
        if (!isRegularFile(reportPath)) die(`missing ${displayPath(reportPath, basePath)}`);
        const report = object(readJson(reportPath, context));
        if (report?.skill_name !== workspaceSkillName || valueAsString(report?.iteration) !== iterationNumber) {
          die(`invalid report identity: ${displayPath(reportPath, basePath)}`);
        }
      }

      for (const caseEntry of entries(iterationDir)) {
        const caseName = basename(caseEntry);
        if (["manifest.json", "benchmark.json", "feedback.json", "grading-summary.json"].includes(caseName)) continue;
        if (!isPhysicalDirectory(caseEntry))
          die(`evaluation case is not a physical directory: ${displayPath(caseEntry, basePath)}`);
        caseArtifactPresent = true;
        if (!ids.includes(caseName))
          die(`workspace case is not in the evaluation manifest: ${displayPath(caseEntry, basePath)}`);
        for (const configurationDir of entries(caseEntry)) {
          if (!isPhysicalDirectory(configurationDir))
            die(`evaluation configuration is not a physical directory: ${displayPath(configurationDir, basePath)}`);
          if (!["with_skill", "old_skill"].includes(basename(configurationDir))) {
            die(`invalid evaluation configuration: ${displayPath(configurationDir, basePath)}`);
          }
        }
      }

      if (iterationState === "historical") {
        if (historyReason === "retired-materialized-incomplete" && !historicalWorkspace) {
          retiredHistoricalIteration = true;
          historicalIteration = true;
        } else {
          if (!historicalWorkspace)
            die(
              `historical evaluation state requires explicit migration metadata: ${displayPath(manifestPath, basePath)}`,
            );
          historicalIteration = true;
        }
      } else if (!iterationState && historicalWorkspace) {
        historicalIteration = true;
      } else if (
        !iterationState &&
        !caseArtifactPresent &&
        isLegacyPreparationSkill(context, workspaceSkillName) &&
        isLegacyPreparationSummary(context, iterationDir)
      ) {
        legacyPreparationIteration = true;
        historicalIteration = true;
      }

      if (!historicalIteration && isCurrentIteration && JSON.stringify(ids) !== JSON.stringify(expectedIds)) {
        die(`current evaluation manifest does not match the evaluation spec: ${displayPath(manifestPath, basePath)}`);
      }
      if (!caseArtifactPresent && historicalIteration) {
        if (retiredHistoricalIteration) {
          console.log(
            `Validating retired incomplete historical evaluation iteration: ${displayPath(iterationDir, basePath)}`,
          );
        } else {
          console.log(`Accepted legacy historical evaluation iteration: ${displayPath(iterationDir, basePath)}`);
        }
      }
      if (!caseArtifactPresent && !historicalIteration) {
        die(
          `evaluation iteration has no case artifacts or explicit historical state: ${displayPath(iterationDir, basePath)}`,
        );
      }

      if (retiredHistoricalIteration) {
        validateRetiredHistoricalIteration(context, iterationDir, ids, workspaceSkillName, iterationNumber);
      } else if (
        (!historicalIteration && (isCurrentIteration || isPreparationIteration || isMaterializedIteration)) ||
        (historicalIteration && caseArtifactPresent)
      ) {
        let materializedExecution = false;
        for (const caseName of ids) {
          const caseEntry = join(iterationDir, caseName);
          if (!isPhysicalDirectory(caseEntry))
            die(`missing evaluation case directory: ${displayPath(caseEntry, basePath)}`);
          for (const configuration of ["with_skill", "old_skill"]) {
            const configurationDir = join(caseEntry, configuration);
            if (!isPhysicalDirectory(configurationDir))
              die(`missing evaluation configuration: ${displayPath(configurationDir, basePath)}`);
            const outputsDir = join(configurationDir, "outputs");
            if (!isPhysicalDirectory(outputsDir)) die(`missing output directory: ${displayPath(outputsDir, basePath)}`);
            for (const extra of ["timing.json", "grading.json"]) {
              const path = join(configurationDir, extra);
              if (!isRegularFile(path)) die(`missing ${displayPath(path, basePath)}`);
              readJson(path, context);
            }
            if (isPreparationIteration) {
              validatePreparationConfig(context, configurationDir);
            } else {
              materializedExecution = true;
              validateMaterializedConfig(context, configurationDir, workspaceSkillName, caseName, configuration);
            }
          }
        }
        if (materializedExecution)
          validateMaterializedReports(context, iterationDir, workspaceSkillName, iterationNumber);
        if (isPreparationIteration)
          validatePreparationReports(context, iterationDir, workspaceSkillName, iterationNumber);
      }
    }
  }

  console.log("Skill evaluation specs and repository-local workspaces are valid.");
}

try {
  main();
} catch (error) {
  console.error(`error: ${errorMessage(error)}`);
  process.exitCode = 1;
}
