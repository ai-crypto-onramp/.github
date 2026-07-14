# audit-event-log (port 8082): append-only audit trail with hash chain.
# Ingest is via Kafka consumer (no REST POST), so the read API is empty
# until events flow. This suite exercises the read endpoints, auth, and
# admin surfaces against an empty store.
# Auth is via X-Audit-Roles header (set by the API gateway in production).

GET http://localhost:8082/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- auth: endpoints require X-Audit-Roles ---

# no roles -> 403
GET http://localhost:8082/v1/events
HTTP 403

# with audit-reader role -> 200
GET http://localhost:8082/v1/events
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" exists
jsonpath "$.next_cursor" exists

# filtered query
GET http://localhost:8082/v1/events?service=ledger&limit=10
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.events" exists

# invalid cursor -> 400
GET http://localhost:8082/v1/events?cursor=not-a-cursor
X-Audit-Roles: audit-reader
HTTP 400

# non-existent event -> 404
GET http://localhost:8082/v1/events/evt_doesnotexist
X-Audit-Roles: audit-reader
HTTP 404

# verify-chain on non-existent event -> 404
GET http://localhost:8082/v1/events/evt_doesnotexist/verify-chain
X-Audit-Roles: audit-reader
HTTP 404

# --- admin endpoints require audit-admin ---

# reader cannot access admin
POST http://localhost:8082/v1/admin/verify-chain
X-Audit-Roles: audit-reader
HTTP 403

# admin can trigger verify-chain
POST http://localhost:8082/v1/admin/verify-chain
X-Audit-Roles: audit-admin
HTTP 200
[Asserts]
jsonpath "$.status" exists

# legal hold on non-existent event -> 404
POST http://localhost:8082/v1/admin/legal-hold/evt_doesnotexist
X-Audit-Roles: audit-admin
HTTP 404

# --- exports ---

# reader cannot create export
POST http://localhost:8082/v1/exports
X-Audit-Roles: audit-reader
Content-Type: application/json
{
  "query": {"service": "ledger"},
  "format": "json"
}
HTTP 403

# admin can create export
POST http://localhost:8082/v1/exports
X-Audit-Roles: audit-admin
Content-Type: application/json
{
  "query": {"service": "ledger"},
  "format": "json"
}
HTTP 202
[Captures]
export_id: jsonpath "$.id"
[Asserts]
jsonpath "$.id" exists
jsonpath "$.status" exists

# PostgREST: confirm the export job landed in audit.export_jobs
GET http://localhost:3009/export_jobs?id=eq.{{export_id}}
HTTP 200
[Asserts]
jsonpath "$[0].id" == "{{export_id}}"

# fetch export status
GET http://localhost:8082/v1/exports/{{export_id}}
X-Audit-Roles: audit-reader
HTTP 200
[Asserts]
jsonpath "$.id" exists

# non-existent export -> 404
GET http://localhost:8082/v1/exports/exp_doesnotexist
X-Audit-Roles: audit-reader
HTTP 404
