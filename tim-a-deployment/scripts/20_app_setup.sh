#!/usr/bin/env bash
# 20_app_setup.sh — Setup Flask + Gunicorn di vm-app (10.0.0.11)
# Target: Ubuntu 22.04. Jalankan via sudo. FP TKA 2026 — Tim A (Phase 2).
# Skema 3-VM: hanya 1 app server. Jika upgrade ke 4-VM, jalankan ulang di vm-app2 dengan
# JWT_SECRET yang SAMA:  sudo JWT_SECRET="<nilai-dari-vm-app>" ./20_app_setup.sh
set -euo pipefail

DB_IP="10.0.0.6"    # app1-dan-db (MongoDB di VM yang sama / VM tetangga)
LB_IP="10.0.0.5"   # lb-dan-fe
APP_DIR="/opt/orderapp"
ENV_DIR="/etc/orderapp"
HERE="$(cd "$(dirname "$0")" && pwd)"
CONFIGS="${HERE}/../configs"

# Sumber app.py + requirements.txt (copy dari Resources/BE/ ke sini dulu).
APP_SRC="${APP_SRC:-$HOME/app-src}"

# JWT_SECRET: pakai dari env kalau ada, else generate (lalu WAJIB dipakai sama di VM lain).
JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"

echo "==> [1/8] Cek sumber app"
for f in app.py requirements.txt; do
  if [ ! -f "${APP_SRC}/${f}" ]; then
    echo "    !! ${APP_SRC}/${f} tidak ada. Copy dulu:"
    echo "       scp fp-tka-26-main/Resources/BE/{app.py,requirements.txt} <vm>:~/app-src/"
    exit 1
  fi
done

echo "==> [2/8] Install Python + venv"
sudo apt-get update -y
sudo apt-get install -y python3 python3-venv python3-pip

echo "==> [3/8] Buat user sistem 'orderapp' + folder"
sudo id -u orderapp >/dev/null 2>&1 || sudo useradd --system --no-create-home --shell /usr/sbin/nologin orderapp
sudo mkdir -p "$APP_DIR" "$ENV_DIR"

echo "==> [4/8] Copy app + config"
sudo cp "${APP_SRC}/app.py"          "${APP_DIR}/app.py"
sudo cp "${APP_SRC}/requirements.txt" "${APP_DIR}/requirements.txt"
sudo cp "${CONFIGS}/gunicorn.conf.py" "${APP_DIR}/gunicorn.conf.py"

echo "==> [5/8] Virtualenv + dependencies"
sudo python3 -m venv "${APP_DIR}/venv"
sudo "${APP_DIR}/venv/bin/pip" install --upgrade pip
sudo "${APP_DIR}/venv/bin/pip" install -r "${APP_DIR}/requirements.txt"
sudo "${APP_DIR}/venv/bin/pip" freeze | sudo tee "${APP_DIR}/requirements.lock.txt" >/dev/null

echo "==> [6/8] Tulis ${ENV_DIR}/orderapp.env"
sudo tee "${ENV_DIR}/orderapp.env" >/dev/null <<EOF
MONGO_URI=mongodb://${DB_IP}:27017/?maxPoolSize=50
JWT_SECRET=${JWT_SECRET}
JWT_EXPIRES=86400
# Workload I/O-bound (query MongoDB). gthread + banyak thread = throughput jauh lebih tinggi
# daripada sync. 4 worker x 8 thread = 32 request konkuren per VM (64 total dgn 2 app server).
GUNICORN_WORKERS=4
GUNICORN_WORKER_CLASS=gthread
GUNICORN_THREADS=8
EOF
sudo chmod 640 "${ENV_DIR}/orderapp.env"
sudo chown -R orderapp:orderapp "$APP_DIR" "$ENV_DIR"

echo "==> [7/8] Install + start systemd service"
sudo cp "${CONFIGS}/orderapp.service" /etc/systemd/system/orderapp.service
sudo systemctl daemon-reload
sudo systemctl enable orderapp
sudo systemctl restart orderapp
sleep 3
sudo systemctl status orderapp --no-pager || true

echo "==> [8/8] Firewall: port 5000 HANYA dari vm-lb (${LB_IP})"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow from 10.0.0.0/24      to any port 22 proto tcp
  # Azure NSG sudah membatasi SSH dari internet — tidak perlu IAP CIDR (GCP-only)
  sudo ufw allow from "${LB_IP}"       to any port 5000 proto tcp
  sudo ufw deny 5000
  echo "    (ufw rule siap. 'sudo ufw enable' kalau mau aktifkan — SSH sudah dijaga.)"
fi

echo
echo "==> Verifikasi lokal:"
curl -s http://localhost:5000/health && echo
echo "==> JWT_SECRET yang dipakai (PAKAI SAMA di VM app lain):"
echo "    ${JWT_SECRET}"
echo "==> DoD: systemctl status orderapp = active(running); /health → {\"status\":\"ok\"}"
