#!/usr/bin/env bun
//MISE description="Validate review findings envelopes, ledgers, or acknowledgements"
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE arg "<kind>" help="Contract to validate: envelope, ledger, or ack"
//USAGE flag "--input <path>" help="JSON file to validate"

import { readFile } from "node:fs/promises";
import {
  mergeSeen,
  isObject,
  jsonDigest,
  parseArtifactIdentity,
  parseIdentity,
  sameIdentity,
  seenForEnvelope,
  sha256,
  validateProvenance,
  validateEnvelope,
  type ArtifactIdentity,
  type Json,
  type Ledger,
  type LedgerFinding,
  type Seen,
  type ValidatedEnvelope,
} from "./review-findings-contract.ts";

const kind = (process.env.usage_kind ?? "").trim();
const input = (process.env.usage_input ?? "").trim();

function fail(message: string): never {
  throw new Error(message);
}

function digest(value: unknown, name: string): string {
  if (typeof value !== "string" || !/^[a-f0-9]{64}$/.test(value)) fail(`${name} must be a SHA-256 digest`);
  return value;
}

function validateSeen(value: unknown, name: string): void {
  if (!isObject(value)) fail(`${name} must be an object`);
  for (const key of ["reviews", "inline_comments", "issue_comments"]) {
    if (
      !Array.isArray(value[key]) ||
      !(value[key] as unknown[]).every((item) => typeof item === "string" && item.length > 0)
    )
      fail(`${name}.${key} must be a string array`);
    if (new Set(value[key] as string[]).size !== (value[key] as string[]).length)
      fail(`${name}.${key} must not contain duplicate IDs`);
  }
}

function sameStringSet(left: string[], right: string[], name: string): void {
  if (new Set(left).size !== left.length || new Set(right).size !== right.length)
    fail(`${name} must not contain duplicate IDs`);
  if (left.length !== right.length || left.some((value) => !right.includes(value)))
    fail(`${name} does not match the persisted record set`);
}

function findingId(finding: { kind: string; activity_id: string }): string {
  return `${finding.kind}:${finding.activity_id}`;
}

function sameSeen(left: Seen, right: Seen, name: string): void {
  sameStringSet(left.reviews, right.reviews, `${name}.reviews`);
  sameStringSet(left.inline_comments, right.inline_comments, `${name}.inline_comments`);
  sameStringSet(left.issue_comments, right.issue_comments, `${name}.issue_comments`);
}

function persistedSeen(findings: Array<{ kind: string; activity_id: string }>): Seen {
  const seen: Seen = { reviews: [], inline_comments: [], issue_comments: [] };
  for (const finding of findings) {
    if (finding.kind === "nested_comment") continue;
    const key =
      finding.kind === "review" ? "reviews" : finding.kind === "inline_comment" ? "inline_comments" : "issue_comments";
    seen[key].push(finding.activity_id);
  }
  return seen;
}

function sameFindingPayload(finding: LedgerFinding, envelopeFinding: Record<string, Json>, name: string): void {
  if (jsonDigest(finding.payload) !== jsonDigest(envelopeFinding))
    fail(`${name}.payload does not match the parsed envelope finding`);
}

function nonEmpty(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) fail(`${name} must be a non-empty string`);
  return value;
}

function validateDigestSet(value: unknown, name: string): void {
  if (!isObject(value)) fail(`${name} must be an object`);
  for (const key of ["envelope_sha256", "payload_sha256", "findings_sha256"]) digest(value[key], `${name}.${key}`);
}

