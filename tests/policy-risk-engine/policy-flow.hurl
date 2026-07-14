# policy-risk-engine (port 8095): evaluate path with whitelist gating,
# OPA decisions (allow / deny / manual_review by fraud score), and the
# review-queue lifecycle. Each run uses a fresh user ({{newUuid}}), so
# whitelist entries and velocity counters never collide across runs.

GET http://localhost:8095/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# add a whitelist entry — starts pending, does not gate yet
POST http://localhost:8095/v1/policy/whitelist
Content-Type: application/json
{
  "user_id": "hurl-{{newUuid}}",
  "chain": "ethereum",
  "address": "0xhurldest1",
  "label": "hurl test wallet"
}
HTTP 201
[Captures]
policy_user_id: jsonpath "$.user_id"
[Asserts]
jsonpath "$.status" == "pending"

# PostgREST: confirm the whitelist entry landed in policy_engine.whitelist_addresses
GET http://localhost:3004/whitelist_addresses?user_id=eq.{{policy_user_id}}&address=eq.0xhurldest1
HTTP 200
[Asserts]
jsonpath "$[0].user_id" == "{{policy_user_id}}"
jsonpath "$[0].address" == "0xhurldest1"
jsonpath "$[0].status" == "pending"

# pending (unverified) destinations are denied
POST http://localhost:8095/v1/policy/evaluate
Content-Type: application/json
{
  "user_id": "{{policy_user_id}}",
  "amount": "100",
  "currency": "USD",
  "asset": "BTC",
  "rail": "ach",
  "dest_address": "0xhurldest1",
  "dest_chain": "ethereum",
  "kyt_verdict": "clean",
  "fraud_score": 0.1,
  "kyc_status": "verified"
}
HTTP 200
[Asserts]
jsonpath "$.decision" == "deny"
jsonpath "$.reasons" contains "dest_not_whitelisted"

# verify the entry (micro-transfer confirmation)
POST http://localhost:8095/v1/policy/whitelist/{{policy_user_id}}/verify
Content-Type: application/json
{
  "chain": "ethereum",
  "address": "0xhurldest1"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "verified"

# PostgREST: whitelist entry status should now be verified
GET http://localhost:3004/whitelist_addresses?user_id=eq.{{policy_user_id}}&address=eq.0xhurldest1
HTTP 200
[Asserts]
jsonpath "$[0].status" == "verified"

GET http://localhost:8095/v1/policy/whitelist/{{policy_user_id}}
HTTP 200
[Asserts]
jsonpath "$.entries" count == 1

# clean signals + verified destination -> allow
POST http://localhost:8095/v1/policy/evaluate
Content-Type: application/json
{
  "user_id": "{{policy_user_id}}",
  "amount": "100",
  "currency": "USD",
  "asset": "BTC",
  "rail": "ach",
  "dest_address": "0xhurldest1",
  "dest_chain": "ethereum",
  "kyt_verdict": "clean",
  "fraud_score": 0.1,
  "kyc_status": "verified"
}
HTTP 200
[Asserts]
jsonpath "$.decision" == "allow"
jsonpath "$.reasons" contains "whitelisted"
jsonpath "$.decision_id" exists
jsonpath "$.policy_version" exists

# high fraud score -> deny
POST http://localhost:8095/v1/policy/evaluate
Content-Type: application/json
{
  "user_id": "{{policy_user_id}}",
  "amount": "100",
  "currency": "USD",
  "asset": "BTC",
  "rail": "ach",
  "dest_address": "0xhurldest1",
  "dest_chain": "ethereum",
  "kyt_verdict": "clean",
  "fraud_score": 0.9,
  "kyc_status": "verified"
}
HTTP 200
[Asserts]
jsonpath "$.decision" == "deny"

# mid-band fraud score -> manual_review, parked in the review queue
POST http://localhost:8095/v1/policy/evaluate
Content-Type: application/json
{
  "user_id": "{{policy_user_id}}",
  "amount": "100",
  "currency": "USD",
  "asset": "BTC",
  "rail": "ach",
  "dest_address": "0xhurldest1",
  "dest_chain": "ethereum",
  "kyt_verdict": "clean",
  "fraud_score": 0.6,
  "kyc_status": "verified"
}
HTTP 200
[Captures]
decision_id: jsonpath "$.decision_id"
[Asserts]
jsonpath "$.decision" == "manual_review"

# PostgREST: confirm the decision landed in policy_engine.policy_decisions
GET http://localhost:3004/policy_decisions?decision_id=eq.{{decision_id}}
HTTP 200
[Asserts]
jsonpath "$[0].decision_id" == "{{decision_id}}"
jsonpath "$[0].decision" == "manual_review"

# PostgREST: and a review_queue entry was created
GET http://localhost:3004/review_queue?decision_id=eq.{{decision_id}}
HTTP 200
[Asserts]
jsonpath "$[0].status" == "pending"

GET http://localhost:8095/v1/policy/review?status=pending
HTTP 200
[Asserts]
jsonpath "$.items" count >= 1

# resolve the parked review
POST http://localhost:8095/v1/policy/review/{{decision_id}}/resolve
Content-Type: application/json
{
  "assignee": "hurl-analyst",
  "resolution": "allow"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "resolved"
jsonpath "$.resolution" == "allow"

# PostgREST: review_queue entry should now be resolved
GET http://localhost:3004/review_queue?decision_id=eq.{{decision_id}}
HTTP 200
[Asserts]
jsonpath "$[0].status" == "resolved"
jsonpath "$[0].resolution" == "allow"

# a review can only be resolved once
POST http://localhost:8095/v1/policy/review/{{decision_id}}/resolve
Content-Type: application/json
{
  "assignee": "hurl-analyst",
  "resolution": "deny"
}
HTTP 409
[Asserts]
jsonpath "$.error.code" == "review_resolved"

# --- rules metadata ---

GET http://localhost:8095/v1/policy/rules
HTTP 200
[Captures]
policy_version: jsonpath "$.version"
[Asserts]
jsonpath "$.version" exists
jsonpath "$.hash" exists

GET http://localhost:8095/v1/policy/rules/{{policy_version}}
HTTP 200
[Asserts]
jsonpath "$.version" == "{{policy_version}}"

GET http://localhost:8095/v1/policy/rules/no-such-version
HTTP 404
[Asserts]
jsonpath "$.error.code" == "rule_not_found"

# --- error branches ---

# verifying a whitelist entry that does not exist
POST http://localhost:8095/v1/policy/whitelist/{{policy_user_id}}/verify
Content-Type: application/json
{
  "chain": "ethereum",
  "address": "0xneverwhitelisted"
}
HTTP 404
[Asserts]
jsonpath "$.error.code" == "whitelist_not_found"

# empty body is rejected
POST http://localhost:8095/v1/policy/evaluate
HTTP 400
[Asserts]
jsonpath "$.error.code" == "bad_json"
