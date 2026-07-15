# e2e-kafka: create a transaction and verify a saga event was
# produced on the "transactions" topic.
#
# The transaction-orchestrator emits outbox events on state transitions
# (step start/success, terminal states). The outbox relay polls every
# 100ms and publishes to Kafka.

# --- setup consumer for "transactions" topic ---

DELETE http://localhost:8105/consumers/e2e-txo-run/instances/c
HTTP *

POST http://localhost:8105/consumers/e2e-txo-run
Content-Type: application/vnd.kafka.json.v2+json
{
  "name": "c",
  "format": "json",
  "auto.offset.reset": "latest",
  "auto.commit.enable": "false"
}
HTTP 200

POST http://localhost:8105/consumers/e2e-txo-run/instances/c/subscription
Content-Type: application/vnd.kafka.json.v2+json
{
  "topics": ["transactions"]
}
HTTP 204

# Drain poll to establish position at the current end of the topic.
GET http://localhost:8105/consumers/e2e-txo-run/instances/c/records?timeout=500&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *

# --- trigger: create a transaction ---

POST http://localhost:8099/v1/transactions
Content-Type: application/json
{
  "user_id": "e2e-kafka-user",
  "quote_id": "e2e-kafka-{{newUuid}}",
  "amount": "100",
  "asset": "BTC",
  "rail": "card",
  "dest_address": "0xe2ekafkatest"
}
HTTP 201
[Captures]
e2e_tx_id: jsonpath "$.tx_id"
[Asserts]
jsonpath "$.tx_id" exists

# --- verify: at least one saga event arrived on "transactions" ---

GET http://localhost:8105/consumers/e2e-txo-run/instances/c/records?timeout=10000&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *
[Asserts]
status == 200
jsonpath "$" count >= 1
jsonpath "$[0].value.tx_id" == "{{e2e_tx_id}}"
jsonpath "$[0].value.event_type" exists

# --- cleanup ---

DELETE http://localhost:8105/consumers/e2e-txo-run/instances/c
HTTP *
