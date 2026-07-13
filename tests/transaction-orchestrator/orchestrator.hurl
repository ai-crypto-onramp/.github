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

# fetch the transaction
GET http://localhost:8099/v1/transactions/{{tx_id}}
HTTP 200
[Asserts]
jsonpath "$.tx_id" == "{{tx_id}}"
jsonpath "$.status" == "created"
jsonpath "$.current_step" == "policy"
jsonpath "$.steps" exists
jsonpath "$.steps[0].step_name" == "policy"
jsonpath "$.steps[0].status" == "pending"

# non-existent transaction -> 404
GET http://localhost:8099/v1/transactions/tx_doesnotexist
HTTP 404

# --- steps ---

GET http://localhost:8099/v1/transactions/{{tx_id}}/steps
HTTP 200
[Asserts]
jsonpath "$.steps" exists
jsonpath "$.steps[0].step_name" == "policy"
jsonpath "$.steps[5].step_name" == "ledger"
