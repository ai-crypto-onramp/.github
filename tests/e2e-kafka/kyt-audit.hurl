# e2e-kafka: trigger a KYT screen and verify an audit.Event was
# produced on the "kyt.audit.v1" topic.
#
# The aml-kyt-screening service emits audit events asynchronously via
# a bounded-queue emitter, so the Kafka message may arrive a few
# hundred milliseconds after the HTTP response.

# --- setup consumer for "kyt.audit.v1" topic ---

DELETE http://localhost:8105/consumers/e2e-kyt-run/instances/c
HTTP *

POST http://localhost:8105/consumers/e2e-kyt-run
Content-Type: application/vnd.kafka.json.v2+json
{
  "name": "c",
  "format": "json",
  "auto.offset.reset": "latest",
  "auto.commit.enable": "false"
}
HTTP 200

POST http://localhost:8105/consumers/e2e-kyt-run/instances/c/subscription
Content-Type: application/vnd.kafka.json.v2+json
{
  "topics": ["kyt.audit.v1"]
}
HTTP 204

# Drain poll to establish position at the current end of the topic.
GET http://localhost:8105/consumers/e2e-kyt-run/instances/c/records?timeout=500&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *

# --- trigger: screen an address (mock vendor returns clean verdict) ---

POST http://localhost:8081/v1/kyt/screen
Content-Type: application/json
{
  "tx_id": "e2e-kafka-tx-{{newUuid}}",
  "address": "0xe2ekafkaclean",
  "chain": "ethereum",
  "amount": "100.00"
}
HTTP 200
[Captures]
kyt_screen_id: jsonpath "$.screen_id"
[Asserts]
jsonpath "$.decision" == "allow"

# --- verify: an audit.Event arrived on "kyt.audit.v1" ---

GET http://localhost:8105/consumers/e2e-kyt-run/instances/c/records?timeout=10000&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP *
[Asserts]
status == 200
jsonpath "$" count >= 1
jsonpath "$[0].value.screen_id" == "{{kyt_screen_id}}"
jsonpath "$[0].value.decision" == "allow"
jsonpath "$[0].value.address" == "0xe2ekafkaclean"
jsonpath "$[0].value.chain" == "ethereum"

# --- cleanup ---

DELETE http://localhost:8105/consumers/e2e-kyt-run/instances/c
HTTP *
