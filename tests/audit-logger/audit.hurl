# audit-event-log (port 8082): append-only audit trail with hash chain.
# Ingest is via Kafka consumer (no REST POST), so the read API is empty
# until events flow. This suite exercises the read endpoints, auth, and
# admin surfaces against an empty store.
# Auth is via HS256 service-token JWT (Bearer token). The gen-token.py
# script mints service_token (reader) and audit_admin_token (admin).

GET http://localhost:8082/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- auth: endpoints require a valid Bearer token ---

# no token -> 401
GET http://localhost:8082/v1/events
HTTP 401

# reader token -> 200
GET http://localhost:8082/v1/events
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.events" exists
jsonpath "$.next_cursor" exists

# filtered query
GET http://localhost:8082/v1/events?service=ledger&limit=10
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.events" exists

# invalid cursor -> 400
GET http://localhost:8082/v1/events?cursor=not-a-cursor
Authorization: Bearer {{service_token}}
HTTP 400

# non-existent event -> 404
GET http://localhost:8082/v1/events/evt_doesnotexist
Authorization: Bearer {{service_token}}
HTTP 404

# verify-chain on non-existent event -> 404
GET http://localhost:8082/v1/events/evt_doesnotexist/verify-chain
Authorization: Bearer {{service_token}}
HTTP 404

# --- admin endpoints require audit-admin ---

# reader cannot access admin
POST http://localhost:8082/v1/admin/verify-chain
Authorization: Bearer {{service_token}}
HTTP 403

# admin can trigger verify-chain
POST http://localhost:8082/v1/admin/verify-chain
Authorization: Bearer {{audit_admin_token}}
HTTP 200
[Asserts]
jsonpath "$.status" exists

# legal hold on non-existent event -> 404
POST http://localhost:8082/v1/admin/legal-hold/evt_doesnotexist
Authorization: Bearer {{audit_admin_token}}
HTTP 404

# --- exports ---

# reader cannot create export
POST http://localhost:8082/v1/exports
Authorization: Bearer {{service_token}}
Content-Type: application/json
{
  "query": {"service": "ledger"},
  "format": "json"
}
HTTP 403

# admin can create export
POST http://localhost:8082/v1/exports
Authorization: Bearer {{audit_admin_token}}
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

# fetch export status
GET http://localhost:8082/v1/exports/{{export_id}}
Authorization: Bearer {{service_token}}
HTTP 200
[Asserts]
jsonpath "$.id" exists

# non-existent export -> 404
GET http://localhost:8082/v1/exports/exp_doesnotexist
Authorization: Bearer {{service_token}}
HTTP 404