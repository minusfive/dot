#!/usr/bin/env bun
//MISE description="Acknowledge review findings with fixture persistence-before-ack semantics"
//MISE quiet=true
//MISE dir="{{cwd}}"
//USAGE arg "<action>" help="Consumer action: acknowledge"
//USAGE flag "--envelope <path>" help="review-findings.v1 envelope JSON"
//USAGE flag "--state <path>" help="Consumer-owned ledger state JSON"
//USAGE flag "--evidence <path>" help="Optional ledger-ack.v1 evidence output"

import { randomUUID } from "node:crypto";
import { mkdir, open, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import {
  emptyLedger,
  jsonDigest,
  ledgerFinding,
  mergeSeen,
  sameIdentity,
  sha256,
  validateEnvelope,
  type Json,
  type Ledger,
  type ValidatedEnvelope,
} from "./review-findings-contract.ts";
import { validateLedger } from "./review-findings-validate.ts";

const action = (process.env.usage_action ?? "").trim();
const envelopePath = (process.env.usage_envelope ?? "").trim();
const statePath = (process.env.usage_state ?? "").trim();
const evidencePath = (process.env.usage_evidence ?? "").trim();

type Ack = {
  schema_version: "ledger-ack.v1";
  protocol: "persist-before-ack-v1";
  live_vs_fixture: "fixture";
  status: "acknowledged" | "duplicate";
  batch_id: string;
  identity: Record<string, string>;
  digest_set: {
    envelope_sha256: string;
    payload_sha256: string;
    findings_sha256: string;
  };
  finding_count: number;
  ledger: {
    path: string;
    before_sha256: string;
    after_sha256: string;
    durable: true;
    persisted_before_ack: true;
  };
  pending: {
    present: false;
    bytes_preserved: true;
    envelope_sha256: string;
  };
  cursor: { advanced: boolean; seen_count: number };
  ack: { exact: true; durable: true; no_op: boolean };
  failures: [];
};

function fail(message: string): never {
  throw new Error(message);
}

async function loadLedger(path: string): Promise<{ ledger: Ledger; bytes: string }> {
  try {
    const bytes = await readFile(path, "utf8");
    const value = JSON.parse(bytes) as unknown;
    validateLedger(value);
    return { ledger: value, bytes };
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return { ledger: emptyLedger(), bytes: "" };
    }
    throw new Error(`invalid ledger ${path}: ${error instanceof Error ? error.message : String(error)}`);
  }
}

async function writeAtomic(path: string, value: Json, phase: "stage" | "commit"): Promise<void> {
  const failure = (process.env.REVIEW_FINDINGS_CONSUMER_FAIL_PERSIST ?? "").trim();
  if (failure === "any" || failure === phase) fail(`simulated persistence failure during ${phase}`);
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.tmp.${process.pid}.${randomUUID()}`;
  try {
    await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`, "utf8");
    const file = await open(temporary, "r+");
    try {
      await file.sync();
    } finally {
      await file.close();
    }
    await rename(temporary, path);
  } finally {
    await unlink(temporary).catch(() => undefined);
  }
}

function seenCount(ledger: Ledger): number {
  return Object.values(ledger.cursor.seen).reduce((total, entries) => total + entries.length, 0);
}

function matchingBatch(ledger: Ledger, envelope: ValidatedEnvelope) {
  return ledger.acknowledged_batches.find((batch) => batch.batch_id === envelope.batch_id) ?? null;
}

function sameFindingIds(left: string[], right: string[]): boolean {
  return left.length === right.length && new Set(left).size === left.length && left.every((id) => right.includes(id));
}

function ensureIdentity(ledger: Ledger, envelope: ValidatedEnvelope): void {
  if (ledger.identity !== null && !sameIdentity(ledger.identity, envelope.identity))
    fail("envelope identity does not match the ledger identity");
}

