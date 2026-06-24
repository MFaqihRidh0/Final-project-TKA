# BRIEFING CLAUDE CODE — TIM A (Infrastructure & Deployment)
## FP Teknologi Komputasi Awan 2026 — Order Processing Service

> **Cara pakai dokumen ini:** Buka Claude Code di terminal, lalu mulai sesi dengan menyuruhnya membaca file ini sebagai konteks. Contoh prompt awal:
> *"Tolong baca file `BRIEFING_TIM_A.md` ini dulu sebagai konteks. Saya akan delegasikan tugas-tugas deployment ke kamu secara bertahap sesuai phase yang dijelaskan di dokumen tersebut. Mulai dari Phase 1 (MongoDB setup) dulu."*

---

## 0. KONTEKS PROYEK (Baca dulu sebelum eksekusi)

### 0.1 Apa yang dikerjakan

Final Project mata kuliah Teknologi Komputasi Awan ITS 2026. Tugas: deploy dan optimasi backend **Order Processing Service** (Flask + MongoDB) di infrastruktur cloud agar bisa menahan lonjakan traffic (flash sale, promo). Budget maksimum **$75/bulan**.

Source code aplikasi **sudah disediakan** oleh dosen di repo:
- `Resources/BE/app.py` → Flask backend (sudah jadi, jangan diubah logikanya)
- `Resources/FE/index.html`, `styles.css` → Frontend statis
- `Resources/Test/locustfile.py` → Script load testing

**Tugas Tim A bukan menulis aplikasi, tapi men-deploy dan mengkonfigurasi infrastruktur.**

### 0.2 Endpoint REST API yang harus berfungsi

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/order` | Buat pesanan baru, status awal `"pending"` |
| GET | `/order/<order_id>` | Ambil detail satu pesanan |
| GET | `/orders` | Ambil seluruh riwayat pesanan (sorted by created_at desc) |
| PUT | `/order/<order_id>` | Update status pesanan |

### 0.3 Rubrik Penilaian (yang harus selalu diingat Claude Code)

| Komponen | Bobot | Yang dinilai |
|---|---|---|
| Rancangan Arsitektur | 20% | Diagram (10) + tabel harga (10) — **sudah selesai oleh tim lain** |
| Implementasi & Pengujian Endpoint | 20% | Teknis implementasi (10) + pengujian endpoint (10) — **INI TANGGUNG JAWAB UTAMA TIM A** |
| Load Testing Locust | 35% | Max RPS (30) + peak concurrency 4 skenario (5) — **Tim B, Tim A support tuning** |
| Dokumentasi Laporan | 25% | Kualitas README — **Tim C menulis, Tim A support dengan screenshot & config** |

> **Catatan penting:** Nilai RPS dihitung linear `(RPS / 200) × 30`. Artinya setiap tambahan RPS yang stabil di 0% failure langsung naik nilai. **Konfigurasi backend dan database yang dilakukan Tim A langsung berdampak ke 35% nilai.**

### 0.4 Constraint dari soal (WAJIB dipatuhi)

1. Locust **harus dijalankan dari host berbeda** dari server aplikasi → backend tidak boleh di-deploy di laptop yang sama dengan yang menjalankan Locust
2. Database **harus di-flush data yang di-insert per skenario** load testing (TAPI data awal tidak boleh dihapus)
3. Index MongoDB pada `order_id` dan `created_at` **harus dibuat** sebelum load testing
4. Semua resource cloud **harus di-destroy** setelah FP selesai (catatan: pengingat aja)

### 0.5 Tips dari soal yang relevan untuk Tim A

- Mulai dari konfigurasi terkecil, ukur baseline, baru scale-out
- **Optimalkan sebelum scale** — pastikan worker Gunicorn dan connection pool MongoDB optimal sebelum nambah VM
- Pisahkan database dari app server (sudah dilakukan di arsitektur)
- Eksplorasi load balancing strategy (round-robin, least_conn, weighted)
- Monitor resource real-time pakai `htop`, `vmstat`

---

## 1. ARSITEKTUR FINAL (sudah disepakati tim)

### 1.1 Topologi

```
                    Internet/Client
                          │
                          ▼ :80/:443
                  ┌───────────────┐
                  │  vm-lb        │  Nginx Load Balancer (round-robin)
                  │  10.0.0.10    │  vm2 (1vCPU/1GB) — $6
                  └───────┬───────┘
                          │ :5000
                  ┌───────┴───────┐
                  ▼               ▼
            ┌──────────┐    ┌──────────┐
            │ vm-app1  │    │ vm-app2  │   Flask + Gunicorn
            │10.0.0.11 │    │10.0.0.12 │   vm3 (1vCPU/2GB) — $12 ×2
            └────┬─────┘    └─────┬────┘
                 │                │
                 └────────┬───────┘
                          ▼ :27017
                  ┌───────────────┐
                  │  vm-db        │  MongoDB (db: orderdb, coll: orders)
                  │  10.0.0.13    │  vm5 (2vCPU/4GB) — $24
                  └───────────────┘

            ┌──────────┐
            │  vm-fe   │   Nginx static (index.html, styles.css)
            │10.0.0.14 │   vm2 (1vCPU/1GB) — $6
            └──────────┘

         TOTAL: $60/bulan (budget $75)
