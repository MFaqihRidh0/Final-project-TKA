# Tim B — PowerShell Setup & Eksekusi Load Testing (dengan venv)
# FP TKA 2026

# ─── VARIABEL ────────────────────────────────────────────────────────────────
$LOCUST_HOST = "http://20.255.63.132/api"       # IP load balancer Tim A dengan prefix /api (lb-dan-fe)
$MONGO_URI = "mongodb://20.205.18.6:27017"   # IP MongoDB Tim A (app1-dan-db)
$LOCUST_FILE = "../fp-tka-26-main/Resources/Test/locustfile.py"
$VENV_DIR = ".venv"

# ─── SETUP VIRTUAL ENVIRONMENT (VENV) ────────────────────────────────────────
if (-not (Test-Path $VENV_DIR)) {
    Write-Host "[*] Membuat virtual environment (.venv)..." -ForegroundColor Yellow
    python -m venv $VENV_DIR
}

Write-Host "[*] Mengaktifkan virtual environment..." -ForegroundColor Yellow
# Aktifkan venv di sesi PowerShell ini
. .venv\Scripts\Activate.ps1

Write-Host "[*] Menginstall/memastikan dependensi terpasang..." -ForegroundColor Yellow
pip install locust pymongo bcrypt --disable-pip-version-check

# Buat folder output hasil
New-Item -ItemType Directory -Force -Path .\hasil | Out-Null

# ─── STEP 1: SEED DATABASE (jalankan sekali sebelum semua skenario) ───────────
Write-Host "[*] Seeding database..." -ForegroundColor Cyan
python seed_db.py --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 1 — Maksimum RPS (0% failure)
# ════════════════════════════════════════════════════════════════════════════
Write-Host "[*] Running Scenario 1: Maximum RPS..." -ForegroundColor Cyan
python flush_scenario.py arm --uri $MONGO_URI

locust -f $LOCUST_FILE `
    --host=$LOCUST_HOST `
    --headless `
    --users 10 --spawn-rate 1 `
    --run-time 60s `
    --html hasil/skenario1_rps.html `
    --csv  hasil/skenario1_rps

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 2 — Peak Concurrency Spawn Rate 50
# ════════════════════════════════════════════════════════════════════════════
Write-Host "[*] Running Scenario 2: Peak Concurrency (Spawn Rate 50)..." -ForegroundColor Cyan
python flush_scenario.py arm --uri $MONGO_URI

locust -f $LOCUST_FILE `
    --host=$LOCUST_HOST `
    --headless `
    --users 500 --spawn-rate 50 `
    --run-time 60s `
    --html hasil/skenario2_spawn50.html `
    --csv  hasil/skenario2_spawn50

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 3 — Peak Concurrency Spawn Rate 100
# ════════════════════════════════════════════════════════════════════════════
Write-Host "[*] Running Scenario 3: Peak Concurrency (Spawn Rate 100)..." -ForegroundColor Cyan
python flush_scenario.py arm --uri $MONGO_URI

locust -f $LOCUST_FILE `
    --host=$LOCUST_HOST `
    --headless `
    --users 500 --spawn-rate 100 `
    --run-time 60s `
    --html hasil/skenario3_spawn100.html `
    --csv  hasil/skenario3_spawn100

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 4 — Peak Concurrency Spawn Rate 200
# ════════════════════════════════════════════════════════════════════════════
Write-Host "[*] Running Scenario 4: Peak Concurrency (Spawn Rate 200)..." -ForegroundColor Cyan
python flush_scenario.py arm --uri $MONGO_URI

locust -f $LOCUST_FILE `
    --host=$LOCUST_HOST `
    --headless `
    --users 500 --spawn-rate 200 `
    --run-time 60s `
    --html hasil/skenario4_spawn200.html `
    --csv  hasil/skenario4_spawn200

python flush_scenario.py flush --uri $MONGO_URI

# ════════════════════════════════════════════════════════════════════════════
# SKENARIO 5 — Peak Concurrency Spawn Rate 500
# ════════════════════════════════════════════════════════════════════════════
Write-Host "[*] Running Scenario 5: Peak Concurrency (Spawn Rate 500)..." -ForegroundColor Cyan
python flush_scenario.py arm --uri $MONGO_URI

locust -f $LOCUST_FILE `
    --host=$LOCUST_HOST `
    --headless `
    --users 500 --spawn-rate 500 `
    --run-time 60s `
    --html hasil/skenario5_spawn500.html `
    --csv  hasil/skenario5_spawn500

python flush_scenario.py flush --uri $MONGO_URI

# Check orders count
python flush_scenario.py count --uri $MONGO_URI
Write-Host "All scenarios executed successfully!" -ForegroundColor Green
