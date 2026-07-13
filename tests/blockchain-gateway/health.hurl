# blockchain-gateway (port 8083): per-chain broadcast, fee estimation, and
# confirmation tracking. Without CHAINS_SUPPORTED the stack runs it with a
# stub chain adapter, so only the health endpoint is exercised here; set
# CHAINS_SUPPORTED + RPC_URLS_<CHAIN> env overrides to run against a node.

GET http://localhost:8083/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
