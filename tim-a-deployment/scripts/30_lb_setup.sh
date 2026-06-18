#!/usr/bin/env bash
# 30_lb_setup.sh — Setup Nginx Load Balancer di vm-lb (10.0.0.10)
# Target: Ubuntu 22.04. Jalankan via sudo. FP TKA 2026 — Tim A (Phase 3).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIGS="${HERE}/../configs"

echo "==> [1/6] Install Nginx"
sudo apt-get update -y
sudo apt-get install -y nginx

echo "==> [2/6] Pasang nginx.conf (tuning high-concurrency)"
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.$(date +%s) || true
sudo cp "${CONFIGS}/nginx-lb-main.conf" /etc/nginx/nginx.conf

echo "==> [3/6] Pasang site orderapp + nonaktifkan default"
sudo cp "${CONFIGS}/nginx-lb.conf" /etc/nginx/sites-available/orderapp
sudo ln -sf /etc/nginx/sites-available/orderapp /etc/nginx/sites-enabled/orderapp
sudo rm -f /etc/nginx/sites-enabled/default

echo "==> [4/6] Test config"
sudo nginx -t

echo "==> [5/6] Enable + restart"
sudo systemctl enable nginx
sudo systemctl restart nginx
sudo systemctl status nginx --no-pager || true

echo "==> [6/6] Firewall (ufw): 80/443 publik, SSH dijaga"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow from 35.235.240.0/20 to any port 22 proto tcp
  sudo ufw allow 22/tcp
  sudo ufw allow 80/tcp
  sudo ufw allow 443/tcp
  echo "    (GCP firewall sudah buka 80/443 ke tag http-server. ufw opsional.)"
fi

echo
echo "==> Verifikasi:"
curl -s http://localhost/health && echo
echo "==> DoD: curl http://<public-ip-lb>/health → 200; matikan vm-app1, masih terlayani app2."
