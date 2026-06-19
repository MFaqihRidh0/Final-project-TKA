# Phase 2 — App Server (vm-app1 10.0.0.11 & vm-app2 10.0.0.12)

Flask + Gunicorn, **identik** di kedua VM. Depend ke MongoDB (Phase 1) yang sudah hidup.

## Langkah (ulang di vm-app1 DAN vm-app2)

### 1. Copy artefak + source ke VM
```bash
# Dari laptop — lewat jump host vm-lb (vm-app1 tidak punya public IP):
LB_IP="<PUBLIC_IP_vm-lb>"

scp -r -J azureuser@$LB_IP tim-a-deployment/ azureuser@10.0.0.11:~/
scp -J azureuser@$LB_IP fp-tka-26-main/Resources/BE/app.py azureuser@10.0.0.11:~/app-src/
scp -J azureuser@$LB_IP fp-tka-26-main/Resources/BE/requirements.txt azureuser@10.0.0.11:~/app-src/

# (ulang untuk vm-app2, ganti 10.0.0.11 → 10.0.0.12)
```

### 2. Jalankan setup
```bash
# vm-app1 — generate JWT_SECRET, CATAT outputnya:
sudo JWT_SECRET="$(openssl rand -hex 32)" ~/tim-a-deployment/scripts/20_app_setup.sh

# vm-app2 — pakai JWT_SECRET YANG SAMA dari app1:
sudo JWT_SECRET="<nilai-dari-app1>" ~/tim-a-deployment/scripts/20_app_setup.sh
```

> **KRITIS:** `JWT_SECRET` harus identik di kedua VM. LB round-robin → token
> dari app1 harus valid di app2. Beda secret = 401 acak saat load test.

### 3. Verifikasi (Definition of Done)
```bash
systemctl status orderapp                       # active (running) di KEDUA VM
curl http://localhost:5000/health               # {"status":"ok"}
curl http://localhost:5000/products?limit=5     # 200, ada data seed (cek konek DB)
```
Dari vm-lb (uji LB bisa jangkau app):
```bash
curl http://10.0.0.11:5000/health
curl http://10.0.0.12:5000/health
```
Dari internet publik ke `:5000` → harus **gagal** (no public IP + firewall).

## Keputusan & Tuning

| Item | Nilai | Alasan |
|------|-------|--------|
| Bind | `0.0.0.0:5000` | LB perlu connect; akses dibatasi firewall, bukan bind |
| Workers | 4 (`GUNICORN_WORKERS`) | (2×CPU)+1; titik awal, di-tuning dgn Tim B |
| Worker class | `sync` | Paling stabil; opsi `gthread`/`gevent` untuk eksplorasi async |
| `preload_app` | False | Tiap worker MongoClient sendiri (pymongo bukan fork-safe) |
| `max_requests` | 2000 (+jitter) | Cegah memory creep saat load test panjang |
| `LimitNOFILE` | 65535 | Anti "too many open files" |
| Akses :5000 | hanya dari `10.0.0.10` (vm-lb) | Constraint briefing |
| MONGO_URI | `mongodb://10.0.0.13:27017/` | via env, app.py tidak diubah |

## Catatan
- `app.py` **tidak diubah** sama sekali (source dosen). Konfigurasi via env var.
- Connection pool pymongo default `maxPoolSize=100` per worker → 4 worker = ~400
  koneksi ke mongod. `mongod.conf` sudah set `maxIncomingConnections=20000`, aman.
- Health check `/health` dipakai Nginx LB (Phase 3) untuk deteksi app mati.

## Bukti untuk Tim C (screenshot)
- [ ] `systemctl status orderapp` (kedua VM, active running)
- [ ] `curl /health` + `curl /products?limit=5` (konek DB OK)
- [ ] File `/etc/systemd/system/orderapp.service` (= `configs/orderapp.service`)
- [ ] `requirements.lock.txt` (output pip freeze) dari VM
- [ ] Test :5000 dari publik → refused
