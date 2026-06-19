# Phase 1 — MongoDB Setup (vm-db, 10.0.0.13)

Target: Ubuntu 22.04 LTS, MongoDB 7.0, 2vCPU/4GB. Tujuan: DB siap diconnect
oleh vm-app1/vm-app2, dengan index lengkap dan seed data ter-restore.

## Langkah Eksekusi

### 1. Install + konfigurasi MongoDB
```bash
# Dari laptop: copy artifacts ke vm-db
scp -r tim-a-deployment/ user@<vm-db-ip>:~/tim-a-deployment

# SSH ke vm-db, lalu:
chmod +x ~/tim-a-deployment/scripts/10_db_install.sh
~/tim-a-deployment/scripts/10_db_install.sh
```
Script ini: import repo MongoDB 7.0 → `apt install mongodb-org` → pasang
`mongod.conf` (bind 10.0.0.13) → enable+start systemd → ufw rule → buat index.

### 2. Restore seed data dari dosen (WAJIB — load test butuh products & users)
```bash
# Copy folder dump ke vm-db
scp -r fp-tka-26-main/Resources/DB/dump user@<vm-db-ip>:~/dump

# Di vm-db (mongodb-database-tools ikut terinstall via mongodb-org):
mongorestore --uri="mongodb://10.0.0.13:27017" --drop ~/dump
```
> Setelah restore, **jalankan ulang** `11_db_init.js` agar index ter-build di
> atas seed (kalau index dibuat sebelum restore, `--drop` menghapusnya):
> ```bash
> mongosh "mongodb://10.0.0.13:27017" ~/tim-a-deployment/scripts/11_db_init.js
> ```

### 3. Verifikasi (Definition of Done)
```bash
systemctl status mongod                                  # → active (running)
mongod --version | head -1                               # → db version v7.0.x
mongosh "mongodb://10.0.0.13:27017/orderdb" --quiet \
  --eval 'db.orders.getIndexes()'                        # → order_id + created_at ada
mongosh "mongodb://10.0.0.13:27017/orderdb" --quiet \
  --eval 'db.orders.countDocuments()'                    # → 10000 (seed utuh)
```
Dari vm-app1 nanti (uji isolasi network):
```bash
nc -zv 10.0.0.13 27017          # dari vm-app → OK
nc -zv 10.0.0.13 27017          # dari luar subnet → refused/timeout
```

## Keputusan & Tuning

| Item | Nilai | Alasan |
|------|-------|--------|
| MongoDB version | 7.0 | Direkomendasikan briefing, LTS, fitur stabil |
| `bindIp` | `127.0.0.1,10.0.0.13` | App di VM lain perlu connect; bukan 0.0.0.0 (anti-expose) |
| `wiredTigerCacheSizeGB` | 2.0 | 4GB RAM, MongoDB satu-satunya service; working set muat di cache |
| Auth | disabled | App default tanpa kredensial; keamanan via network isolation |
| Firewall :27017 | hanya `10.0.0.0/24` | Constraint soal — tidak boleh publik |

## Index yang Dibuat (lihat 11_db_init.js)

**Wajib (constraint soal #3):** `orders.order_id` (unique), `orders.created_at`.

**Performa (berdampak skor RPS 35%):**
- `orders {user_id, created_at}` — GET /orders user
- `orders {status, created_at}` — GET /orders admin
- `products {is_active, category, created_at}` — GET /products (task terberat)
- `products {is_active, price}`, `{is_active, rating}` — sort varian
- `users.email` — login/register lookup
- `audit_logs.created_at` — GET /admin/logs

## Bukti untuk Tim C (capture screenshot)
- [ ] `mongod --version`
- [ ] `systemctl status mongod` (active running)
- [ ] `db.orders.getIndexes()`
- [ ] `db.orders.countDocuments()` = 10000
- [ ] File `/etc/mongod.conf` (sudah ada di `configs/mongod.conf`)
- [ ] Test koneksi dari vm-app (`nc -zv`) + test tolak dari luar subnet
