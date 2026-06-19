// 11_db_init.js — Buat index untuk Order Processing Service
// Jalankan: mongosh "mongodb://10.0.0.13:27017" 11_db_init.js
//
// Phase 1 — Tim A. Idempotent: createIndex aman dijalankan berulang.
// PENTING: jalankan SETELAH restore dump (mongorestore), supaya index
// ter-build di atas data seed dan langsung dipakai load test.

const db = db.getSiblingDB("orderdb");

print("=== orderdb: membuat index ===");

// ── orders ──────────────────────────────────────────────
// WAJIB (constraint soal #3):
db.orders.createIndex({ order_id: 1 }, { unique: true, name: "order_id_unique" });
db.orders.createIndex({ created_at: -1 }, { name: "created_at_desc" });

// PERFORMA (dibutuhkan locustfile — langsung berdampak ke skor RPS 35%):
//   GET /orders user  → find({user_id}).sort(created_at desc)
db.orders.createIndex({ user_id: 1, created_at: -1 }, { name: "user_created" });
//   GET /orders admin → find({status}).sort(created_at desc)
db.orders.createIndex({ status: 1, created_at: -1 }, { name: "status_created" });

// ── products ────────────────────────────────────────────
// GET /products = task terberat (weight 4): find({is_active, category}).sort(...)
db.products.createIndex({ is_active: 1, category: 1, created_at: -1 }, { name: "active_cat_created" });
db.products.createIndex({ is_active: 1, price: 1 }, { name: "active_price" });
db.products.createIndex({ is_active: 1, rating: -1 }, { name: "active_rating" });

// ── users ───────────────────────────────────────────────
// /auth/login & /auth/register lookup by email (tiap on_start locust)
db.users.createIndex({ email: 1 }, { name: "email" });

// ── audit_logs ──────────────────────────────────────────
// GET /admin/logs sort created_at desc
db.audit_logs.createIndex({ created_at: -1 }, { name: "log_created_desc" });

print("\n=== orders.getIndexes() ===");
printjson(db.orders.getIndexes());
print("\n=== products.getIndexes() ===");
printjson(db.products.getIndexes());

print("\n=== Document counts (verifikasi seed ada) ===");
["users", "products", "orders", "audit_logs"].forEach(function (c) {
  print("  " + c + ": " + db.getCollection(c).countDocuments());
});
print("=== SELESAI ===");
