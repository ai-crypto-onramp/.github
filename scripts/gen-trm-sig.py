#!/usr/bin/env python3
"""Mint a fresh TRM webhook event_id + HMAC-SHA256 signature pair for the
Hurl integration tests.

The aml-kyt-screening webhook verifier requires HMAC-SHA256 over the exact
request body (HMAC-SHA256(secret, body)). The body embeds an event_id that
is also used for idempotency dedup, so a fixed event_id would be deduped
across test runs and no alert would be created after the first run. This
script generates a fresh event_id and computes the matching signature so
each run gets a fresh alert.

Outputs `name=value` token lines on stdout:
    trm_evt_1=<uuid>
    trm_sig_1=<hexsig>

The Makefile prepends `--variable ` to each line and inlines the result
into the hurl invocation. The .hurl file references them as
{{trm_evt_1}} and {{trm_sig_1}}.

DEV/STAGING ONLY — the dev secret is not a real secret.
"""
from __future__ import annotations

import hashlib
import hmac
import uuid

DEFAULT_SECRET = "dev-secret-trm"
BODY_TEMPLATE = (
    '{{"event_id":"{evt}","address":"0xhurlbad1","chain":"ethereum",'
    '"exposure":"sanctioned","tx_id":"hurl-tx-wh1"}}'
)


def sign(secret: str, event_id: str) -> str:
    body = BODY_TEMPLATE.format(evt=event_id).encode()
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def main() -> int:
    secret = DEFAULT_SECRET
    evt = str(uuid.uuid4())
    print(f"trm_evt_1={evt}")
    print(f"trm_sig_1={sign(secret, evt)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())