# api-gateway (port 8080): TypeScript BFF edge — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8080/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
