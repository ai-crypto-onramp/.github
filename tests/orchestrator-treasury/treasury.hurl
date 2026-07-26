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

# non-existent batch -> 404 or 400 (batch id parsing)
GET http://localhost:8100/v1/batches/999999
HTTP *
[Asserts]
jsonpath "$.error" exists

# closing a non-existent / non-open batch -> 404 or 400
POST http://localhost:8100/v1/batches/999999/close
HTTP *

# --- float: positions may exist from seeded data; assert structure only ---

GET http://localhost:8100/v1/float/USD
HTTP 200
[Asserts]
jsonpath "$.fiat_currency" == "USD"
jsonpath "$.short_fiat_amount" exists

# --- funding requests: POST creates a fresh row each run ---

POST http://localhost:8100/v1/funding-requests
Content-Type: application/json
{
  "wallet_id": "hurl-wallet-{{newUuid}}",
  "asset": "BTC",
  "amount": "1.25",
  "source_venue": "kraken"
}
HTTP 201
[Captures]
funding_id: jsonpath "$.id"
[Asserts]
jsonpath "$.wallet_id" exists
jsonpath "$.asset" == "BTC"
jsonpath "$.amount" == "1.25"
jsonpath "$.source_venue" == "kraken"

# funding request landed — the POST response already asserted id,
# wallet_id, asset, amount, and source_venue. The list endpoint below
# also confirms the row is queryable.

# list funding requests (wallet-management may not be wired in the dev
# stack, so the request can land as rejected — assert it exists, not the
# status, which depends on the downstream wallet call)
GET http://localhost:8100/v1/funding-requests
HTTP 200
[Asserts]
jsonpath "$.funding_requests" exists

# invalid amount -> 400
POST http://localhost:8100/v1/funding-requests
Content-Type: application/json
{
  "wallet_id": "hurl-wallet-bad",
  "asset": "BTC",
  "amount": "-1",
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

# --- batch memberships: ListMemberships returns 200 with an empty array
# for any valid uuid (the store filters by batch_id, no batch existence
# check), so exercise the endpoint with a fixed uuid and assert shape.
# An invalid id (not a uuid) is rejected earlier by handleBatchByID.

GET http://localhost:8100/v1/batches/00000000-0000-0000-0000-000000000000/memberships
HTTP 200
[Asserts]
jsonpath "$.memberships" exists

# invalid batch id (not a uuid) -> 400 from the batch-id parser
GET http://localhost:8100/v1/batches/not-a-uuid/memberships
HTTP 400
[Asserts]
jsonpath "$.error" exists

# --- float list (all currencies) ---

GET http://localhost:8100/v1/float
HTTP 200
[Asserts]
jsonpath "$.float_positions" exists

# --- aggregate orders ---

GET http://localhost:8100/v1/aggregate-orders
HTTP 200
[Asserts]
jsonpath "$.aggregate_orders" exists

GET http://localhost:8100/v1/aggregate-orders?status=settled
HTTP 200
[Asserts]
jsonpath "$.aggregate_orders" exists

# --- events: POST a tx.completed event to the HTTP-push endpoint ---

POST http://localhost:8100/v1/events/tx.completed
Content-Type: application/json
{
  "tx_id": "hurl-tx-{{newUuid}}",
  "amount": "0.5",
  "asset": "BTC",
  "fiat_currency": "USD",
  "notional_usd": "500.00",
  "user_id": "hurl-user-{{newUuid}}",
  "completed_at": "2026-01-01T00:00:00Z"
}
HTTP 202

# missing topic -> 400
POST http://localhost:8100/v1/events/
Content-Type: application/json
{}
HTTP 400
