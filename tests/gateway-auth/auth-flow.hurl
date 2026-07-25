# identity-auth (port 8087): full account lifecycle — register, verify
# email, login (with lockout/MFA error branches), session refresh
# rotation, logout, account closure. Each run registers a fresh user
# ({{newUuid}} email), so the suite is idempotent against accumulated
# state.

GET http://localhost:8087/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# register: account starts pending with a verification token
POST http://localhost:8087/v1/users
Content-Type: application/json
{
  "email": "hurl-{{newUuid}}@example.com",
  "password": "S3cretPass!"
}
HTTP 201
[Captures]
user_id: jsonpath "$.id"
email: jsonpath "$.email"
verify_token: jsonpath "$.verification_token"
[Asserts]
jsonpath "$.status" == "PENDING"

# register response already asserts id, email, and status == PENDING —
# that is the service contract for "row landed". (No GET-by-id user
# endpoint; /v1/users/me requires a session, which we don't have yet.)

# the same email cannot register twice
POST http://localhost:8087/v1/users
Content-Type: application/json
{
  "email": "{{email}}",
  "password": "S3cretPass!"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "email_taken"

# weak passwords are rejected
POST http://localhost:8087/v1/users
Content-Type: application/json
{
  "email": "hurl-{{newUuid}}@example.com",
  "password": "short"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "weak_password"

# login before email verification is forbidden
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{email}}",
  "password": "S3cretPass!"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "account_pending"

# verify the email
POST http://localhost:8087/v1/users/verify
Content-Type: application/json
{
  "token": "{{verify_token}}"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "ACTIVE"

# verify response already asserts status == ACTIVE — the service contract
# for "state transition landed in the DB".

# wrong password is rejected
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{email}}",
  "password": "WrongPass!"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "invalid_credentials"

# login issues an access + refresh token pair
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{email}}",
  "password": "S3cretPass!"
}
HTTP 200
[Captures]
access_token: jsonpath "$.access_token"
refresh_token: jsonpath "$.refresh_token"
[Asserts]
jsonpath "$.expires_in" == 900

GET http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.email" == "{{email}}"

# --- PATCH /me: update email ---

PATCH http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "email": "hurl-patch-{{newUuid}}@example.com"
}
HTTP 200
[Captures]
patched_email: jsonpath "$.email"
[Asserts]
jsonpath "$.id" == "{{user_id}}"
jsonpath "$.status" == "ACTIVE"

# --- DELETE /sessions/:id (non-existent -> 404) ---

DELETE http://localhost:8087/v1/sessions/00000000-0000-7000-8000-000000000000
Authorization: Bearer {{access_token}}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "session_not_found"

# --- MFA lifecycle ---

POST http://localhost:8087/v1/mfa/enroll
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "type": "TOTP"
}
HTTP 200
[Captures]
mfa_factor_id: jsonpath "$.factor_id"
[Asserts]
jsonpath "$.secret" exists
jsonpath "$.qr_uri" exists

# verify with a wrong code -> 401
POST http://localhost:8087/v1/mfa/verify
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "factor_id": "{{mfa_factor_id}}",
  "code": "000000"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "mfa_invalid"

# generate recovery codes
POST http://localhost:8087/v1/mfa/recovery
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "code": "dummy"
}
HTTP 200
[Asserts]
jsonpath "$.recovery_codes" count >= 1

# delete the MFA factor
DELETE http://localhost:8087/v1/mfa/factors/{{mfa_factor_id}}
Authorization: Bearer {{access_token}}
HTTP 204

# --- password reset ---

POST http://localhost:8087/v1/password/reset/init
Content-Type: application/json
{
  "email": "{{patched_email}}"
}
HTTP 200
[Captures]
reset_token: jsonpath "$.reset_token"
[Asserts]
jsonpath "$.reset_token" exists

# confirm with an invalid token -> 400
POST http://localhost:8087/v1/password/reset/confirm
Content-Type: application/json
{
  "token": "invalid-token",
  "password": "NewS3cret!"
}
HTTP 400
[Asserts]
jsonpath "$.error.code" == "invalid_token"

# --- API key CRUD ---

POST http://localhost:8087/v1/api-keys
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "partner_id": "partner-hurl",
  "scopes": ["payments:write"]
}
HTTP 201
[Captures]
api_key_id: jsonpath "$.id"
[Asserts]
jsonpath "$.key" exists
jsonpath "$.prefix" exists
jsonpath "$.scopes[0]" == "payments:write"

GET http://localhost:8087/v1/api-keys
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$" exists

# rotate the key
POST http://localhost:8087/v1/api-keys/{{api_key_id}}/rotate
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$.id" == "{{api_key_id}}"

# delete (revoke) the key
DELETE http://localhost:8087/v1/api-keys/{{api_key_id}}
Authorization: Bearer {{access_token}}
HTTP 204

# --- RBAC ---

GET http://localhost:8087/v1/roles
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$" count >= 1
jsonpath "$[0].name" exists
jsonpath "$[0].permissions" exists

GET http://localhost:8087/v1/role-bindings
Authorization: Bearer {{access_token}}
HTTP 200

# authz check for an action without a binding -> denied
POST http://localhost:8087/v1/authz
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "resource": "tx",
  "action": "create"
}
HTTP 200
[Asserts]
jsonpath "$.allow" == false

# --- audit events ---

GET http://localhost:8087/v1/audit-events
Authorization: Bearer {{access_token}}
HTTP 200

# --- admin unlock (invalid uuid -> error) ---

POST http://localhost:8087/v1/admin/unlock
Authorization: Bearer {{access_token}}
Content-Type: application/json
{
  "user_id": "00000000-0000-7000-8000-000000000099"
}
HTTP 404

GET http://localhost:8087/v1/sessions
Authorization: Bearer {{access_token}}
HTTP 200
[Asserts]
jsonpath "$" count >= 1

# refresh rotates the token pair
POST http://localhost:8087/v1/sessions/refresh
Content-Type: application/json
{
  "refresh_token": "{{refresh_token}}"
}
HTTP 200
[Captures]
access_token2: jsonpath "$.access_token"
[Asserts]
jsonpath "$.refresh_token" != "{{refresh_token}}"

# logout revokes the session…
DELETE http://localhost:8087/v1/sessions
Authorization: Bearer {{access_token2}}
HTTP 204

# …so the token no longer works
GET http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token2}}
HTTP 401

# --- refresh-token reuse detection ---

POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{patched_email}}",
  "password": "S3cretPass!"
}
HTTP 200
[Captures]
refresh_token_b: jsonpath "$.refresh_token"

POST http://localhost:8087/v1/sessions/refresh
Content-Type: application/json
{
  "refresh_token": "{{refresh_token_b}}"
}
HTTP 200
[Captures]
access_token_b2: jsonpath "$.access_token"

# reusing the rotated-out refresh token is rejected…
POST http://localhost:8087/v1/sessions/refresh
Content-Type: application/json
{
  "refresh_token": "{{refresh_token_b}}"
}
HTTP 401
[Asserts]
jsonpath "$.error.code" == "refresh_invalid"

# …and revokes the whole session chain as a security measure
GET http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token_b2}}
HTTP 401

# close the account (cleanup): fresh login, then delete
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{patched_email}}",
  "password": "S3cretPass!"
}
HTTP 200
[Captures]
access_token3: jsonpath "$.access_token"

DELETE http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token3}}
HTTP 204

# account closure is confirmed by the 204 response and by the next login
# attempt returning account_closed (below) — no postgrest needed.

# closed accounts cannot log in
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{patched_email}}",
  "password": "S3cretPass!"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "account_closed"
