# rail-connectors (port 8097): per-rail adapters — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8097/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
