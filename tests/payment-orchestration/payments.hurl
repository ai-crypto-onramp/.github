# payment-orchestration (port 8094): payment intents with dummy rail adapter.
# Intents are created fresh every run via UUID, so the suite is idempotent.

GET http://localhost:8094/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8094/readyz
HTTP 200

# --- create a card intent (auto-authorized) ---

POST http://localhost:8094/v1/payments/intents
Content-Type: application/json
{
  "rail": "card",
  "amount": "100.00",
  "currency": "USD",
  "payer_ref": "hurl-payer-{{newUuid}}"
}
HTTP 201
[Captures]
payment_id: jsonpath "$.id"
[Asserts]
jsonpath "$.rail" == "card"
jsonpath "$.amount" == "100.00"
jsonpath "$.currency" == "USD"
jsonpath "$.status" == "authorized"

# fetch the intent
GET http://localhost:8094/v1/payments/{{payment_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{payment_id}}"
jsonpath "$.status" == "authorized"
jsonpath "$.lifecycle" exists

# non-existent intent -> 404
GET http://localhost:8094/v1/payments/pm_doesnotexist
HTTP 404

# --- capture ---

POST http://localhost:8094/v1/payments/{{payment_id}}/capture
Content-Type: application/json
{
  "amount": "100.00"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "captured"

# --- refund ---

POST http://localhost:8094/v1/payments/{{payment_id}}/refund
Content-Type: application/json
{
  "amount": "50.00"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "refunded"

# --- 3DS flow: create a card intent requiring 3DS ---

POST http://localhost:8094/v1/payments/intents
Content-Type: application/json
{
  "rail": "card",
  "amount": "200.00",
  "currency": "USD",
  "payer_ref": "hurl-payer-{{newUuid}}",
  "three_ds_required": true
}
HTTP 201
[Captures]
ds_payment_id: jsonpath "$.id"
[Asserts]
jsonpath "$.status" == "3ds_pending"

# resume from 3DS challenge
POST http://localhost:8094/v1/payments/{{ds_payment_id}}/3ds-challenge
Content-Type: application/json
{
  "result": "success"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "authorized"

# --- webhook ingestion: invalid signature -> 401 ---

POST http://localhost:8094/v1/webhooks/card
Content-Type: application/json
X-Webhook-Signature: invalid-signature
{
  "event": "test"
}
HTTP 401
