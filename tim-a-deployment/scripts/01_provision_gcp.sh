#!/usr/bin/env bash
# 01_provision_gcp.sh — Provision 5 VM + VPC + firewall + Cloud NAT di GCP
# FP TKA 2026 — Tim A (Phase 0). Region asia-southeast2 (Jakarta).
#
# Jalankan dari laptop (gcloud terpasang) ATAU dari Google Cloud Shell.
# Idempotent-ish: kalau resource sudah ada, gcloud akan error tapi tidak merusak.
# Cek dulu: gcloud auth login && gcloud config set project <PROJECT_ID>
set -euo pipefail

# ─── Konfigurasi (ubah sesuai kebutuhan) ──────────────────────────
PROJECT="$(gcloud config get-value project 2>/dev/null)"
REGION="asia-southeast2"
ZONE="asia-southeast2-a"
NET="tka-vpc"
SUBNET="tka-subnet"
SUBNET_RANGE="10.0.0.0/24"
IMG_FAMILY="ubuntu-2204-lts"
IMG_PROJECT="ubuntu-os-cloud"

# Machine types (e2). Sesuaikan kalau mau hemat/lebih kuat.
MT_LB="e2-small"            # vm-lb  1vCPU/2GB (≈ spec 1/1)
MT_FE="e2-small"            # vm-fe  1vCPU/2GB
MT_APP="e2-small"           # vm-app 1vCPU/2GB
MT_DB="e2-custom-2-4096"    # vm-db  2vCPU/4GB

echo "Project = ${PROJECT} | Region = ${REGION} | Zone = ${ZONE}"
read -p "Lanjut provisioning? (y/N) " ok; [ "$ok" = "y" ] || exit 1

# ─── 1. VPC + Subnet ──────────────────────────────────────────────
gcloud compute networks create "$NET" --subnet-mode=custom
gcloud compute networks subnets create "$SUBNET" \
  --network="$NET" --region="$REGION" --range="$SUBNET_RANGE"

# ─── 2. Firewall ──────────────────────────────────────────────────
# 2a. Semua trafik INTERNAL dalam subnet (app→db:27017, lb→app:5000, dll)
gcloud compute firewall-rules create "${NET}-allow-internal" \
  --network="$NET" --direction=INGRESS --action=ALLOW \
  --rules=tcp,udp,icmp --source-ranges="$SUBNET_RANGE"

# 2b. HTTP/HTTPS publik HANYA ke vm-lb & vm-fe (target tag http-server)
gcloud compute firewall-rules create "${NET}-allow-http" \
  --network="$NET" --direction=INGRESS --action=ALLOW \
  --rules=tcp:80,tcp:443 --source-ranges="0.0.0.0/0" \
  --target-tags=http-server

# 2c. SSH via IAP (untuk VM internal-only). Range IAP = 35.235.240.0/20
gcloud compute firewall-rules create "${NET}-allow-iap-ssh" \
  --network="$NET" --direction=INGRESS --action=ALLOW \
  --rules=tcp:22 --source-ranges="35.235.240.0/20"

# (CATATAN: port 5000 & 27017 TIDAK dibuka ke publik — hanya lewat allow-internal.)

# ─── 3. Cloud NAT (egress internet utk VM tanpa public IP → apt install) ──
gcloud compute routers create "${NET}-router" \
  --network="$NET" --region="$REGION"
gcloud compute routers nats create "${NET}-nat" \
  --router="${NET}-router" --region="$REGION" \
  --nat-all-subnet-ip-ranges --auto-allocate-nat-external-ips

# ─── 4. VM ────────────────────────────────────────────────────────
# Internal-only (NO public IP): db, app1, app2
gcloud compute instances create vm-db \
  --zone="$ZONE" --machine-type="$MT_DB" \
  --image-family="$IMG_FAMILY" --image-project="$IMG_PROJECT" \
  --network-interface="subnet=${SUBNET},private-network-ip=10.0.0.13,no-address" \
  --boot-disk-size=20GB

gcloud compute instances create vm-app1 \
  --zone="$ZONE" --machine-type="$MT_APP" \
  --image-family="$IMG_FAMILY" --image-project="$IMG_PROJECT" \
  --network-interface="subnet=${SUBNET},private-network-ip=10.0.0.11,no-address"

gcloud compute instances create vm-app2 \
  --zone="$ZONE" --machine-type="$MT_APP" \
  --image-family="$IMG_FAMILY" --image-project="$IMG_PROJECT" \
  --network-interface="subnet=${SUBNET},private-network-ip=10.0.0.12,no-address"

# Public (punya external IP + tag http-server): lb, fe
gcloud compute instances create vm-lb \
  --zone="$ZONE" --machine-type="$MT_LB" \
  --image-family="$IMG_FAMILY" --image-project="$IMG_PROJECT" \
  --tags=http-server \
  --network-interface="subnet=${SUBNET},private-network-ip=10.0.0.10"

gcloud compute instances create vm-fe \
  --zone="$ZONE" --machine-type="$MT_FE" \
  --image-family="$IMG_FAMILY" --image-project="$IMG_PROJECT" \
  --tags=http-server \
  --network-interface="subnet=${SUBNET},private-network-ip=10.0.0.14"

echo
echo "==> Provisioning selesai. Daftar VM:"
gcloud compute instances list --zones="$ZONE"
echo
echo "Public IP vm-lb & vm-fe ada di kolom EXTERNAL_IP (untuk Tim B & frontend)."
echo "SSH ke VM internal:  gcloud compute ssh vm-db --zone=${ZONE} --tunnel-through-iap"
