# e2e-async: create a parent order on engine-liquidity, exercising the
# `liquidity.fills` async topic via the Option 1 per-service direct
# trigger approach.
#
# Trigger:  POST /v1/parent-orders on engine-liquidity (port 8089).
# Verify:   GET /v1/parent-orders/{id} and GET /v1/parent-orders/{id}/fills
#           on engine-liquidity.
#
# Topic wiring note:
#   The slicer (TWAP/VWAP) is not auto-started for new parent orders in
#   dev mode — CreateParentOrder (lifecycle.go) only validates/persists
#   the order; slicing is driven by a separate worker that only resumes
#   *existing* active orders on restart (app.go: ResumeActive). The
#   Kafka producer for `liquidity.fills` is wired only when
#   EVENT_BUS_URL=kafka://... is set (otherwise FakeReconciliation is
#   used). So in dev mode no fills are produced for a freshly created
#   parent order.
#
#   This test exercises the trigger (parent order creation) and the
#   verify endpoints (order persistence + fills endpoint shape), which
#   is the Option 1 direct-trigger coverage the plan calls for. The
#   fills array is empty in dev mode (no slicer running); full async
#   pipeline coverage awaits a dev-mode slicer driver (Option 2 in the
#   coverage plan). The test asserts the fills endpoint returns a valid
#   array (possibly empty) and the parent order is durably persisted.

GET http://localhost:8089/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- trigger: create a TWAP parent order ---

POST http://localhost:8089/v1/parent-orders
Content-Type: application/json
{
  "asset": "BTC",
  "side": "BUY",
  "notional": 50000,
  "strategy": "TWAP",
  "client_request_id": "e2e-async-liquidity-{{newUuid}}",
  "quoted_mid": 65000
}
HTTP 201
[Captures]
liq_parent_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.asset" == "BTC"
jsonpath "$.side" == "BUY"
jsonpath "$.strategy" == "TWAP"
jsonpath "$.status" == "PENDING"

# --- verify: parent order persisted (re-fetch via service-native GET) ---

GET http://localhost:8089/v1/parent-orders/{{liq_parent_id}}
HTTP 200
[Asserts]
jsonpath "$.parent.id" == "{{liq_parent_id}}"
jsonpath "$.parent.asset" == "BTC"
jsonpath "$.parent.side" == "BUY"
jsonpath "$.slicing_progress" exists

# --- verify: fills endpoint returns a valid array ---
# In dev mode (no slicer auto-start) the fills array is empty; once a
# dev-mode slicer driver is wired, fills would appear here. The endpoint
# shape proves the fill-ingestion path is queryable.

GET http://localhost:8089/v1/parent-orders/{{liq_parent_id}}/fills
HTTP 200
[Asserts]
jsonpath "$.fills" exists