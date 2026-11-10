# Review findings consumer

The fixture-only consumer implements ORCH-115's `persist-before-ack-v1` protocol:

```bash
mise run pr:review-findings-consumer -- acknowledge \
  --envelope path/to/review-findings.v1.json \
  --state path/to/review-findings-ledger.json
```

The consumer writes every finding and the exact envelope bytes to the consumer-owned ledger before it acknowledges the batch. It advances seen IDs only in the durable acknowledgement write. An exact replay is a no-op. Malformed, mismatched, unknown-version, interrupted, and persistence-failing inputs leave the pending bytes and prior cursor state unchanged.

Use the semantic validator for the envelope, ledger, or acknowledgement:

```bash
mise run pr:review-findings-validate -- envelope --input path/to/envelope.json
mise run pr:review-findings-validate -- ledger --input path/to/ledger.json
mise run pr:review-findings-validate -- ack --input path/to/ack.json
```

The consumer uses fixtures only. Its passes prove protocol ordering and replay behavior, not production storage durability. Production durability requires separate attributable restart and recovery evidence from the configured durable store.
