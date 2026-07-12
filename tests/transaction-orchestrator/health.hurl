# transaction-orchestrator (port 8099): saga engine — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8099/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
