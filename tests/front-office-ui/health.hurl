# front-office-ui (port 8102): Next.js customer-facing app; only the
# health endpoint is implemented so far.

GET http://localhost:8102/api/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
