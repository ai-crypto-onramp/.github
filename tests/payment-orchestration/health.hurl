# payment-orchestration (port 8094): fiat ingress orchestration — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8094/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
