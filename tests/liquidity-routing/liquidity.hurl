# liquidity-routing (port 8089): smart order routing, TWAP/VWAP slicing.
# Parent orders are created fresh every run via client_request_id (UUID),
# so the suite is idempotent.

GET http://localhost:8089/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8089/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- create parent order ---

POST http://localhost:8089/v1/parent-orders
Content-Type: application/json
{
  "asset": "BTC",
  "side": "buy",
  "notional": 50000,
  "strategy": "twap",
  "client_request_id": "hurl-{{newUuid}}",
  "quoted_mid": 65000
}
HTTP 201
[Captures]
order_id: jsonpath "$.id"
[Asserts]
jsonpath "$.asset" == "BTC"
jsonpath "$.side" == "buy"
jsonpath "$.strategy" == "twap"
jsonpath "$.status" == "pending"

# duplicate client_request_id returns the existing order (200, not 201)
POST http://localhost:8089/v1/parent-orders
Content-Type: application/json
{
  "asset": "BTC",
  "side": "buy",
  "notional": 50000,
  "strategy": "twap",
  "client_request_id": "hurl-dup-{{newUuid}}",
  "quoted_mid": 65000
}
HTTP 201
[Captures]
dup_crid: jsonpath "$.client_request_id"

POST http://localhost:8089/v1/parent-orders
Content-Type: application/json
{
  "asset": "BTC",
  "side": "buy",
  "notional": 50000,
  "strategy": "twap",
  "client_request_id": "{{dup_crid}}",
  "quoted_mid": 65000
}
HTTP 200

# invalid strategy -> 400
POST http://localhost:8089/v1/parent-orders
Content-Type: application/json
{
  "asset": "BTC",
  "side": "buy",
  "notional": 1000,
  "strategy": "hold",
  "client_request_id": "hurl-bad-{{newUuid}}",
  "quoted_mid": 65000
}
HTTP 400
[Asserts]
jsonpath "$.error" exists

# --- fetch parent order ---

GET http://localhost:8089/v1/parent-orders/{{order_id}}
HTTP 200
[Asserts]
jsonpath "$.parent.id" == "{{order_id}}"
jsonpath "$.parent.asset" == "BTC"
jsonpath "$.slicing_progress" exists

# non-existent order -> 404
GET http://localhost:8089/v1/parent-orders/po_doesnotexist
HTTP 404
[Asserts]
jsonpath "$.error" exists

# --- fills (empty until slicing produces child orders) ---

GET http://localhost:8089/v1/parent-orders/{{order_id}}/fills
HTTP 200
[Asserts]
jsonpath "$.fills" exists

# fills on non-existent order -> 404
GET http://localhost:8089/v1/parent-orders/po_doesnotexist/fills
HTTP 404

# --- cancel ---

POST http://localhost:8089/v1/parent-orders/{{order_id}}/cancel
HTTP 200
[Asserts]
jsonpath "$.id" == "{{order_id}}"

# cancelling a non-existent order -> 404
POST http://localhost:8089/v1/parent-orders/po_doesnotexist/cancel
HTTP 404