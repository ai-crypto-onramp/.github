#!/usr/bin/env python3
"""Mint a fresh timestamp + HMAC-SHA256 signature pair for the notifier
/v1/webhooks/verify Hurl integration test.

The notifier webhook verifier computes HMAC-SHA256(secret, "<ts>.<raw_body>")
and rejects timestamps older than 300s, so a hardcoded pair would go stale
between runs. This script generates a current timestamp and the matching
signature over a fixed raw_body using the same secret the notifier suite
registers its partner webhook with (hurl-partner-secret).

Outputs `name=value` token lines on stdout:
    webhook_ts=<unix seconds>
    webhook_sig=<hexsig>

The Makefile prepends `--variable ` to each line and inlines the result
into the hurl invocation. The .hurl file references them as
{{webhook_ts}} and {{webhook_sig}}.

DEV/STAGING ONLY — the dev secret is not a real secret.
"""
from __future__ import annotations

import hashlib
import hmac
import time

DEFAULT_SECRET = "hurl-partner-secret"
RAW_BODY = '{"event":"tx.created","id":"hurl-verify"}'


def sign(secret: str, timestamp: str, raw_body: str) -> str:
    return hmac.new(
        secret.encode(),
        f"{timestamp}.{raw_body}".encode(),
        hashlib.sha256,
    ).hexdigest()


def main() -> int:
    secret = DEFAULT_SECRET
    ts = str(int(time.time()))
    print(f"webhook_ts={ts}")
    print(f"webhook_sig={sign(secret, ts, RAW_BODY)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())