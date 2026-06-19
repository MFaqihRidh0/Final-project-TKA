#!/usr/bin/env bash
# 01_provision_azure.sh — Provision 5 VM + VNet + NSG di Azure
# FP TKA 2026 — Tim A (Phase 0). Region southeastasia (Singapore).
#
# Prasyarat: az login && az account set --subscription <ID>
# Jalankan dari laptop (Azure CLI) atau Azure Cloud Shell.
set -euo pipefail

# ─── Konfigurasi ──────────────────────────────────────────
RG="fp-tka-rg"
LOCATION="southeastasia"
VNET="tka-vnet"
SUBNET="tka-subnet"
NSG="tka-nsg"
ADDR_PREFIX="10.0.0.0/24"
IMG="Ubuntu2204"
ADMIN="azureuser"

# Machine sizes
SZ_SMALL="Standard_B1s"    # 1vCPU/1GB  — vm-lb, vm-fe
SZ_APP="Standard_B1ms"     # 1vCPU/2GB  — vm-app1, vm-app2
SZ_DB="Standard_B2s"       # 2vCPU/4GB  — vm-db

echo "Resource Group : $RG"
echo "Location       : $LOCATION"
read -p "Lanjut provisioning? (y/N) " ok; [ "$ok" = "y" ] || exit 1

# ─── 1. Resource Group ────────────────────────────────────
az group create --name "$RG" --location "$LOCATION"

# ─── 2. VNet + Subnet ─────────────────────────────────────
az network vnet create \
  --resource-group "$RG" --name "$VNET" \
  --address-prefix "$ADDR_PREFIX" \
  --subnet-name "$SUBNET" --subnet-prefix "$ADDR_PREFIX"

# ─── 3. Network Security Group (NSG) ──────────────────────
az network nsg create --resource-group "$RG" --name "$NSG"

# 3a. SSH dari internet (untuk semua VM — pakai key auth)
az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Allow-SSH --priority 100 \
  --protocol Tcp --direction Inbound --access Allow \
  --source-address-prefixes "*" --destination-port-ranges 22

# 3b. HTTP publik (hanya vm-lb & vm-fe yang punya public IP)
az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Allow-HTTP --priority 110 \
  --protocol Tcp --direction Inbound --access Allow \
  --source-address-prefixes "*" --destination-port-ranges 80

# 3c. Port 5000 HANYA dari internal subnet (vm-lb → vm-app)
az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Allow-App-Internal --priority 120 \
  --protocol Tcp --direction Inbound --access Allow \
  --source-address-prefixes "$ADDR_PREFIX" --destination-port-ranges 5000

# 3d. Port 27017 HANYA dari internal subnet (vm-app → vm-db)
az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Allow-Mongo-Internal --priority 130 \
  --protocol Tcp --direction Inbound --access Allow \
  --source-address-prefixes "$ADDR_PREFIX" --destination-port-ranges 27017

# 3e. Blok 5000 & 27017 dari internet (eksplisit deny)
az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Deny-App-Public --priority 200 \
  --protocol Tcp --direction Inbound --access Deny \
  --source-address-prefixes "Internet" --destination-port-ranges 5000

az network nsg rule create --resource-group "$RG" --nsg-name "$NSG" \
  --name Deny-Mongo-Public --priority 210 \
  --protocol Tcp --direction Inbound --access Deny \
  --source-address-prefixes "Internet" --destination-port-ranges 27017

# ─── 4. VM ────────────────────────────────────────────────
create_vm() {
  local NAME=$1 SIZE=$2 IP=$3 PUBLIC_IP=$4
  echo "==> Buat $NAME ($SIZE, $IP, public=$PUBLIC_IP)"
  az vm create \
    --resource-group "$RG" --name "$NAME" \
    --image "$IMG" --size "$SIZE" \
    --vnet-name "$VNET" --subnet "$SUBNET" \
    --private-ip-address "$IP" \
    --public-ip-address "$PUBLIC_IP" \
    --nsg "$NSG" \
    --admin-username "$ADMIN" \
    --generate-ssh-keys \
    --no-wait
}

# Opsi A: vm-lb juga serve frontend (vm-fe dihapus, hemat 1 vCPU)
# Total vCPU: vm-lb(1) + vm-app1(1) + vm-app2(1) + vm-db(2) = 5 vCPU

# VM dengan public IP
create_vm vm-lb   "$SZ_SMALL" "10.0.0.10" "vm-lb-ip"

# VM internal (no public IP — SSH via vm-lb sebagai jump host)
create_vm vm-app1 "$SZ_APP" "10.0.0.11" '""'
create_vm vm-app2 "$SZ_APP" "10.0.0.12" '""'
create_vm vm-db   "$SZ_DB"  "10.0.0.13" '""'

echo "==> Menunggu semua VM selesai dibuat..."
az vm wait --resource-group "$RG" \
  --ids $(az vm list -g "$RG" --query "[].id" -o tsv) \
  --created

echo
echo "==> Provisioning selesai. Daftar VM:"
az vm list-ip-addresses --resource-group "$RG" --output table

echo
echo "Public IP vm-lb di kolom PublicIPAddresses."
echo "SSH ke vm-lb  : ssh $ADMIN@<PUBLIC_IP_vm-lb>"
echo "SSH ke vm-app1: ssh -J $ADMIN@<PUBLIC_IP_vm-lb> $ADMIN@10.0.0.11"
echo "SSH ke vm-app2: ssh -J $ADMIN@<PUBLIC_IP_vm-lb> $ADMIN@10.0.0.12"
echo "SSH ke vm-db  : ssh -J $ADMIN@<PUBLIC_IP_vm-lb> $ADMIN@10.0.0.13"
echo
echo "CATATAN: vm-lb sekarang juga serve frontend (Opsi A — vm-fe digabung)."
echo "Jalankan 30_lb_setup.sh (bukan 40_fe_setup.sh) untuk setup LB + FE sekaligus."
