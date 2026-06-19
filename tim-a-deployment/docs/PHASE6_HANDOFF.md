# Phase 6 — Handoff ke Tim B & Tim C

## Untuk Tim B (Load Testing)

### Yang diberikan
- **Public IP/domain vm-lb** → target Locust: `locust -f locustfile.py --host=http://<public-ip-lb>`
- **Akses SSH** semua VM (monitoring `htop`/`vmstat` saat test):
  ```bash
  LB_IP="<PUBLIC_IP_vm-lb>"
  ssh -J azureuser@$LB_IP azureuser@10.0.0.11   # vm-app
  ssh -J azureuser@$LB_IP azureuser@10.0.0.13   # vm-db
  ```
- **Worker Gunicorn saat ini = 4.** Untuk ubah saat tuning:
  ```bash
  # di vm-app: edit /etc/orderapp/orderapp.env → GUNICORN_WORKERS=N
  sudo systemctl restart orderapp
  ```

### Flush antar skenario — `scripts/flush_orders.sh`
Hapus HANYA order hasil load test, **jaga 10.000 seed**:
```bash
./flush_orders.sh arm      # tepat SEBELUM skenario
# (jalankan Locust)
./flush_orders.sh flush    # SETELAH skenario → hapus order skenario itu saja
./flush_orders.sh count    # cek jumlah order kapan saja
```
Mekanisme: `arm` catat waktu mulai, `flush` hapus `created_at >= waktu itu`.
Seed (created_at < hari test) aman. Ada guard: warning kalau sisa < 9000.

### ⚠️ Caveat untuk Tim B
1. **Stok produk berkurang tiap order** (app.py `$inc stock -qty`). Setelah banyak
   skenario, produk bisa habis → `POST /orders` balas "stok tidak cukup" (locust
   anggap ini sukses 400, RPS tetap kehitung, tapi write berkurang). Kalau mau
   write konsisten, reset stock antar sesi:
   ```bash
   mongosh "mongodb://10.0.0.13:27017/orderdb" --eval \
     'db.products.updateMany({}, {$set:{stock: 100000}})'
   ```
   (Ini mengubah field seed `stock` saja — bukan menghapus data. Catat di laporan.)
2. **Locust harus dari host berbeda** dari server (constraint soal #1). Jangan jalankan
   Locust di vm-app/vm-lb.
3. JWT_SECRET sudah identik di app1 & app2 → token valid lintas worker (tidak ada 401 acak).

## Untuk Tim C (Dokumentasi)

### Config files siap di-commit (folder `configs/` + `scripts/` + `frontend/`)
Struktur target di repo kelompok:
```
fp-tka-26-main/
├── configs/
│   ├── mongod.conf
│   ├── gunicorn.conf.py
│   ├── orderapp.service
│   ├── orderapp.env.example
│   ├── nginx-lb-main.conf
│   ├── nginx-lb.conf
│   └── nginx-fe.conf
├── scripts/
│   ├── 01_provision_gcp.sh
│   ├── 10_db_install.sh
│   ├── 11_db_init.js
│   ├── 20_app_setup.sh
│   ├── 30_lb_setup.sh
│   ├── 40_fe_setup.sh
│   ├── verify_endpoints.sh
│   └── flush_orders.sh
└── frontend/ (index.html, styles.css — versi adaptasi)
```

### Bukti yang dikumpulkan per phase
Lihat checklist "Bukti untuk Tim C" di tiap `docs/PHASEx_*.md`.

### Catatan transparansi untuk laporan
- Endpoint & frontend bawaan **tidak cocok** dengan `app.py` asli (kemungkinan
  versi soal berbeda). Tim A menyesuaikan index/script ke API asli + JWT. Jelaskan
  di laporan.
- Index MongoDB dibuat melebihi yang diminta (order_id, created_at) karena load
  test butuh index di `user_id`, `status`, `products`, `users.email`.

## Checklist final sebelum "Tim A selesai"

- [ ] 4 VM hidup & accessible via SSH (vm-lb langsung, vm-app1/app2/db via jump host)
- [ ] MongoDB running, index lengkap, seed ter-restore (10.000 orders)
- [ ] vm-app1 & vm-app2 jalan via systemd, JWT_SECRET identik
- [ ] Nginx LB round-robin terverifikasi (HA: matikan 1 app, tetap jalan)
- [ ] Frontend accessible publik, login → produk → checkout → riwayat OK
- [ ] `verify_endpoints.sh` → 6 passed, 0 failed
- [ ] Firewall: :5000 & :27017 tidak publik
- [ ] Public IP LB + akses SSH dishare ke Tim B
- [ ] `flush_orders.sh` siap & dijelaskan ke Tim B
- [ ] Semua config di-commit ke repo
- [ ] ⚠️ Jadwalkan teardown resource setelah deadline
