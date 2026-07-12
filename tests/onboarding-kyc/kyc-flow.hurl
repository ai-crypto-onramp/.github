# onboarding-kyc (port 8093): application state machine from started
# through documents_uploaded, liveness_passed, and screening, plus a
# manual-review branch (seeded sanctions list matches "BAD ACTOR").
# Each run creates fresh applications ({{newUuid}} user ids), so the
# suite is idempotent.

GET http://localhost:8093/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

GET http://localhost:8093/readyz
HTTP 200
[Asserts]
jsonpath "$.status" == "ready"

# create an application
POST http://localhost:8093/v1/kyc/applications
Content-Type: application/json
{
  "user_id": "hurl-{{newUuid}}",
  "full_name": "Alice Cleanname"
}
HTTP 201
[Captures]
app_id: jsonpath "$.id"
kyc_user_id: jsonpath "$.user_id"
[Asserts]
jsonpath "$.state" == "started"

# one active application per user
POST http://localhost:8093/v1/kyc/applications
Content-Type: application/json
{
  "user_id": "{{kyc_user_id}}"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "duplicate_application"

# user_id is required
POST http://localhost:8093/v1/kyc/applications
Content-Type: application/json
{
  "vendor": "onfido"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "missing_user_id"

# upload the two required documents (id_front + selfie)
POST http://localhost:8093/v1/kyc/applications/{{app_id}}/documents
Content-Type: application/json
{
  "type": "id_front",
  "content": "aHVybC1pZC1mcm9udA=="
}
HTTP 201
[Asserts]
jsonpath "$.type" == "id_front"

POST http://localhost:8093/v1/kyc/applications/{{app_id}}/documents
Content-Type: application/json
{
  "type": "selfie",
  "content": "aHVybC1zZWxmaWU="
}
HTTP 201
[Asserts]
jsonpath "$.type" == "selfie"

# invalid document types are rejected
POST http://localhost:8093/v1/kyc/applications/{{app_id}}/documents
Content-Type: application/json
{
  "type": "tattoo",
  "content": "bm9wZQ=="
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "bad_doc_type"

GET http://localhost:8093/v1/kyc/applications/{{app_id}}/documents
HTTP 200
[Asserts]
jsonpath "$.documents" count == 2

# required docs present -> state advanced to documents_uploaded
GET http://localhost:8093/v1/kyc/applications/{{app_id}}
HTTP 200
[Asserts]
jsonpath "$.state" == "documents_uploaded"
jsonpath "$.documents" count == 2

# liveness check (stub vendor always passes)
POST http://localhost:8093/v1/kyc/applications/{{app_id}}/liveness
HTTP 201
[Asserts]
jsonpath "$.result" == "pass"

GET http://localhost:8093/v1/kyc/applications/{{app_id}}/liveness
HTTP 200
[Asserts]
jsonpath "$.result" == "pass"

GET http://localhost:8093/v1/kyc/status/{{kyc_user_id}}
HTTP 200
[Asserts]
jsonpath "$.application_id" == "{{app_id}}"
jsonpath "$.state" == "liveness_passed"

# clean name screens with no sanctions hits
POST http://localhost:8093/v1/kyc/applications/{{app_id}}/screening
Content-Type: application/json
{
  "full_name": "Alice Cleanname"
}
HTTP 200
[Asserts]
jsonpath "$.manual_review" == false

# --- manual-review branch: name on the seeded sanctions list ---

POST http://localhost:8093/v1/kyc/applications
Content-Type: application/json
{
  "user_id": "hurl-{{newUuid}}",
  "full_name": "Bad Actor"
}
HTTP 201
[Captures]
bad_app_id: jsonpath "$.id"

POST http://localhost:8093/v1/kyc/applications/{{bad_app_id}}/screening
Content-Type: application/json
{
  "full_name": "Bad Actor"
}
HTTP 200
[Asserts]
jsonpath "$.manual_review" == true
jsonpath "$.hits" count >= 1

# --- error branches ---

GET http://localhost:8093/v1/kyc/applications/00000000-0000-0000-0000-000000000000
HTTP 404
[Asserts]
jsonpath "$.error.code" == "application_not_found"

# vendor webhooks without a valid signature are rejected
POST http://localhost:8093/v1/webhooks/onfido
Content-Type: application/json
{
  "event": "check.completed"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "webhook_rejected"
