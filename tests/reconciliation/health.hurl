# reconciliation (port 8098): Python ledger-vs-external matching — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8098/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
