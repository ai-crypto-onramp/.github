# blockchain-gateway (port 8083): per-chain broadcast/confirmation tracking — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8083/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