```

### 1.2 Tabel Spec VM

| Hostname | Role | Internal IP | Spec | Tipe | Harga |
|---|---|---|---|---|---|
| vm-lb | Nginx Load Balancer | 10.0.0.10 | 1vCPU / 1GB | vm2 | $6 |
| vm-app1 | Flask + Gunicorn | 10.0.0.11 | 1vCPU / 2GB | vm3 | $12 |
| vm-app2 | Flask + Gunicorn | 10.0.0.12 | 1vCPU / 2GB | vm3 | $12 |
| vm-db | MongoDB | 10.0.0.13 | 2vCPU / 4GB | vm5 | $24 |
| vm-fe | Nginx static | 10.0.0.14 | 1vCPU / 1GB | vm2 | $6 |
| | | | | **TOTAL** | **$60** |

### 1.3 Deployment Target

GCP region `asia-southeast2` (Jakarta). VPC `10.0.0.0/24`. Semua VM dalam VPC yang sama, public IP hanya pada vm-lb dan vm-fe (sisanya internal-only).

---

## 2. URUTAN EKSEKUSI (Sequential Phases)

> **PENTING untuk Claude Code:** Eksekusi phase secara berurutan. Jangan lompat phase tanpa konfirmasi user. Setiap phase selesai → tunggu konfirmasi dari user sebelum lanjut.

### PHASE 1 — MongoDB Setup (vm-db, 10.0.0.13)

**Kenapa duluan:** App server depend ke MongoDB. Kalau MongoDB belum siap, app server akan crash saat startup.

**Tugas:**
1. Install MongoDB Community Edition (versi 7.0+ direkomendasikan) di Ubuntu/Debian
2. Konfigurasi MongoDB untuk bind ke internal IP `10.0.0.13` (jangan cuma `127.0.0.1`, app server di VM lain perlu connect)
3. Pastikan port `:27017` hanya bisa diakses dari subnet internal `10.0.0.0/24`, tidak dari publik
4. Setup MongoDB sebagai systemd service yang auto-start saat boot
5. Buat database `orderdb` dan collection `orders`
6. **Buat index pada field `order_id` dan `created_at`** (wajib sesuai Tips soal nomor 7)
7. Tuning ringan untuk performa: pastikan `wiredTigerCacheSizeGB` reasonable untuk 4GB RAM

**Definition of done:**
- `systemctl status mongod` → active (running)
- Dari vm-app1 (nanti) bisa `mongosh "mongodb://10.0.0.13:27017"` tanpa error
- `db.orders.getIndexes()` menunjukkan index `order_id` dan `created_at` aktif
- Connection dari luar subnet ditolak

**Yang harus disimpan untuk Tim C (dokumentasi):**
- Output `mongod --version`
- Screenshot `db.orders.getIndexes()`
- File `/etc/mongod.conf` (dicommit ke repo)

---

### PHASE 2 — App Server Setup (vm-app1 & vm-app2)

**Kenapa setelah MongoDB:** App server butuh connection string MongoDB yang sudah hidup.

**Tugas (lakukan identik di kedua VM):**
1. Install Python 3.10+, pip, dan dependencies aplikasi (Flask, pymongo, gunicorn)
2. Clone repo kelompok atau copy file `app.py` ke `/opt/orderapp/`
3. **Baca `app.py` dulu** untuk pahami:
   - MongoDB connection string yang dipakai (kemungkinan ada env var atau konstanta)
   - Port yang di-listen (kemungkinan `:5000`)
   - Apakah ada dependency tambahan
4. Set environment variable atau ubah connection string MongoDB jadi mengarah ke `10.0.0.13:27017` (database: `orderdb`)
5. Setup Gunicorn dengan **worker awal 4** (akan di-tuning bareng Tim B nanti)
   - Formula umum: `workers = (2 × CPU) + 1`. Untuk vm3 (1 vCPU): mulai dari 3-4
   - Pakai worker class `sync` dulu (default), nanti bisa coba `gevent` kalau Tim B butuh async
6. Buat systemd service `orderapp.service` yang menjalankan Gunicorn:
   - Listen di `0.0.0.0:5000` (supaya LB bisa connect)
   - Auto-restart kalau crash
   - Logging ke journald
7. Aktifkan dan enable service
8. Pastikan firewall: port `:5000` hanya menerima dari `10.0.0.10` (vm-lb), tidak publik

**Definition of done:**
- `systemctl status orderapp` → active (running) di kedua VM
- `curl http://localhost:5000/orders` dari dalam VM → response 200 (mungkin array kosong)
- `curl http://10.0.0.11:5000/orders` dari vm-lb → response 200
- `curl` dari internet publik ke port 5000 → connection refused / timeout

