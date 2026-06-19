# gunicorn.conf.py — vm-app1 & vm-app2 (identik)
# Order Processing Service — FP TKA 2026 (Tim A, Phase 2)
# Tunable via env (di-set lewat orderapp.env). Tim B akan eksperimen worker count.
import os

# Bind 0.0.0.0:5000 supaya vm-lb bisa connect (firewall yang batasi akses, bukan bind).
bind = "0.0.0.0:5000"

# Worker: formula (2*CPU)+1. e2-small ≈ 1 vCPU efektif → mulai 4 (sesuai briefing).
# Naikkan/turunkan via GUNICORN_WORKERS saat tuning bareng Tim B.
workers = int(os.environ.get("GUNICORN_WORKERS", "4"))

# Worker class: 'sync' dulu (default, paling stabil). Untuk workload I/O-bound
# (call ke MongoDB), 'gthread' + threads sering naikkan throughput tanpa risiko
# monkeypatch. 'gevent' bisa dicoba tapi butuh paket gevent & hati-hati dgn pymongo.
worker_class = os.environ.get("GUNICORN_WORKER_CLASS", "sync")
threads      = int(os.environ.get("GUNICORN_THREADS", "1"))

# JANGAN preload: biar tiap worker import app SETELAH fork → tiap worker punya
# MongoClient sendiri (pymongo tidak fork-safe kalau client dibuat sebelum fork).
preload_app = False

# Recycle worker untuk cegah memory creep saat load test panjang.
max_requests        = 2000
max_requests_jitter = 200

timeout   = 60      # request lama (mis. /admin/stats aggregate) jangan langsung dibunuh
keepalive = 5       # cocokkan dengan keepalive upstream Nginx LB (Phase 3)

# Logging: matikan access log saat load test (overhead per-request). Error tetap ke journald.
accesslog = None
errorlog  = "-"     # stderr → journald
loglevel  = "info"
