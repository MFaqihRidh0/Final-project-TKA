# Phase 0 — Provision Azure (5 VM + VNet + NSG)

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
NSG dengan 5 rule keamanan, dan 5 VM dengan IP privat statik 10.0.0.10–14.

## Topologi Jaringan

```
Internet
  │
  ├─ vm-lb  (10.0.0.10) — public IP ✅ port 80 terbuka
  └─ vm-fe  (10.0.0.14) — public IP ✅ port 80 terbuka

  vm-app1 (10.0.0.11) — NO public IP (internal only)
  vm-app2 (10.0.0.12) — NO public IP (internal only)
  vm-db   (10.0.0.13) — NO public IP (internal only)
```

NSG memblok port 5000 & 27017 dari internet — hanya bisa diakses antar VM dalam VNet.

## SSH ke VM

**vm-lb & vm-fe** (punya public IP):
```bash
ssh azureuser@<PUBLIC_IP_vm-lb>
ssh azureuser@<PUBLIC_IP_vm-fe>
```

**vm-app1, vm-app2, vm-db** (internal, lewat jump host vm-lb):
```bash
ssh -J azureuser@<PUBLIC_IP_vm-lb> azureuser@10.0.0.11   # vm-app1
ssh -J azureuser@<PUBLIC_IP_vm-lb> azureuser@10.0.0.12   # vm-app2
ssh -J azureuser@<PUBLIC_IP_vm-lb> azureuser@10.0.0.13   # vm-db
```

> **Tip Windows:** Kalau pakai PowerShell dan `-J` tidak dikenali, pakai PuTTY
> dengan proxy tunnel, atau install OpenSSH via Settings → Apps → Optional Features.

## Transfer File ke VM

```bash
# Kirim folder deployment ke semua VM
scp -r tim-a-deployment/ azureuser@<PUBLIC_IP_vm-lb>:~
scp -r tim-a-deployment/ azureuser@<PUBLIC_IP_vm-fe>:~

# VM internal (lewat jump host)
scp -r -J azureuser@<PUBLIC_IP_vm-lb> tim-a-deployment/ azureuser@10.0.0.11:~
scp -r -J azureuser@<PUBLIC_IP_vm-lb> tim-a-deployment/ azureuser@10.0.0.12:~
scp -r -J azureuser@<PUBLIC_IP_vm-lb> tim-a-deployment/ azureuser@10.0.0.13:~

# Source code app ke vm-app1 & vm-app2
scp -J azureuser@<PUBLIC_IP_vm-lb> fp-tka-26-main/Resources/BE/app.py azureuser@10.0.0.11:~/app-src/
scp -J azureuser@<PUBLIC_IP_vm-lb> fp-tka-26-main/Resources/BE/requirements.txt azureuser@10.0.0.11:~/app-src/
scp -J azureuser@<PUBLIC_IP_vm-lb> fp-tka-26-main/Resources/BE/app.py azureuser@10.0.0.12:~/app-src/
scp -J azureuser@<PUBLIC_IP_vm-lb> fp-tka-26-main/Resources/BE/requirements.txt azureuser@10.0.0.12:~/app-src/

# DB dump ke vm-db
scp -r -J azureuser@<PUBLIC_IP_vm-lb> fp-tka-26-main/Resources/DB/dump azureuser@10.0.0.13:~/db-dump
```

## Setelah Selesai

```bash
az vm list-ip-addresses --resource-group fp-tka-rg --output table
```

Catat EXTERNAL IP vm-lb (untuk Tim B) dan vm-fe (untuk akses browser).
Lanjut ke **Phase 1** (`docs/PHASE1_MONGODB.md`).

## Teardown (setelah FP selesai — wajib agar credit tidak habis)

```bash
az group delete --name fp-tka-rg --yes --no-wait
```

> Satu perintah ini menghapus semua resource (VM, VNet, NSG, IP) sekaligus.
