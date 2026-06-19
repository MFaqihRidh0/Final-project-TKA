# Phase 3 — Nginx Load Balancer (vm-lb, 10.0.0.10)

Reverse proxy ke vm-app (10.0.0.11). Komponen paling berdampak ke skor RPS.
Skema 3-VM: 1 backend. Untuk round-robin, aktifkan vm-app2 di `nginx-lb-fe.conf`.

## Langkah
```bash
# vm-lb punya public IP → scp langsung
LB_IP="<PUBLIC_IP_vm-lb>"
scp -r tim-a-deployment/ azureuser@$LB_IP:~/

# SSH lalu jalankan:
ssh azureuser@$LB_IP
chmod +x ~/tim-a-deployment/scripts/30_lb_setup.sh
sudo ~/tim-a-deployment/scripts/30_lb_setup.sh
```

## Verifikasi (Definition of Done)
```bash
# Dari laptop / internet:
curl http://<public-ip-lb>/health                 # → {"status":"ok"}
curl http://<public-ip-lb>/products?limit=5       # → 200, data seed

# POST order nyata masuk MongoDB (butuh token; cek alur penuh di verify_endpoints.sh nanti)

# Uji app bisa diakses via LB:
curl http://<public-ip-lb>/api/health             # → {"status":"ok"} (dari vm-app)
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
- [ ] File `/etc/nginx/nginx.conf` (= `configs/nginx-lb-main.conf`) + `sites-available/orderapp` (= `configs/nginx-lb-fe.conf`)
- [ ] Catatan tuning (tabel di atas)
