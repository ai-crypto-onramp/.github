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

# PostgREST: confirm the wallet row landed in wallet_management.wallets
GET http://localhost:3005/wallets?id=eq.{{wallet_id}}
HTTP 200
[Asserts]
jsonpath "$[0].id" == "{{wallet_id}}"
jsonpath "$[0].chain" == "ethereum"
jsonpath "$[0].type" == "hot"
jsonpath "$[0].state" == "active"

GET http://localhost:8101/v1/wallets/{{wallet_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{wallet_id}}"
jsonpath "$.label" == "hurl-smoke"

POST http://localhost:8101/v1/wallets/{{wallet_id}}/addresses/derive
HTTP 201
[Captures]
derived_address: jsonpath "$.address"
[Asserts]
jsonpath "$.wallet_id" == "{{wallet_id}}"
jsonpath "$.address" matches "^0x[0-9a-fA-F]{40}$"
# The derivation index is allocated per chain (wallets share the chain xpub),
# so it grows across runs — assert the path shape, not a fixed index.
jsonpath "$.derivation_path" matches "^m/44'/60'/0'/0/\\d+$"
jsonpath "$.state" == "active"

# PostgREST: confirm the address row landed in wallet_management.addresses
GET http://localhost:3005/addresses?address=eq.{{derived_address}}
HTTP 200
[Asserts]
jsonpath "$[0].wallet_id" == "{{wallet_id}}"
jsonpath "$[0].state" == "active"

GET http://localhost:8101/v1/wallets/{{wallet_id}}/balances
HTTP 200
[Asserts]
jsonpath "$" count == 0
