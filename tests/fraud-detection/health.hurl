# fraud-detection (port 8085): Python ML scoring — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8085/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
