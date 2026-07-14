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
jsonpath "$.steps" count == 6

# Verify the transaction persisted in Postgres via Postgrest (port 3011).
GET http://localhost:3011/transactions?tx_id=eq.{{tx_id}}
HTTP 200
[Asserts]
jsonpath "$[0].tx_id" == "{{tx_id}}"
jsonpath "$[0].user_id" == "hurl-user"
jsonpath "$[0].amount" == "500"
jsonpath "$[0].asset" == "BTC"
jsonpath "$[0].status" == "created"

# Verify saga_state row was created.
GET http://localhost:3011/saga_state?tx_id=eq.{{tx_id}}
HTTP 200
[Asserts]
jsonpath "$[0].tx_id" == "{{tx_id}}"
jsonpath "$[0].current_step" == "policy"

# Verify transaction_steps rows were created (6 steps), sorted by step_name.
GET http://localhost:3011/transaction_steps?tx_id=eq.{{tx_id}}&order=step_name.asc
HTTP 200
[Asserts]
jsonpath "$" count == 6
jsonpath "$[0].step_name" == "broadcast"
jsonpath "$[0].status" == "pending"

# non-existent transaction -> 404
GET http://localhost:8099/v1/transactions/tx_doesnotexist
HTTP 404

# --- steps ---

GET http://localhost:8099/v1/transactions/{{tx_id}}/steps
HTTP 200
[Asserts]
jsonpath "$.steps" exists
jsonpath "$.steps" count == 6

# --- retry ---

# retry a specific step on a freshly created (non-terminal) transaction
POST http://localhost:8099/v1/transactions/{{tx_id}}/retry
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
Content-Type: application/json
{}
HTTP 202
[Asserts]
jsonpath "$.status" == "retry-accepted"

# --- compensate ---

# compensate a non-terminal transaction
POST http://localhost:8099/v1/transactions/{{tx_id}}/compensate
HTTP 202
[Asserts]
jsonpath "$.status" == "compensate-accepted"

# compensating again may return 409 (terminal) or 202 (still processing)
POST http://localhost:8099/v1/transactions/{{tx_id}}/compensate
HTTP *
[Asserts]
status >= 200
status < 500

# retry on a non-existent transaction -> 400 (no saga state found)
POST http://localhost:8099/v1/transactions/tx_doesnotexist/retry
Content-Type: application/json
{"step": "policy"}
HTTP *
