# mpc-signing-service (port 8091): Rust threshold signing — scaffold service,
# only the health endpoint is implemented so far.

GET http://localhost:8091/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
