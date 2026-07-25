#!/usr/bin/env python3
"""Populate every service database with synthetic fixture data.

Replaces the static fixtures/seed/*.sql files with a generator that mints
fresh UUIDs, hashes, and timestamps on every run, so two runs never collide
and the size of the dataset is configurable.

Usage:
    python3 scripts/seed.py              # default: 10 records per table
    python3 scripts/seed.py --mode 10    # 10 records per table
    python3 scripts/seed.py --mode 100   # 100 records per table
    python3 scripts/seed.py --mode 1000  # 1000 records per table
    python3 scripts/seed.py --dsn postgresql://postgres:postgres@localhost:5432
    python3 scripts/seed.py --db identity_auth  # seed only one database

The script inserts fixture rows without truncating first — run
`make reset-db` first if you need a clean slate, or just `make seed-db`
to append to whatever the services have already created or migrated.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import secrets
import sys
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Sequence

try:
    import psycopg
except ImportError:
    print("psycopg >= 3 is required: pip install psycopg[binary]", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def uuid7() -> str:
    """Return a random UUID string (sufficient for fixture PKs)."""
    return str(uuid.uuid4())


def random_sha256() -> str:
    return secrets.token_hex(32)


def random_bytes_hex(n: int) -> str:
    return secrets.token_hex(n)


def random_email() -> str:
    return f"user{secrets.randbelow(10**9)}@example.com"


def random_eth_address() -> str:
    return "0x" + secrets.token_hex(20)


def random_btc_address() -> str:
    return "bc1q" + secrets.token_hex(20)


def random_phone() -> str:
    return f"+1{secrets.randbelow(9000000000) + 1000000000}"


def random_device_token() -> str:
    return "device-" + secrets.token_hex(16)


def random_url() -> str:
    return f"https://partner{secrets.randbelow(10000)}.example.com/hooks"


def now() -> datetime:
    return datetime.now(timezone.utc)


def ago(minutes: float = 0, hours: float = 0, days: float = 0) -> datetime:
    return now() - timedelta(minutes=minutes, hours=hours, days=days)


def future(minutes: float = 0, hours: float = 0, days: float = 0) -> datetime:
    return now() + timedelta(minutes=minutes, hours=hours, days=days)


def pick(seq: Sequence, i: int) -> Any:
    return seq[i % len(seq)]


def jsonb(d: Any) -> str:
    return json.dumps(d)


# ---------------------------------------------------------------------------
# DB connection
# ---------------------------------------------------------------------------

def connect(dsn: str, dbname: str) -> "psycopg.Connection":
    conn = psycopg.connect(f"{dsn}/{dbname}", autocommit=True)
    return conn


# ---------------------------------------------------------------------------
# Per-DB seeders
# ---------------------------------------------------------------------------

def seed_identity_auth(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        statuses = ["ACTIVE", "ACTIVE", "ACTIVE", "LOCKED", "PENDING"]
        for i in range(n):
            uid = uuid7()
            cur.execute(
                "INSERT INTO users (id, email, password_hash, status, created_at, updated_at, closed_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, NULL)",
                (uid, random_email(), f"argon2id${random_sha256()[:24]}", pick(statuses, i),
                 ago(days=30 - i % 30, hours=i), ago(hours=i % 24)),
            )
            cur.execute(
                "INSERT INTO sessions (id, user_id, refresh_token_hash, issuer, issued_at, last_seen_at, expires_at, revoked_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, NULL, %s, %s)",
                (uuid7(), uid, f"rthash-{random_sha256()[:16]}", "api-gateway",
                 ago(days=i % 7), ago(minutes=i % 60), future(days=6), ago(days=i % 7), ago(minutes=i % 60)),
            )
            if i % 2 == 0:
                cur.execute(
                    "INSERT INTO mfa_factors (id, user_id, type, secret_encrypted, confirmed, created_at, updated_at, disabled_at) "
                    "VALUES (%s, %s, %s, %s, true, %s, %s, NULL)",
                    (uuid7(), uid, "TOTP", secrets.token_bytes(20).hex().encode(), ago(days=29), ago(days=29)),
                )
            cur.execute(
                "INSERT INTO audit_events (id, type, subject_id, session_id, request_id, metadata, created_at, updated_at) "
                "VALUES (%s, %s, %s, NULL, %s, %s::jsonb, %s, %s)",
                (uuid7(), "user.login" if i % 3 != 0 else "user.login_failed", uid, f"req-{uuid7()[:12]}",
                 jsonb({"ip": f"10.0.{i % 256}.{i % 256}"}), ago(hours=i % 24), ago(hours=i % 24)),
            )


def seed_onboarding_kyc(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        states = ["PASS", "MANUAL_REVIEW", "DOCUMENTS_UPLOADED", "FAIL", "STARTED"]
        vendors = ["sumsub", "onfido"]
        for i in range(n):
            uid = uuid7()
            cur.execute(
                "INSERT INTO kyc_applications (id, user_id, vendor, vendor_application_id, state, created_at, updated_at, expires_at, re_kyc_due_at, decided_at, version) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uid, uuid7(), pick(vendors, i), f"{pick(vendors, i)}-app-{i}",
                 pick(states, i), ago(days=i % 25, hours=i), ago(hours=i % 24),
                 future(days=30), future(days=335) if i % 4 == 0 else None,
                 ago(days=i % 25) if i % 4 == 0 else None, (i % 3) + 1),
            )
            cur.execute(
                "INSERT INTO documents (id, application_id, type, object_key, vendor_document_id, uploaded_at, retention_until, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), uid, pick(["ID_FRONT", "ID_BACK", "SELFIE"], i),
                 f"s3://kyc/app-{i}/doc-{i}.jpg", f"vendor-doc-{i}",
                 ago(days=i % 25, hours=i), future(days=335), ago(days=i % 25, hours=i), ago(days=i % 25, hours=i)),
            )
            if i % 3 == 0:
                cur.execute(
                    "INSERT INTO liveness_sessions (id, application_id, vendor_session_id, status, started_at, completed_at, result, retention_until, created_at, updated_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s)",
                    (uuid7(), uid, f"live-{uuid7()[:12]}", "PASSED", ago(days=i % 25), ago(days=i % 25),
                     jsonb({"score": 0.9 + (i % 10) / 100}), future(days=335), ago(days=i % 25), ago(days=i % 25)),
                )
            cur.execute(
                "INSERT INTO audit_events (id, aggregate, action, actor, payload, occurred_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s::jsonb, %s, %s, %s)",
                (uuid7(), "kyc_application", "STATE_CHANGED", "system",
                 jsonb({"from": "SCREENING", "to": pick(states, i)}), ago(hours=i % 24), ago(hours=i % 24), ago(hours=i % 24)),
            )


def seed_policy_engine(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        policy_ids = [uuid7(), uuid7()]
        for pid in policy_ids:
            cur.execute(
                "INSERT INTO policies (id, scope, active_version, created_at, updated_at) "
                "VALUES (%s, %s, NULL, %s, %s)",
                (pid, f"scope-{pid[:8]}", ago(days=30), ago(days=30)),
            )
        version_ids = []
        for i, pid in enumerate(policy_ids):
            vid = uuid7()
            version_ids.append(vid)
            cur.execute(
                "INSERT INTO policy_versions (id, policy_id, version, rego_hash, rego_source, created_at, updated_at, created_by) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (vid, pid, i + 1, f"rego-{random_sha256()[:12]}",
                 f"package default.allow; default allow := false; allow if {{ input.amount <= {100000 * (i + 1)} }}",
                 ago(days=30 - i * 10), ago(days=30 - i * 10), "admin"),
            )
            cur.execute("UPDATE policies SET active_version = %s WHERE id = %s", (vid, pid))
        decisions = ["ALLOW", "DENY", "REVIEW"]
        for i in range(n):
            cur.execute(
                "INSERT INTO policy_decisions (decision_id, policy_version, request_hash, decision, reasons, applied_rules, score, signature, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, NULL, %s, %s)",
                (uuid7(), pick(version_ids, i), f"req-{random_sha256()[:12]}", pick(decisions, i),
                 [f"rule_{i % 3}"], [f"rule_{i % 3}"], round(secrets.randbelow(100) / 100, 2),
                 ago(hours=i % 24), ago(hours=i % 24)),
            )
        for i in range(n):
            cur.execute(
                "INSERT INTO whitelist_addresses (id, user_id, chain, address, label, verified_at, status, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), uuid7(), pick(["ethereum", "bitcoin"], i),
                 random_eth_address() if i % 2 == 0 else random_btc_address(),
                 f"label-{i}", ago(days=20) if i % 3 == 0 else None,
                 "VERIFIED" if i % 3 == 0 else "PENDING", ago(days=25), ago(days=20)),
            )


def seed_fraud(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        bands = ["LOW", "MEDIUM", "HIGH"]
        for i in range(n):
            cur.execute(
                "INSERT INTO fraud_scores (id, tx_id, user_id, score, risk_band, model_version, variant, top_features, scored_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), f"tx-{uuid7()[:12]}", uuid7(), round(secrets.randbelow(100) / 100, 2),
                 pick(bands, i), "gbm-v1", "CONTROL",
                 jsonb([{"feature": "velocity_24h", "value": secrets.randbelow(60)},
                        {"feature": "device_age_hours", "value": secrets.randbelow(800)}]),
                 ago(hours=i % 24), ago(hours=i % 24), ago(hours=i % 24)),
            )
        run_id = uuid7()[:8]
        for i in range(max(1, n // 10)):
            cur.execute(
                "INSERT INTO model_versions (id, name, version, stage, metrics, traffic_split, trained_at, updated_at, created_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), "gbm", f"v{run_id}-{i}", "PRODUCTION" if i == 0 else "SHADOW",
                 jsonb({"auc": 0.91 + i * 0.01, "precision": 0.83, "recall": 0.77}),
                 jsonb({"control": 1.0 - i * 0.2, "shadow": i * 0.2}),
                 ago(days=10 - i), ago(days=i + 1), ago(days=10 - i)),
            )


def seed_pricing_quote(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        pairs = [("USD", "BTC"), ("USD", "ETH"), ("EUR", "BTC"), ("BTC", "USD"), ("EUR", "ETH")]
        statuses = ["CLAIMED", "EXPIRED", "PENDING", "CLAIMED"]
        for i in range(n):
            fc, tc = pick(pairs, i)
            rate = 65000.0 if tc == "BTC" else (3500.0 if tc == "ETH" else 1.0)
            amount = round((secrets.randbelow(50000) + 100), 2)
            cur.execute(
                "INSERT INTO quotes (quote_id, from_ccy, to_ccy, amount, rate, spread_bps, fee, fee_currency, total, crypto_amount, user_tier, side, status, created_at, updated_at, expires_at, claimed_at, claimed_by, source_venue) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), fc, tc, amount, rate, secrets.randbelow(100) + 50,
                 round(amount * 0.005, 2), fc, round(amount * 1.005, 2),
                 round(amount / rate, 8), pick(["TIER_1", "TIER_2", "TIER_3"], i),
                 "BUY" if i % 2 == 0 else "SELL", pick(statuses, i),
                 ago(hours=i % 24), ago(minutes=i % 60), future(minutes=5),
                 ago(minutes=30) if i % 4 == 0 else None, uuid7() if i % 4 == 0 else "",
                 pick(["binance", "kraken", "coinbase"], i)),
            )


def seed_liquidity(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        assets = ["BTC", "ETH", "USDC"]
        strategies = ["TWAP", "VWAP", "POV"]
        statuses = ["EXECUTING", "COMPLETE", "PENDING"]
        parent_ids = []
        for i in range(n):
            pid = uuid7()
            parent_ids.append(pid)
            cur.execute(
                "INSERT INTO parent_orders (id, asset, side, notional, strategy, status, quoted_mid, realized_slippage_bps, vwap_benchmark, client_request_id, filled_qty, avg_fill_price, total_fee, slice_count, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (pid, pick(assets, i), "BUY", round(secrets.randbelow(50000) + 1000, 2),
                 pick(strategies, i), pick(statuses, i), 65000.0, round(secrets.randbelow(500) / 100, 2),
                 65100.0, f"req-{uuid7()[:12]}", round(secrets.randbelow(50000), 2), 65050.0,
                 round(secrets.randbelow(100), 2), secrets.randbelow(10),
                 ago(hours=i % 24), ago(minutes=i % 60)),
            )
        for i, pid in enumerate(parent_ids):
            for s in range(secrets.randbelow(5) + 1):
                cur.execute(
                    "INSERT INTO child_orders (id, parent_order_id, venue_id, side, size, price_limit, status, idempotency_key, slice_index, created_at, updated_at) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (uuid7(), pid, pick(["kraken", "binance"], s), "BUY",
                     round(secrets.randbelow(1000) + 10, 2), 65000.0 + s * 50,
                     pick(["FILLED", "WORKING", "OPEN"], s), f"idem-{uuid7()[:12]}", s,
                     ago(hours=i % 24, minutes=s), ago(minutes=i % 60 + s)),
                )


def seed_fx_hedging(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        currencies = ["EUR", "GBP", "JPY", "USD", "AUD"]
        for i in range(n):
            cur.execute(
                "INSERT INTO fx_exposures (id, currency, net_amount, hedge_coverage, open_amount, source_flow, event_id, ts, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(currencies, i), round(secrets.randbelow(500000) + 10000, 2),
                 round(secrets.randbelow(400000) + 5000, 2), round(secrets.randbelow(50000), 2),
                 "PAYMENT_CAPTURE", f"evt-{uuid7()[:12]}", ago(hours=i % 24), ago(hours=i % 24), ago(hours=i % 24)),
            )
        for i in range(n):
            cur.execute(
                "INSERT INTO hedges (id, currency, notional, tenor, type, status, quoted_rate, slippage_bps, pnl, client_request_id, policy_ratio, policy_cap_usd, cap_breached, value_date, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(currencies, i), round(secrets.randbelow(200000) + 1000, 2),
                 pick(["SPOT", "FORWARD_1M", "FORWARD_3M"], i), pick(["SPOT", "FORWARD"], i),
                 pick(["EXECUTED", "PENDING", "EXECUTED"], i), round(1.0 + secrets.randbelow(100) / 100, 4),
                 round(secrets.randbelow(300) / 100, 2), round(secrets.randbelow(1000), 2),
                 f"bo-ui-{i}", 0.9, 500000.0, False, future(days=i % 30),
                 ago(hours=i % 24), ago(minutes=i % 60)),
            )


def seed_blockchain_gateway(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        chains = ["ethereum", "bitcoin"]
        for i in range(n):
            tx_hash = "0x" + secrets.token_hex(32) if i % 2 == 0 else secrets.token_hex(32)
            cur.execute(
                "INSERT INTO broadcasts (id, chain_id, tx_hash, signed_tx, from_addr, to_addr, value, nonce, submitted_at, submitted_by, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(chains, i), tx_hash, secrets.token_hex(50).encode().hex(),
                 random_eth_address() if i % 2 == 0 else random_btc_address(),
                 random_eth_address() if i % 2 == 0 else random_btc_address(),
                 round(secrets.randbelow(1000) / 100, 4), i,
                 ago(hours=i % 24), "transaction-orchestrator", ago(hours=i % 24), ago(hours=i % 24)),
            )
        for i in range(n):
            cur.execute(
                "INSERT INTO fee_estimates (id, chain_id, priority, gas_limit, max_fee_per_gas, max_priority_fee_per_gas, gas_price, total_fee, sample_count, strategy, computed_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), "ethereum", pick(["LOW", "MEDIUM", "HIGH"], i), 21000,
                 round(10 + i * 5, 2), round(1.0 + i, 2), 0,
                 round(0.0002 + i * 0.0001, 7), 10, f"percentile_{50 + i * 15}",
                 ago(minutes=i), ago(minutes=i), ago(minutes=i)),
            )
        for chain in chains:
            cur.execute(
                "INSERT INTO chain_tips (chain_id, tip_height, tip_hash, finalized_height, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s) ON CONFLICT (chain_id) DO NOTHING",
                (chain, 19000000 + secrets.randbelow(1000), "0x" + secrets.token_hex(32),
                 18999000, ago(hours=1), ago(minutes=5)),
            )


def seed_wallet_management(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        wallet_ids = []
        for i in range(n):
            wid = uuid7()
            wallet_ids.append(wid)
            cur.execute(
                "INSERT INTO wallets (id, chain, type, label, state, key_id, custodian_ref, rotation_days, rotation_after_receives, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (wid, pick(["ethereum", "bitcoin", "polygon"], i), pick(["HOT", "WARM", "COLD"], i),
                 f"Wallet-{i}", pick(["ACTIVE", "PAUSED"], i), f"key-{uuid7()[:12]}",
                 f"custody-{uuid7()[:12]}" if i % 3 == 0 else "", 30 + i % 60, 1000 if i % 2 == 0 else None,
                 ago(days=i % 60), ago(days=i % 10)),
            )
        for i, wid in enumerate(wallet_ids):
            cur.execute(
                "INSERT INTO addresses (id, wallet_id, chain, address, derivation_path, index, change, state, receive_count, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), wid, pick(["ethereum", "bitcoin", "polygon"], i),
                 random_eth_address() if i % 2 == 0 else random_btc_address(),
                 f"m/44'/60'/0'/0/{i}", i, 0, "ACTIVE", secrets.randbelow(100),
                 ago(days=i % 30), ago(days=i % 10)),
            )
            cur.execute(
                "INSERT INTO balances (wallet_id, asset, confirmed, pending, locked, last_block_seen, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (wid, pick(["ETH", "BTC", "MATIC"], i), secrets.randbelow(10**18),
                 secrets.randbelow(10**16), secrets.randbelow(10**15),
                 19000000 + i, ago(days=30), ago(minutes=5)),
            )


def seed_transaction_orchestrator(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        rails = ["CARD", "ACH", "SEPA", "PIX", "UPI"]
        statuses = ["COMPLETED", "EXECUTING", "PENDING", "FAILED"]
        tx_biz_ids = []
        for i in range(n):
            tid = uuid7()
            biz_id = f"tx-{uuid7()[:12]}"
            tx_biz_ids.append(biz_id)
            cur.execute(
                "INSERT INTO transactions (id, tx_id, user_id, quote_id, amount, asset, rail, dest_address, status, created_at, updated_at, version) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (tid, biz_id, uuid7(), f"q-{uuid7()[:12]}", str(secrets.randbelow(50000) + 100),
                 pick(["BTC", "ETH", "USDC"], i), pick(rails, i),
                 random_eth_address() if i % 2 == 0 else random_btc_address(),
                 pick(statuses, i), ago(hours=i % 24), ago(minutes=i % 60), (i % 5) + 1),
            )
        steps = ["policy_check", "payment_capture", "kyt_screen", "mpc_sign", "chain_broadcast", "ledger_post"]
        for i, biz_id in enumerate(tx_biz_ids):
            for s, step in enumerate(steps):
                cur.execute(
                    "INSERT INTO transaction_steps (id, tx_id, step_name, status, attempt, started_at, finished_at, error, idempotency_key) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                    (uuid7(), biz_id, step, pick(["COMPLETED", "EXECUTING", "PENDING", "FAILED"], s + i),
                     1, ago(hours=i % 24, minutes=s * 10), ago(hours=i % 24, minutes=s * 5),
                     None if s % 4 != 0 else "error", f"idem-{uuid7()[:12]}"),
                )


def seed_treasury(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        for i in range(n):
            cur.execute(
                "INSERT INTO batches (id, asset_pair, status, notional_usd, opened_at, closed_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(["BTC/USD", "ETH/USD", "BTC/EUR"], i), pick(["OPEN", "CLOSED"], i),
                 round(secrets.randbelow(50000) + 1000, 2), ago(hours=i % 24),
                 ago(hours=i % 24 - 1) if i % 2 == 0 else None, ago(hours=i % 24), ago(minutes=i % 60)),
            )
        for i in range(n):
            cur.execute(
                "INSERT INTO float_positions (id, fiat_currency, short_fiat_amount, long_crypto_amount, long_crypto_asset, settlement_due_at, settled, batch_id, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(["USD", "EUR", "GBP"], i), round(secrets.randbelow(100000) + 1000, 2),
                 round(secrets.randbelow(100) / 10, 4), pick(["BTC", "ETH"], i),
                 future(days=i % 5), i % 2 == 0, uuid7(), ago(hours=i % 24), ago(minutes=i % 60)),
            )


def seed_audit(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        sources = ["transaction-orchestrator", "payment-orchestration", "mpc-signing-service",
                   "policy-risk-engine", "engine-recon"]
        actions = ["tx.created", "payment.captured", "signature.completed", "policy.evaluated"]
        for i in range(n):
            cur.execute(
                "INSERT INTO audit_events (id, ts, source_service, actor_id, action, target_type, target_id, payload_hash, payload_ref, prev_hash, this_hash, anchored, legal_hold, redacted, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), ago(hours=i % 24), pick(sources, i), uuid7(), pick(actions, i),
                 pick(["TRANSACTION", "PAYMENT", "SIGNING_SESSION", "DECISION"], i), f"target-{uuid7()[:12]}",
                 secrets.token_bytes(32), f"s3://audit/{i}.json",
                 secrets.token_bytes(32), secrets.token_bytes(32),
                 i % 10 == 0, i % 20 == 0, False, ago(hours=i % 24), ago(hours=i % 24)),
            )


def seed_notification(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        event_types = ["tx.created", "payment.captured", "tx.confirmed", "tx.failed", "tx.refunded"]
        channels = ["EMAIL", "SMS", "PUSH", "WEBHOOK"]
        statuses = ["DELIVERED", "SENT", "FAILED", "PENDING"]
        for i in range(n):
            cur.execute(
                "INSERT INTO notifications (id, event_id, event_type, channel, recipient, user_id, template_id, status, traffic_class, locale, created_at, updated_at, sent_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), f"evt-{uuid7()[:12]}", pick(event_types, i), pick(channels, i),
                 random_email() if i % 4 == 0 else (random_phone() if i % 4 == 1 else
                 (random_device_token() if i % 4 == 2 else random_url())),
                 uuid7(), pick(event_types, i), pick(statuses, i), "TRANSACTIONAL", "en",
                 ago(hours=i % 24), ago(minutes=i % 60), ago(minutes=i % 60 - 1)),
            )
        for i in range(max(1, n // 5)):
            cur.execute(
                "INSERT INTO user_preferences (id, user_id, email, sms, push, webhook, locale, quiet_start, quiet_end, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), uuid7(), i % 2 == 0, i % 3 == 0, i % 4 == 0, i % 5 == 0, "en",
                 "22:00" if i % 2 == 0 else None, "07:00" if i % 2 == 0 else None,
                 ago(days=i + 1), ago(days=i)),
            )


def seed_aml_kyt(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        exposures = ["LOW", "MEDIUM", "HIGH"]
        decisions = ["APPROVE", "REVIEW", "BLOCK"]
        screen_ids = []
        for i in range(n):
            sid = uuid7()
            screen_ids.append(sid)
            cur.execute(
                "INSERT INTO kyt_screens (screen_id, tx_id, address, source_address, chain, amount, risk_score, exposure, decision, vendor, vendor_response_id, cache_hit, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (sid, f"tx-{uuid7()[:12]}", random_eth_address() if i % 2 == 0 else random_btc_address(),
                 random_eth_address(), pick(["ethereum", "bitcoin"], i),
                 round(secrets.randbelow(1000) / 100, 2), secrets.randbelow(100),
                 pick(exposures, i), pick(decisions, i), pick(["chainalysis", "trm"], i),
                 uuid7(), i % 3 == 0, ago(hours=i % 24), ago(hours=i % 24)),
            )
        for i in range(max(1, n // 3)):
            cur.execute(
                "INSERT INTO kyt_alerts (id, screen_id, tx_id, address, chain, exposure, severity, status, assignee, created_at, updated_at, closed_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(screen_ids, i), f"tx-{uuid7()[:12]}", random_eth_address(), "ethereum",
                 pick(exposures, i), pick(exposures, i), pick(["OPEN", "IN_REVIEW", "CLOSED"], i),
                 f"analyst-{uuid7()[:12]}" if i % 2 == 0 else None, ago(hours=i % 24), ago(minutes=i % 60),
                 ago(minutes=30) if i % 3 == 0 else None),
            )


def seed_ledger_accounting(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        acct_types = [
            ("user_custodial", "DEBIT", ["DEBIT", "CREDIT"], "BOTH"),
            ("user_payable", "CREDIT", ["DEBIT", "CREDIT"], "FIAT"),
            ("fee_revenue", "CREDIT", ["CREDIT"], "FIAT"),
            ("treasury_crypto", "DEBIT", ["DEBIT", "CREDIT"], "CRYPTO"),
            ("hot_wallet", "DEBIT", ["DEBIT", "CREDIT"], "CRYPTO"),
            ("fx_settlement", "DEBIT", ["DEBIT", "CREDIT"], "FIAT"),
        ]
        for type_name, nb, dirs, ac in acct_types:
            cur.execute(
                "INSERT INTO chart_of_accounts (version, type_name, normal_balance, allowed_directions, asset_class, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s) ON CONFLICT (version, type_name) DO NOTHING",
                ("v1", type_name, nb, dirs, ac, ago(days=30), ago(days=30)),
            )
        account_ids = []
        for i in range(max(n, 7)):
            aid = uuid7()
            account_ids.append(aid)
            tn, _, _, ac = pick(acct_types, i)
            cur.execute(
                "INSERT INTO accounts (account_id, type_name, asset_class, label, parent_id, status, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, NULL, %s, %s, %s)",
                (aid, tn, ac, f"Account {i}", "ACTIVE", ago(days=30), ago(days=30)),
            )
        prev_hash = "0" * 64
        seq = 1
        for i in range(n):
            post_id = uuid7()
            ts = ago(hours=n - i)
            ts_epoch = int(ts.timestamp())
            debit_acc = pick(account_ids, i * 2)
            credit_acc = pick(account_ids, i * 2 + 1)
            amount = secrets.randbelow(10**9) + 1
            asset = pick(["BTC", "ETH", "USD", "EUR"], i)
            cur.execute(
                "INSERT INTO postings (posting_id, ref_tx_id, memo, status, hash_chain_head, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (post_id, f"tx-{i:03d}", f"Posting {i}", "POSTED", "", ts, ts),
            )
            e1_id = uuid7()
            canonical1 = f"{prev_hash}|{e1_id}|{debit_acc}|DEBIT|{amount}|{asset}|{ts_epoch}"
            this_hash1 = hashlib.sha256(canonical1.encode()).hexdigest()
            cur.execute(
                "INSERT INTO entries (entry_id, posting_id, account_id, direction, amount, asset, sequence_number, prev_hash, this_hash, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (e1_id, post_id, debit_acc, "DEBIT", amount, asset, seq, prev_hash, this_hash1, ts, ts),
            )
            prev_hash = this_hash1
            seq += 1
            e2_id = uuid7()
            canonical2 = f"{prev_hash}|{e2_id}|{credit_acc}|CREDIT|{amount}|{asset}|{ts_epoch}"
            this_hash2 = hashlib.sha256(canonical2.encode()).hexdigest()
            cur.execute(
                "INSERT INTO entries (entry_id, posting_id, account_id, direction, amount, asset, sequence_number, prev_hash, this_hash, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (e2_id, post_id, credit_acc, "CREDIT", amount, asset, seq, prev_hash, this_hash2, ts, ts),
            )
            prev_hash = this_hash2
            seq += 1
            cur.execute(
                "UPDATE postings SET hash_chain_head = %s WHERE posting_id = %s",
                (this_hash2, post_id),
            )
            cur.execute(
                "INSERT INTO hash_chain (posting_id, head_hash, global_sequence_head, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s)",
                (post_id, this_hash2, this_hash2, ts, ts),
            )


def seed_reconciliation(conn: "psycopg.Connection", n: int) -> None:
    with conn.cursor() as cur:
        sources = ["LEDGER", "RAILS", "EXCHANGES", "ONCHAIN", "CUSTODY"]
        for i in range(n):
            cur.execute(
                "INSERT INTO external_events (id, source, external_event_id, payload, ingested_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s::jsonb, %s, %s, %s)",
                (uuid7(), pick(sources, i), f"evt-{uuid7()[:12]}",
                 jsonb({"amount": secrets.randbelow(10000), "asset": pick(["USD", "BTC", "ETH"], i)}),
                 ago(hours=i % 24), ago(hours=i % 24), ago(hours=i % 24)),
            )
        run_ids = []
        for i in range(n):
            rid = uuid7()
            run_ids.append(rid)
            cur.execute(
                "INSERT INTO recon_runs (id, source, scope, status, matched_count, unmatched_count, breaks_count, started_at, completed_at, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (rid, pick(sources, i), pick(["DAILY", "INTRADAY"], i),
                 pick(["COMPLETED", "RUNNING", "FAILED"], i),
                 secrets.randbelow(100), secrets.randbelow(10), secrets.randbelow(10),
                 ago(hours=i % 24), ago(hours=i % 24 - 1) if i % 3 == 0 else None,
                 ago(hours=i % 24), ago(minutes=i % 60)),
            )
        for i in range(max(1, n // 3)):
            cur.execute(
                "INSERT INTO breaks (id, run_id, type, classification, source, asset, reference, internal_amount, external_amount, status, detected_at, resolved_at, age_seconds, created_at, updated_at) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (uuid7(), pick(run_ids, i), pick(["AMOUNT_MISMATCH", "MISSING_ENTRY", "DUPLICATE", "TIMING_GAP"], i),
                 pick(["TIMING", "REAL"], i), pick(sources, i), pick(["USD", "BTC", "ETH"], i),
                 f"ref-{uuid7()[:12]}", round(secrets.randbelow(10000), 2), round(secrets.randbelow(10000), 2),
                 pick(["OPEN", "RESOLVED", "ESCALATED"], i), ago(hours=i % 24),
                 ago(minutes=30) if i % 3 == 0 else None, secrets.randbelow(10000),
                 ago(hours=i % 24), ago(minutes=i % 60)),
            )


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

SEEDERS = {
    "identity_auth": seed_identity_auth,
    "onboarding_kyc": seed_onboarding_kyc,
    "policy_engine": seed_policy_engine,
    "fraud": seed_fraud,
    "pricing_quote": seed_pricing_quote,
    "liquidity": seed_liquidity,
    "fx_hedging": seed_fx_hedging,
    "blockchain_gateway": seed_blockchain_gateway,
    "wallet_management": seed_wallet_management,
    "transaction_orchestrator": seed_transaction_orchestrator,
    "treasury": seed_treasury,
    "audit": seed_audit,
    "notification": seed_notification,
    "aml_kyt": seed_aml_kyt,
    "ledger_accounting": seed_ledger_accounting,
    "reconciliation": seed_reconciliation,
}


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

DEFAULT_MODE = 10


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", type=int, default=DEFAULT_MODE,
                        help="records per table (default: 10; try 100 or 1000)")
    parser.add_argument("--dsn", default=os.environ.get("SEED_DSN", "postgresql://postgres:postgres@localhost:5432"),
                        help="base Postgres DSN (without DB name)")
    parser.add_argument("--db", help="seed only this database (default: all)")
    args = parser.parse_args()

    n = args.mode
    dbs = [args.db] if args.db else list(SEEDERS)

    for dbname in dbs:
        seeder = SEEDERS.get(dbname)
        if not seeder:
            print(f"unknown db: {dbname}", file=sys.stderr)
            continue
        print(f"  seeding {dbname} ({n} records)...", flush=True)
        try:
            conn = connect(args.dsn, dbname)
            seeder(conn, n)
            conn.close()
        except Exception as exc:
            print(f"  ERROR {dbname}: {exc}", file=sys.stderr)
            return 1

    print(f"done: {len(dbs)} databases seeded with {n} records each")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())