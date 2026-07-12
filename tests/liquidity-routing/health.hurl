# liquidity-routing (port 8089): smart order routing — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8089/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
