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
  "channels": {"email": true, "sms": false, "push": true, "webhook": false},
  "locale": "en"
}
HTTP 201
[Asserts]
jsonpath "$.user_id" == "hurl-user"
jsonpath "$.channels.email" == true
jsonpath "$.channels.sms" == false

GET http://localhost:8092/v1/preferences/hurl-user
HTTP 200
[Asserts]
jsonpath "$.locale" == "en"
jsonpath "$.channels.push" == true

# unknown channels are rejected
POST http://localhost:8092/v1/preferences/hurl-user
Content-Type: application/json
{
  "channels": {"carrier-pigeon": true}
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
  "channel": "email",
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
jsonpath "$.channel" == "email"
jsonpath "$.event_type" == "payment.captured"

# the same (event, channel, recipient) is deduplicated
POST http://localhost:8092/v1/notifications/send
Content-Type: application/json
{
  "event_id": "{{sent_event_id}}",
  "channel": "email",
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
  "secret": "hurl-partner-secret"
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
