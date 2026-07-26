# e2e-async: create a payment intent and capture it, then verify
# the intent reaches the terminal `captured` state via the
# orchestrator-fiat GET /v1/payments/{id} endpoint (no kafka-rest needed).
#
# This test follows the Option 1 per-service direct trigger approach
# from the coverage plan:
#   - Trigger:  POST /v1/payments/intents + POST /v1/payments/{id}/capture
#                on orchestrator-fiat (port 8094)
#   - Verify:   GET /v1/payments/{id} (status == "captured")
#
# The orchestrator-fiat payment state machine transitions synchronously
# inside the capture handler (see internal/api/handlers.go: when
# CapturedAmount >= Amount it calls i.Transition(StatusCaptured) and
# persists before returning), so GET /v1/payments/{id} reflects the
# captured state immediately — a single GET verify is sufficient, the
# same pattern used by the other e2e-async tests (orchestrator-tx,
# exchange-fills, ledger-events).
#
# Kafka producer note: the `payment.events.v1` topic is declared in
# docker-compose but orchestrator-fiat does NOT publish to it — the
# only Kafka sink in the service is the audit sink (internal/audit),
# which emits to `audit.v1` (audit.go: AuditTopic = "audit.v1"). In dev
# mode (KAFKA_BROKERS unset) even the audit sink falls back to an
# in-memory recorder (cmd/orchestrator-fiat/main.go). The verify via
# GET /v1/payments/{id} works regardless because the payment state
# machine updates synchronously on capture, independent of any Kafka
# emission. This test therefore exercises the synchronous trigger +
# state-persistence path; full async pipeline coverage for
# `payment.events.v1` awaits a producer being wired (Option 2 in the
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
Idempotency-Key: hurl-async-{{newUuid}}
{
  "rail": "card",
  "amount": 10000,
  "currency": "USD",
  "payer_ref": "hurl-async-payer-{{newUuid}}"
}
HTTP 201
[Captures]
e2e_payment_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.rail" == "card"
jsonpath "$.amount" == 10000
jsonpath "$.currency" == "USD"
jsonpath "$.status" == "authorized"

# --- trigger: capture the full authorized amount ---
# A full capture transitions the intent authorized -> captured
# synchronously inside the handler, so the response already carries
# status == "captured".

POST http://localhost:8094/v1/payments/{{e2e_payment_id}}/capture
Authorization: Bearer {{service_token}}
Content-Type: application/json
Idempotency-Key: hurl-async-cap-{{newUuid}}
{
  "amount": 10000
}
HTTP 200
[Asserts]
jsonpath "$.status" == "captured"

# --- verify: GET the intent and confirm it is durably in the captured state ---
# The capture handler persists the transition before returning, so a
# single GET is enough to confirm the terminal state (no retry loop
# required). This mirrors the verify pattern used in the other
# e2e-async tests.

GET http://localhost:8094/v1/payments/{{e2e_payment_id}}
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{e2e_payment_id}}"
jsonpath "$.status" == "captured"
jsonpath "$.captured_amount" == 10000
jsonpath "$.history" exists