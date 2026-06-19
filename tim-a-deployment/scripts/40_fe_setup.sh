#!/usr/bin/env bash
# 40_fe_setup.sh — Setup Nginx static frontend + reverse proxy di vm-fe (10.0.0.14)
# Target: Ubuntu 22.04. Jalankan via sudo. FP TKA 2026 — Tim A (Phase 4).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIGS="${HERE}/../configs"
FE_SRC="${HERE}/../frontend"
WEBROOT="/var/www/orderfe"

echo "==> [1/6] Install Nginx"
sudo apt-get update -y
sudo apt-get install -y nginx

echo "==> [2/6] Copy frontend ke ${WEBROOT}"
sudo mkdir -p "$WEBROOT"
sudo cp "${FE_SRC}/index.html" "${WEBROOT}/index.html"
sudo cp "${FE_SRC}/styles.css" "${WEBROOT}/styles.css"
sudo chown -R www-data:www-data "$WEBROOT"

echo "==> [3/6] Pasang site orderfe (static + proxy /api → vm-lb)"
sudo cp "${CONFIGS}/nginx-fe.conf" /etc/nginx/sites-available/orderfe
sudo ln -sf /etc/nginx/sites-available/orderfe /etc/nginx/sites-enabled/orderfe
sudo rm -f /etc/nginx/sites-enabled/default

echo "==> [4/6] Test config"
sudo nginx -t

echo "==> [5/6] Enable + restart"
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager || true

echo "==> [6/6] Firewall (ufw): 80 publik, SSH dijaga"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow from 35.235.240.0/20 to any port 22 proto tcp
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
fi

echo
echo "==> Verifikasi:"
curl -s -o /dev/null -w "static / → HTTP %{http_code}\n" http://localhost/
curl -s -o /dev/null -w "proxy /api/health → HTTP %{http_code}\n" http://localhost/api/health
echo "==> DoD: buka http://<public-ip-fe> di browser → login → muat produk → buat order."
