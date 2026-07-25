# transaction-orchestrator (port 8099): saga engine for crypto purchases.
# Transactions are created fresh per run via UUID.

GET http://localhost:8099/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8099/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- create transaction ---

POST http://localhost:8099/v1/transactions
Authorization: Bearer {{service_token}}
Content-Type: application/json
{
  "user_id": "hurl-user",
  "quote_id": "hurl-{{newUuid}}",
  "amount": "500",
  "asset": "BTC",
  "rail": "card",
  "dest_address": "0xhurl-test"
}
HTTP 201
[Captures]
tx_id: jsonpath "$.tx_id"
[Asserts]
jsonpath "$.tx_id" exists

# fetch the transaction — verifies tx + saga state + steps all persisted
GET http://localhost:8099/v1/transactions/{{tx_id}}
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.tx_id" == "{{tx_id}}"
jsonpath "$.user_id" == "hurl-user"
jsonpath "$.amount" == "500"
jsonpath "$.asset" == "BTC"
jsonpath "$.status" == "CREATED"
jsonpath "$.current_step" == "POLICY"
jsonpath "$.steps" exists
jsonpath "$.steps" count == 6

# non-existent transaction -> 404
GET http://localhost:8099/v1/transactions/tx_doesnotexist
Authorization: Bearer {{service_token}}
HTTP 404

# --- steps ---

GET http://localhost:8099/v1/transactions/{{tx_id}}/steps
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.steps" exists
jsonpath "$.steps" count == 6

# --- retry ---

# retry a specific step on a freshly created (non-terminal) transaction
POST http://localhost:8099/v1/transactions/{{tx_id}}/retry
Authorization: Bearer {{service_token}}
Content-Type: application/json
{
  "step": "policy"
}
HTTP 202
[Asserts]
jsonpath "$.status" == "retry-accepted"
jsonpath "$.step" == "policy"

# retry without a step uses the current saga step
POST http://localhost:8099/v1/transactions/{{tx_id}}/retry
Authorization: Bearer {{service_token}}
Content-Type: application/json
{}
HTTP 202
[Asserts]
jsonpath "$.status" == "retry-accepted"

# --- compensate ---

# compensate a non-terminal transaction
POST http://localhost:8099/v1/transactions/{{tx_id}}/compensate
Authorization: Bearer {{service_token}}
HTTP 202
[Asserts]
jsonpath "$.status" == "compensate-accepted"

# compensating again may return 409 (terminal) or 202 (still processing)
POST http://localhost:8099/v1/transactions/{{tx_id}}/compensate
Authorization: Bearer {{service_token}}
HTTP *
[Asserts]
status >= 200
status < 500

# retry on a non-existent transaction -> 400 (no saga state found)
POST http://localhost:8099/v1/transactions/tx_doesnotexist/retry
Authorization: Bearer {{service_token}}
Content-Type: application/json
{"step": "policy"}
HTTP *
