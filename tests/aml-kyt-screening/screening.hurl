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
jsonpath "$.decision" == "allow"
jsonpath "$.exposure" == "clean"

# PostgREST: confirm the screen row landed in aml_kyt.kyt_screens
GET http://localhost:3003/kyt_screens?screen_id=eq.{{screen_id}}
HTTP 200
[Asserts]
jsonpath "$[0].screen_id" == "{{screen_id}}"
jsonpath "$[0].decision" == "allow"
jsonpath "$[0].exposure" == "clean"

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
jsonpath "$.decision" == "allow"
jsonpath "$.cache_hit" == true

# malformed body is rejected
POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
`{not json`
HTTP 400
[Asserts]
jsonpath "$.error.code" == "bad_json"

# --- vendor webhooks (TRM, HMAC-signed) ---

# signed reclassification is accepted (duplicate on re-runs, still accepted)
POST http://localhost:8081/v1/webhooks/trm
X-Webhook-Signature: b7b89bb9316cc54626fd1e21773e4409d8e0a8f6af8dc70eac63374c7410caaa
`{"event_id":"hurl-evt-1","address":"0xhurlbad1","chain":"ethereum","exposure":"sanctioned","tx_id":"hurl-tx-wh1"}`
HTTP 200
[Asserts]
jsonpath "$.accepted" == true
jsonpath "$.event_id" == "hurl-evt-1"

# replaying the same event is deduplicated
POST http://localhost:8081/v1/webhooks/trm
X-Webhook-Signature: b7b89bb9316cc54626fd1e21773e4409d8e0a8f6af8dc70eac63374c7410caaa
`{"event_id":"hurl-evt-1","address":"0xhurlbad1","chain":"ethereum","exposure":"sanctioned","tx_id":"hurl-tx-wh1"}`
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

# PostgREST: confirm the alert row landed in aml_kyt.kyt_alerts
# Status may be open or in_review (assign persists across re-runs with DB)
GET http://localhost:3003/kyt_alerts?id=eq.{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$[0].id" == "{{alert_id}}"
jsonpath "$[0].exposure" == "sanctioned"
jsonpath "$[0].status" matches "^(open|in_review)$"

# assign moves the alert to in_review (never closed, so re-runs keep working)
POST http://localhost:8081/v1/kyt/alerts/{{alert_id}}/assign
Content-Type: application/json
{
  "assignee": "hurl-analyst"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "in_review"
jsonpath "$.assignee" == "hurl-analyst"

# PostgREST: alert status should now be in_review
GET http://localhost:3003/kyt_alerts?id=eq.{{alert_id}}
HTTP 200
[Asserts]
jsonpath "$[0].status" == "in_review"
jsonpath "$[0].assignee" == "hurl-analyst"

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