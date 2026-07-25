# exchange-connectors (port 8084): dummy venue connector for order placement,
# fills, balances, and order book. Orders are created fresh per run.

GET http://localhost:8084/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8084/readyz
HTTP 200

# --- place an order (dummy returns immediate fill, 200 not 201) ---

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
order_id: jsonpath "$.venue_order_id"
[Asserts]
jsonpath "$.venue" == "dummy"
jsonpath "$.pair" == "BTC/USD"
jsonpath "$.status" == "filled"

# fetch fills for the order
GET http://localhost:8084/v1/orders/{{order_id}}/fills
HTTP 200
[Asserts]
jsonpath "$.fills" exists

# cancel the order
POST http://localhost:8084/v1/orders/{{order_id}}/cancel
HTTP 200

# cancel non-existent order (dummy always returns 200)
POST http://localhost:8084/v1/orders/ord_doesnotexist/cancel
HTTP 200

# --- balances ---

GET http://localhost:8084/v1/balances
HTTP 200
[Asserts]
jsonpath "$.Assets" exists

# --- admin ---

GET http://localhost:8084/admin/status
HTTP 200
[Asserts]
jsonpath "$.circuit_breaker" == "closed"

POST http://localhost:8084/admin/rotate-credentials
HTTP 200

# --- order book ---

GET http://localhost:8084/v1/book/BTCUSDT
HTTP 200
[Asserts]
jsonpath "$.Pair" == "BTCUSDT"
jsonpath "$.Bid" exists
jsonpath "$.Ask" exists

# non-existent pair -> 404
GET http://localhost:8084/v1/book/NOPEUSDT
HTTP 404
