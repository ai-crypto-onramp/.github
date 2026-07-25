# engine-fraud (port 8085): fraud scoring, model registry, and chargeback feedback.
# Each run creates fresh tx_ids via {{newUuid}} so dedup state never collides.

GET http://localhost:8085/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- model registry ---

GET http://localhost:8085/v1/fraud/models
HTTP 200
[Asserts]
jsonpath "$.models" count >= 1
jsonpath "$.models[0].name" exists
jsonpath "$.models[0].champion" exists

# --- fraud scoring ---

POST http://localhost:8085/v1/fraud/score
Content-Type: application/json
{
  "tx_id": "hurl-{{newUuid}}",
  "user_id": "hurl-user",
  "payment_id": "pm-hurl",
  "amount": {"minor_units": 10000, "currency": "USD"},
  "device": {"id": "dev-hurl", "fingerprint": "fp-hurl", "user_agent": "hurl/1.0"},
  "ip": "10.0.0.1"
}
HTTP 200
[Asserts]
jsonpath "$.score" exists
jsonpath "$.risk_band" matches "^(LOW|MEDIUM|HIGH)$"
jsonpath "$.model_version" exists
jsonpath "$.scored_at" exists

# missing payment_id -> 422
POST http://localhost:8085/v1/fraud/score
Content-Type: application/json
{
  "tx_id": "hurl-bad",
  "user_id": "hurl-user"
}
HTTP 422

# --- chargeback feedback ---

POST http://localhost:8085/v1/fraud/feedback
Content-Type: application/json
{
  "tx_id": "hurl-{{newUuid}}",
  "outcome": "CHARGEBACK",
  "reason_code": "10.4",
  "reported_at": "2026-01-01T00:00:00Z"
}
HTTP 204

# invalid outcome -> 422
POST http://localhost:8085/v1/fraud/feedback
Content-Type: application/json
{
  "tx_id": "hurl-bad",
  "outcome": "BOGUS",
  "reported_at": "2026-01-01T00:00:00Z"
}
HTTP 422
