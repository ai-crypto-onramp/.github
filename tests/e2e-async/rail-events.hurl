# e2e-async: capture a card payment on orchestrator-fiat and verify
# the rail.events.v1 async pipeline is exercised by running a recon run
# on engine-recon against the RAILS source and confirming the run
# reaches a terminal state (Option 1: per-service direct trigger).
#
# This test follows the Option 1 per-service direct trigger approach
# from the coverage plan:
#   - Trigger:  POST /v1/payments/intents + POST /v1/payments/{id}/capture
#                on orchestrator-fiat (port 8094). A full capture
#                transitions the intent authorized -> captured and drives
#                the rail settlement path that, in a fully-wired stack,
#                emits rail.settlement.completed onto rail.events.v1.
#   - Verify:   POST /v1/recon-runs + GET /v1/recon-runs/{id} on
#                engine-recon (port 8098) with source=RAILS — the
#                canonical source that maps to the rail.events.v1 topic
#                (engine-recon/src/reconciliation/config.py:
#                 CONSUMER_TOPICS["RAILS"] = "rail.events.v1").
#
# The canonical producer of rail.events.v1 is gateway-fiat
# (gateway-fiat/README.md: "emits rail.settlement.completed and
# rail.chargeback.received events to Reconciliation"). We hit
# gateway-fiat's healthz to confirm the rail gateway is up, and
# optionally probe GET /v1/status/{payment_id} to exercise the rail
# settlement status path. Note: orchestrator-fiat's capture handler
# uses an in-process DummyAdapter (cmd/orchestrator-fiat/main.go:
# rail.NewDummy() in DEV_MODE), so it does not call gateway-fiat over
# HTTP; the payment_id created on orchestrator-fiat therefore does not
# exist in gateway-fiat's store, and GET /v1/status/{payment_id} on
# gateway-fiat is expected to 400 (unknown payment_id) — we do not
# assert on it, only confirm the gateway is reachable.
#
# Kafka wiring note: in dev mode the rail.events.v1 pipeline is NOT
# wired end-to-end:
#   1. gateway-fiat has no Kafka producer — its audit.Sink is an
#      in-memory Recorder (internal/audit/audit.go: NewRecorder;
#      grep for kafka/producer in gateway-fiat returns nothing).
#      rail.settlement.completed events are emitted to the Recorder
#      only (PROJECT_PLAN.md: "emitted via in-memory audit.Sink").
#   2. engine-recon only starts a consumer for ledger.events.v1
#      (src/reconciliation/kafka_ledger_consumer.py:
#       build_ledger_consumer subscribes to recon_ledger_topic only);
#      there is no rails consumer loop wired, even though
#      rail.events.v1 is declared in CONSUMER_TOPICS and pre-created
#      by the kafka-init container in docker-compose.
# Because of this, the recon run against source=RAILS will complete
# with no external events ingested (matched_count=0, unmatched_count=0
# when no ledger entries are fetched either). This test therefore
# exercises the synchronous trigger chain (capture -> captured state)
# and the engine-recon run execution path, and asserts the run
# reaches the terminal COMPLETED status with the expected shape —
# a best-effort verify, not a strict matched_count >= 1. Full async
# pipeline coverage for rail.events.v1 awaits a Kafka producer in
# gateway-fiat and a rails consumer in engine-recon (Option 2 in the
# coverage plan).

# --- orchestrator-fiat: health check (port 8094) ---

GET http://localhost:8094/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- trigger: create a card intent (auto-authorized) ---

POST http://localhost:8094/v1/payments/intents
Authorization: Bearer {{service_token}}
Content-Type: application/json
Idempotency-Key: hurl-async-rail-{{newUuid}}
{
  "rail": "card",
  "amount": 10000,
  "currency": "USD",
  "payer_ref": "hurl-async-rail-payer-{{newUuid}}"
}
HTTP 201
[Captures]
e2e_rail_payment_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.rail" == "card"
jsonpath "$.amount" == 10000
jsonpath "$.currency" == "USD"
jsonpath "$.status" == "authorized"

# --- trigger: capture the full authorized amount ---
# A full capture transitions the intent authorized -> captured
# synchronously inside the handler (internal/api/handlers.go: when
# CapturedAmount >= Amount it calls i.Transition(StatusCaptured) and
# persists before returning), so the response already carries
# status == "captured". This is the rail settlement trigger step.

POST http://localhost:8094/v1/payments/{{e2e_rail_payment_id}}/capture
Authorization: Bearer {{service_token}}
Content-Type: application/json
Idempotency-Key: hurl-async-rail-cap-{{newUuid}}
{
  "amount": 10000
}
HTTP 200
[Asserts]
jsonpath "$.status" == "captured"

# --- verify: the intent is durably in the captured state ---
# The capture handler persists the transition before returning, so a
# single GET is enough to confirm the terminal state (no retry loop
# required). This mirrors the verify pattern in payment-events.hurl.

GET http://localhost:8094/v1/payments/{{e2e_rail_payment_id}}
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{e2e_rail_payment_id}}"
jsonpath "$.status" == "captured"
jsonpath "$.captured_amount" == 10000
jsonpath "$.history" exists

# --- gateway-fiat: health check (port 8097) ---
# gateway-fiat is the canonical producer of rail.events.v1. We confirm
# it is up; the rail settlement events would flow through it in a
# fully-wired stack. We do not drive gateway-fiat's capture directly
# here because the payment_id lives in orchestrator-fiat's store, not
# gateway-fiat's, and orchestrator-fiat's DEV_MODE dummy adapter does
# not proxy to gateway-fiat.

GET http://localhost:8097/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- engine-recon: health check (port 8098) ---

GET http://localhost:8098/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- verify: run a recon run against the RAILS source ---
# The handler calls Reconciler.execute synchronously and returns the
# already-completed run, so run_id is terminal immediately. source=RAILS
# is the canonical identifier that maps to the rail.events.v1 topic
# (engine-recon/src/reconciliation/config.py: CONSUMER_TOPICS["RAILS"]
# = "rail.events.v1"). In a fully-wired stack, the rails Kafka consumer
# would have ingested settlement events into the external_events table
# and this run would match them against ledger entries; in dev mode
# (no rails consumer wired), the run still executes and completes with
# zero matched/unmatched.

POST http://localhost:8098/v1/recon-runs
Content-Type: application/json
{
  "source": "RAILS",
  "scope": "daily",
  "mode": "eod"
}
HTTP 200
[Captures]
e2e_rail_run_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.status" exists

# --- verify: poll the recon run until terminal ---
# Reconciler.execute completes the run before returning, but we poll
# once via GET to confirm the row is durably queryable and exposes the
# matched/unmatched/breaks counters that reflect the rail settlement
# pipeline. We retry a small number of times to tolerate a brief commit
# lag (same pattern as ledger-events.hurl).
#
# We assert the run reaches COMPLETED and exposes the counter fields —
# a shape check rather than a strict matched_count >= 1, to stay robust
# to the dev-mode no-Kafka path (see the wiring note in the header).

GET http://localhost:8098/v1/recon-runs/{{e2e_rail_run_id}}
[Options]
retry: 5
retry-interval: 200ms
HTTP 200
[Asserts]
jsonpath "$.id" == {{e2e_rail_run_id}}
jsonpath "$.source" == "RAILS"
jsonpath "$.status" == "COMPLETED"
jsonpath "$.matched_count" exists
jsonpath "$.unmatched_count" exists
jsonpath "$.breaks_count" exists
# A terminal run exposes completed_at once it has finished matching.
jsonpath "$.completed_at" exists
