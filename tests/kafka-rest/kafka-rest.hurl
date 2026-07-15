# kafka-rest (port 8088): Confluent REST Proxy over the shared Kafka
# broker. This suite exercises the HTTP produce/consume round-trip so
# the proxy is covered independently of any service.
#
# The v2 JSON API uses content type
#   application/vnd.kafka.json.v2+json
# for both produce and consume. Consume requires a consumer instance
# created via POST /consumers/{group}; subsequent calls address the
# instance at /consumers/{group}/instances/{instance}. We use a fixed
# instance id and delete it on cleanup so re-runs start fresh.

# --- produce ---

# Create the hurl test topic (idempotent).
POST http://localhost:8105/topics/hurl-test
Content-Type: application/vnd.kafka.json.v2+json
{
  "records": [
    {"key": "k1", "value": {"msg": "hello kafka"}},
    {"key": "k2", "value": {"msg": "second record"}}
  ]
}
HTTP 200
[Asserts]
jsonpath "$.offsets[0].error" == null
jsonpath "$.offsets[0].partition" exists
jsonpath "$.offsets[1].error" == null

# --- consume ---

# Delete any leftover consumer instance from a prior run (204 on success,
# 404 if absent — both fine).
DELETE http://localhost:8105/consumers/hurl-test-group/instances/hurl-consumer
HTTP *

# Create a consumer instance in a dedicated group.
POST http://localhost:8105/consumers/hurl-test-group
Content-Type: application/vnd.kafka.json.v2+json
{
  "name": "hurl-consumer",
  "format": "json",
  "auto.offset.reset": "earliest",
  "auto.commit.enable": "false"
}
HTTP 200

# Subscribe the consumer instance to the hurl-test topic.
POST http://localhost:8105/consumers/hurl-test-group/instances/hurl-consumer/subscription
Content-Type: application/vnd.kafka.json.v2+json
{
  "topics": ["hurl-test"]
}
HTTP 204

# Drain records (poll). At least one record should arrive quickly.
GET http://localhost:8105/consumers/hurl-test-group/instances/hurl-consumer/records?timeout=5000&max_bytes=1048576
Accept: application/vnd.kafka.json.v2+json
HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].value.msg" exists

# Delete the consumer instance (cleanup).
DELETE http://localhost:8105/consumers/hurl-test-group/instances/hurl-consumer
HTTP 204