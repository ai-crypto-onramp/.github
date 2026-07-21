#!/usr/bin/env bash
# Generate an ephemeral internal PKI for the compose stack: a CA plus a
# cert/key per service that opts into mTLS (mpc-signing-service,
# transaction-orchestrator, and any other internal partner). The output is
# intended to be mounted at /certs in compose. DEV/STAGING ONLY — production
# issues short-lived certs from the internal PKI, not this script.
set -euo pipefail

OUT="${1:-./certs}"
SERVICES="${SERVICES:-mpc-signing-service transaction-orchestrator policy-risk-engine aml-kyt-screening ledger-accounting blockchain-gateway}"
DAYS="${DAYS:-3650}"

mkdir -p "$OUT"
cd "$OUT"

if [[ ! -f internal-ca.key ]]; then
  echo "==> generating internal CA"
  openssl genrsa -out internal-ca.key 4096 2>/dev/null
  openssl req -x509 -new -nodes -key internal-ca.key -sha256 -days "$DAYS" \
    -subj "/CN=ai-crypto-onramp-internal-ca" -out internal-ca.crt 2>/dev/null
fi

for svc in $SERVICES; do
  echo "==> issuing cert for $svc"
  openssl genrsa -out "$svc.key" 2048 2>/dev/null
  openssl req -new -key "$svc.key" -subj "/CN=$svc" -out "$svc.csr" 2>/dev/null
  cat > "$svc.ext" <<EOF
subjectAltName = DNS:localhost, DNS:$svc, IP:127.0.0.1
extendedKeyUsage = serverAuth, clientAuth
EOF
  openssl x509 -req -in "$svc.csr" -CA internal-ca.crt -CAkey internal-ca.key \
    -CAcreateserial -out "$svc.crt" -days "$DAYS" -sha256 -extfile "$svc.ext" 2>/dev/null
  rm -f "$svc.csr" "$svc.ext"
done

echo "==> internal PKI written to $OUT (internal-ca.crt + per-service .crt/.key)"
echo "    mount this dir at /certs in compose, then uncomment the TLS_* env"
echo "    vars and the internal-certs volume mount in .github/docker-compose.yml"