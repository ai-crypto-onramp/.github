# wallet-management (port 8101): custody inventory, address derivation,
# balances, funding, withdrawals. See wallet.hurl for the API smoke flow.

GET http://localhost:8101/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
