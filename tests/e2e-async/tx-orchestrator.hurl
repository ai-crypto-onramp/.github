# e2e-async: create a transaction and verify the saga state + steps
# were persisted, proving the orchestrator's outbox + saga engine
# wrote durable state (no kafka-rest needed).
#
# The orchestrator emits outbox events on state transitions (step
# start/success, terminal states). The outbox relay polls every 100ms
# and publishes to Kafka. In dev mode the saga stays at the POLICY step
# (partner stubs don't drive it forward), but the transaction, saga_state,
# and transaction_steps rows are all persisted — we verify via the
# service-native GET endpoints.

GET http://localhost:8099/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- trigger: create a transaction ---

POST http://localhost:8099/v1/transactions
Authorization: Bearer {{service_token}}
Content-Type: application/json
{
  "user_id": "e2e-async-user",
  "quote_id": "e2e-async-{{newUuid}}",
  "amount": "100",
  "asset": "BTC",
  "rail": "card",
  "dest_address": "0xe2easynctest"
}
HTTP 201
[Captures]
e2e_tx_id: jsonpath "$.tx_id"
[Asserts]
jsonpath "$.tx_id" exists

# --- verify: transaction persisted with saga state ---

GET http://localhost:8099/v1/transactions/{{e2e_tx_id}}
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.tx_id" == "{{e2e_tx_id}}"
jsonpath "$.status" == "CREATED"
jsonpath "$.current_step" == "POLICY"
jsonpath "$.state" == "CREATED"
jsonpath "$.steps" exists
jsonpath "$.steps" count == 6

# --- verify: steps are individually queryable ---

GET http://localhost:8099/v1/transactions/{{e2e_tx_id}}/steps
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.steps" exists
jsonpath "$.steps" count == 6