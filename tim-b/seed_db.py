#!/usr/bin/env python3
"""
seed_db.py — Seed database untuk FP TKA 2026
Tim B: jalankan SEKALI sebelum mulai load testing.

Yang dibuat:
  - 50 user biasa  : user1@example.com … user50@example.com  / User@12345
  - 5  admin       : admin1@tka.its.ac.id … admin5@tka.its.ac.id / Admin@12345
  - 100 produk     : berbagai kategori, stok besar agar tidak habis
  - 10.000 orders  : seed awal (created_at masa lalu) — optional, pakai --orders N

Usage:
    pip install pymongo bcrypt
    python seed_db.py --uri mongodb://10.0.0.13:27017
    python seed_db.py --uri mongodb://10.0.0.13:27017 --orders 0   # skip orders
"""

import argparse
import random
import uuid
from datetime import datetime, timezone, timedelta

import bcrypt
from pymongo import MongoClient, ASCENDING, DESCENDING

# ─── CLI ──────────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="Seed DB untuk FP TKA 2026")
parser.add_argument("--uri",    default="mongodb://localhost:27017/",
                    help="MongoDB URI (default: localhost)")
parser.add_argument("--orders", type=int, default=10_000,
                    help="Jumlah seed orders (default: 10000, 0 = skip)")
args = parser.parse_args()

# ─── Koneksi ──────────────────────────────────────────────────────────────────
print(f"[*] Konek ke {args.uri} ...")
client = MongoClient(args.uri, serverSelectionTimeoutMS=5000)
client.server_info()   # raise kalau tidak bisa konek
db = client["orderdb"]

users_col  = db["users"]
prods_col  = db["products"]
orders_col = db["orders"]

def now_utc():
    return datetime.now(timezone.utc)

def hash_pw(plain: str) -> str:
    return bcrypt.hashpw(plain.encode(), bcrypt.gensalt()).decode()

# ─── Helper random ────────────────────────────────────────────────────────────
CITIES   = ["Surabaya","Jakarta","Bandung","Medan","Semarang","Makassar",
            "Yogyakarta","Palembang","Denpasar","Balikpapan"]
PAYMENTS = ["gopay","ovo","dana","transfer_bank","kartu_kredit","qris"]
STATUSES = ["pending","processing","completed","cancelled"]

# ─── 1. Users ─────────────────────────────────────────────────────────────────
print("[1] Seed users …")

def upsert_user(doc: dict):
    users_col.update_one({"email": doc["email"]}, {"$setOnInsert": doc}, upsert=True)

# 50 user biasa
for i in range(1, 51):
    now = now_utc()
    upsert_user({
        "name":       f"User {i}",
        "email":      f"user{i}@example.com",
        "password":   hash_pw("User@12345"),
        "role":       "user",
        "city":       random.choice(CITIES),
        "phone":      f"08{random.randint(10000000000, 99999999999)}",
        "address":    f"Jl. Contoh No. {i}, {random.choice(CITIES)}",
        "is_active":  True,
        "created_at": now,
        "updated_at": now,
        "last_login": None,
    })
    print(f"   user{i}@example.com", end="\r")

print(f"   50 user biasa selesai               ")

# 5 admin
for i in range(1, 6):
    now = now_utc()
    upsert_user({
        "name":       f"Admin {i}",
        "email":      f"admin{i}@tka.its.ac.id",
        "password":   hash_pw("Admin@12345"),
        "role":       "admin",
        "city":       "Surabaya",
        "phone":      f"0315{100000 + i}",
        "address":    "Kampus ITS Sukolilo, Surabaya",
        "is_active":  True,
        "created_at": now,
        "updated_at": now,
        "last_login": None,
    })
print("   5 admin selesai")

# Index email
users_col.create_index("email", unique=True, background=True)

# ─── 2. Produk ────────────────────────────────────────────────────────────────
print("[2] Seed produk …")

