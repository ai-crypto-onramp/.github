# ledger-accounting (port 8088): Rust double-entry ledger — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8088/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
