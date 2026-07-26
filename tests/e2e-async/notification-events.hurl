# e2e-async: trigger a manual notification send on notifier and
# verify the notification.v1 async pipeline is exercised by polling the
# delivery status until it reaches a terminal state.
#
# The notifier consumes `notification.v1` (src/kafka-bus.ts subscribes to
# the `notification.v1` topic, default EVENT_BUS_TOPIC). It does NOT
# produce to `notification.v1`; instead every notification lifecycle
# transition (requested/delivered/failed/suppressed) is emitted to the
# `audit.v1` Kafka topic via `KafkaAuditEmitter` (src/audit.ts) when
# KAFKA_BROKERS is configured. In dev mode (DEV_MODE=1, no
# KAFKA_BROKERS) the emitter degrades to `RecordingAuditEmitter`, so the
# service still works without Kafka. The `POST /v1/notifications/send`
# endpoint bypasses the Kafka consumer path entirely: it calls
# `manualSend` (src/pipeline.ts) which resolves the channel route and
# fires `sendRoute` (src/router.ts) — which calls the channel provider
# (stub providers in dev mode return immediately) and updates the
# notification status to DELIVERED/FAILED. The endpoint returns the
# notification synchronously with status "PENDING" (set in
# channelRouter.resolve before the send completes); the terminal
# status is written by the fire-and-forget `sendRoute` promise, so the
# caller must poll GET /v1/notifications/{id} to observe it.
#
# This test follows the Option 1 per-service direct trigger approach
# from .github/docs/E2E_ASYNC_COVERAGE_PLAN.md:
#   - Trigger:  POST /v1/notifications/send on notifier (port 8092)
#   - Verify:   GET /v1/notifications/{id} on notifier
#               (status = DELIVERED/PENDING/FAILED)
#
# Terminal status values (src/router.ts sendRoute): "DELIVERED" on
# success, "FAILED" on channel error; "THROTTLED" is mapped back to
# "PENDING" so the notification stays retryable (non-terminal). The
# status field is uppercase on both GET endpoints (overall_status on
# /status, notification.status on the detail endpoint).
#
# Assumption: dev mode uses stub channel providers (StubSesProvider
# etc.) whose `send()` resolves on the next microtask, so a single
# follow-up GET is usually sufficient to observe DELIVERED. We still
# retry a small number of times to tolerate the fire-and-forget
# `sendRoute` promise settling after the POST response. If KAFKA_BROKERS
# is wired (full stack), the audit.v1 emission exercises the Kafka
# producer path; otherwise the recording emitter captures the event
# in-memory and the test still passes.

# --- notifier: health check (port 8092) ---

GET http://localhost:8092/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8092/readyz
HTTP 200
[Asserts]
jsonpath "$.ready" == true

# --- trigger: manual send on notifier ---
# Uses the same request shape as notifier/notifications.hurl: channel,
# recipient, event_type, user_id, data. event_id is minted per run via
# {{newUuid}} so dedupe state never collides across runs.

POST http://localhost:8092/v1/notifications/send
Content-Type: application/json
{
  "event_id": "e2e-async-nf-{{newUuid}}",
  "channel": "EMAIL",
  "recipient": "e2e-async-nf@example.com",
  "event_type": "payment.captured",
  "user_id": "e2e-async-nf-user",
  "data": {"tx_id": "tx-e2e-async-nf", "amount": "100", "currency": "USD", "user_name": "E2E"}
}
HTTP 201
[Captures]
e2e_notif_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.channel" == "EMAIL"
jsonpath "$.event_type" == "payment.captured"
# The POST returns the notification with the PENDING status set in
# channelRouter.resolve before sendRoute completes delivery.
jsonpath "$.status" == "PENDING"

# --- verify: notification persisted and queryable ---
# manualSend calls store.addNotification synchronously inside
# channelRouter.resolve, so the row is queryable immediately even
# before the fire-and-forget sendRoute settles.

GET http://localhost:8092/v1/notifications/{{e2e_notif_id}}
HTTP 200
[Asserts]
jsonpath "$.notification.id" == "{{e2e_notif_id}}"
jsonpath "$.notification.channel" == "EMAIL"
jsonpath "$.notification.recipient" == "e2e-async-nf@example.com"
jsonpath "$.notification.event_type" == "payment.captured"
jsonpath "$.notification.status" exists

# --- verify: poll status endpoint until terminal ---
# sendRoute is fired with `void` (not awaited) by manualSend, so the
# terminal status (DELIVERED/FAILED) is written after the POST returns.
# We poll GET /v1/notifications/{id}/status a few times; the stub
# providers resolve immediately, so the first poll almost always
# observes the terminal state. "PENDING" is treated as in-flight and
# re-queried; "DELIVERED"/"FAILED" are terminal.

GET http://localhost:8092/v1/notifications/{{e2e_notif_id}}/status
HTTP 200
[Asserts]
jsonpath "$.notification_id" == "{{e2e_notif_id}}"
jsonpath "$.overall_status" exists
# Accept the common terminal outcomes from the stub provider path.
# DELIVERED is the happy path; FAILED is also terminal (e.g. if a
# provider env var is missing). PENDING/THROTTLED would mean delivery
# is still in flight and we'd retry below.
jsonpath "$.overall_status" != ""

# Retry once more in case the first poll caught the still-PENDING
# fire-and-forget result. After this, the stub provider should have
# resolved and the status should be terminal.

GET http://localhost:8092/v1/notifications/{{e2e_notif_id}}/status
HTTP 200
[Asserts]
jsonpath "$.notification_id" == "{{e2e_notif_id}}"
jsonpath "$.overall_status" != "PENDING"

# --- verify: final state of the notification detail ---
# Confirm the same terminal status is reflected on the notification
# object itself (not just the status aggregate), proving the
# in-memory store was updated by sendRoute.

GET http://localhost:8092/v1/notifications/{{e2e_notif_id}}
HTTP 200
[Asserts]
jsonpath "$.notification.id" == "{{e2e_notif_id}}"
jsonpath "$.notification.status" != "PENDING"
# sent_at is populated by sendRoute once delivery settles (success or
# failure); it is null only while the notification is still PENDING.
jsonpath "$.notification.sent_at" exists

# --- verify: the notification shows up in the list view ---

GET http://localhost:8092/v1/notifications
HTTP 200
[Asserts]
jsonpath "$.notifications" count >= 1
jsonpath "$.notifications[?@.id=='{{e2e_notif_id}}'].id" exists