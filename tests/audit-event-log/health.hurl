# audit-event-log (port 8082): append-only audit trail — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8082/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
