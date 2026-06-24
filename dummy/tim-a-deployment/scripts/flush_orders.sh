#!/usr/bin/env bash
# flush_orders.sh — Flush HANYA order hasil load test, jaga seed (Phase 6, untuk Tim B)
# FP TKA 2026 — Tim A.
#
# Constraint soal: "flush data yang di-insert per skenario, TAPI data awal jangan dihapus."
# Seed = 10.000 order dgn created_at dalam 1 tahun terakhir (semua < hari test).
# Load test = order baru dgn created_at >= waktu mulai skenario.
# Mekanisme: 'arm' catat waktu mulai → 'flush' hapus order created_at >= waktu itu.
#
# Alur per skenario:
#   ./flush_orders.sh arm        # tepat sebelum skenario dimulai
#   <jalankan Locust>
#   ./flush_orders.sh flush      # setelah skenario → hapus order skenario itu saja
#
# Override manual: FLUSH_SINCE="2026-06-18T10:00:00.000Z" ./flush_orders.sh flush
set -euo pipefail

DB_URI="${DB_URI:-mongodb://10.0.0.13:27017/orderdb}"
MARK="${MARK:-/tmp/flush_orders.marker}"

case "${1:-flush}" in
  arm)
    date -u +%Y-%m-%dT%H:%M:%S.000Z > "$MARK"
    echo "Armed: $(cat "$MARK"). Jalankan skenario, lalu './flush_orders.sh flush'."
    ;;

  count)
    mongosh "$DB_URI" --quiet --eval 'print("orders total: " + db.orders.countDocuments())'
    ;;

  flush)
    SINCE="${FLUSH_SINCE:-$(cat "$MARK" 2>/dev/null || true)}"
    if [ -z "$SINCE" ]; then
      echo "❌ Belum di-arm. Jalankan './flush_orders.sh arm' sebelum skenario, atau set FLUSH_SINCE."
      exit 1
    fi
    mongosh "$DB_URI" --quiet --eval "
      const since = ISODate('${SINCE}');
      const before = db.orders.countDocuments();
      const res    = db.orders.deleteMany({ created_at: { \$gte: since } });
      const after  = db.orders.countDocuments();
      print('Cutoff      : ' + since.toISOString());
      print('Sebelum     : ' + before);
      print('Dihapus     : ' + res.deletedCount + '  (order hasil load test)');
      print('Sisa (seed) : ' + after);
      if (after < 9000) print('⚠️  PERINGATAN: sisa < 9000, cek apakah cutoff terlalu awal!');
    "
    rm -f "$MARK"
    ;;

  *)
    echo "Usage: $0 {arm|flush|count}"; exit 1;;
esac