function validateLedgerFinding(
  value: unknown,
  name: string,
): {
  finding_id: string;
  source_batch_id: string;
  kind: string;
  activity_id: string;
  identity: ArtifactIdentity;
} {
  if (!isObject(value)) fail(`${name} must be an object`);
  const findingId = nonEmpty(value.finding_id, `${name}.finding_id`);
  if (!isObject(value.payload)) fail(`${name}.payload must be an object`);
  const kind = nonEmpty(value.payload.kind, `${name}.payload.kind`);
  if (!["review", "inline_comment", "issue_comment", "nested_comment"].includes(kind))
    fail(`${name}.payload.kind is invalid`);
  const activityId = nonEmpty(value.payload.activity_id, `${name}.payload.activity_id`);
  if (findingId !== `${kind}:${activityId}`) fail(`${name}.finding_id does not match payload identity`);
  const identity = parseArtifactIdentity(value.identity, `${name}.identity`);
  const payloadIdentity = parseArtifactIdentity(value.payload.identity, `${name}.payload.identity`);
  if (!sameIdentity(identity, payloadIdentity)) fail(`${name}.identity does not match payload.identity`);
  if (!Number.isSafeInteger(value.payload.result_number) || value.payload.result_number !== identity.pull_request)
    fail(`${name}.payload.result_number mismatches identity.pull_request`);
  const provenance = validateProvenance(value.provenance, kind);
  if (!isObject(value.payload.provenance) || jsonDigest(provenance) !== jsonDigest(value.payload.provenance))
    fail(`${name}.provenance does not match payload.provenance`);
  if (
    !isObject(value.disposition) ||
    value.disposition.status !== "pending" ||
    typeof value.disposition.owner !== "string" ||
    value.disposition.owner.trim().length === 0
  )
    fail(`${name}.disposition is invalid`);
  if (
    !isObject(value.evidence) ||
    value.evidence.source !== "review-findings.v1" ||
    typeof value.evidence.source_batch_id !== "string"
  )
    fail(`${name}.evidence is invalid`);
  const sourceBatchId = nonEmpty(value.evidence.source_batch_id, `${name}.evidence.source_batch_id`);
  if (value.payload.source_batch_id !== sourceBatchId)
    fail(`${name}.evidence.source_batch_id does not match payload.source_batch_id`);
  digest(value.evidence.source_artifact_digest, `${name}.evidence.source_artifact_digest`);
  nonEmpty(value.evidence.captured_at, `${name}.evidence.captured_at`);
  if (jsonDigest(value.payload) !== value.evidence.source_artifact_digest)
    fail(`${name}.evidence source digest does not match payload`);
  if (
    !isObject(value.protocol) ||
    value.protocol.schema_version !== "persist-before-ack-v1" ||
    value.protocol.persistence_order !== "finding-before-ack" ||
    value.protocol.transport !== "fixture"
  )
    fail(`${name}.protocol is invalid`);
  if (
    !isObject(value.delivery) ||
    value.delivery.repository !== identity.repository ||
    value.delivery.candidate_id !== identity.candidate_id ||
    value.delivery.pull_request !== identity.pull_request ||
    value.delivery.head !== identity.head ||
    value.delivery.live_vs_fixture !== "fixture" ||
    value.delivery.review_state !== "pending"
  )
    fail(`${name}.delivery is invalid`);
  if (!isObject(value.digest)) fail(`${name}.digest must be an object`);
  digest(value.digest.finding_sha256, `${name}.digest.finding_sha256`);
  validateDigestSet(value.digest, `${name}.digest`);
  if (value.digest.finding_sha256 !== jsonDigest(value.payload))
    fail(`${name}.digest finding digest does not match payload`);
  return { finding_id: findingId, source_batch_id: sourceBatchId, kind, activity_id: activityId, identity };
}

