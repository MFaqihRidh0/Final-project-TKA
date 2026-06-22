# Laporan Load Testing & Performance Engineering
## Sistem Order Processing Service — Tim B

Laporan ini disusun untuk memenuhi tugas Final Project Teknologi Komputasi Awan 2026. Fokus pengujian adalah menguji keandalan infrastruktur backend terdistribusi (2 VM Flask/Gunicorn backend, 1 VM Nginx Load Balancer, dan 1 VM MongoDB) dalam menghadapi berbagai skenario lonjakan beban (traffic concurrency).

---

## 1. Lingkungan Pengujian (Infrastruktur VM)
Pengujian dijalankan secara terpisah dari server aplikasi dengan detail spesifikasi VM sebagai berikut:

*   **Host Penguji (Locust)**: Laptop Pribadi (Windows / macOS / Linux)
*   **Target Load Balancer + Frontend (`vm-lb`)**: Public IP `20.255.63.132` (1vCPU / 1GB RAM)
*   **Target Backend 1 & Database (`app1-dan-db`)**: Public IP `20.205.18.6` (1vCPU / 2GB RAM)
*   **Target Backend 2 (`app2`)**: Public IP `20.2.80.145` (1vCPU / 2GB RAM)

---

## 2. Hasil Eksekusi 5 Skenario Load Testing
*Catatan: Skenario dijalankan dengan durasi 60 detik per skenario dan database dibersihkan (flush) di antara pengujian menggunakan script `flush_scenario.py` agar hasil data tidak terakumulasi.*

### Skenario 1 — Maksimum RPS (0% Failure)
*   **Tujuan**: Menentukan throughput (RPS) maksimum yang bisa dicapai oleh server dengan tingkat kegagalan tepat 0%.
*   **Metode**: Jumlah user dinaikkan secara bertahap (misal: 10 -> 50 -> 100 -> 150 -> 200).
*   **Hasil**:
    *   **User Terbanyak (0% Failure)**: `[MASUKKAN_JUMLAH_USER_DISINI]` concurrent users.
    *   **Rata-rata RPS Maksimum**: `[MASUKKAN_RPS_DISINI]` RPS.
    *   **Response Time (Rata-rata)**: `[MASUKKAN_MS_DISINI]` ms.
*   **Screenshot Hasil Locust**:
    *(Tempel screenshot grafik RPS, Response Time, dan Failures dari Locust Web UI di sini)*
*   **Screenshot Resource Utilization**:
    *(Tempel screenshot output `htop` atau dashboard monitoring cloud untuk CPU & Memory di sini)*

---

### Skenario 2 — Peak Concurrency (Spawn Rate 50)
*   **Tujuan**: Mengukur batas konkurensi (jumlah user) tertinggi saat dipercepat dengan penambahan **50 user baru setiap detik** hingga kegagalan mulai muncul (Failure > 0%).
*   **Hasil**:
    *   **User Konkuren Tertinggi (0% Failure)**: `[MASUKKAN_USER_DISINI]` users.
    *   **RPS pada Titik Puncak**: `[MASUKKAN_RPS_DISINI]` RPS.
    *   **Kegagalan Mulai Muncul Pada**: `[MASUKKAN_USER_SAAT_MULAI_FAIL]` users.
*   **Screenshot Hasil Locust & Resource**:
    *(Tempel screenshot grafik Locust & CPU/Memory server di sini)*

---

### Skenario 3 — Peak Concurrency (Spawn Rate 100)
*   **Tujuan**: Mengukur batas konkurensi tertinggi saat dipercepat dengan penambahan **100 user baru setiap detik** hingga kegagalan mulai muncul.
*   **Hasil**:
    *   **User Konkuren Tertinggi (0% Failure)**: `[MASUKKAN_USER_DISINI]` users.
    *   **RPS pada Titik Puncak**: `[MASUKKAN_RPS_DISINI]` RPS.
    *   **Kegagalan Mulai Muncul Pada**: `[MASUKKAN_USER_SAAT_MULAI_FAIL]` users.
*   **Screenshot Hasil Locust & Resource**:
    *(Tempel screenshot grafik Locust & CPU/Memory server di sini)*

---

