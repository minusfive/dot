import { createHash } from "node:crypto";

export type Json = null | boolean | number | string | Json[] | { [key: string]: Json };

export type Identity = {
  repository: string;
  coordinator_id: string;
  scheduler_id: string;
  assignment_id: string;
  scope_id: string;
  candidate_id: string;
};

export type ArtifactIdentity = Identity & {
  pull_request: number;
  head: string;
};

export type Seen = {
  reviews: string[];
  inline_comments: string[];
  issue_comments: string[];
};

export type DigestSet = {
  envelope_sha256: string;
  payload_sha256: string;
  findings_sha256: string;
};

export type FindingKind = "review" | "inline_comment" | "issue_comment" | "nested_comment";

export const expectedProvenanceSource: Record<FindingKind, string> = {
  review: "pull_request_review",
  inline_comment: "pull_request_review_comment",
  issue_comment: "issue_comment",
  nested_comment: "nested_review_comment",
};

export type ValidatedEnvelope = {
  schema_version: "review-findings.v1";
  batch_id: string;
  identity: Identity;
  complete: true;
  findings: Array<Record<string, Json>>;
  counts: Record<string, number>;
  payload_sha256: string;
  findings_sha256: string;
};

export type LedgerFinding = {
  finding_id: string;
  payload: Record<string, Json>;
  identity: ArtifactIdentity;
  provenance: Record<string, Json>;
  disposition: { status: "pending"; owner: string };
  evidence: {
    source_batch_id: string;
    source_artifact_digest: string;
    captured_at: string;
    source: "review-findings.v1";
  };
  protocol: {
    schema_version: "persist-before-ack-v1";
    persistence_order: "finding-before-ack";
    transport: "fixture";
  };
  delivery: {
    repository: string;
    candidate_id: string;
    pull_request: number;
    head: string;
    live_vs_fixture: "fixture";
    review_state: "pending";
  };
  digest: DigestSet & { finding_sha256: string };
};

export type Ledger = {
  schema_version: "review-findings-ledger.v1";
  protocol: "persist-before-ack-v1";
  identity: Identity | null;
  findings: LedgerFinding[];
  acknowledged_batches: Array<{
    batch_id: string;
    identity: Identity;
    envelope_sha256: string;
    payload_sha256: string;
    findings_sha256: string;
    finding_ids: string[];
    acknowledged_at: string;
  }>;
  cursor: {
    last_acknowledged_batch_id: string | null;
    seen: Seen;
  };
  pending: {
    batch_id: string;
    identity: Identity;
    envelope_bytes: string;
    envelope_sha256: string;
    payload_sha256: string;
    findings_sha256: string;
    findings: LedgerFinding[];
    next_seen: Seen;
    staged_at: string;
  } | null;
};

