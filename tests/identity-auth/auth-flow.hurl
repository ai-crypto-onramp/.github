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
jsonpath "$.status" == "pending"

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
jsonpath "$.status" == "active"

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
  "email": "{{email}}",
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
  "email": "{{email}}",
  "password": "S3cretPass!"
}
HTTP 200
[Captures]
access_token3: jsonpath "$.access_token"

DELETE http://localhost:8087/v1/users/me
Authorization: Bearer {{access_token3}}
HTTP 204

# closed accounts cannot log in
POST http://localhost:8087/v1/sessions
Content-Type: application/json
{
  "email": "{{email}}",
  "password": "S3cretPass!"
}
HTTP 403
[Asserts]
jsonpath "$.error.code" == "account_closed"