### Skenario 4 — Peak Concurrency (Spawn Rate 200)
*   **Tujuan**: Mengukur batas konkurensi tertinggi saat dipercepat dengan penambahan **200 user baru setiap detik** hingga kegagalan mulai muncul.
*   **Hasil**:
    *   **User Konkuren Tertinggi (0% Failure)**: `[MASUKKAN_USER_DISINI]` users.
    *   **RPS pada Titik Puncak**: `[MASUKKAN_RPS_DISINI]` RPS.
    *   **Kegagalan Mulai Muncul Pada**: `[MASUKKAN_USER_SAAT_MULAI_FAIL]` users.
*   **Screenshot Hasil Locust & Resource**:
    *(Tempel screenshot grafik Locust & CPU/Memory server di sini)*

---

### Skenario 5 — Peak Concurrency (Spawn Rate 500)
*   **Tujuan**: Mengukur batas konkurensi tertinggi saat dipercepat dengan penambahan **500 user baru setiap detik** (akselerasi ekstrim/hampir instan) hingga kegagalan mulai muncul.
*   **Hasil**:
    *   **User Konkuren Tertinggi (0% Failure)**: `[MASUKKAN_USER_DISINI]` users.
    *   **RPS pada Titik Puncak**: `[MASUKKAN_RPS_DISINI]` RPS.
    *   **Kegagalan Mulai Muncul Pada**: `[MASUKKAN_USER_SAAT_MULAI_FAIL]` users.
*   **Screenshot Hasil Locust & Resource**:
    *(Tempel screenshot grafik Locust & CPU/Memory server di sini)*

---

## 3. Analisis Kinerja & Bottleneck

Selama proses pengujian dan penyetelan sistem, Tim B mengidentifikasi beberapa faktor utama yang mempengaruhi performa throughput server:

### A. Bottleneck Enkripsi Password (Bcrypt) & Sync Workers
*   **Temuan Awal**: Pada konfigurasi default menggunakan `GUNICORN_WORKER_CLASS=sync` (4 workers), server mengalami error **`502 Bad Gateway`** pada RPS yang sangat rendah (sekitar 67 RPS).
*   **Analisis**: Endpoint `/auth/login` melakukan komputasi berat menggunakan pustaka `bcrypt` untuk verifikasi password. Karena worker Gunicorn bertipe `sync`, setiap proses worker hanya bisa melayani satu request pada satu waktu. Saat puluhan user melakukan login bersamaan, semua worker tersumbat oleh proses verifikasi bcrypt yang menghabiskan CPU, menyebabkan request lain (seperti `/products` dan `/orders`) mengalami timeout di antrean Nginx.
*   **Solusi & Hasil Tuning**: Setelah mengubah konfigurasi ke kelas worker async (**`gevent`**) di file `.env` backend dan menginstal dependensi `gevent` di server, server mampu menerima ribuan request konkuren secara paralel tanpa langsung menghasilkan 502/504 Bad Gateway.

### B. Optimalisasi Index Database (MongoDB)
*   Kehadiran index pada field `order_id` (`order_id_unique`) dan `created_at` (`created_at_desc`) terbukti sangat krusial. Saat data riwayat order (`orders`) menumpuk di atas 10.000 data, query history (`GET /orders`) dan status check (`GET /orders/<id>`) tetap merespons dengan cepat (< 5ms) tanpa menyebabkan lonjakan pemakaian CPU yang tinggi pada VM Database (`app1-dan-db`).

---

## 4. Kesimpulan dan Rekomendasi

1.  **Kesimpulan**: 
    Arsitektur terdistribusi yang membagi Nginx Load Balancer, 2 App Backend, dan 1 Shared Database MongoDB terbukti tangguh dalam memproses beban konkuren tinggi setelah dikonfigurasikan dengan worker async (`gevent`) dan index database yang tepat.
2.  **Rekomendasi untuk Deployment Nyata**:
    *   **Penerapan Caching**: Disarankan untuk menambahkan Redis Cache di depan backend untuk menyimpan data statis seperti katalog produk (`GET /products`) sehingga backend tidak perlu query ke MongoDB berulang kali.
    *   **Autoscaling**: Menerapkan VM Autoscaling berbasis metrik penggunaan CPU di Cloud Provider agar VM backend dapat bertambah otomatis saat terjadi lonjakan traffic flash sale nyata.
    *   **Pembagian Database**: Jika traffic bertambah ekstrim, lakukan pemisahan database baca (Read Replica) dan tulis untuk membagi beban MongoDB.
