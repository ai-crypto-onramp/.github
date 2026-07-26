# engine-pricing (port 8096): quote issuance against seeded spot rates
# and fee schedules, the 30s rate lock, atomic claim, refresh, bulk
# quotes, and validation errors. Quotes are created fresh every run,
# so the suite is idempotent.

GET http://localhost:8096/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# spot cache is seeded at boot
GET http://localhost:8096/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# issue a quote: tier_1 BTC buy in the 0-1000 band -> 80 bps spread
POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "from": "USD",
  "to": "BTC",
  "amount": "500",
  "user_tier": "TIER_1",
  "side": "BUY"
}
HTTP 201
[Captures]
quote_id: jsonpath "$.quote_id"
[Asserts]
jsonpath "$.status" == "OPEN"
jsonpath "$.spread_bps" == 80
jsonpath "$.fee_currency" == "USD"
jsonpath "$.source_venue" == "kraken"
jsonpath "$.rate" exists
jsonpath "$.expires_at" exists

GET http://localhost:8096/v1/quotes/{{quote_id}}
HTTP 200
[Asserts]
jsonpath "$.quote_id" == "{{quote_id}}"
jsonpath "$.status" == "OPEN"

# claim the quote (orchestrator-internal, within the 30s rate lock)
POST http://localhost:8096/internal/v1/quotes/{{quote_id}}/claim
Content-Type: application/json
{
  "claimed_by": "hurl-orchestrator"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "CLAIMED"
jsonpath "$.claimed_by" == "hurl-orchestrator"

# a quote can only be claimed once
POST http://localhost:8096/internal/v1/quotes/{{quote_id}}/claim
Content-Type: application/json
{
  "claimed_by": "hurl-orchestrator-2"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "already_claimed"

# refresh cancels the old quote and issues a new one
POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "from": "USD",
  "to": "ETH",
  "amount": "50",
  "user_tier": "TIER_2",
  "side": "BUY"
}
HTTP 201
[Captures]
quote_id2: jsonpath "$.quote_id"

POST http://localhost:8096/v1/quotes/{{quote_id2}}/refresh
HTTP 201
[Asserts]
jsonpath "$.quote_id" != "{{quote_id2}}"
jsonpath "$.status" == "OPEN"
jsonpath "$.from" == "USD"
jsonpath "$.to" == "ETH"

# bulk quotes: per-item results, invalid items fail individually
POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "items": [
    {"from": "USD", "to": "BTC", "amount": "100", "user_tier": "TIER_1", "side": "BUY"},
    {"from": "USD", "to": "BTC", "amount": "100", "user_tier": "TIER_99", "side": "BUY"}
  ]
}
HTTP 201
[Asserts]
jsonpath "$.items[0].ok" == true
jsonpath "$.items[1].ok" == false
jsonpath "$.items[1].error" == "invalid_tier"

# --- validation errors ---

POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "from": "USD",
  "to": "BTC",
  "amount": "-5",
  "user_tier": "TIER_1",
  "side": "BUY"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "invalid_amount"

POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "from": "us",
  "to": "BTC",
  "amount": "100",
  "user_tier": "TIER_1",
  "side": "BUY"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "invalid_currency"

POST http://localhost:8096/v1/quotes
Content-Type: application/json
{
  "from": "USD",
  "to": "BTC",
  "amount": "100",
  "user_tier": "TIER_1",
  "side": "hold"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "invalid_side"

GET http://localhost:8096/v1/quotes/q_doesnotexist
HTTP 404
[Asserts]
jsonpath "$.error.code" == "not_found"

# --- internal ops surface ---

POST http://localhost:8096/internal/v1/fee-schedules/reload
HTTP 200
[Asserts]
jsonpath "$.status" == "reloaded"

GET http://localhost:8096/v1/audit-events
HTTP 200
[Asserts]
jsonpath "$.events" count >= 1

# --- list / registry endpoints ---

# GET /v1/quotes: list all issued quotes (newest first). Quotes issued
# earlier in this run must be present.
GET http://localhost:8096/v1/quotes
HTTP 200
[Asserts]
jsonpath "$.quotes" count >= 1
jsonpath "$.quotes[0].quote_id" exists
jsonpath "$.quotes[0].from" exists
jsonpath "$.quotes[0].to" exists
jsonpath "$.quotes[0].status" exists

# GET /v1/fee-schedules: in-effect spread/fee schedules, seeded at boot.
GET http://localhost:8096/v1/fee-schedules
HTTP 200
[Asserts]
jsonpath "$.fee_schedules" count >= 1
jsonpath "$.fee_schedules[0].id" exists
jsonpath "$.fee_schedules[0].user_tier" exists
jsonpath "$.fee_schedules[0].asset" exists
jsonpath "$.fee_schedules[0].spread_bps" exists
jsonpath "$.fee_schedules[0].enabled" isBoolean

# GET /v1/rate-sources: enabled upstream venues, ordered by priority.
GET http://localhost:8096/v1/rate-sources
HTTP 200
[Asserts]
jsonpath "$.rate_sources" exists
