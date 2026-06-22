# Tim A — Infrastructure & Deployment (Work Folder)

Folder kerja Tim A untuk FP Teknologi Komputasi Awan 2026 — Order Processing Service.
Semua config, script, dan log deployment dikumpulkan di sini, lalu di-commit ke
repo kelompok (`fp-tka-26-main/configs/`) saat handoff ke Tim C.

## Arsitektur Target (Skema 3-VM, 6 vCPU)

| Hostname | Role | Internal IP | Spec | vCPU | Harga |
| --- | --- | --- | --- | --- | --- |
| vm-lb | Nginx LB + Frontend | 10.0.0.10 | Standard_B2s (2vCPU/4GB) | 2 | ~$30 |
| vm-app | Flask + Gunicorn | 10.0.0.11 | Standard_B2s (2vCPU/4GB) | 2 | ~$30 |
| vm-db | MongoDB 7.0 | 10.0.0.13 | Standard_B2s (2vCPU/4GB) | 2 | ~$30 |

Total: 6 vCPU, ~$90/bulan.

> Skema minimum viable dengan quota **6 vCPU**. Untuk upgrade ke 4-VM (HA round-robin),
> tambah vm-app2 (10.0.0.12) dan aktifkan baris di `nginx-lb-fe.conf` + `01_provision_azure.sh`.

Azure region `southeastasia` (Singapore). VNet `10.0.0.0/24`. Public IP hanya pada
vm-lb. VM internal (vm-app, vm-db) diakses via SSH jump host vm-lb.

## Struktur Folder

```
tim-a-deployment/
├── README.md                 ← file ini (progress tracker)
├── configs/                  ← config final, di-commit ke repo
│   ├── mongod.conf           (vm-db)
│   ├── nginx-lb-fe.conf      (vm-lb — LB + frontend gabung, Phase 3+4)
│   ├── nginx-lb-main.conf    (nginx.conf tuning high-concurrency)
│   ├── gunicorn.conf.py      (vm-app)
│   └── orderapp.service      (vm-app, systemd)
├── scripts/
│   ├── 01_provision_azure.sh ← az create 3 VM + VNet + NSG (skema 6 vCPU)
│   ├── 01_provision_gcp.sh   ← arsip GCP (tidak dipakai)
│   ├── 10_db_install.sh      ← install MongoDB 7.0 di vm-db
│   ├── 11_db_init.js         ← buat index orders/products/users (mongosh)
│   ├── 20_app_setup.sh       ← Flask + Gunicorn di vm-app
│   ├── 30_lb_setup.sh        ← Nginx LB + Frontend di vm-lb
│   ├── flush_orders.sh       ← untuk Tim B (Phase 6)
│   └── verify_endpoints.sh   ← E2E test (Phase 5)
└── docs/
    ├── PHASE0_PROVISION.md   ← topologi + SSH/SCP commands
    ├── PHASE1_MONGODB.md     ← install + seed + index
    ├── PHASE2_APP.md         ← Flask + Gunicorn setup
    ├── PHASE3_LB.md          ← Nginx LB setup
    ├── PHASE4_FE.md          ← Frontend (digabung Phase 3)
    ├── PHASE5_VERIFY.md      ← E2E verification
    └── PHASE6_HANDOFF.md     ← handoff Tim B & Tim C
```

## Catatan Penting (Reality Check vs Briefing)

Briefing menyebut endpoint sederhana (`POST /order`, dll). **App asli (`app.py`)
ternyata lebih kompleks**: JWT auth + 4 collection (`users`, `products`, `orders`,
`audit_logs`). Endpoint sebenarnya:

- `POST /auth/register`, `POST /auth/login`, `GET /auth/me`
- `GET /products`, `GET /products/<id>`, `POST/PUT/DELETE /products/<id>` (admin)
- `POST /orders`, `GET /orders`, `GET /orders/<id>`, `PUT /orders/<id>/status`
- `GET /admin/stats`, `GET /admin/users`, `GET /admin/logs`
- `GET /health`

Implikasi: index yang dibutuhkan **lebih dari** sekadar `order_id` + `created_at`.
Lihat `scripts/11_db_init.js`.

Seed data dari dosen (`Resources/DB/dump/`): 505 users, 96 products, 10.000 orders,
2.000 audit_logs, 100 sessions. **JANGAN dihapus** — hanya data hasil load test yang
boleh di-flush antar skenario.

## Progress

- [~] Phase 0 — Provision Azure (4 VM, VNet, NSG) — `01_provision_azure.sh` siap
- [~] Phase 1 — MongoDB setup (vm-db) — artifacts dibuat, eksekusi pending
- [~] Phase 2 — App server (vm-app 10.0.0.11) — artifacts dibuat, eksekusi pending
- [~] Phase 3 — Nginx LB + Frontend (vm-lb, Opsi A) — artifacts dibuat, eksekusi pending
- [~] Phase 4 — (digabung ke Phase 3 via Opsi A — vm-fe tidak terpisah)
- [~] Phase 5 — E2E verification — verify_endpoints.sh siap (JWT-aware)
- [~] Phase 6 — Handoff Tim B & Tim C — flush_orders.sh + doc handoff siap

> Semua artefak Phase 0–6 **selesai dibuat**. Status `[~]` = tinggal dieksekusi di VM
> setelah Azure di-provision. Tidak ada yang diblok dari sisi pembuatan config/script.
.