PRODUCTS_TEMPLATE = [
    # (nama, kategori, harga, deskripsi)
    ("Laptop Gaming ASUS ROG Strix G16",    "Elektronik",    24_999_000, "Laptop gaming performa tinggi RTX 4060"),
    ("Laptop ThinkPad X1 Carbon Gen 12",    "Elektronik",    28_500_000, "Ultrabook bisnis premium Intel Core Ultra"),
    ("Monitor LG UltraWide 34 inci",        "Elektronik",     6_999_000, "Monitor curved 3440x1440 165Hz"),
    ("SSD Samsung 990 Pro 2TB",             "Elektronik",     2_199_000, "NVMe Gen4 read 7450MB/s"),
    ("RAM Corsair Vengeance 32GB DDR5",     "Elektronik",     1_850_000, "DDR5 5600MHz kit 2x16GB"),
    ("iPhone 15 Pro Max 256GB",             "Smartphone",    21_499_000, "Chip A17 Pro, titanium frame"),
    ("Samsung Galaxy S24 Ultra 512GB",      "Smartphone",    19_999_000, "S-Pen, AI Photo, 200MP"),
    ("Xiaomi 14 Ultra 512GB",               "Smartphone",    16_999_000, "Leica optics, Snapdragon 8 Gen 3"),
    ("Google Pixel 8 Pro 256GB",            "Smartphone",    13_999_000, "Tensor G3, best Android camera"),
    ("OPPO Find X7 Pro 256GB",              "Smartphone",    11_999_000, "Hasselblad camera, 100W charging"),
    ("Sepatu Lari Nike Pegasus 41",         "Olahraga",       1_899_000, "Cushioning ReactX terbaru"),
    ("Dumbbell Set 5-30kg",                 "Olahraga",       2_450_000, "Hex rubber adjustable set"),
    ("Yoga Mat Premium 6mm",                "Olahraga",         350_000, "Anti-slip, extra wide"),
    ("Raket Badminton Yonex Astrox 99",     "Olahraga",       3_200_000, "Rotational generator system"),
    ("Sepeda Lipat Polygon Urbano 3",       "Olahraga",       4_999_000, "7-speed, alloy frame"),
    ("Jaket Hoodie Premium Unisex",         "Fashion",          299_000, "Fleece inside, oversized fit"),
    ("Kemeja Flanel Kotak Premium",         "Fashion",          185_000, "100% cotton brushed flannel"),
    ("Celana Chino Slim Fit",               "Fashion",          249_000, "Stretchable cotton blend"),
    ("Sepatu Casual Adidas Samba",          "Fashion",          999_000, "Leather upper, vintage style"),
    ("Topi Baseball New Era 59FIFTY",       "Fashion",          450_000, "Fitted cap, wool blend"),
    ("Atomic Habits — James Clear",         "Buku",              98_000, "Cara membangun kebiasaan baik"),
    ("Clean Code — Robert Martin",          "Buku",             125_000, "Panduan menulis kode bersih"),
    ("Deep Work — Cal Newport",             "Buku",              89_000, "Kerja fokus di era distraksi"),
    ("Filosofi Teras — Henry Manampiring",  "Buku",              79_000, "Stoisisme versi Indonesia"),
    ("Laskar Pelangi — Andrea Hirata",      "Buku",              75_000, "Novel inspiratif Indonesia"),
    ("Air Fryer Philips 4.1L",              "Rumah Tangga",   1_290_000, "Teknologi Rapid Air, 90% less fat"),
    ("Blender Ninja Professional 1000W",    "Rumah Tangga",   1_099_000, "Total crushing blades"),
    ("Vacuum Cleaner Dyson V15",            "Rumah Tangga",   7_499_000, "Laser detect, HEPA filter"),
    ("Rice Cooker Miyako 1.8L",             "Rumah Tangga",     299_000, "Keep warm, inner pot anti lengket"),
    ("Lemari Pakaian 4 Pintu Olympic",      "Rumah Tangga",   3_299_000, "Full mirror, anti-rayap"),
    ("Kopi Arabika Gayo 1kg",               "Makanan",          145_000, "Single origin Aceh Tengah"),
    ("Madu Hutan Asli 1kg",                 "Makanan",          189_000, "Raw unfiltered, dark honey"),
    ("Granola Oat Premium 500g",            "Makanan",           89_000, "Panggang, rendah gula"),
    ("Protein Whey Optimum Nutrition 5lb",  "Makanan",           799_000, "Gold Standard Whey, 24g protein"),
    ("Cokelat Silverqueen 70% 120g",        "Makanan",            45_000, "Dark chocolate premium"),
    ("Mechanical Keyboard 75% RGB",         "Elektronik",        759_000, "Hot-swap Gateron switches"),
    ("Mouse Logitech MX Master 3S",         "Elektronik",        999_000, "8K DPI, silent click"),
    ("Webcam Logitech C920 HD",             "Elektronik",        750_000, "1080p 30fps, stereo mic"),
    ("Speaker JBL Flip 6",                  "Elektronik",        999_000, "IP67 waterproof, 12h battery"),
    ("Earphone Sony WH-1000XM5",            "Elektronik",       4_499_000, "ANC terbaik, 30h battery"),
    ("Tumbler Stainless 1L",                "Rumah Tangga",       89_000, "Double wall, 24h cold"),
    ("Tas Laptop Thinkpad 15.6 inci",       "Elektronik",        350_000, "TSA-friendly, water resistant"),
    ("Power Bank Anker 26800mAh",           "Elektronik",        599_000, "PD 65W, 3 port"),
    ("Charger GaN 65W",                     "Elektronik",        299_000, "3 port USB-C + USB-A"),
    ("Smartwatch Samsung Galaxy Watch 6",   "Elektronik",       3_499_000, "ECG, body composition, 40mm"),
]

