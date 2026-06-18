# Phase 3 — Nginx Load Balancer (vm-lb, 10.0.0.10)

Reverse proxy round-robin ke vm-app1 & vm-app2. Komponen paling berdampak ke skor RPS.

## Langkah
```bash
# Copy artefak ke vm-lb (vm-lb punya public IP → SSH biasa juga bisa)
gcloud compute scp --recurse tim-a-deployment vm-lb:~ --zone=asia-southeast2-a

# Di vm-lb:
chmod +x ~/tim-a-deployment/scripts/30_lb_setup.sh
sudo ~/tim-a-deployment/scripts/30_lb_setup.sh
```

## Verifikasi (Definition of Done)
```bash
# Dari laptop / internet:
curl http://<public-ip-lb>/health                 # → {"status":"ok"}
curl http://<public-ip-lb>/products?limit=5       # → 200, data seed

# POST order nyata masuk MongoDB (butuh token; cek alur penuh di verify_endpoints.sh nanti)

# Uji High-Availability (load balancing bekerja):
gcloud compute ssh vm-app1 --tunnel-through-iap --command 'sudo systemctl stop orderapp'
curl http://<public-ip-lb>/health                 # tetap 200 (dilayani vm-app2)
gcloud compute ssh vm-app1 --tunnel-through-iap --command 'sudo systemctl start orderapp'
```

## Tuning (alasan, untuk laporan Tim C)

| Setting | Nilai | Dampak |
|---------|-------|--------|
| `worker_processes` | auto | 1 worker/core, sesuai vCPU |
| `worker_connections` | 8192 | Koneksi simultan per worker — inti concurrency |
| `worker_rlimit_nofile` | 65535 | Anti "too many open files" saat RPS tinggi |
| `use epoll` + `multi_accept` | on | Event model efisien di Linux |
| `keepalive` (upstream) | 64 | Pool koneksi persisten ke app → hemat TCP handshake |
| `proxy_http_version 1.1` + `Connection ""` | — | Syarat keepalive upstream aktif |
| `access_log` | off | Hilangkan I/O log per-request saat load test |
| `keepalive_requests` | 10000 | Banyak request per koneksi client |
| `proxy_next_upstream` | error/timeout/502-504 | Failover otomatis antar app |

## Eksplorasi strategy (Tips soal #3)
Di `nginx-lb.conf`, ganti algoritma upstream lalu `nginx -t && systemctl reload nginx`:
- **round-robin** (default) — merata
- **least_conn** — uncomment `least_conn;`; bagus kalau durasi request bervariasi
- **weighted** — `server 10.0.0.11:5000 weight=2;` kalau satu app lebih kuat

Catat hasil RPS tiap strategy untuk bagian eksplorasi di laporan.

## Bukti untuk Tim C
- [ ] `nginx -t` (config test passed)
- [ ] `curl http://<public-ip>/health` dari internet → 200
- [ ] Demo HA: vm-app1 mati, request tetap jalan
- [ ] File `/etc/nginx/nginx.conf` (= `configs/nginx-lb-main.conf`) + `sites-available/orderapp` (= `configs/nginx-lb.conf`)
- [ ] Catatan tuning (tabel di atas)
