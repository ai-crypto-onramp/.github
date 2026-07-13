# rail-connectors (port 8097): dummy rail connector for authorize, capture,
# refund, status, and webhooks. Uses a fixed payment_id per run.

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
  "payment_id": "hurl-pay-{{newUuid}}",
  "amount": 100.00,
  "currency": "USD",
  "payer_ref": "hurl-payer"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "authorized"
jsonpath "$.rail_ref" exists

# --- status (uses payment_id from the request, not rail_ref from response) ---
# Since we can't capture payment_id from the response, use a fixed one for
# the status/capture/refund flow below.

POST http://localhost:8097/v1/authorize
Content-Type: application/json
{
  "rail": "card",
  "payment_id": "hurl-fixed-status",
  "amount": 100.00,
  "currency": "USD",
  "payer_ref": "hurl-payer"
}
HTTP 200

GET http://localhost:8097/v1/status/hurl-fixed-status
HTTP 200
[Asserts]
jsonpath "$.status" == "authorized"

# non-existent payment -> 400 (INVALID_REQUEST)
GET http://localhost:8097/v1/status/rail_doesnotexist
HTTP 400

# --- capture ---

POST http://localhost:8097/v1/capture/hurl-fixed-status
Content-Type: application/json
{
  "amount": 100.00
}
HTTP 200
[Asserts]
jsonpath "$.status" == "captured"

# --- refund ---

POST http://localhost:8097/v1/refund/hurl-fixed-status
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
