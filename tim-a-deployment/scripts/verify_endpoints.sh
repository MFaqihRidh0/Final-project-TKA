#!/usr/bin/env bash
# verify_endpoints.sh — E2E test semua endpoint via Load Balancer (Phase 5)
# FP TKA 2026 — Tim A. Disesuaikan ke API ASLI (JWT auth + items[]).
#
# Pakai:  ./verify_endpoints.sh http://<public-ip-lb>
#         ./verify_endpoints.sh                 # default http://localhost
# Butuh: curl, jq
set -uo pipefail

BASE="${1:-http://localhost}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin1@tka.its.ac.id}"
ADMIN_PASS="${ADMIN_PASS:-Admin@12345}"

pass=0; fail=0
check () { # nama  expected  actual
  if [ "$2" = "$3" ]; then echo "  ✅ $1 (HTTP $3)"; pass=$((pass+1));
  else echo "  ❌ $1 (expected $2, got $3)"; fail=$((fail+1)); fi
}

echo "=== Target: $BASE ==="

echo "── 0. GET /health"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/health")
check "health" 200 "$code"

echo "── 1. POST /auth/login (admin)"
LOGIN=$(curl -s -X POST "$BASE/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")
TOKEN=$(echo "$LOGIN" | jq -r '.token // empty')
[ -n "$TOKEN" ] && check "login admin" "ok" "ok" || { echo "  ❌ login gagal: $LOGIN"; fail=$((fail+1)); }
AUTH=(-H "Authorization: Bearer $TOKEN")

echo "── 2. GET /products (ambil 1 product_id)"
PRODS=$(curl -s "$BASE/products?limit=1")
PID=$(echo "$PRODS" | jq -r '.data[0]._id // empty')
[ -n "$PID" ] && check "list products" "ok" "ok" || { echo "  ❌ tak ada produk (seed belum di-restore?)"; fail=$((fail+1)); }

echo "── 3. POST /orders (buat pesanan)"
ORDER=$(curl -s -X POST "$BASE/orders" "${AUTH[@]}" -H 'Content-Type: application/json' \
  -d "{\"items\":[{\"product_id\":\"$PID\",\"qty\":1}],\"payment_method\":\"qris\",\"address\":\"Jl. Tes No.1, Surabaya\"}")
OID=$(echo "$ORDER" | jq -r '.order_id // empty')
[ -n "$OID" ] && check "create order" "ok" "ok" || { echo "  ❌ create order gagal: $ORDER"; fail=$((fail+1)); }
echo "     order_id = $OID"

echo "── 4. GET /orders/<id>"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/orders/$OID" "${AUTH[@]}")
check "get order detail" 200 "$code"

echo "── 5. PUT /orders/<id>/status (admin → processing)"
code=$(curl -s -o /dev/null -w '%{http_code}' -X PUT "$BASE/orders/$OID/status" "${AUTH[@]}" \
  -H 'Content-Type: application/json' -d '{"status":"processing"}')
check "update status" 200 "$code"

echo "── 6. GET /orders (list)"
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/orders?limit=5" "${AUTH[@]}")
check "list orders" 200 "$code"

echo
echo "=== HASIL: $pass passed, $fail failed ==="
exit $([ "$fail" -eq 0 ] && echo 0 || echo 1)