inserted_products = []
for idx, (name, cat, price, desc) in enumerate(PRODUCTS_TEMPLATE, 1):
    # Masukkan 2x tiap produk (beda variant) supaya total ≥ 80 produk
    for variant in ["Standard", "Premium"]:
        now = now_utc() - timedelta(days=random.randint(30, 365))
        vname  = name if variant == "Standard" else f"{name} ({variant})"
        vprice = price if variant == "Standard" else int(price * 1.15)
        doc = {
            "name":         vname,
            "category":     cat,
            "price":        float(vprice),
            "stock":        random.randint(500, 2000),  # stok besar agar tidak habis saat test
            "rating":       round(random.uniform(3.8, 5.0), 1),
            "rating_count": random.randint(50, 5000),
            "description":  desc,
            "image_url":    "",
            "is_active":    True,
            "created_at":   now,
            "updated_at":   now,
        }
        result = prods_col.update_one(
            {"name": vname}, {"$setOnInsert": doc}, upsert=True
        )
        if result.upserted_id:
            doc["_id"] = result.upserted_id
            inserted_products.append(doc)
        else:
            existing = prods_col.find_one({"name": vname})
            if existing:
                inserted_products.append(existing)

prods_col.create_index("category", background=True)
prods_col.create_index("is_active", background=True)
prods_col.create_index([("created_at", DESCENDING)], background=True)

print(f"   {prods_col.count_documents({'is_active': True})} produk aktif di database")

# ─── 3. Seed orders (masa lalu) ───────────────────────────────────────────────
if args.orders > 0:
    print(f"[3] Seed {args.orders:,} orders (ini butuh beberapa menit) …")

    all_users  = list(users_col.find({"role": "user"}, {"_id": 1, "name": 1, "email": 1, "city": 1, "address": 1}))
    all_prods  = list(prods_col.find({"is_active": True}, {"_id": 1, "name": 1, "category": 1, "price": 1}))

    BATCH = 500
    total_inserted = 0
    # cutoff seed: semua created_at SEBELUM hari ini → aman dari flush skenario
    seed_end = now_utc() - timedelta(hours=1)

    for batch_start in range(0, args.orders, BATCH):
        batch_size = min(BATCH, args.orders - batch_start)
        docs = []
        for _ in range(batch_size):
            user   = random.choice(all_users)
            n_item = random.randint(1, 3)
            items  = []
            sub    = 0
            for _ in range(n_item):
                p   = random.choice(all_prods)
                qty = random.randint(1, 3)
                s   = p["price"] * qty
                items.append({
                    "product_id":   p["_id"],
                    "product_name": p["name"],
                    "category":     p["category"],
                    "qty":          qty,
                    "price":        p["price"],
                    "subtotal":     s,
                })
                sub += s
            ship   = random.choice([0, 9_000, 15_000, 25_000])
            status = random.choices(STATUSES, weights=[10, 20, 60, 10])[0]
            # created_at: acak dalam 1 tahun terakhir, semua sebelum seed_end
            created = seed_end - timedelta(seconds=random.randint(1, 365*24*3600))
            docs.append({
                "order_id":         str(uuid.uuid4()),
                "user_id":          user["_id"],
                "customer_name":    user["name"],
                "customer_email":   user["email"],
                "customer_city":    user.get("city", ""),
                "customer_address": user.get("address", ""),
                "items":            items,
                "subtotal":         sub,
                "discount_pct":     0,
                "discount_amt":     0,
                "shipping_cost":    ship,
                "total":            sub + ship,
                "status":           status,
                "payment_method":   random.choice(PAYMENTS),
                "payment_status":   "paid" if status in ("processing","completed") else "unpaid",
                "notes":            "",
                "created_at":       created,
                "updated_at":       created,
            })
        orders_col.insert_many(docs)
        total_inserted += batch_size
        pct = total_inserted / args.orders * 100
        print(f"   {total_inserted:,}/{args.orders:,} ({pct:.0f}%)", end="\r")

    # Index penting untuk performa query
    orders_col.create_index([("created_at", DESCENDING)], background=True)
    orders_col.create_index("order_id",  background=True)
    orders_col.create_index("user_id",   background=True)
    orders_col.create_index("status",    background=True)

    print(f"\n   {orders_col.count_documents({}):,} total orders di database")
else:
    print("[3] Skip seed orders (--orders 0)")

# ─── Ringkasan ────────────────────────────────────────────────────────────────
print()
print("=" * 50)
print("✅ Seed selesai!")
print(f"   Users  : {users_col.count_documents({})} ({users_col.count_documents({'role':'user'})} user, {users_col.count_documents({'role':'admin'})} admin)")
print(f"   Produk : {prods_col.count_documents({'is_active': True})} aktif")
print(f"   Orders : {orders_col.count_documents({}):,}")
print()
print("Login test:")
print("   User  → user1@example.com   / User@12345")
print("   Admin → admin1@tka.its.ac.id / Admin@12345")
print("=" * 50)