function ensureExistingFindingsMatch(ledger: Ledger, envelope: ValidatedEnvelope): void {
  for (const rawFinding of envelope.findings) {
    const findingId = `${rawFinding.kind}:${rawFinding.activity_id}`;
    const existing = ledger.findings.find((finding) => finding.finding_id === findingId);
    if (!existing) continue;
    if (existing.evidence.source_batch_id !== envelope.batch_id)
      fail(`finding identity already belongs to another batch: ${findingId}`);
    const incomingDigest = jsonDigest(rawFinding);
    if (existing.digest.finding_sha256 !== incomingDigest)
      fail(`finding identity collision with different payload: ${findingId}`);
    if (existing.identity.repository !== envelope.identity.repository)
      fail(`finding identity collision with foreign repository: ${findingId}`);
  }
}

function stagedLedger(
  ledger: Ledger,
  envelope: ValidatedEnvelope,
  rawBytes: string,
  envelopeSha256: string,
  stagedAt: string,
): Ledger {
  ensureIdentity(ledger, envelope);
  ensureExistingFindingsMatch(ledger, envelope);
  const stagedFindings = envelope.findings.map((finding) => ledgerFinding(finding, envelope, envelopeSha256, stagedAt));
  const existingIds = new Set(ledger.findings.map((finding) => finding.finding_id));
  const findings = [...ledger.findings, ...stagedFindings.filter((finding) => !existingIds.has(finding.finding_id))];
  return {
    ...ledger,
    identity: ledger.identity ?? envelope.identity,
    findings,
    pending: {
      batch_id: envelope.batch_id,
      identity: envelope.identity,
      envelope_bytes: rawBytes,
      envelope_sha256: envelopeSha256,
      payload_sha256: envelope.payload_sha256,
      findings_sha256: envelope.findings_sha256,
      findings: stagedFindings,
      next_seen: mergeSeen(ledger.cursor.seen, {
        reviews: envelope.findings
          .filter((finding) => finding.kind === "review")
          .map((finding) => String(finding.activity_id)),
        inline_comments: envelope.findings
          .filter((finding) => finding.kind === "inline_comment")
          .map((finding) => String(finding.activity_id)),
        issue_comments: envelope.findings
          .filter((finding) => finding.kind === "issue_comment")
          .map((finding) => String(finding.activity_id)),
      }),
      staged_at: stagedAt,
    },
  };
}

function committedLedger(ledger: Ledger, envelope: ValidatedEnvelope, envelopeSha256: string): Ledger {
  if (!ledger.pending) fail("cannot commit an acknowledgement without a pending batch");
  if (ledger.pending.batch_id !== envelope.batch_id || ledger.pending.envelope_sha256 !== envelopeSha256)
    fail("pending batch does not exactly match the acknowledgement");
  return {
    ...ledger,
    acknowledged_batches: [
      ...ledger.acknowledged_batches,
      {
        batch_id: envelope.batch_id,
        identity: envelope.identity,
        envelope_sha256: envelopeSha256,
        payload_sha256: envelope.payload_sha256,
        findings_sha256: envelope.findings_sha256,
        finding_ids: ledger.pending.findings.map((finding) => finding.finding_id),
        acknowledged_at: new Date().toISOString(),
      },
    ],
    cursor: {
      last_acknowledged_batch_id: envelope.batch_id,
      seen: ledger.pending.next_seen,
    },
    pending: null,
  };
}

async function writeEvidence(path: string, ack: Ack): Promise<void> {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(resolve(path), `${JSON.stringify(ack, null, 2)}\n`, "utf8");
}