export function validateLedger(value: unknown): asserts value is Ledger {
  if (!isObject(value)) fail("ledger must be an object");
  const ledger = value as unknown as Ledger;
  if (value.schema_version !== "review-findings-ledger.v1") fail("ledger schema_version is invalid");
  if (value.protocol !== "persist-before-ack-v1") fail("ledger protocol is invalid");
  const ledgerIdentity = value.identity === null ? null : parseIdentity(value.identity, "ledger.identity");
  if (!Array.isArray(value.findings) || !Array.isArray(value.acknowledged_batches)) fail("ledger arrays are invalid");
  if (
    !isObject(value.cursor) ||
    (value.cursor.last_acknowledged_batch_id !== null && typeof value.cursor.last_acknowledged_batch_id !== "string")
  )
    fail("ledger.cursor is invalid");
  validateSeen(value.cursor.seen, "ledger.cursor.seen");
  if (value.pending !== null && !isObject(value.pending)) fail("ledger.pending is invalid");
  const findingIds = new Set<string>();
  const findingsByBatch = new Map<
    string,
    Array<{
      finding: LedgerFinding;
      finding_id: string;
      kind: string;
      activity_id: string;
      identity: ArtifactIdentity;
    }>
  >();
  for (const [index, raw] of value.findings.entries()) {
    if (!isObject(raw)) fail(`ledger.findings[${index}] must be an object`);
    const findingId = raw.finding_id;
    if (typeof findingId !== "string" || findingId.length === 0 || findingIds.has(findingId))
      fail(`ledger.findings[${index}] has a duplicate or invalid finding_id`);
    findingIds.add(findingId);
    const details = validateLedgerFinding(raw, `ledger.findings[${index}]`);
    const finding = raw as unknown as LedgerFinding;
    const batchFindings = findingsByBatch.get(details.source_batch_id) ?? [];
    batchFindings.push({ finding, ...details });
    findingsByBatch.set(details.source_batch_id, batchFindings);
    if (
      ledgerIdentity !== null &&
      !sameIdentity(ledgerIdentity, parseIdentity(details.identity, `ledger.findings[${index}].identity`))
    )
      fail(`ledger.findings[${index}].identity does not match ledger.identity`);
  }
  const batchIds = new Set<string>();
  const batches = new Map<
    string,
    {
      identity: ReturnType<typeof parseIdentity>;
      envelope_sha256: string;
      payload_sha256: string;
      findings_sha256: string;
      finding_ids: string[];
    }
  >();
  for (const [index, raw] of value.acknowledged_batches.entries()) {
    if (!isObject(raw)) fail(`ledger.acknowledged_batches[${index}] must be an object`);
    if (typeof raw.batch_id !== "string" || raw.batch_id.trim().length === 0 || batchIds.has(raw.batch_id))
      fail(`ledger.acknowledged_batches[${index}] has an invalid batch_id`);
    batchIds.add(raw.batch_id);
    const batchIdentity = parseIdentity(raw.identity, `ledger.acknowledged_batches[${index}].identity`);
    if (ledgerIdentity !== null && !sameIdentity(ledgerIdentity, batchIdentity))
      fail(`ledger.acknowledged_batches[${index}].identity does not match ledger.identity`);
    const envelopeSha256 = digest(raw.envelope_sha256, `ledger.acknowledged_batches[${index}].envelope_sha256`);
    const payloadSha256 = digest(raw.payload_sha256, `ledger.acknowledged_batches[${index}].payload_sha256`);
    const findingsSha256 = digest(raw.findings_sha256, `ledger.acknowledged_batches[${index}].findings_sha256`);
    if (!Array.isArray(raw.finding_ids)) fail(`ledger.acknowledged_batches[${index}].finding_ids must be an array`);
    if (
      !(raw.finding_ids as unknown[]).every((item) => typeof item === "string" && item.length > 0) ||
      new Set(raw.finding_ids as string[]).size !== (raw.finding_ids as string[]).length
    )
      fail(`ledger.acknowledged_batches[${index}].finding_ids must be unique non-empty strings`);
    batches.set(raw.batch_id, {
      identity: batchIdentity,
      envelope_sha256: envelopeSha256,
      payload_sha256: payloadSha256,
      findings_sha256: findingsSha256,
      finding_ids: raw.finding_ids as string[],
    });
  }
  if (
    (value.findings.length > 0 || value.acknowledged_batches.length > 0 || value.pending !== null) &&
    ledgerIdentity === null
  )
    fail("ledger.identity is required when the ledger contains state");
  for (const [batchId, batch] of batches) {
    const persisted = findingsByBatch.get(batchId) ?? [];
    sameStringSet(
      batch.finding_ids,
      persisted.map((entry) => entry.finding_id),
      `acknowledged batch ${batchId} finding_ids`,
    );
    for (const entry of persisted) {
      if (
        !sameIdentity(batch.identity, parseIdentity(entry.identity, `acknowledged batch ${batchId} finding identity`))
      )
        fail(`acknowledged batch ${batchId} identity does not match persisted finding ${entry.finding_id}`);
      if (
        entry.finding.digest.envelope_sha256 !== batch.envelope_sha256 ||
        entry.finding.digest.payload_sha256 !== batch.payload_sha256 ||
        entry.finding.digest.findings_sha256 !== batch.findings_sha256
      )
        fail(`acknowledged batch ${batchId} digest set does not match persisted finding ${entry.finding_id}`);
    }
  }
  for (const [batchId, entries] of findingsByBatch) {
    if (!batches.has(batchId) && ledger.pending?.batch_id !== batchId)
      fail(`persisted findings belong to unknown batch ${batchId}`);
    for (const entry of entries) {
      if (entry.finding.digest.envelope_sha256.length !== 64)
        fail(`persisted finding ${entry.finding_id} has invalid envelope digest`);
    }
  }
  const acknowledgedSeen = persistedSeen(
    [...batches.keys()].flatMap((batchId) =>
      (findingsByBatch.get(batchId) ?? []).map((entry) => ({ kind: entry.kind, activity_id: entry.activity_id })),
    ),
  );
  if (ledger.acknowledged_batches.length === 0) {
    if (ledger.cursor.last_acknowledged_batch_id !== null)
      fail("cursor.last_acknowledged_batch_id is invalid for an empty acknowledgement set");
  } else if (ledger.cursor.last_acknowledged_batch_id !== ledger.acknowledged_batches.at(-1)?.batch_id) {
    fail("cursor.last_acknowledged_batch_id does not match the last acknowledged batch");
  }
  sameSeen(ledger.cursor.seen, acknowledgedSeen, "ledger.cursor.seen");
  if (ledger.pending !== null) {
    const pending = ledger.pending;
    const pendingBytes = nonEmpty(pending.envelope_bytes, "ledger.pending.envelope_bytes");
    nonEmpty(pending.batch_id, "ledger.pending.batch_id");
    nonEmpty(pending.staged_at, "ledger.pending.staged_at");
    digest(pending.envelope_sha256, "ledger.pending.envelope_sha256");
    digest(pending.payload_sha256, "ledger.pending.payload_sha256");
    digest(pending.findings_sha256, "ledger.pending.findings_sha256");
    if (sha256(pendingBytes) !== pending.envelope_sha256) fail("ledger.pending envelope bytes digest mismatch");
    const pendingIdentity = parseIdentity(pending.identity, "ledger.pending.identity");
    if (ledgerIdentity === null || !sameIdentity(pendingIdentity, ledgerIdentity))
      fail("ledger.pending.identity does not match ledger.identity");
    if (!Array.isArray(pending.findings)) fail("ledger.pending.findings must be an array");
    if (batchIds.has(pending.batch_id)) fail("pending batch is already acknowledged");
    let pendingEnvelope: ValidatedEnvelope;
    try {
      pendingEnvelope = validateEnvelope(JSON.parse(pendingBytes) as unknown, pendingBytes);
    } catch (error) {
      fail(`ledger.pending envelope is invalid: ${error instanceof Error ? error.message : String(error)}`);
    }
    if (
      pendingEnvelope.batch_id !== pending.batch_id ||
      !sameIdentity(pendingEnvelope.identity, pendingIdentity) ||
      pendingEnvelope.payload_sha256 !== pending.payload_sha256 ||
      pendingEnvelope.findings_sha256 !== pending.findings_sha256 ||
      sha256(pendingBytes) !== pending.envelope_sha256
    )
      fail("ledger.pending envelope identity or digest set does not match parsed envelope bytes");
    const pendingIds = new Set<string>();
    pending.findings.forEach((finding, index) => {
      if (!isObject(finding)) fail(`ledger.pending.findings[${index}] must be an object`);
      const details = validateLedgerFinding(finding, `ledger.pending.findings[${index}]`);
      if (pendingIds.has(details.finding_id)) fail(`ledger.pending.findings contains duplicate ${details.finding_id}`);
      pendingIds.add(details.finding_id);
      if (
        !isObject(finding.digest) ||
        !isObject(finding.evidence) ||
        finding.digest.envelope_sha256 !== pending.envelope_sha256 ||
        finding.digest.payload_sha256 !== pending.payload_sha256 ||
        finding.digest.findings_sha256 !== pending.findings_sha256 ||
        finding.evidence.source_batch_id !== pending.batch_id
      )
        fail(`ledger.pending.findings[${index}] digest or batch binding is invalid`);
      const envelopeFinding = pendingEnvelope.findings.find(
        (candidate) => findingId(candidate as { kind: string; activity_id: string }) === details.finding_id,
      );
      if (!envelopeFinding) fail(`ledger.pending.findings[${index}] is not present in the parsed envelope`);
      sameFindingPayload(finding as unknown as LedgerFinding, envelopeFinding, `ledger.pending.findings[${index}]`);
    });
    sameStringSet(
      [...pendingIds],
      pendingEnvelope.findings.map((finding) => findingId(finding as { kind: string; activity_id: string })),
      "ledger.pending.finding_ids",
    );
    const persistedPending = findingsByBatch.get(pending.batch_id) ?? [];
    sameStringSet(
      [...pendingIds],
      persistedPending.map((entry) => entry.finding_id),
      "ledger.pending persisted finding_ids",
    );
    for (const entry of persistedPending) {
      if (
        entry.finding.digest.envelope_sha256 !== pending.envelope_sha256 ||
        entry.finding.digest.payload_sha256 !== pending.payload_sha256 ||
        entry.finding.digest.findings_sha256 !== pending.findings_sha256
      )
        fail(`ledger.pending digest set does not match persisted finding ${entry.finding_id}`);
      const envelopeFinding = pendingEnvelope.findings.find(
        (candidate) => findingId(candidate as { kind: string; activity_id: string }) === entry.finding_id,
      );
      if (!envelopeFinding) fail(`ledger.pending persisted finding ${entry.finding_id} is not in the parsed envelope`);
      sameFindingPayload(entry.finding, envelopeFinding, `ledger.pending persisted finding ${entry.finding_id}`);
    }
    validateSeen(pending.next_seen, "ledger.pending.next_seen");
    sameSeen(
      pending.next_seen,
      mergeSeen(ledger.cursor.seen, seenForEnvelope(pendingEnvelope)),
      "ledger.pending.next_seen",
    );
    const acknowledgedFindingIds = new Set(
      [...batches.keys()].flatMap((batchId) => (findingsByBatch.get(batchId) ?? []).map((entry) => entry.finding_id)),
    );
    for (const pendingId of pendingIds) {
      if (acknowledgedFindingIds.has(pendingId))
        fail(`pending finding ${pendingId} already exists in acknowledged findings`);
    }
  } else {
    for (const [batchId, entries] of findingsByBatch) {
      if (!batches.has(batchId)) fail(`persisted finding ${entries[0].finding_id} has no acknowledged batch`);
    }
  }
}

