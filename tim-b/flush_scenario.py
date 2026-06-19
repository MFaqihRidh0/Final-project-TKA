#!/usr/bin/env python3
"""
flush_scenario.py — Hapus orders hasil load test saja, seed awal tetap aman.
Tim B: jalankan dari laptop sebelum & sesudah tiap skenario Locust.

Cara pakai:
    python flush_scenario.py arm   --uri mongodb://10.0.0.13:27017
    <jalankan Locust skenario X>
    python flush_scenario.py flush --uri mongodb://10.0.0.13:27017
    python flush_scenario.py count --uri mongodb://10.0.0.13:27017

File marker: flush_marker.txt (disimpan lokal di folder ini)
"""

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

from pymongo import MongoClient

MARKER_FILE = Path(__file__).parent / "flush_marker.txt"

# ─── CLI ──────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Flush orders skenario Locust")
parser.add_argument("action", choices=["arm", "flush", "count", "status"],
                    help="arm=catat waktu mulai | flush=hapus | count=hitung | status=cek marker")
parser.add_argument("--uri", default="mongodb://localhost:27017/",
                    help="MongoDB URI (default: localhost)")
parser.add_argument("--since", default=None,
                    help="Override cutoff ISO timestamp, mis. 2026-06-19T10:00:00.000Z")
args = parser.parse_args()

def mongo_connect():
    client = MongoClient(args.uri, serverSelectionTimeoutMS=5000)
    client.server_info()
    return client["orderdb"]["orders"]

def utc_now_str():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

# ─── ARM ──────────────────────────────────────────────────────────────────────
if args.action == "arm":
    ts = utc_now_str()
    MARKER_FILE.write_text(ts)
    print(f"✅ Armed pada {ts}")
    print(f"   File marker: {MARKER_FILE}")
    print(f"   Sekarang jalankan Locust, lalu 'python flush_scenario.py flush'")

# ─── STATUS ───────────────────────────────────────────────────────────────────
elif args.action == "status":
    if MARKER_FILE.exists():
        ts = MARKER_FILE.read_text().strip()
        print(f"🕐 Marker aktif: {ts}")
        print(f"   Flush akan hapus semua orders dengan created_at >= {ts}")
    else:
        print("⚠️  Belum di-arm. Jalankan 'arm' terlebih dahulu.")

# ─── COUNT ────────────────────────────────────────────────────────────────────
elif args.action == "count":
    orders = mongo_connect()
    total  = orders.count_documents({})
    print(f"📊 Total orders di database: {total:,}")

    if MARKER_FILE.exists():
        ts = MARKER_FILE.read_text().strip()
        since = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        seed_count  = orders.count_documents({"created_at": {"$lt":  since}})
        test_count  = orders.count_documents({"created_at": {"$gte": since}})
        print(f"   Seed (sebelum {ts}): {seed_count:,}")
        print(f"   Load test (sesudah): {test_count:,}")

# ─── FLUSH ────────────────────────────────────────────────────────────────────
elif args.action == "flush":
    # Tentukan cutoff
    if args.since:
        ts = args.since
    elif MARKER_FILE.exists():
        ts = MARKER_FILE.read_text().strip()
    else:
        print("❌ Belum di-arm dan --since tidak diberikan.")
        print("   Jalankan 'arm' sebelum skenario, atau pakai --since <timestamp>")
        sys.exit(1)

    since = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    orders = mongo_connect()

    before = orders.count_documents({})
    result = orders.delete_many({"created_at": {"$gte": since}})
    after  = orders.count_documents({})

    print(f"🗑️  Flush selesai!")
    print(f"   Cutoff     : {ts}")
    print(f"   Sebelum    : {before:,}")
    print(f"   Dihapus    : {result.deleted_count:,}  (order hasil load test)")
    print(f"   Sisa (seed): {after:,}")

    if after < 9_000:
        print(f"⚠️  PERINGATAN: sisa < 9000, cutoff mungkin terlalu awal!")

    # Reset marker setelah flush
    if MARKER_FILE.exists():
        MARKER_FILE.unlink()
        print("   Marker dihapus (siap untuk arm skenario berikutnya)")
