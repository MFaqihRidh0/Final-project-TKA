# Phase 0 — Provision GCP (5 VM + VPC + Firewall + Cloud NAT)

VM belum ada → buat dulu sebelum Phase 1. Eksekusi manual oleh Anda.

## Prasyarat (di laptop Windows)
1. Install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
2. Login & set project:
   ```bash
   gcloud auth login
   gcloud config set project <PROJECT_ID>
   ```
   > Alternatif tanpa install: pakai **Google Cloud Shell** (browser) —
   > upload folder `tim-a-deployment/` ke sana, gcloud sudah siap.

## Jalankan
```bash
chmod +x tim-a-deployment/scripts/01_provision_gcp.sh
./tim-a-deployment/scripts/01_provision_gcp.sh
```
Script membuat: VPC `tka-vpc` + subnet `10.0.0.0/24`, 3 firewall rule
(internal, http publik, IAP-SSH), Cloud NAT, dan 5 VM dengan IP statik
10.0.0.10–14.

## Dua hal penting yang ditangani script
- **Cloud NAT** → vm-db/app1/app2 tidak punya public IP tapi tetap bisa
  `apt install` (egress internet) tanpa terekspos publik.
- **IAP SSH** → SSH ke VM internal-only:
  ```bash
  gcloud compute ssh vm-db   --zone=asia-southeast2-a --tunnel-through-iap
  gcloud compute ssh vm-app1 --zone=asia-southeast2-a --tunnel-through-iap
  ```
  vm-lb & vm-fe punya public IP, bisa SSH biasa juga.

## Setelah selesai
- Catat EXTERNAL_IP vm-lb (untuk Tim B & frontend) dan vm-fe.
- Verifikasi: `gcloud compute instances list`
- Lanjut ke **Phase 1** (`docs/PHASE1_MONGODB.md`).

## ⚠️ Teardown (setelah FP selesai — wajib biar credit tidak habis)
```bash
gcloud compute instances delete vm-lb vm-app1 vm-app2 vm-db vm-fe --zone=asia-southeast2-a
gcloud compute routers nats delete tka-vpc-nat --router=tka-vpc-router --region=asia-southeast2
gcloud compute routers delete tka-vpc-router --region=asia-southeast2
gcloud compute firewall-rules delete tka-vpc-allow-internal tka-vpc-allow-http tka-vpc-allow-iap-ssh
gcloud compute networks subnets delete tka-subnet --region=asia-southeast2
gcloud compute networks delete tka-vpc
```
