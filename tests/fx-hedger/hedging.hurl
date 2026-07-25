# fx-hedging (port 8086): dummy FX provider for exposure tracking, hedge
# execution, P&L, and slippage. Hedges are created fresh per run.

GET http://localhost:8086/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8086/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- exposure tracking ---
# Use a unique currency per run to avoid accumulating exposure across
# test runs (the exposure cap is global per currency).

POST http://localhost:8086/v1/exposure/X{{newUuid}}
Content-Type: application/json
{
  "amount": "250000"
}
HTTP 200
[Captures]
exp_currency: jsonpath "$.currency"
[Asserts]
jsonpath "$.currency" exists
jsonpath "$.net_amount" >= "250000"

GET http://localhost:8086/v1/exposure/{{exp_currency}}
HTTP 200
[Asserts]
jsonpath "$.currency" == "{{exp_currency}}"
jsonpath "$.net_amount" >= "250000"

# zero exposure for unknown currency
GET http://localhost:8086/v1/exposure/JPY
HTTP 200
[Asserts]
jsonpath "$.net_amount" == "0"

# --- hedge execution ---

POST http://localhost:8086/v1/hedges
Content-Type: application/json
{
  "currency": "EUR",
  "notional": "225000",
  "tenor": "SPOT",
  "type": "SPOT"
}
HTTP 201
[Captures]
hedge_id: jsonpath "$.id"
[Asserts]
jsonpath "$.currency" == "EUR"
jsonpath "$.notional" == "225000"
jsonpath "$.status" == "EXECUTED"
jsonpath "$.quoted_rate" == "1.1"
jsonpath "$.fills[0].price" == "1.1"

# fetch the hedge
GET http://localhost:8086/v1/hedges/{{hedge_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{hedge_id}}"
jsonpath "$.status" == "EXECUTED"
jsonpath "$.fills" exists

# non-existent hedge -> 404
GET http://localhost:8086/v1/hedges/hedge_doesnotexist
HTTP 404

# --- P&L ---

GET http://localhost:8086/v1/pnl
HTTP 200
[Asserts]
jsonpath "$.by_currency" exists
jsonpath "$.total" exists

# --- slippage ---

GET http://localhost:8086/v1/slippage?pair=EUR/USD
HTTP 200
[Asserts]
jsonpath "$.pair" == "EUR/USD"
jsonpath "$.aggregates" exists

# --- settlement ---

GET http://localhost:8086/v1/settlement
HTTP 200
[Asserts]
jsonpath "$" exists