**Yang harus disimpan untuk Tim C:**
- File `/etc/systemd/system/orderapp.service`
- Output `pip freeze` (requirements.txt)
- Screenshot output `systemctl status orderapp` yang menunjukkan service running

---

### PHASE 3 — Nginx Load Balancer Setup (vm-lb, 10.0.0.10)

**Tugas:**
1. Install Nginx (latest stable)
2. Buat konfigurasi upstream round-robin ke kedua app server:
   ```nginx
   upstream backend_pool {
       server 10.0.0.11:5000;
       server 10.0.0.12:5000;
       # Strategy: round-robin (default). Nanti coba least_conn / weighted untuk eksplorasi (Tips soal #3)
   }
   ```
3. Server block yang proxy_pass ke upstream:
   - Listen di `:80` (dan `:443` opsional dengan self-signed cert)
   - Pass header `Host`, `X-Real-IP`, `X-Forwarded-For`
   - Set timeout yang reasonable (`proxy_connect_timeout 5s`, `proxy_read_timeout 30s`)
4. **Tuning Nginx untuk high concurrency** (kritis untuk skor RPS):
   - `worker_processes auto;`
   - `worker_connections 4096;` (atau lebih, sesuaikan dengan `ulimit -n`)
   - `keepalive` di upstream block
   - Naikkan `ulimit` system jika perlu
5. Aktifkan dan enable Nginx sebagai systemd service
6. Public IP vm-lb harus accessible dari internet di port `:80`

**Definition of done:**
- `curl http://<public-ip-lb>/orders` dari internet → response 200
- Test request `POST /order` berhasil masuk ke MongoDB (cek di vm-db)
- Matikan vm-app1, request masih terlayani oleh vm-app2 (verifikasi load balancing bekerja)

**Yang harus disimpan untuk Tim C:**
- File `/etc/nginx/nginx.conf` dan `/etc/nginx/sites-available/orderapp`
- Hasil `nginx -t` (config test passed)
- Catatan tuning yang dilakukan (worker_connections, dll)

---

### PHASE 4 — Frontend Setup (vm-fe, 10.0.0.14)

**Tugas:**
1. Install Nginx
2. Copy `index.html` dan `styles.css` ke `/var/www/orderfe/`
3. **PENTING:** Buka `index.html`, cek apakah ada JavaScript yang manggil API. Jika ya:
   - Pastikan URL API mengarah ke **public IP atau domain vm-lb** (bukan `localhost` atau internal IP)
   - Kalau di kode masih hardcoded `localhost:5000`, ubah jadi `http://<public-ip-vm-lb>` atau gunakan reverse proxy di Nginx FE supaya domain sama
4. Konfigurasi Nginx untuk serve static files dari `/var/www/orderfe/`
5. Listen di `:80` (public)
6. Enable CORS jika diperlukan (kalau frontend dan API beda domain)

**Definition of done:**
- Akses public IP vm-fe dari browser → halaman muncul dengan styling benar
- Klik tombol create order di frontend → request berhasil ke backend (cek network tab browser)
- Halaman riwayat pesanan menampilkan data dari MongoDB

**Yang harus disimpan untuk Tim C:**
- Screenshot halaman frontend (form create order, list orders)
- File konfigurasi Nginx FE

---

### PHASE 5 — End-to-End Verification

