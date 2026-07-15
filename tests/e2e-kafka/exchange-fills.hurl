# e2e-kafka: end-to-end tests that trigger a service HTTP endpoint and
# then verify the expected Kafka message was produced via the Confluent
# REST Proxy (port 8105).
#
# Pattern (1 partition per topic, 24h retention):
#   1. Delete any leftover consumer instance (idempotent).
#   2. Create a consumer with auto.offset.reset=latest, no auto-commit.
#   3. Subscribe to the target topic.
#   4. Drain poll (500ms) to establish position at the current end.
#   5. Trigger the service HTTP endpoint.
#   6. Poll for new records (10s timeout) and assert on the payload.
#   7. Delete the consumer instance (cleanup).
#
# With a single partition, latest positions cleanly at the end after
# the drain, so the next poll only sees the newly produced message.

# ========================================================================
# Test 1: exchange-connectors — POST /v1/orders produces a FillEvent
#          on the "recon" topic.
# ========================================================================

# --- setup consumer for "recon" topic ---

DELETE http://localhost:8105/consumers/e2e-exchange-run/instances/c
HTTP *

POST http://localhost:8105/consumers/e2e-exchange-run
Content-Type: application/vnd.kafka.json.v2+json
{
  "name": "c",
  "format": "json",
  "auto.offset.reset": "latest",
  "auto.commit.enable": "false"
}
HTTP 200

POST http://localhost:8105/consumers/e2e-exchange-run/instances/c/subscription
Content-Type: application/vnd.kafka.json.v2+json
{
  "topics": ["recon"]
}
HTTP 204

# Drain poll to establish position at the current end of the topic.
GET http://localhost:8105/consumers/e2e-exchange-run/instances/c/records?timeout=500&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *

# --- trigger: place an order (dummy venue returns immediate fill) ---

POST http://localhost:8084/v1/orders
Content-Type: application/json
{
  "venue": "binance",
  "pair": "BTC/USD",
  "side": "buy",
  "type": "market",
  "amount": "1.0"
}
HTTP 200
[Captures]
fill_order_id: jsonpath "$.venue_order_id"

# --- verify: a FillEvent arrived on the "recon" topic ---

GET http://localhost:8105/consumers/e2e-exchange-run/instances/c/records?timeout=10000&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *
[Asserts]
status == 200
jsonpath "$" count >= 1
jsonpath "$[0].value.venue_order_id" == "{{fill_order_id}}"
jsonpath "$[0].value.venue" == "dummy"
jsonpath "$[0].value.pair" == "BTC/USD"

# --- cleanup ---

DELETE http://localhost:8105/consumers/e2e-exchange-run/instances/c
HTTP *
