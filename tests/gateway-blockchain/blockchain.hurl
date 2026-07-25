# gateway-blockchain (port 8083): per-chain broadcast, fee estimation, and
# confirmation tracking. Without CHAINS_SUPPORTED the dev stack runs a stub
# chain adapter, so chain-specific endpoints return "unknown chain" errors.
# These tests exercise every endpoint: the error path for unknown chains
# and the health endpoint.

GET http://localhost:8083/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- estimate fee ---

POST http://localhost:8083/v1/chains/ethereum/estimate-fee
Content-Type: application/json
{
  "priority": "MEDIUM"
}
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"

# --- broadcast ---

POST http://localhost:8083/v1/chains/ethereum/broadcast
Content-Type: application/json
{
  "signed_tx": "0xdeadbeef",
  "from_addr": "0xabc",
  "to_addr": "0xdef",
  "value": "1.0",
  "nonce": 5
}
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"

# --- chain height ---

GET http://localhost:8083/v1/chains/ethereum/height
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"

# --- address balance ---

GET http://localhost:8083/v1/chains/ethereum/address/0xabc/balance
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"

# --- tx lookup ---

GET http://localhost:8083/v1/chains/ethereum/tx/0xabc123
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"

# --- tx status ---

GET http://localhost:8083/v1/chains/ethereum/tx/0xabc123/status
HTTP 404
[Asserts]
jsonpath "$.error" contains "unknown chain"
