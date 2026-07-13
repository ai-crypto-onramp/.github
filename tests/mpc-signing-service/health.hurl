# mpc-signing-service (port 8091): policy-gated signing behind the
# SigningEngine boundary. The signing API is gRPC on the internal network
# (mpc-signing-service:9090) — HTTP exposes /healthz and the custody webhook,
# so only health is exercised here.

GET http://localhost:8091/healthz
HTTP 200
[Asserts]
jsonpath "$.status" == "ok"

# The custody webhook is present but reports 501 until
# CUSTODY_WEBHOOK_SECRET is configured for a provider.
POST http://localhost:8091/v1/custody/webhook
{}
HTTP 501
[Asserts]
jsonpath "$.error" exists
