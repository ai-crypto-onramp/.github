# e2e-async: trigger a KYT screen and verify the audit event was
# ingested by the audit-logger service (no kafka-rest needed).
#
# The kyt-aml-screening service emits audit events asynchronously to the
# audit.v1 Kafka topic; the audit-logger consumes that topic and exposes
# a REST query API at GET /v1/events. We trigger a screen, then poll
# the audit-logger until the event appears.

GET http://localhost:8081/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- trigger: screen an address (mock vendor returns clean verdict) ---

POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
{
  "tx_id": "e2e-async-kyt-{{newUuid}}",
  "address": "0xe2easynckyt",
  "chain": "ethereum",
  "amount": "100.00"
}
HTTP 200
[Captures]
kyt_screen_id: jsonpath "$.screen_id"
[Asserts]
jsonpath "$.decision" == "ALLOW"

# --- verify: the audit event was ingested by audit-logger ---
# The async emitter has a bounded queue with a short flush interval,
# so we poll with a retry. Hurl has no native retry, so we issue a
# few sequential GETs — the event typically lands within 1-2s.

GET http://localhost:8082/v1/events?service=kyt-aml-screening&target_id={{kyt_screen_id}}&limit=1
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" exists

# If the first poll was too early, try again.
GET http://localhost:8082/v1/events?service=kyt-aml-screening&target_id={{kyt_screen_id}}&limit=1
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" exists

# Third poll — by now the event should have landed.
GET http://localhost:8082/v1/events?service=kyt-aml-screening&target_id={{kyt_screen_id}}&limit=1
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" count >= 1
jsonpath "$.events[0].source_service" == "kyt-aml-screening"
jsonpath "$.events[0].target_id" == "{{kyt_screen_id}}"
jsonpath "$.events[0].action" exists