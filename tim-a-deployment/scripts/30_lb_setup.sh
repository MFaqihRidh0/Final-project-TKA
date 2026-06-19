#!/usr/bin/env bash
# 30_lb_setup.sh — Setup Nginx LB + Frontend di vm-lb (10.0.0.10)
# Opsi A: vm-lb dan vm-fe digabung dalam 1 VM.
# Target: Ubuntu 22.04. Jalankan via sudo. FP TKA 2026 — Tim A (Phase 3).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIGS="${HERE}/../configs"
FE_SRC="${HERE}/../frontend"
WEBROOT="/var/www/orderfe"

echo "==> [1/7] Install Nginx"
sudo apt-get update -y
sudo apt-get install -y nginx

echo "==> [2/7] Pasang nginx.conf (tuning high-concurrency)"
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s) || true
sudo cp "${CONFIGS}/nginx-lb-main.conf" /etc/nginx/nginx.conf

echo "==> [3/7] Copy frontend ke ${WEBROOT}"
sudo mkdir -p "$WEBROOT"
sudo cp "${FE_SRC}/index.html" "${WEBROOT}/index.html"
sudo cp "${FE_SRC}/styles.css"  "${WEBROOT}/styles.css"
sudo chown -R www-data:www-data "$WEBROOT"

echo "==> [4/7] Pasang site orderapp (LB + static FE) + nonaktifkan default"
sudo cp "${CONFIGS}/nginx-lb-fe.conf" /etc/nginx/sites-available/orderapp
sudo ln -sf /etc/nginx/sites-available/orderapp /etc/nginx/sites-enabled/orderapp
sudo rm -f /etc/nginx/sites-enabled/default

echo "==> [5/7] Test config"
sudo nginx -t

echo "==> [6/7] Enable + restart"
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager || true

echo "==> [7/7] Firewall (ufw): 80 publik, SSH dijaga"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
fi

echo
echo "==> Verifikasi:"
curl -s -o /dev/null -w "GET /         → HTTP %{http_code}\n" http://localhost/
curl -s -o /dev/null -w "GET /health   → HTTP %{http_code}\n" http://localhost/health
curl -s -o /dev/null -w "GET /api/health → HTTP %{http_code}\n" http://localhost/api/health
echo
echo "==> DoD:"
echo "    - http://<public-ip-lb>          → halaman toko muncul"
echo "    - http://<public-ip-lb>/health   → {status:ok}"
echo "    - Login di frontend → muat produk → buat order (via /api/)"
echo "    (Skema 3-VM: 1 app server — upgrade ke 4-VM untuk HA round-robin)"
