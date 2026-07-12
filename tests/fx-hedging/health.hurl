# fx-hedging (port 8086): currency exposure management — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8086/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
