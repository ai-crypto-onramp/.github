# treasury-orchestration (port 8100): aggregate buys / float management — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8100/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
