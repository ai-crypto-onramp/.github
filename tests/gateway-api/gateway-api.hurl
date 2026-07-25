# gateway-api (port 8080): TypeScript BFF edge. Most routes require a JWT
# verified against a remote JWKS endpoint; in dev mode the JWKS URL points
# to a placeholder, so JWT-protected routes return 401 "invalid token".
# The auth/session route accepts a refresh_token grant and returns a mock
# token. The partner/webhooks route validates the payload shape (no API
# key required for the validation to run).

GET http://localhost:8080/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# --- auth/session: refresh_token grant returns mock token ---

POST http://localhost:8080/v1/auth/session
Content-Type: application/json
{
  "grantType": "refresh_token",
  "refreshToken": "dummy"
}
HTTP 200
[Asserts]
jsonpath "$.accessToken" exists
jsonpath "$.tokenType" == "Bearer"
jsonpath "$.expiresIn" exists

# --- auth/session: missing grantType -> 400 ---

POST http://localhost:8080/v1/auth/session
Content-Type: application/json
{
  "refreshToken": "dummy"
}
HTTP 400

# --- auth/session: invalid grantType -> 400 ---

POST http://localhost:8080/v1/auth/session
Content-Type: application/json
{
  "grantType": "bogus",
  "refreshToken": "dummy"
}
HTTP 400

# --- protected routes without token -> 401 ---

GET http://localhost:8080/v1/me
HTTP 401
[Asserts]
jsonpath "$.code" == "unauthorized"

POST http://localhost:8080/v1/quotes
Content-Type: application/json
{"from": "USD", "to": "BTC", "amount": "1000"}
HTTP 401

POST http://localhost:8080/v1/transactions
Content-Type: application/json
{"quoteId": "q1"}
HTTP 401

GET http://localhost:8080/v1/transactions
HTTP 401

POST http://localhost:8080/v1/kyc/start
Content-Type: application/json
{"userId": "u1"}
HTTP 401

GET http://localhost:8080/v1/kyc/status?userId=u1
HTTP 401

# --- partner/webhooks: invalid event -> 400 ---

POST http://localhost:8080/v1/partner/webhooks
Content-Type: application/json
{
  "events": ["bogus.event"],
  "url": "http://test",
  "secret": "s1"
}
HTTP 400

# --- partner/webhooks: missing events -> 400 ---

POST http://localhost:8080/v1/partner/webhooks
Content-Type: application/json
{
  "url": "http://test",
  "secret": "s1"
}
HTTP 400
