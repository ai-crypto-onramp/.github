# treasury-orchestration (port 8100): batch aggregation, float tracking,
# hot-wallet funding, and rebalancing. Batches are created internally
# by the tx.completed event consumer, so this suite exercises the
# funding-request surface (POST), the read endpoints, and float queries.
# Funding requests are created fresh every run, so the suite is idempotent.

GET http://localhost:8100/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8100/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- batches: empty until the event consumer populates them ---

GET http://localhost:8100/v1/batches
HTTP 200
[Asserts]
jsonpath "$.batches" exists

# non-existent batch -> 404
GET http://localhost:8100/v1/batches/999999
HTTP 404
[Asserts]
jsonpath "$.error" exists

# closing a non-existent / non-open batch -> 404 or 409
POST http://localhost:8100/v1/batches/999999/close
HTTP 404

# --- float: no positions until an aggregate fill lands ---

GET http://localhost:8100/v1/float/USD
HTTP 200
[Asserts]
jsonpath "$.fiat_currency" == "USD"
jsonpath "$.short_fiat_amount" == 0

# --- funding requests: POST creates a fresh row each run ---

POST http://localhost:8100/v1/funding-requests
Content-Type: application/json
{
  "wallet_id": "hurl-wallet-{{newUuid}}",
  "asset": "BTC",
  "amount": 1.25,
  "source_venue": "kraken"
}
HTTP 201
[Captures]
funding_id: jsonpath "$.id"
[Asserts]
jsonpath "$.wallet_id" exists
jsonpath "$.asset" == "BTC"
jsonpath "$.amount" == 1.25
jsonpath "$.status" == "pending"
jsonpath "$.source_venue" == "kraken"

# list funding requests, filter by status
GET http://localhost:8100/v1/funding-requests?status=pending
HTTP 200
[Asserts]
jsonpath "$.funding_requests" exists
jsonpath "$.funding_requests[0].status" == "pending"

# invalid amount -> 400
POST http://localhost:8100/v1/funding-requests
Content-Type: application/json
{
  "wallet_id": "hurl-wallet-bad",
  "asset": "BTC",
  "amount": -1,
  "source_venue": "kraken"
}
HTTP 400
[Asserts]
jsonpath "$.error" exists

# --- rebalancing jobs: read-only, empty until the loop creates them ---

GET http://localhost:8100/v1/rebalancing-jobs
HTTP 200
[Asserts]
jsonpath "$.rebalancing_jobs" exists

GET http://localhost:8100/v1/rebalancing-jobs?status=pending
HTTP 200
[Asserts]
jsonpath "$.rebalancing_jobs" exists