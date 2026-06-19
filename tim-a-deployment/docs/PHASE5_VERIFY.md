# Phase 5 — End-to-End Verification

Script `scripts/verify_endpoints.sh` menguji seluruh alur lewat Load Balancer,
**disesuaikan ke API asli** (JWT + `items[]`), bukan contoh sederhana di briefing.

## Jalankan
```bash
# dari laptop / mesin mana pun yang bisa akses public IP LB:
chmod +x tim-a-deployment/scripts/verify_endpoints.sh
./tim-a-deployment/scripts/verify_endpoints.sh http://<public-ip-lb>

# simpan log sebagai bukti:
./tim-a-deployment/scripts/verify_endpoints.sh http://<public-ip-lb> | tee verify_$(date +%F).log
```
Butuh `curl` + `jq`. Override akun admin: `ADMIN_EMAIL=... ADMIN_PASS=... ./verify_endpoints.sh ...`

## Yang diuji (urut)
| # | Endpoint | Harapan |
|---|----------|---------|
| 0 | `GET /health` | 200 |
| 1 | `POST /auth/login` (admin) | dapat token |
| 2 | `GET /products?limit=1` | ada `product_id` (seed) |
| 3 | `POST /orders` (items[]) | dapat `order_id` |
| 4 | `GET /orders/<id>` | 200 |
| 5 | `PUT /orders/<id>/status` (admin) | 200 |
| 6 | `GET /orders?limit=5` | 200 |

## Definition of Done
- Output `=== HASIL: 6 passed, 0 failed ===`
- Exit code 0
- Log disimpan untuk laporan Tim C

> Jika gagal di step 2 → seed belum di-restore (lihat Phase 1).
> Jika gagal di step 3 dgn "stok tidak cukup" → produk pertama habis; script
> pakai limit=1, coba produk lain atau reset stock (lihat catatan Phase 6).
