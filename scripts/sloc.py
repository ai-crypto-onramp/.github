#!/usr/bin/env python3
"""Print raw SLOC (code lines) per service directory using scc.

Output format: one line per service, "<name> <count>". Total on the last line.
Ignores generated/vendored dirs (respects .gitignore; --no-gen skips generated).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

SERVICES = [
    "aml-kyt-screening",
    "api-gateway",
    "audit-event-log",
    "back-office-ui",
    "blockchain-gateway",
    "exchange-connectors",
    "fraud-detection",
    "fx-hedging",
    "front-office-ui",
    "identity-auth",
    "ledger-accounting",
    "liquidity-routing",
    "middle-office-ui",
    "mpc-signing-service",
    "notification",
    "onboarding-kyc",
    "payment-orchestration",
    "policy-risk-engine",
    "pricing-quote",
    "rail-connectors",
    "reconciliation",
    "transaction-orchestrator",
    "treasury-orchestration",
    "wallet-management",
]

# .github/ is its own repo; services live in the sibling directories of
# .github/, i.e. one level above .github/. This script lives at
# .github/scripts/sloc.py, so the monorepo root is two parents up.
ROOT = Path(__file__).resolve().parent.parent.parent


def sloc(path: Path) -> int:
    proc = subprocess.run(
        ["scc", str(path), "--no-cocomo", "--no-gen", "--format", "json"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        print(f"scc failed for {path}: {proc.stderr}", file=sys.stderr)
        return 0
    data = json.loads(proc.stdout)
    return sum(lang["Code"] for lang in data)


def main() -> int:
    if not shutil.which("scc"):
        print("scc not found on PATH; install via `go install github.com/boyter/scc/v3@latest`", file=sys.stderr)
        return 1

    total = 0
    for name in SERVICES:
        path = ROOT / name
        if not path.exists():
            print(f"{name} 0  (missing)")
            continue
        count = sloc(path)
        total += count
        print(f"{name} {count}")
    print(f"total {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())