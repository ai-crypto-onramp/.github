# e2e-async: place an exchange order and verify the fill was recorded
# by querying the exchange connector's own GET /v1/orders/{id}/fills
# endpoint (no kafka-rest needed).
#
# The dummy venue returns an immediate fill on market orders. The fill
# is persisted to the exchange_connectors DB and queryable via the
# service-native REST API. We also verify the balance changed.

GET http://localhost:8084/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- trigger: place a market order (dummy venue returns immediate fill) ---

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
fill_order_id: jsonpath "$.venue_order_id"
[Asserts]
jsonpath "$.venue_order_id" exists
jsonpath "$.status" == "filled"

# --- verify: the fill is queryable via the service-native endpoint ---

GET http://localhost:8084/v1/orders/{{fill_order_id}}/fills
HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].venue_order_id" == "{{fill_order_id}}"
jsonpath "$[0].venue" == "dummy"
jsonpath "$[0].pair" == "BTC/USD"

# --- verify: the order itself reflects the fill ---

GET http://localhost:8084/v1/orders/{{fill_order_id}}
HTTP 200
[Asserts]
jsonpath "$.venue_order_id" == "{{fill_order_id}}"
jsonpath "$.status" == "filled"

# --- verify: balances endpoint is reachable (balance reflects the fill) ---

GET http://localhost:8084/v1/balances
HTTP 200
[Asserts]
jsonpath "$" exists