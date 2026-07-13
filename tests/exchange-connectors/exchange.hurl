# exchange-connectors (port 8084): dummy venue connector for order placement,
# fills, balances, and order book. Orders are created fresh per run.

GET http://localhost:8084/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8084/readyz
HTTP 200

# --- place an order ---

POST http://localhost:8084/v1/orders
Content-Type: application/json
{
  "venue": "binance",
  "pair": "BTC/USD",
  "side": "buy",
  "type": "market",
  "amount": 1.0
}
HTTP 201
[Captures]
order_id: jsonpath "$.id"
[Asserts]
jsonpath "$.venue" == "binance"
jsonpath "$.pair" == "BTC/USD"
jsonpath "$.side" == "buy"
jsonpath "$.status" exists

# fetch fills for the order
GET http://localhost:8084/v1/orders/{{order_id}}/fills
HTTP 200
[Asserts]
jsonpath "$.fills" exists

# cancel the order
POST http://localhost:8084/v1/orders/{{order_id}}/cancel
HTTP 200

# cancel non-existent order -> 404
POST http://localhost:8084/v1/orders/ord_doesnotexist/cancel
HTTP 404

# --- balances ---

GET http://localhost:8084/v1/balances
HTTP 200
[Asserts]
jsonpath "$.balances" exists

# --- order book ---

GET http://localhost:8084/v1/book/BTC/USD
HTTP 200
[Asserts]
jsonpath "$.pair" == "BTC/USD"

# --- admin ---

GET http://localhost:8084/admin/status
HTTP 200
[Asserts]
jsonpath "$.circuit_breaker" exists

POST http://localhost:8084/admin/rotate-credentials
HTTP 200