async function main(): Promise<void> {
  if (!["envelope", "ledger", "ack"].includes(kind)) fail("kind must be envelope, ledger, or ack");
  if (!input) fail("--input is required");
  const raw = await readFile(input, "utf8");
  const value = JSON.parse(raw) as unknown;
  if (kind === "envelope") validateEnvelope(value, raw);
  else if (kind === "ledger") validateLedger(value);
  else {
    if (
      !isObject(value) ||
      value.schema_version !== "ledger-ack.v1" ||
      value.protocol !== "persist-before-ack-v1" ||
      value.live_vs_fixture !== "fixture" ||
      !["acknowledged", "duplicate"].includes(String(value.status)) ||
      typeof value.batch_id !== "string" ||
      !isObject(value.digest_set) ||
      !isObject(value.ledger) ||
      !isObject(value.pending) ||
      !isObject(value.cursor) ||
      !isObject(value.ack) ||
      !Array.isArray(value.failures) ||
      value.failures.length !== 0
    )
      fail("acknowledgement is incomplete");
    parseIdentity(value.identity, "ack.identity");
    for (const key of ["envelope_sha256", "payload_sha256", "findings_sha256"])
      digest(value.digest_set[key], `ack.digest_set.${key}`);
    for (const key of ["before_sha256", "after_sha256"]) digest(value.ledger[key], `ack.ledger.${key}`);
    if (value.ledger.durable !== true || value.ledger.persisted_before_ack !== true)
      fail("ack ledger durability flags are invalid");
    if (value.pending.present !== false || value.pending.bytes_preserved !== true)
      fail("ack pending preservation flags are invalid");
    digest(value.pending.envelope_sha256, "ack.pending.envelope_sha256");
    if (value.ack.exact !== true || value.ack.durable !== true || typeof value.ack.no_op !== "boolean")
      fail("ack durability flags are invalid");
    if (
      (value.status === "acknowledged" && (value.ack.no_op !== false || value.cursor.advanced !== true)) ||
      (value.status === "duplicate" && (value.ack.no_op !== true || value.cursor.advanced !== false))
    )
      fail("ack status does not match acknowledgement flags");
  }
  process.stdout.write("valid\n");
}

if (import.meta.main) {
  await main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
