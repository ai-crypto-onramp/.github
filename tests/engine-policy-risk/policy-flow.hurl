# engine-policy-risk (port 8095): evaluate path with whitelist gating,
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
jsonpath "$.status" == "PENDING"

# whitelist entry landed — verify via the service-native GET endpoint
GET http://localhost:8095/v1/policy/whitelist/{{policy_user_id}}
HTTP 200
[Asserts]
jsonpath "$.entries" count == 1
jsonpath "$.entries[0].user_id" == "{{policy_user_id}}"
jsonpath "$.entries[0].address" == "0xhurldest1"
jsonpath "$.entries[0].status" == "PENDING"

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
jsonpath "$.status" == "VERIFIED"

# whitelist entry status should now be verified
GET http://localhost:8095/v1/policy/whitelist/{{policy_user_id}}
HTTP 200
[Asserts]
jsonpath "$.entries[0].status" == "VERIFIED"

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

# decision landed — the evaluate response already asserted decision_id +
# decision == manual_review. Verify the review-queue side effect via the
# service-native GET /v1/policy/review?status=pending (called below).

GET http://localhost:8095/v1/policy/review?status=PENDING
HTTP 200
[Asserts]
jsonpath "$.items" count >= 1
jsonpath "$.items[?(@.decision_id == '{{decision_id}}')].status" contains "PENDING"

# resolve the parked review
POST http://localhost:8095/v1/policy/review/{{decision_id}}/resolve
Content-Type: application/json
{
  "assignee": "hurl-analyst",
  "resolution": "ALLOW"
}
HTTP 200
[Asserts]
jsonpath "$.status" == "RESOLVED"
jsonpath "$.resolution" == "ALLOW"

# review_queue entry should now be resolved — verify via service-native GET
GET http://localhost:8095/v1/policy/review?status=RESOLVED
HTTP 200
[Asserts]
jsonpath "$.items[?(@.decision_id == '{{decision_id}}')].status" contains "RESOLVED"
jsonpath "$.items[?(@.decision_id == '{{decision_id}}')].resolution" contains "ALLOW"

# a review can only be resolved once
POST http://localhost:8095/v1/policy/review/{{decision_id}}/resolve
Content-Type: application/json
{
  "assignee": "hurl-analyst",
  "resolution": "DENY"
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

# --- publish new rules (POST /v1/policy/rules) ---

# publishing without activate creates a new staged version
POST http://localhost:8095/v1/policy/rules
Content-Type: text/plain
```
package onramp.decisions
default allow := false
allow if { input.fraud_score < 0.5 }
```
HTTP 201
[Asserts]
jsonpath "$.version" exists
jsonpath "$.hash" exists
jsonpath "$.activate" == false

# publishing with activate=true swaps the active policy
POST http://localhost:8095/v1/policy/rules?activate=true
Content-Type: text/plain
```
package onramp.decisions
default allow := false
allow if { input.fraud_score < 0.5 }
```
HTTP 201
[Asserts]
jsonpath "$.version" exists
jsonpath "$.activate" == true

# re-publishing the same source returns the same version (idempotent)
POST http://localhost:8095/v1/policy/rules?activate=true
Content-Type: text/plain
```
package onramp.decisions
default allow := false
allow if { input.fraud_score < 0.5 }
```
HTTP 201
[Asserts]
jsonpath "$.version" exists
jsonpath "$.activate" == true

# empty body is rejected
POST http://localhost:8095/v1/policy/rules
HTTP 400
[Asserts]
jsonpath "$.error.code" == "bad_json"

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
