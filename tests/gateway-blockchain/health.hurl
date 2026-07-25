# blockchain-gateway (port 8083): per-chain broadcast, fee estimation, and
# confirmation tracking. Without CHAINS_SUPPORTED the stack runs it with a
# stub chain adapter, so only the health endpoint is exercised here; set
# CHAINS_SUPPORTED + RPC_URLS_<CHAIN> env overrides to run against a node.

GET http://localhost:8083/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# Schema migration smoke: the service runs migrations on startup and
# healthz returns 200 only after the DB-backed store is ready, so the
# healthz check above is sufficient proof the tables exist. Without a
# real chain adapter (CHAINS_SUPPORTED + RPC_URLS_<CHAIN> env), the
# broadcast/tip/fee endpoints return 404 for unknown chains, so there
# is no service-native GET that returns an empty list to assert on.
