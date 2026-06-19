#!/usr/bin/env bash
# 10_db_install.sh — Install & configure MongoDB 7.0 di vm-db (10.0.0.13)
# Target: Ubuntu 22.04 LTS (jammy). Jalankan sebagai root / via sudo.
#
# Phase 1 — Tim A. Idempotent sebisa mungkin; aman dijalankan ulang.
set -euo pipefail

INTERNAL_IP="10.0.0.13"
SUBNET="10.0.0.0/24"
CONF_SRC="$(dirname "$0")/../configs/mongod.conf"

echo "==> [1/7] Import GPG key & repo MongoDB 7.0"
sudo apt-get update -y
sudo apt-get install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor --yes
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list

echo "==> [2/7] Install mongodb-org"
sudo apt-get update -y
sudo apt-get install -y mongodb-org

echo "==> [3/7] Pasang mongod.conf (bind ke ${INTERNAL_IP})"
if [ -f "$CONF_SRC" ]; then
  sudo cp "$CONF_SRC" /etc/mongod.conf
else
  echo "    !! $CONF_SRC tidak ditemukan — pastikan bindIp = 127.0.0.1,${INTERNAL_IP}"
fi
sudo chown mongodb:mongodb /etc/mongod.conf || true

echo "==> [4/7] Enable + start systemd service"
sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl restart mongod
sleep 3
sudo systemctl status mongod --no-pager || true

echo "==> [5/7] Firewall (ufw): hanya subnet ${SUBNET} boleh akses :27017"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow from "${SUBNET}" to any port 27017 proto tcp
  sudo ufw deny 27017
  echo "    (ufw rule ditambahkan. 'sudo ufw enable' jika belum aktif.)"
else
  echo "    ufw tidak ada — andalkan GCP VPC firewall (lihat 01_provision_gcp.sh)."
fi

echo "==> [6/7] Buat index (orders/products/users)"
mongosh "mongodb://${INTERNAL_IP}:27017" "$(dirname "$0")/11_db_init.js"

echo "==> [7/7] Verifikasi versi & index"
mongod --version | head -n 1
mongosh "mongodb://${INTERNAL_IP}:27017/orderdb" --quiet --eval 'printjson(db.orders.getIndexes())'

echo "==> DONE. Cek DoD: systemctl status mongod = active(running),"
echo "    db.orders.getIndexes() menunjukkan order_id & created_at."
