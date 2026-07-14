# middle-office-ui (port 8103): Vite SPA served by nginx; static
# /healthz endpoint served from public/healthz.json.

GET http://localhost:8103/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"
