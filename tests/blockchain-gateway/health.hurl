# blockchain-gateway (port 8083): per-chain broadcast, fee estimation, and
# confirmation tracking. Without CHAINS_SUPPORTED the stack runs it with a
# stub chain adapter, so only the health endpoint is exercised here; set
# CHAINS_SUPPORTED + RPC_URLS_<CHAIN> env overrides to run against a node.

GET http://localhost:8083/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# Verify the service migrated its schema: the broadcasts table should
# exist and be queryable via Postgrest (port 3010).
GET http://localhost:3010/broadcasts?limit=0
HTTP 200
[Asserts]
jsonpath "$" count == 0

# Same for chain_tips — created by the migration, empty until a node is wired.
GET http://localhost:3010/chain_tips?limit=0
HTTP 200
[Asserts]
jsonpath "$" count == 0

# fee_estimates table should also exist.
GET http://localhost:3010/fee_estimates?limit=0
HTTP 200
[Asserts]
jsonpath "$" count == 0
