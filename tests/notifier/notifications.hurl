# notification (port 8092): preferences CRUD, event ingestion, manual
# sends with dedupe, delivery status, and partner webhook registration.
# Event ids are generated per run ({{newUuid}}), so dedupe state never
# collides across runs.

GET http://localhost:8092/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8092/readyz
HTTP 200
[Asserts]
jsonpath "$.ready" == true

# --- preferences ---

POST http://localhost:8092/v1/preferences/hurl-user
Content-Type: application/json
{
  "channels": {"EMAIL": true, "SMS": false, "PUSH": true, "WEBHOOK": false},
  "locale": "en"
}
HTTP 201
[Asserts]
jsonpath "$.user_id" == "hurl-user"
jsonpath "$.channels.EMAIL" == true
jsonpath "$.channels.SMS" == false

GET http://localhost:8092/v1/preferences/hurl-user
HTTP 200
[Asserts]
jsonpath "$.locale" == "en"
jsonpath "$.channels.PUSH" == true

# unknown channels are rejected
POST http://localhost:8092/v1/preferences/hurl-user
Content-Type: application/json
{
  "channels": {"CARRIER_PIGEON": true}
}
HTTP 400
[Asserts]
jsonpath "$.error" contains "invalid channel"

GET http://localhost:8092/v1/preferences/hurl-nobody
HTTP 404

# --- event ingestion ---

POST http://localhost:8092/v1/events
Content-Type: application/json
{
  "event_id": "hurl-{{newUuid}}",
  "event_type": "tx.created",
  "user_id": "hurl-user",
  "recipient": "hurl-user@example.com",
  "data": {"tx_id": "tx-123", "amount": "100", "currency": "USD", "user_name": "Hurl"}
}
HTTP 202
[Asserts]
jsonpath "$.accepted" == true

# events must carry a recipient
POST http://localhost:8092/v1/events
Content-Type: application/json
{
  "event_id": "hurl-{{newUuid}}",
  "event_type": "tx.created",
  "user_id": "hurl-user"
}
HTTP 400
[Asserts]
jsonpath "$.error" contains "recipient required"

# --- manual send + status ---

POST http://localhost:8092/v1/notifications/send
Content-Type: application/json
{
  "event_id": "hurl-{{newUuid}}",
  "channel": "EMAIL",
  "recipient": "hurl-user@example.com",
  "event_type": "payment.captured",
  "user_id": "hurl-user",
  "data": {"tx_id": "tx-123", "amount": "100", "currency": "USD", "user_name": "Hurl"}
}
HTTP 201
[Captures]
notification_id: jsonpath "$.id"
sent_event_id: jsonpath "$.event_id"
[Asserts]
jsonpath "$.channel" == "EMAIL"
jsonpath "$.event_type" == "payment.captured"

# the same (event, channel, recipient) is deduplicated
POST http://localhost:8092/v1/notifications/send
Content-Type: application/json
{
  "event_id": "{{sent_event_id}}",
  "channel": "EMAIL",
  "recipient": "hurl-user@example.com",
  "event_type": "payment.captured"
}
HTTP 400
[Asserts]
jsonpath "$.error" contains "duplicate"

GET http://localhost:8092/v1/notifications/{{notification_id}}
HTTP 200
[Asserts]
jsonpath "$.notification.id" == "{{notification_id}}"

GET http://localhost:8092/v1/notifications/{{notification_id}}/status
HTTP 200
[Asserts]
jsonpath "$.notification_id" == "{{notification_id}}"
jsonpath "$.overall_status" exists

GET http://localhost:8092/v1/notifications/ntf_doesnotexist
HTTP 404

# --- partner webhooks ---

POST http://localhost:8092/v1/webhooks/partners
Content-Type: application/json
{
  "url": "https://partner.example.com/hooks/tx",
  "secret": "hurl-partner-secret",
  "retry_policy": {"max_attempts": 1, "backoff_ms": [0]}
}
HTTP 201
[Captures]
webhook_id: jsonpath "$.id"

GET http://localhost:8092/v1/webhooks/partners
HTTP 200
[Asserts]
jsonpath "$.webhooks" count >= 1

# secret is mandatory
POST http://localhost:8092/v1/webhooks/partners
Content-Type: application/json
{
  "url": "https://partner.example.com/hooks/tx"
}
HTTP 400
[Asserts]
jsonpath "$.error" == "secret required"

POST http://localhost:8092/v1/webhooks/partners/{{webhook_id}}/confirm
Content-Type: application/json
{
  "notification_id": "{{notification_id}}",
  "status": "delivered"
}
HTTP 200
[Asserts]
jsonpath "$.confirmed" == true

# --- audit trail ---

GET http://localhost:8092/v1/audit-events
HTTP 200
[Asserts]
jsonpath "$.events" count >= 1

# --- list notifications ---

GET http://localhost:8092/v1/notifications
HTTP 200
[Asserts]
jsonpath "$.notifications" count >= 1
jsonpath "$.notifications[?@.id=='{{notification_id}}'].id" exists

# --- manual webhook delivery + signature verification ---

# manual delivery against the registered partner webhook. Uses
# simulate_failure to skip the real HTTP POST to the unreachable partner URL
# (otherwise the 10s fetch timeout × retry backoff hangs the suite); the
# endpoint still returns 200 with the backoff/delivery result, exercising the
# handler + retry accounting path.
POST http://localhost:8092/v1/webhooks/partners/{{webhook_id}}/deliver
Content-Type: application/json
{
  "payload": {"event": "tx.created", "notification_id": "{{notification_id}}"},
  "simulate_failure": true
}
HTTP 200
[Asserts]
jsonpath "$.delivered" == false
jsonpath "$.attempts" exists

# webhook signature verifier (HMAC-SHA256 over "<ts>.<raw_body>"). The
# timestamp + signature pair is minted per run by scripts/gen-webhook-sig.py
# using the same secret as the partner webhook registered above, so the
# verifier accepts it on every run.
POST http://localhost:8092/v1/webhooks/verify
Content-Type: application/json
{
  "secret": "hurl-partner-secret",
  "raw_body": "{\"event\":\"tx.created\",\"id\":\"hurl-verify\"}",
  "timestamp": "{{webhook_ts}}",
  "signature": "{{webhook_sig}}"
}
HTTP 200
[Asserts]
jsonpath "$.valid" == true

# a wrong secret is rejected (valid:false, still 200 — the endpoint only
# reports the verification result, it never errors out).
POST http://localhost:8092/v1/webhooks/verify
Content-Type: application/json
{
  "secret": "wrong-secret",
  "raw_body": "{\"event\":\"tx.created\",\"id\":\"hurl-verify\"}",
  "timestamp": "{{webhook_ts}}",
  "signature": "{{webhook_sig}}"
}
HTTP 200
[Asserts]
jsonpath "$.valid" == false