export function isObject(value: unknown): value is Record<string, Json> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function canonicalJson(value: Json): string {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (!isObject(value)) return JSON.stringify(value);
  return `{${Object.keys(value)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`)
    .join(",")}}`;
}

export function sha256(value: string): string {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

export function jsonDigest(value: Json): string {
  return sha256(canonicalJson(value));
}

function nonEmptyString(value: unknown, name: string): string {
  if (typeof value !== "string" || value.trim().length === 0) throw new Error(`${name} must be a non-empty string`);
  return value;
}

function positiveInteger(value: unknown, name: string): number {
  if (!Number.isSafeInteger(value) || (value as number) <= 0) throw new Error(`${name} must be a positive integer`);
  return value as number;
}

export function parseIdentity(value: unknown, name: string): Identity {
  if (!isObject(value)) throw new Error(`${name} must be an object`);
  const identity = {
    repository: nonEmptyString(value.repository, `${name}.repository`),
    coordinator_id: nonEmptyString(value.coordinator_id, `${name}.coordinator_id`),
    scheduler_id: nonEmptyString(value.scheduler_id, `${name}.scheduler_id`),
    assignment_id: nonEmptyString(value.assignment_id, `${name}.assignment_id`),
    scope_id: nonEmptyString(value.scope_id, `${name}.scope_id`),
    candidate_id: nonEmptyString(value.candidate_id, `${name}.candidate_id`),
  };
  return identity;
}

export function parseArtifactIdentity(value: unknown, name: string): ArtifactIdentity {
  if (!isObject(value)) throw new Error(`${name} must be an object`);
  return {
    ...parseIdentity(value, name),
    pull_request: positiveInteger(value.pull_request, `${name}.pull_request`),
    head: nonEmptyString(value.head, `${name}.head`),
  };
}

export function sameIdentity(left: Identity, right: Identity): boolean {
  return canonicalJson(left) === canonicalJson(right);
}

export function validateProvenance(value: unknown, kind: string): Record<string, Json> {
  if (!isObject(value)) throw new Error(`${kind}.provenance must be an object`);
  const expectedSource = expectedProvenanceSource[kind as FindingKind];
  if (!expectedSource) throw new Error(`${kind} is invalid`);
  if (value.source !== expectedSource) throw new Error(`${kind}.provenance.source is invalid`);
  if (kind === "review") {
    nonEmptyString(value.review_id, `${kind}.provenance.review_id`);
    if (value.revision_id !== null && value.revision_id !== undefined)
      nonEmptyString(value.revision_id, `${kind}.provenance.revision_id`);
    return value;
  }
  if (value.comment_id === undefined) throw new Error(`${kind}.provenance.comment_id is required`);
  if (
    !["string", "number"].includes(typeof value.comment_id) ||
    (typeof value.comment_id === "string" && value.comment_id.trim().length === 0)
  )
    throw new Error(`${kind}.provenance.comment_id is invalid`);
  if (!["diff", "pathless"].includes(String(value.location))) throw new Error(`${kind}.provenance.location is invalid`);
  if (typeof value.outside_diff !== "boolean") throw new Error(`${kind}.provenance.outside_diff must be boolean`);
  if (value.revision_id !== null && value.revision_id !== undefined)
    nonEmptyString(value.revision_id, `${kind}.provenance.revision_id`);
  return value;
}

export function validateEnvelope(value: unknown, rawBytes: string): ValidatedEnvelope {
  void rawBytes;
  if (!isObject(value)) throw new Error("review findings envelope must be an object");
  if (value.schema_version !== "review-findings.v1") throw new Error("unknown review findings schema version");
  const batchId = nonEmptyString(value.batch_id, "batch_id");
  if (value.complete !== true) throw new Error("review findings envelope must be complete");
  const identity = parseIdentity(value.identity, "identity");
  if (!Array.isArray(value.findings)) throw new Error("findings must be an array");
  if (!isObject(value.counts)) throw new Error("counts must be an object");
  const findings = value.findings.map((rawFinding, index) => {
    if (!isObject(rawFinding)) throw new Error(`findings[${index}] must be an object`);
    const kind = nonEmptyString(rawFinding.kind, `findings[${index}].kind`);
    if (!["review", "inline_comment", "issue_comment", "nested_comment"].includes(kind))
      throw new Error(`findings[${index}].kind is invalid`);
    const findingIdentity = parseArtifactIdentity(rawFinding.identity, `findings[${index}].identity`);
    if (
      findingIdentity.repository !== identity.repository ||
      findingIdentity.coordinator_id !== identity.coordinator_id ||
      findingIdentity.scheduler_id !== identity.scheduler_id ||
      findingIdentity.assignment_id !== identity.assignment_id ||
      findingIdentity.scope_id !== identity.scope_id ||
      findingIdentity.candidate_id !== identity.candidate_id
    )
      throw new Error(`findings[${index}] identity does not match the envelope`);
    if (rawFinding.source_batch_id !== batchId)
      throw new Error(`findings[${index}].source_batch_id mismatches batch_id`);
    if (!Number.isSafeInteger(rawFinding.result_number) || rawFinding.result_number !== findingIdentity.pull_request)
      throw new Error(`findings[${index}].result_number mismatches pull_request`);
    nonEmptyString(rawFinding.activity_id, `findings[${index}].activity_id`);
    const provenance = validateProvenance(rawFinding.provenance, kind);
    return rawFinding;
  });
  const counts = {
    pull_requests: value.counts.pull_requests as number,
    reviews: value.counts.reviews as number,
    inline_comments: value.counts.inline_comments as number,
    issue_comments: value.counts.issue_comments as number,
  };
  for (const key of ["pull_requests", "reviews", "inline_comments", "issue_comments"] as const) {
    if (!Number.isSafeInteger(value.counts[key]) || (value.counts[key] as number) < 0)
      throw new Error(`counts.${key} must be a non-negative integer`);
  }
  const primaryKinds = {
    reviews: findings.filter((finding) => finding.kind === "review").length,
    inline_comments: findings.filter((finding) => finding.kind === "inline_comment").length,
    issue_comments: findings.filter((finding) => finding.kind === "issue_comment").length,
  };
  for (const key of ["reviews", "inline_comments", "issue_comments"] as const) {
    if (counts[key] !== primaryKinds[key]) throw new Error(`counts.${key} is inconsistent with findings`);
  }
  const findingIds = new Set<string>();
  for (const finding of findings) {
    const id = `${finding.kind}:${finding.activity_id}`;
    if (findingIds.has(id)) throw new Error(`duplicate finding identity: ${id}`);
    findingIds.add(id);
  }
  return {
    schema_version: "review-findings.v1",
    batch_id: batchId,
    identity,
    complete: true,
    findings,
    counts,
    payload_sha256: jsonDigest(value as Json),
    findings_sha256: jsonDigest(findings as unknown as Json),
  };
}

export function emptyLedger(): Ledger {
  return {
    schema_version: "review-findings-ledger.v1",
    protocol: "persist-before-ack-v1",
    identity: null,
    findings: [],
    acknowledged_batches: [],
    cursor: {
      last_acknowledged_batch_id: null,
      seen: { reviews: [], inline_comments: [], issue_comments: [] },
    },
    pending: null,
  };
}

export function seenForEnvelope(envelope: ValidatedEnvelope): Seen {
  const seen: Seen = { reviews: [], inline_comments: [], issue_comments: [] };
  for (const finding of envelope.findings) {
    if (finding.kind === "nested_comment") continue;
    const key =
      finding.kind === "review" ? "reviews" : finding.kind === "inline_comment" ? "inline_comments" : "issue_comments";
    seen[key].push(String(finding.activity_id));
  }
  return seen;
}

export function mergeSeen(left: Seen, right: Seen): Seen {
  return {
    reviews: [...new Set([...left.reviews, ...right.reviews])],
    inline_comments: [...new Set([...left.inline_comments, ...right.inline_comments])],
    issue_comments: [...new Set([...left.issue_comments, ...right.issue_comments])],
  };
}

export function ledgerFinding(
  finding: Record<string, Json>,
  envelope: ValidatedEnvelope,
  envelopeSha256: string,
  capturedAt: string,
): LedgerFinding {
  const identity = parseArtifactIdentity(finding.identity, "finding.identity");
  const provenance = validateProvenance(finding.provenance, String(finding.kind));
  const findingDigest = jsonDigest(finding as Json);
  return {
    finding_id: `${finding.kind}:${finding.activity_id}`,
    payload: finding,
    identity,
    provenance,
    disposition: { status: "pending", owner: "review-delivery" },
    evidence: {
      source_batch_id: envelope.batch_id,
      source_artifact_digest: findingDigest,
      captured_at: capturedAt,
      source: "review-findings.v1",
    },
    protocol: {
      schema_version: "persist-before-ack-v1",
      persistence_order: "finding-before-ack",
      transport: "fixture",
    },
    delivery: {
      repository: identity.repository,
      candidate_id: identity.candidate_id,
      pull_request: identity.pull_request,
      head: identity.head,
      live_vs_fixture: "fixture",
      review_state: "pending",
    },
    digest: {
      finding_sha256: findingDigest,
      envelope_sha256: envelopeSha256,
      payload_sha256: envelope.payload_sha256,
      findings_sha256: envelope.findings_sha256,
    },
  };
}
