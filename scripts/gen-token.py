#!/usr/bin/env python3
"""Mint an HS256 service-token JWT for the Hurl integration tests.

Reads SERVICE_TOKEN_SECRET (default: the dev secret committed in
docker-compose.yml) and prints `service_token=<jwt>` with sub=hurl-test
and a 24h exp, matching what transaction-orchestrator/internal/authtoken.Issue()
produces. The Makefile prepends `--variable ` to each output line and
inlines the result into the hurl invocation.

DEV/STAGING ONLY — the dev secret is not a real secret; production issues
short-lived tokens from a proper auth service.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time

DEFAULT_SECRET = "dev-internal-shared-secret"
SUB = "hurl-test"
TTL_SECONDS = 24 * 60 * 60


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def sign(secret: str, sub: str, ttl: int) -> str:
    now = int(time.time())
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {"sub": sub, "iat": now, "exp": now + ttl}
    h = _b64url(json.dumps(header, separators=(",", ":")).encode())
    p = _b64url(json.dumps(payload, separators=(",", ":")).encode())
    sig = _b64url(
        hmac.new(secret.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest()
    )
    return f"{h}.{p}.{sig}"


def main() -> int:
    secret = os.environ.get("SERVICE_TOKEN_SECRET", DEFAULT_SECRET)
    print(f"service_token={sign(secret, SUB, TTL_SECONDS)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())