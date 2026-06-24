# Tim B — Panduan Setup & Eksekusi Load Testing
# FP TKA 2026

# ─── INSTALL DEPENDENCIES ────────────────────────────────────────────────────
pip install locust pymongo bcrypt

# ─── VARIABEL — ganti sesuai IP dari Tim A ───────────────────────────────────
# Setelah Tim A provisioning, minta dua IP ini:
LOCUST_HOST=http://20.255.63.132/api      # IP load balancer Tim A dengan prefix /api (lb-dan-fe)
MONGO_URI=mongodb://20.205.18.6:27017   # IP MongoDB Tim A (app1-dan-db)

# ─── STEP 1: SEED DATABASE (jalankan sekali sebelum semua skenario) ───────────
python seed_db.py --uri $MONGO_URI

# ─── ALUR PER SKENARIO ────────────────────────────────────────────────────────
# Sebelum tiap skenario: ARM dulu
# Jalankan Locust
# Sesudah skenario: FLUSH

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 1 — Maksimum RPS (0% failure)
# Naikkan user secara bertahap, catat RPS tertinggi saat failure masih 0%
# ════════════════════════════════════════════════════════════════════════════
python flush_scenario.py arm --uri $MONGO_URI

locust -f ../fp-tka-26-main/Resources/Test/locustfile.py \
    --host=$LOCUST_HOST \
    --headless \
    --users 10 --spawn-rate 1 \
    --run-time 60s \
    --html hasil/skenario1_rps.html \
    --csv  hasil/skenario1_rps

# (Atau buka UI: locust -f locustfile.py --host=$LOCUST_HOST → buka http://localhost:8089)

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 2 — Peak Concurrency Spawn Rate 50
# ════════════════════════════════════════════════════════════════════════════
python flush_scenario.py arm --uri $MONGO_URI

locust -f ../fp-tka-26-main/Resources/Test/locustfile.py \
    --host=$LOCUST_HOST \
    --headless \
    --users 500 --spawn-rate 50 \
    --run-time 60s \
    --html hasil/skenario2_spawn50.html \
    --csv  hasil/skenario2_spawn50

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 3 — Peak Concurrency Spawn Rate 100
# ════════════════════════════════════════════════════════════════════════════
python flush_scenario.py arm --uri $MONGO_URI

locust -f ../fp-tka-26-main/Resources/Test/locustfile.py \
    --host=$LOCUST_HOST \
    --headless \
    --users 500 --spawn-rate 100 \
    --run-time 60s \
    --html hasil/skenario3_spawn100.html \
    --csv  hasil/skenario3_spawn100

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 4 — Peak Concurrency Spawn Rate 200
# ════════════════════════════════════════════════════════════════════════════
python flush_scenario.py arm --uri $MONGO_URI

locust -f ../fp-tka-26-main/Resources/Test/locustfile.py \
    --host=$LOCUST_HOST \
    --headless \
    --users 500 --spawn-rate 200 \
    --run-time 60s \
    --html hasil/skenario4_spawn200.html \
    --csv  hasil/skenario4_spawn200

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 5 — Peak Concurrency Spawn Rate 500
# ════════════════════════════════════════════════════════════════════════════
python flush_scenario.py arm --uri $MONGO_URI

locust -f ../fp-tka-26-main/Resources/Test/locustfile.py \
    --host=$LOCUST_HOST \
    --headless \
    --users 500 --spawn-rate 500 \
    --run-time 60s \
    --html hasil/skenario5_spawn500.html \
    --csv  hasil/skenario5_spawn500

python flush_scenario.py flush --uri $MONGO_URI

# ─── CEK JUMLAH ORDERS KAPAN SAJA ────────────────────────────────────────────
python flush_scenario.py count --uri $MONGO_URI
