# exchange-connectors (port 8084): venue adapters — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8084/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
