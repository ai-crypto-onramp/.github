# wallet-management (port 8101): wallet lifecycle + EVM address derivation
# smoke — create a hot Ethereum wallet, read it back, derive a receive
# address, and check the (empty) balances list.

POST http://localhost:8101/v1/wallets
{
  "chain": "ethereum",
  "type": "hot",
  "label": "hurl-smoke"
}
HTTP 201
[Captures]
wallet_id: jsonpath "$.id"
[Asserts]
jsonpath "$.chain" == "ethereum"
jsonpath "$.type" == "hot"
jsonpath "$.state" == "active"

GET http://localhost:8101/v1/wallets/{{wallet_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{wallet_id}}"
jsonpath "$.label" == "hurl-smoke"

POST http://localhost:8101/v1/wallets/{{wallet_id}}/addresses/derive
HTTP 201
[Asserts]
jsonpath "$.wallet_id" == "{{wallet_id}}"
jsonpath "$.address" matches "^0x[0-9a-fA-F]{40}$"
jsonpath "$.derivation_path" == "m/44'/60'/0'/0/0"
jsonpath "$.state" == "active"

GET http://localhost:8101/v1/wallets/{{wallet_id}}/balances
HTTP 200
[Asserts]
jsonpath "$" count == 0