**Tugas:** Buat **script bash** `verify_endpoints.sh` di repo yang otomatis test semua 4 endpoint via `curl` ke load balancer. Ini akan dipakai:
- Tim A untuk sanity check setelah perubahan config
- Tim C untuk verifikasi sebelum capture Postman screenshot

Contoh struktur script:
```bash
#!/bin/bash
LB_URL="http://<public-ip-lb>"

# Test 1: POST /order
echo "=== Test POST /order ==="
RESPONSE=$(curl -s -X POST $LB_URL/order \
  -H "Content-Type: application/json" \
  -d '{"product":"Test Product","quantity":2,"price":150000}')
echo $RESPONSE
ORDER_ID=$(echo $RESPONSE | jq -r '.order_id')

# Test 2: GET /order/<id>
# Test 3: PUT /order/<id>
# Test 4: GET /orders
# Lengkapi sendiri...
```

**Definition of done:**
- Script jalan tanpa error
- Semua 4 endpoint return status code yang diharapkan (201, 200, 200, 200)
- Output script disimpan sebagai log → bisa dijadikan bukti di laporan

---

### PHASE 6 — Handoff ke Tim B & Tim C

Setelah Phase 5 sukses, persiapan handoff:

**Untuk Tim B (Load Testing):**
- Berikan public IP/domain vm-lb
- Berikan akses SSH ke semua VM (untuk monitoring `htop` selama testing)
- Briefing: jumlah worker Gunicorn current = 4, bisa diminta diubah kalau perlu
- Siapkan command untuk **flush collection orders** yang akan dipanggil antar skenario:
  ```bash
  # Sediakan script flush_orders.sh
  mongosh "mongodb://10.0.0.13:27017/orderdb" --eval "db.orders.deleteMany({})"
  ```
  > ⚠️ Pastikan Tim B paham: data yang dihapus hanya yang di-insert per skenario. Kalau ada data awal/seed, **jangan** dihapus (sesuai constraint soal).

**Untuk Tim C (Dokumentasi):**
- Kumpulkan semua config files yang sudah dibuat → commit ke repo dengan struktur:
  ```
  fp-tka-[nama-kelompok]/
  ├── README.md
  ├── Resources/
  │   ├── BE/app.py
  │   ├── FE/{index.html, styles.css}
  │   └── Test/locustfile.py
  ├── configs/                          ← Tambahan dari Tim A
  │   ├── nginx-lb.conf
  │   ├── nginx-fe.conf
  │   ├── mongod.conf
  │   ├── orderapp.service
  │   └── verify_endpoints.sh
  └── result/                           ← Diisi oleh Tim B & Tim C
      ├── locust_rps.png
      ├── locust_concurrency_*.png
      └── cpu_usage_*.png
  ```
- Berikan list semua command yang sudah dijalankan → Tim C butuh untuk bagian "Implementasi" di laporan

---

## 3. ATURAN KERJA UNTUK CLAUDE CODE

### Yang HARUS dilakukan

- ✅ Selalu pakai **systemd service** untuk semua daemon (MongoDB, Gunicorn, Nginx). JANGAN jalanin manual via `nohup` atau `screen` — saat VM restart auto-mati, ribet pas load testing
- ✅ Setiap perubahan config file, **simpan versi terakhirnya** ke folder `configs/` di repo
- ✅ Selalu jalankan `systemctl status <service>` setelah restart untuk verifikasi
- ✅ Selalu cek `journalctl -u <service> -n 50` kalau ada error
- ✅ Setiap selesai phase, kasih ringkasan ke user: "Phase X selesai. Hasil: A, B, C. Lanjut ke Phase X+1?"
- ✅ Test koneksi antar VM dengan `curl` atau `nc` sebelum claim "selesai"
- ✅ Catat semua command penting yang dijalankan — Tim C akan butuh untuk bagian "Implementasi" di README

### Yang JANGAN dilakukan

- ❌ JANGAN ubah logika di `app.py` — itu source dari dosen, biarkan apa adanya. Hanya boleh ubah connection string MongoDB (lewat env var lebih baik)
- ❌ JANGAN hardcode password MongoDB di file yang akan di-commit publik
- ❌ JANGAN buka port `:5000` ke publik — hanya boleh diakses dari vm-lb
- ❌ JANGAN buka port `:27017` ke publik — hanya boleh dari vm-app1 dan vm-app2
- ❌ JANGAN install paket yang tidak perlu — keep it minimal, hemat resource (terutama di vm-app yang cuma 2GB RAM)
- ❌ JANGAN skip Phase secara prematur. Tunggu konfirmasi user setiap selesai 1 phase
- ❌ JANGAN delete data lama di MongoDB tanpa konfirmasi — bisa salah hapus seed data

