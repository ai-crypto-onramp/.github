# reconciliation (port 8098): ledger-vs-external matching, break detection
# & escalation, recon runs, and CSV/JSON export. The service auto-creates
# its schema on first request, so the suite can run against a fresh stack.
# Runs and breaks are created fresh each invocation, so the suite is
# idempotent (asserts use count >= 0 and shape checks, not fixed ids).

GET http://localhost:8098/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8098/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# --- breaks: empty until a recon run detects them ---

GET http://localhost:8098/v1/breaks
HTTP 200
[Asserts]
jsonpath "$.breaks" exists
jsonpath "$.total" >= 0

# non-existent break -> 404
GET http://localhost:8098/v1/breaks/999999
HTTP 404

# resolving a non-existent break -> 404
POST http://localhost:8098/v1/breaks/999999/resolve
Content-Type: application/json
{
  "actor": "hurl-tester",
  "note": "attempt to resolve a missing break"
}
HTTP 404

# escalating a non-existent break -> 404
POST http://localhost:8098/v1/breaks/999999/escalate
Content-Type: application/json
{
  "actor": "hurl-tester"
}
HTTP 404

# --- recon runs: trigger an EOD run against the ledger source ---

POST http://localhost:8098/v1/recon-runs
Content-Type: application/json
{
  "source": "ledger",
  "scope": "daily",
  "mode": "eod"
}
HTTP 200
[Captures]
run_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.status" exists

# PostgREST: confirm the recon run landed in reconciliation.recon_runs
GET http://localhost:3007/recon_runs?id=eq.{{run_id}}
HTTP 200
[Asserts]
jsonpath "$[0].id" == {{run_id}}
jsonpath "$[0].source" == "ledger"

# fetch the run we just created
GET http://localhost:8098/v1/recon-runs/{{run_id}}
HTTP 200
[Asserts]
jsonpath "$.id" == {{run_id}}
jsonpath "$.source" == "ledger"
jsonpath "$.status" exists
jsonpath "$.matched_count" >= 0
jsonpath "$.unmatched_count" >= 0

# non-existent run -> 404
GET http://localhost:8098/v1/recon-runs/999999
HTTP 404

# --- reports ---

# CSV report for the run we just created
GET http://localhost:8098/v1/recon-runs/{{run_id}}/report?fmt=csv
HTTP 200
[Asserts]
header "Content-Type" contains "text/csv"

# JSON report
GET http://localhost:8098/v1/recon-runs/{{run_id}}/report?fmt=json
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"

# report for a non-existent run -> 404
GET http://localhost:8098/v1/recon-runs/999999/report
HTTP 404

# --- breaks export (CSV + JSON) ---

GET http://localhost:8098/v1/breaks-export?fmt=csv
HTTP 200
[Asserts]
header "Content-Type" contains "text/csv"

GET http://localhost:8098/v1/breaks-export?fmt=json
HTTP 200
[Asserts]
header "Content-Type" contains "application/json"

# filtered export by source
GET http://localhost:8098/v1/breaks-export?source=ledger&fmt=csv
HTTP 200
[Asserts]
header "Content-Type" contains "text/csv"
