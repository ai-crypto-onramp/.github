# wallet-management (port 8101): wallet lifecycle + EVM address derivation
# smoke — create a hot Ethereum wallet, read it back, derive a receive
# address, and check the (empty) balances list.

POST http://localhost:8101/v1/wallets
{
  "chain": "ethereum",
  "type": "HOT",
  "label": "hurl-smoke"
}
HTTP 201
[Captures]
wallet_id: jsonpath "$.id"
[Asserts]
jsonpath "$.chain" == "ethereum"
jsonpath "$.type" == "HOT"
jsonpath "$.state" == "ACTIVE"

# wallet row landed — re-fetch via the service-native GET endpoint
GET http://localhost:8101/v1/wallets/{{wallet_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{wallet_id}}"
jsonpath "$.chain" == "ethereum"
jsonpath "$.type" == "HOT"
jsonpath "$.state" == "ACTIVE"
jsonpath "$.label" == "hurl-smoke"

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
jsonpath "$.state" == "ACTIVE"

# address row landed — verify via the service-native GET addresses endpoint
GET http://localhost:8101/v1/wallets/{{wallet_id}}/addresses
HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].wallet_id" == "{{wallet_id}}"
jsonpath "$[0].address" == "{{derived_address}}"
jsonpath "$[0].state" == "ACTIVE"

GET http://localhost:8101/v1/wallets/{{wallet_id}}/balances
HTTP 200
[Asserts]
jsonpath "$" count == 0
