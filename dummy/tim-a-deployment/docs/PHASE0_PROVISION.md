# Phase 0 — Provision Azure (3 VM + VNet + NSG)

VM belum ada → buat dulu sebelum Phase 1. Eksekusi manual oleh Anda.

## Prasyarat (di laptop Windows)

1. Install Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows
2. Login & set subscription:
   ```bash
   az login
   az account list --output table          # lihat subscription ID
   az account set --subscription <ID>
   ```
   > Alternatif tanpa install: pakai **Azure Cloud Shell** di portal.azure.com —
   > upload folder `tim-a-deployment/` ke sana, az CLI sudah siap.

## Jalankan

```bash
chmod +x tim-a-deployment/scripts/01_provision_azure.sh
./tim-a-deployment/scripts/01_provision_azure.sh
```

Script membuat: Resource Group `fp-tka-rg`, VNet `tka-vnet` + subnet `10.0.0.0/24`,
NSG dengan 5 rule keamanan, dan **3 VM** (skema 6 vCPU, semua Standard_B2s):

| VM     | IP         | Public IP | Role                |
| ------ | ---------- | --------- | ------------------- |
| vm-lb  | 10.0.0.10  | Ya        | Nginx LB + Frontend |
| vm-app | 10.0.0.11  | Tidak     | Flask + Gunicorn    |
| vm-db  | 10.0.0.13  | Tidak     | MongoDB 7.0         |

## Topologi Jaringan

```text
Internet
  │
  └─ vm-lb  (10.0.0.10) — public IP, port 80 terbuka
       │  serve static frontend + proxy /api/ → vm-app:5000
       │
  vm-app (10.0.0.11) — internal only (Flask/Gunicorn)
  vm-db  (10.0.0.13) — internal only (MongoDB)
```

NSG memblok port 5000 & 27017 dari internet — hanya bisa diakses dalam VNet.

## SSH ke VM

**vm-lb** (punya public IP — SSH langsung):

```bash
ssh azureuser@<PUBLIC_IP_vm-lb>
```

**vm-app & vm-db** (internal, lewat jump host vm-lb):

```bash
ssh -J azureuser@<PUBLIC_IP_vm-lb> azureuser@10.0.0.11   # vm-app
ssh -J azureuser@<PUBLIC_IP_vm-lb> azureuser@10.0.0.13   # vm-db
```

> **Tip Windows:** Kalau pakai PowerShell dan `-J` tidak dikenali, install OpenSSH
> via Settings → Apps → Optional Features, atau gunakan Azure Cloud Shell.

## Transfer File ke VM

```bash
LB_IP="<PUBLIC_IP_vm-lb>"

# vm-lb (public IP langsung)
scp -r tim-a-deployment/ azureuser@$LB_IP:~

# vm-app (lewat jump host)
scp -r -J azureuser@$LB_IP tim-a-deployment/ azureuser@10.0.0.11:~
scp -J azureuser@$LB_IP fp-tka-26-main/Resources/BE/app.py azureuser@10.0.0.11:~/app-src/
scp -J azureuser@$LB_IP fp-tka-26-main/Resources/BE/requirements.txt azureuser@10.0.0.11:~/app-src/

# vm-db (lewat jump host)
scp -r -J azureuser@$LB_IP tim-a-deployment/ azureuser@10.0.0.13:~
scp -r -J azureuser@$LB_IP fp-tka-26-main/Resources/DB/dump azureuser@10.0.0.13:~/db-dump
```

## Setelah Selesai

```bash
az vm list-ip-addresses --resource-group fp-tka-rg --output table
```

Catat EXTERNAL IP vm-lb — ini yang dibagikan ke Tim B (untuk load test) dan dibuka di browser.
Lanjut ke **Phase 1** (`docs/PHASE1_MONGODB.md`).

## Teardown (setelah FP selesai — wajib agar credit tidak habis)

```bash
az group delete --name fp-tka-rg --yes --no-wait
```

> Satu perintah ini menghapus semua resource (VM, VNet, NSG, IP) sekaligus.
