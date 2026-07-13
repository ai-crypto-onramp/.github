# rail-connectors (port 8097): dummy rail connector for authorize, capture,
# refund, status, and webhooks. Payment IDs are fresh per run.

GET http://localhost:8097/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8097/readyz
HTTP 200

# --- authorize ---

POST http://localhost:8097/v1/authorize
Content-Type: application/json
{
  "rail": "card",
  "amount": 100.00,
  "currency": "USD",
  "payer_ref": "hurl-payer-{{newUuid}}"
}
HTTP 200
[Captures]
payment_id: jsonpath "$.rail_ref"
[Asserts]
jsonpath "$.status" == "authorized"
jsonpath "$.rail_ref" exists

# --- status ---

GET http://localhost:8097/v1/status/{{payment_id}}
HTTP 200
[Asserts]
jsonpath "$.status" == "authorized"

# non-existent payment -> 404
GET http://localhost:8097/v1/status/rail_doesnotexist
HTTP 404

# --- capture ---

POST http://localhost:8097/v1/capture/{{payment_id}}
Content-Type: application/json
{
  "amount": 100.00
}
HTTP 200
[Asserts]
jsonpath "$.status" == "captured"

# --- refund ---

POST http://localhost:8097/v1/refund/{{payment_id}}
Content-Type: application/json
{
  "amount": 50.00
}
HTTP 200
[Asserts]
jsonpath "$.status" == "refunded"

# --- webhook: invalid signature -> 401 ---

POST http://localhost:8097/webhooks/card
Content-Type: application/json
X-Webhook-Signature: invalid-signature
{
  "event": "test"
}
HTTP 401
