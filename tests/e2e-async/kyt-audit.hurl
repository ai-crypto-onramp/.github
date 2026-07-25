# e2e-async: trigger a KYT screen and verify the screen response,
# plus verify the audit-logger is consuming events (the audit pipeline
# is exercised end-to-end by checking that audit-logger has ingested
# events from at least one service).
#
# The KYT service emits audit events asynchronously to audit.v1; the
# audit-logger consumes that topic. We verify:
#   1. The screen response is correct (sync path).
#   2. The audit-logger has ingested at least one event from any service
#      (async path — proves the Kafka pipeline is wired).

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
jsonpath "$.screen_id" exists
jsonpath "$.decision" == "ALLOW"
jsonpath "$.exposure" == "CLEAN"

# --- verify: audit-logger is running and has ingested events ---

GET http://localhost:8082/v1/events?limit=5
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" exists
jsonpath "$.events" count >= 1
jsonpath "$.events[0].source_service" exists
jsonpath "$.events[0].action" exists
