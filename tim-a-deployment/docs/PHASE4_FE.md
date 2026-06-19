# Phase 4 — Frontend (vm-fe, 10.0.0.14)

Nginx serve static `index.html` + `styles.css`, plus reverse proxy `/api` → vm-lb.

## ⚠️ Frontend di-ADAPTASI ke backend asli
Frontend bawaan dosen (`Resources/FE/`) dibuat untuk API versi sederhana
(`POST /order`, dll) yang **tidak ada** di `app.py` asli. Frontend di folder ini
(`frontend/index.html`, `frontend/styles.css`) sudah **ditulis ulang** agar cocok:
- Login JWT (`POST /auth/login`) + simpan token
- Katalog (`GET /products`) → grid produk + select
- Buat pesanan (`POST /orders` dengan `items:[{product_id, qty}]`) + cart
- Cek detail (`GET /orders/<id>`), Update status admin (`PUT /orders/<id>/status`)
- Riwayat (`GET /orders`) → kartu dengan status pill
- UI dirombak jadi **storefront e-commerce**: nav + search, hero Flash Sale,
  filter kategori, grid produk (gambar/ikon + rating + harga Rupiah), **cart
  drawer** slide-in dengan stepper qty + checkout, modal login/register, modal
  akun & riwayat, toast, status pill berwarna. Pakai Google Font Inter.

> **Catatan demo fallback:** kalau `GET /products` gagal (backend belum konek),
> frontend menampilkan **data produk demo** agar UI tetap terlihat penuh saat
> preview lokal, dan memunculkan toast "Mode preview". Saat live, data seed asli
> otomatis dipakai. Tim B/C: pastikan toast preview TIDAK muncul saat verifikasi
> di server — kalau muncul, berarti proxy `/api` ke LB belum benar.

**CORS diselesaikan tanpa menyentuh `app.py`:** FE pakai `API_BASE="/api"` →
Nginx FE proxy ke vm-lb (same-origin). Tidak perlu header CORS di backend.

## Langkah
```bash
gcloud compute scp --recurse tim-a-deployment vm-fe:~ --zone=asia-southeast2-a
# vm-fe (punya public IP, SSH biasa juga bisa):
chmod +x ~/tim-a-deployment/scripts/40_fe_setup.sh
sudo ~/tim-a-deployment/scripts/40_fe_setup.sh
```

## Verifikasi (Definition of Done)
- Buka `http://<public-ip-fe>` di browser → halaman tampil dengan styling.
- Login `admin1@tka.its.ac.id / Admin@12345` → badge user muncul di nav.
- "Muat Produk" → grid produk dari seed tampil.
- Tambah item → "Buat Pesanan" → order_id balik (cek di Network tab → request ke `/api/orders` 201).
- "Tampilkan Riwayat" → kartu order muncul.
- Sebagai admin: Update Status → 200.

## Catatan untuk Tim C
- Frontend asli dosen TIDAK dipakai (mismatch endpoint). Versi adaptasi ada di
  `frontend/`. Jelaskan keputusan ini di laporan (transparansi).
- Update status hanya berfungsi untuk akun **admin** (sesuai `@admin_required` di app.py).

## Bukti untuk Tim C (screenshot)
- [ ] Halaman penuh (UI rapi)
- [ ] Login berhasil (toast + badge user)
- [ ] Grid produk termuat
- [ ] Buat order sukses + Network tab `POST /api/orders` 201
- [ ] Riwayat order tampil
- [ ] File `nginx-fe.conf`, `frontend/index.html`, `frontend/styles.css`
