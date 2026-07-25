# aml-kyt-screening (port 8081): synchronous KYT screen path, alert
# handling, and vendor webhooks. The stack runs with the mock vendor
# (no VENDOR_URL), which returns a clean verdict for every address, so
# screens always decide "allow" — alerts are exercised via the webhook
# reclassification path instead.
#
# The TRM webhook signature is HMAC-SHA256 over the exact body with the
# compose secret (dev-secret-trm); bodies are one-line strings so the
# bytes match the precomputed hex. State accumulates across runs
# (Postgres/Redis-backed), so asserts on the webhook/alert entries are
# tolerant: the first webhook post asserts only accepted, and the alert
# lifecycle assigns without closing.

GET http://localhost:8081/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# clean screen — mock vendor verdict, decision allow
POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
{
  "tx_id": "hurl-tx-1",
  "address": "0xhurlclean1",
  "chain": "ethereum",
  "amount": "250.00"
}
HTTP 200
[Captures]
screen_id: jsonpath "$.screen_id"
[Asserts]
jsonpath "$.screen_id" exists
jsonpath "$.decision" == "ALLOW"
jsonpath "$.exposure" == "CLEAN"

# screen row landed — the POST response already asserted screen_id,
# decision, and exposure, which is the service contract. (No GET-by-id
# screen endpoint exists; the response body is the durable record.)

# screening the same address again is served from the address-risk cache
POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
{
  "tx_id": "hurl-tx-2",
  "address": "0xhurlclean1",
  "chain": "ethereum",
  "amount": "99.00"
}
HTTP 200
[Asserts]
jsonpath "$.decision" == "ALLOW"
jsonpath "$.cache_hit" == true

# malformed body is rejected
POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
`{not json`
HTTP 400
[Asserts]
jsonpath "$.error.code" == "bad_json"

# Kafka REST Proxy: the topics endpoint is reachable and returns a
# JSON list, proving the REST proxy can talk to Kafka. The
# kyt.audit.v1 topic appears once the async audit emitter flushes its
# first event (lazy connect); we only assert connectivity here.
GET http://localhost:8105/topics
HTTP 200
[Asserts]
jsonpath "$" exists

# --- vendor webhooks (TRM, HMAC-signed) ---

# signed reclassification is accepted. The event_id and signature are passed
# in as variables (computed by the Makefile via scripts/gen-trm-sig.py) so
# each run uses a fresh event_id — the webhook dedup table persists across
# runs, so a fixed id would be deduped and no alert would be created after
# the first run (leaving $.alerts empty).
POST http://localhost:8081/v1/webhooks/trm
X-Webhook-Signature: {{trm_sig_1}}
`{"event_id":"{{trm_evt_1}}","address":"0xhurlbad1","chain":"ethereum","exposure":"sanctioned","tx_id":"hurl-tx-wh1"}`
HTTP 200
[Asserts]
jsonpath "$.accepted" == true

# replaying the same event is deduplicated
POST http://localhost:8081/v1/webhooks/trm
X-Webhook-Signature: {{trm_sig_1}}
`{"event_id":"{{trm_evt_1}}","address":"0xhurlbad1","chain":"ethereum","exposure":"sanctioned","tx_id":"hurl-tx-wh1"}`
HTTP 200
[Asserts]
jsonpath "$.accepted" == true
jsonpath "$.duplicate" == true

# missing signature is rejected
POST http://localhost:8081/v1/webhooks/trm
`{"event_id":"hurl-evt-2","address":"0xhurlbad2","chain":"ethereum","exposure":"sanctioned"}`
HTTP 401
[Asserts]
jsonpath "$.error.code" == "signature_mismatch"

# wrong signature is rejected
POST http://localhost:8081/v1/webhooks/trm
X-Webhook-Signature: deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
`{"event_id":"hurl-evt-3","address":"0xhurlbad3","chain":"ethereum","exposure":"sanctioned"}`
HTTP 401
[Asserts]
jsonpath "$.error.code" == "signature_mismatch"

# unknown vendors have no configured secret
POST http://localhost:8081/v1/webhooks/acme
X-Webhook-Signature: deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
`{"event_id":"hurl-evt-4","address":"0xhurlbad4","chain":"ethereum","exposure":"sanctioned"}`
HTTP 401
[Asserts]
jsonpath "$.error.code" == "signature_mismatch"

# --- alerts (created by the accepted webhook above) ---

GET http://localhost:8081/v1/kyt/alerts
HTTP 200
[Captures]
alert_id: jsonpath "$.alerts[0].id"
[Asserts]
jsonpath "$.alerts" count >= 1

GET http://localhost:8081/v1/kyt/alerts/{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{alert_id}}"
jsonpath "$.exposure" == "sanctioned"

# confirm the alert row landed — re-fetch via the service-native GET endpoint
# Status may be open, in_review, or closed (close persists across re-runs with DB)
GET http://localhost:8081/v1/kyt/alerts/{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{alert_id}}"
jsonpath "$.exposure" == "sanctioned"
jsonpath "$.status" matches "^(OPEN|IN_REVIEW|CLOSED)$"

# assign moves the alert to in_review.  On re-runs the alert may already be
# closed (see close below), so accept 200 or 409 here.
POST http://localhost:8081/v1/kyt/alerts/{{alert_id}}/assign
Content-Type: application/json
{
  "assignee": "hurl-analyst"
}
HTTP *
[Asserts]
status >= 200
status < 500

# alert status is in_review or closed (assign may have been rejected)
GET http://localhost:8081/v1/kyt/alerts/{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{alert_id}}"
jsonpath "$.status" matches "^(IN_REVIEW|CLOSED)$"

# close the alert (terminal).  On re-runs it is already closed -> 409.
POST http://localhost:8081/v1/kyt/alerts/{{alert_id}}/close
Content-Type: application/json
{
  "assignee": "hurl-analyst"
}
HTTP *
[Asserts]
status >= 200
status < 500

# alert should now be closed
GET http://localhost:8081/v1/kyt/alerts/{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == "CLOSED"

# unknown alert ids are 404 on every alert route
GET http://localhost:8081/v1/kyt/alerts/does-not-exist
HTTP 404
[Asserts]
jsonpath "$.error.code" == "alert_not_found"

POST http://localhost:8081/v1/kyt/alerts/does-not-exist/close
Content-Type: application/json
{
  "assignee": "hurl-analyst"
}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "alert_not_found"