---

## 4. CHECKLIST FINAL SEBELUM HANDOFF KE TIM B

Sebelum bilang "Tim A selesai", pastikan semua poin ini ✅:

- [ ] 5 VM hidup dan accessible via SSH
- [ ] MongoDB running, index `order_id` & `created_at` ada
- [ ] vm-app1 dan vm-app2 jalan via systemd, accessible dari vm-lb
- [ ] Nginx LB jalan, round-robin ke kedua app server terverifikasi
- [ ] Frontend accessible dari publik, bisa create + view order
- [ ] Semua 4 endpoint pass dari script `verify_endpoints.sh`
- [ ] Firewall sudah benar: `:5000` dan `:27017` tidak publik
- [ ] Semua config files sudah di-commit ke repo (folder `configs/`)
- [ ] Public IP vm-lb sudah dishare ke Tim B
- [ ] Script `flush_orders.sh` siap untuk Tim B
- [ ] Tim B sudah dapat akses SSH untuk monitoring

---

## 5. TROUBLESHOOTING UMUM (untuk referensi Claude Code)

| Gejala | Kemungkinan penyebab | Cek dengan |
|---|---|---|
| App server tidak bisa connect ke MongoDB | Bind IP salah, atau firewall MongoDB block | `nc -zv 10.0.0.13 27017` dari vm-app |
| Nginx LB return 502 Bad Gateway | App server down atau port salah | `curl http://10.0.0.11:5000/orders` dari vm-lb |
| Throughput rendah di Locust | Worker Gunicorn terlalu sedikit, atau MongoDB tanpa index | `htop` di vm-app, cek index di mongosh |
| "Too many open files" saat load testing | `ulimit -n` terlalu rendah | `ulimit -n 65535` di systemd service file |
| Connection refused dari publik ke LB | Firewall GCP belum buka :80 | Cek VPC firewall rule di GCP console |

---

## 6. REMINDER AKHIR

- 📅 **Deadline:** Minggu 17 — penilaian diambil dari commit terakhir sebelum deadline
- 🌐 Repo GitHub kelompok **harus public**
- 🗑️ **Destroy semua resources GCP setelah FP berakhir** — penting biar credit tidak habis sia-sia atau kena tagihan
- 📸 Setiap step penting, **capture screenshot** untuk Tim C: terminal output, browser, MongoDB shell, dll.

---

**Akhir briefing.** Claude Code, sekarang silakan mulai dengan menanyakan ke user: "Saya sudah baca briefing. Apakah VM sudah di-provision di GCP, atau saya perlu bantu generate command `gcloud compute instances create` dulu untuk kelima VM tersebut?"

### Tim A Tim B

Tim A — Cloud Infrastructure & Deployment 
 Tanggung jawab:

Provisioning VM di cloud provider (saran: GCP karena credit $300 paling besar dan budget $75/bulan jadi aman)
Deploy backend Flask + Gunicorn (tuning jumlah worker)
Setup MongoDB di VM terpisah + bikin index pada created_at dan order_id
Konfigurasi Nginx sebagai reverse proxy / load balancer
Deploy frontend (index.html + styles.css)
Tuning OS-level (ulimit, sysctl) kalau perlu untuk handle high concurrency

Tim B — Load Testing & Performance Engineering 
Bobot 35% — bagian paling menentukan nilai akhir. Tanggung jawab:

Setup Locust di host/laptop terpisah (penting, sesuai constraint soal)
Bikin script cleanup MongoDB antar skenario (drop data yang di-insert tiap skenario, jangan drop seluruh collection)
Eksekusi 5 skenario (Skenario 1 untuk max RPS, Skenario 2-5 untuk peak concurrency dengan spawn rate berbeda)
Monitoring resource server selama pengujian (htop, vmstat, atau dashboard cloud) — screenshot CPU/memory wajib
Koordinasi sama Tim A: kalau ada bottleneck, kasih feedback ke Tim A buat tuning ulang (siklus test → tune → test)
Analisis hasil + grafik

Idealnya, 1 orang fokus ke eksekusi Locust dan 1 orang fokus ke monitoring + dokumentasi hasil real-time. Anggota yang teliti dan paham scripting Python taruh di sini.