async function acknowledge(): Promise<void> {
  if (!envelopePath || !statePath) fail("--envelope and --state are required");
  const rawBytes = await readFile(resolve(envelopePath), "utf8");
  const value = JSON.parse(rawBytes) as unknown;
  const envelope = validateEnvelope(value, rawBytes);
  const envelopeSha256 = sha256(rawBytes);
  const { ledger: priorLedger, bytes: priorBytes } = await loadLedger(resolve(statePath));
  ensureIdentity(priorLedger, envelope);
  const priorDigest = sha256(priorBytes);
  const duplicate = matchingBatch(priorLedger, envelope);
  if (duplicate) {
    if (
      duplicate.envelope_sha256 !== envelopeSha256 ||
      duplicate.payload_sha256 !== envelope.payload_sha256 ||
      duplicate.findings_sha256 !== envelope.findings_sha256 ||
      !sameIdentity(duplicate.identity, envelope.identity) ||
      !sameFindingIds(
        duplicate.finding_ids,
        envelope.findings.map((finding) => `${finding.kind}:${finding.activity_id}`),
      )
    )
      fail("batch_id was already acknowledged with a different digest or identity");
    const ack: Ack = {
      schema_version: "ledger-ack.v1",
      protocol: "persist-before-ack-v1",
      live_vs_fixture: "fixture",
      status: "duplicate",
      batch_id: envelope.batch_id,
      identity: envelope.identity,
      digest_set: {
        envelope_sha256: envelopeSha256,
        payload_sha256: envelope.payload_sha256,
        findings_sha256: envelope.findings_sha256,
      },
      finding_count: envelope.findings.length,
      ledger: {
        path: statePath,
        before_sha256: sha256(priorBytes),
        after_sha256: sha256(priorBytes),
        durable: true,
        persisted_before_ack: true,
      },
      pending: { present: false, bytes_preserved: true, envelope_sha256: envelopeSha256 },
      cursor: { advanced: false, seen_count: seenCount(priorLedger) },
      ack: { exact: true, durable: true, no_op: true },
      failures: [],
    };
    if (evidencePath) await writeEvidence(evidencePath, ack);
    process.stdout.write(`${JSON.stringify(ack)}\n`);
    return;
  }
  if (priorLedger.pending) {
    if (
      priorLedger.pending.batch_id !== envelope.batch_id ||
      priorLedger.pending.envelope_sha256 !== envelopeSha256 ||
      priorLedger.pending.envelope_bytes !== rawBytes
    )
      fail("pending acknowledgement does not exactly match the supplied envelope");
  }
  const staged = priorLedger.pending
    ? priorLedger
    : stagedLedger(priorLedger, envelope, rawBytes, envelopeSha256, new Date().toISOString());
  validateLedger(staged);
  if (!priorLedger.pending) {
    await writeAtomic(resolve(statePath), staged as unknown as Json, "stage");
    if (process.env.REVIEW_FINDINGS_CONSUMER_INTERRUPT_AFTER_STAGE === "1")
      fail("simulated interruption after durable finding persistence");
  }
  const committed = committedLedger(staged, envelope, envelopeSha256);
  validateLedger(committed);
  await writeAtomic(resolve(statePath), committed as unknown as Json, "commit");
  const committedBytes = JSON.stringify(committed, null, 2) + "\n";
  const ack: Ack = {
    schema_version: "ledger-ack.v1",
    protocol: "persist-before-ack-v1",
    live_vs_fixture: "fixture",
    status: "acknowledged",
    batch_id: envelope.batch_id,
    identity: envelope.identity,
    digest_set: {
      envelope_sha256: envelopeSha256,
      payload_sha256: envelope.payload_sha256,
      findings_sha256: envelope.findings_sha256,
    },
    finding_count: envelope.findings.length,
    ledger: {
      path: statePath,
      before_sha256: priorDigest,
      after_sha256: sha256(committedBytes),
      durable: true,
      persisted_before_ack: true,
    },
    pending: { present: false, bytes_preserved: true, envelope_sha256: envelopeSha256 },
    cursor: { advanced: true, seen_count: seenCount(committed) },
    ack: { exact: true, durable: true, no_op: false },
    failures: [],
  };
  if (evidencePath) await writeEvidence(evidencePath, ack);
  process.stdout.write(`${JSON.stringify(ack)}\n`);
}

async function main(): Promise<void> {
  if (action !== "acknowledge") fail("action must be acknowledge");
  await acknowledge();
}

if (import.meta.main) {
  await main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
