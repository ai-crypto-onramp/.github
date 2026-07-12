# wallet-management (port 8101): wallet inventory — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8101/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
