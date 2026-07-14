# ledger-accounting (port 8088): in-memory double-entry ledger with
# hash chain, chart of accounts, postings, and balance queries.
# Accounts are created fresh per run via UUID.

GET http://localhost:8088/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8088/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- chart of accounts ---

GET http://localhost:8088/v1/chart-of-accounts
HTTP 200
[Asserts]
jsonpath "$.account_types" exists
jsonpath "$.account_types[0].type" == "user_custodial"

# --- create accounts ---

POST http://localhost:8088/v1/accounts
Content-Type: application/json
{
  "type": "user_custodial",
  "asset_class": "crypto",
  "label": "hurl-custodial"
}
HTTP 201
[Captures]
acc_debit: jsonpath "$.account_id"
[Asserts]
jsonpath "$.account_id" exists

POST http://localhost:8088/v1/accounts
Content-Type: application/json
{
  "type": "user_payable",
  "asset_class": "fiat",
  "label": "hurl-payable"
}
HTTP 201
[Captures]
acc_credit: jsonpath "$.account_id"

# unknown account type -> 400
POST http://localhost:8088/v1/accounts
Content-Type: application/json
{
  "type": "nonexistent",
  "asset_class": "fiat",
  "label": "bad"
}
HTTP 400

# --- balanced posting ---

POST http://localhost:8088/v1/postings
Content-Type: application/json
{
  "posting_id": "hurl-{{newUuid}}",
  "entries": [
    {
      "account_id": "{{acc_debit}}",
      "direction": "debit",
      "amount": 100,
      "asset": "USD"
    },
    {
      "account_id": "{{acc_credit}}",
      "direction": "credit",
      "amount": 100,
      "asset": "USD"
    }
  ],
  "memo": "hurl test posting"
}
HTTP 201
[Captures]
posting_id: jsonpath "$.posting_id"
[Asserts]
jsonpath "$.status" == "posted"
jsonpath "$.entry_ids" exists
jsonpath "$.hash_head" exists

# duplicate posting_id returns existing (200)
POST http://localhost:8088/v1/postings
Content-Type: application/json
{
  "posting_id": "{{posting_id}}",
  "entries": [
    {
      "account_id": "{{acc_debit}}",
      "direction": "debit",
      "amount": 100,
      "asset": "USD"
    },
    {
      "account_id": "{{acc_credit}}",
      "direction": "credit",
      "amount": 100,
      "asset": "USD"
    }
  ],
  "memo": "hurl test posting"
}
HTTP 200

# unbalanced posting -> 400
POST http://localhost:8088/v1/postings
Content-Type: application/json
{
  "posting_id": "hurl-unbalanced-{{newUuid}}",
  "entries": [
    {
      "account_id": "{{acc_debit}}",
      "direction": "debit",
      "amount": 100,
      "asset": "USD"
    },
    {
      "account_id": "{{acc_credit}}",
      "direction": "credit",
      "amount": 50,
      "asset": "USD"
    }
  ],
  "memo": "unbalanced"
}
HTTP 400

# --- fetch posting ---

GET http://localhost:8088/v1/postings/{{posting_id}}
HTTP 200
[Asserts]
jsonpath "$.posting_id" == "{{posting_id}}"
jsonpath "$.status" == "posted"
jsonpath "$.entries" exists

# non-existent posting -> 404
GET http://localhost:8088/v1/postings/post_doesnotexist
HTTP 404

# --- balance ---

GET http://localhost:8088/v1/accounts/{{acc_debit}}/balance?asset=USD
HTTP 200
[Asserts]
jsonpath "$.account_id" == "{{acc_debit}}"
jsonpath "$.asset" == "USD"
jsonpath "$.balance" == "100"

# --- ledger ---

GET http://localhost:8088/v1/accounts/{{acc_debit}}/ledger?limit=10
HTTP 200
[Asserts]
jsonpath "$.entries" exists
jsonpath "$.final_balance" exists

# --- chain verification ---

GET http://localhost:8088/v1/chain/verify
HTTP 200
[Asserts]
jsonpath "$.ok" exists

# --- reconciliation: user custodial sum ---

GET http://localhost:8088/v1/reconciliation/user-custodial-sum
HTTP 200
[Asserts]
jsonpath "$.user_custodial_sum" exists
