# 🚨 Sistem Monitoring, Deteksi, dan Respons Insiden  
_Berbasis Pulumi IaC di DigitalOcean Kubernetes_

## 📌 Deskripsi
Proyek ini membangun infrastruktur **Security Operations Center (SOC)** otomatis menggunakan pendekatan **Infrastructure as Code (IaC)** dengan **Pulumi**. Sistem dijalankan di atas **DigitalOcean Kubernetes** dan mengintegrasikan beberapa komponen utama untuk monitoring, deteksi, dan respons insiden keamanan siber.

### 🔑 Komponen Utama
- **Wazuh** – SIEM & EDR untuk monitoring, deteksi, dan respons.  
- **Suricata** – IDS/IPS untuk inspeksi lalu lintas jaringan.  
- **TheHive** – Case management untuk insiden.  
- **Cortex** – Data enrichment & analyzer.  
- **Shuffle** – SOAR untuk otomasi workflow insiden.  
- **Pulumi** – IaC untuk provisioning & deployment.  

---

## 🏗️ Arsitektur Sistem
Arsitektur deployment Kubernetes di DigitalOcean:

![Arsitektur Sistem](/gambar/topologi.png)

---

## 🔄 Gambaran Umum Alur Sistem
Alur deteksi, eskalasi, dan respons insiden:

![Gambaran Umum](/gambar/gambaran.png)

---

## ⚙️ Prasyarat
- Akun **DigitalOcean** dengan akses API.  
- **Pulumi** sudah terinstall.  
- **kubectl** sudah dikonfigurasi ke cluster.  
- **docker** sudah terinstall (untuk build image Cortex).  
- **bash** environment (Linux/WSL).    

---

## 📥 Instalasi & Deployment

### 1) Clone Wazuh (ubah storage + SSL)
```bash
git clone https://github.com/wazuh/wazuh-kubernetes.git -b v4.12.0 --depth=1
# → Update storageClassName ke DigitalOcean (mis. do-block-storage)
# → Generate sertifikat SSL untuk Wazuh
````

### 2) Clone Shuffle Chart

```bash
git clone https://github.com/Shuffle/Shuffle.git
# chart ada di: Shuffle/functions/kubernetes/charts/shuffle
```

### 3) Build & Push Image **Cortex** (sebelum `pulumi up`)
```bash
docker login registry.digitalocean.com
docker build -t registry.digitalocean.com/dmrs/cortex-custom:latest .
docker push registry.digitalocean.com/dmrs/cortex-custom:latest
```

### 4) Konfigurasi Pulumi Secrets

```bash
pulumi config set digitalocean:token <API_TOKEN> --secret
```

### 5) Deploy ke cluster

```bash
pulumi up
```

### 6) Konfigurasi Router

```bash
chmod +x setup_router.sh
./setup_router.sh
```

### 7) Konfigurasi Agent

```bash
chmod +x setup_agent.sh
./setup_agent.sh
```

---

## 🚀 Cara Menggunakan

Akses layanan utama setelah deployment:

* **Wazuh Dashboard**

  ```
  https://<WAZUH_DASHBOARD_IP>
  ```

* **TheHive**

  ```
  http://<NODE_IP>:30001
  ```

* **Cortex**

  ```
  http://<NODE_IP>:30002
  ```

* **Shuffle**

  ```
  http://<NODE_IP>:30080
  ```

---

## 🔧 Post-Deploy Setup

### 1) TheHive — Buat Organisasi & User

1. Login admin ke TheHive (`http://<NODE_IP>:30001`).
2. **Buat Organization baru** (mis. `dmrs`).
3. **Buat User baru** untuk analis → assign ke organisasi tersebut.

---

### 2) Cortex — Buat Organisasi & User + Aktifkan Analyzer

1. Login admin ke Cortex (`http://<NODE_IP>:30002`).
2. **Buat Organization baru** (mis. `dmrs`).
3. **Buat User baru** untuk analis.
4. **Aktifkan Analyzer** yang diperlukan:

   * `VirusTotal`
   * `AbuseIPDB`
5. Masukkan API Key:

   * `VT_API_KEY = <YOUR_VT_API_KEY>`
   * `ABUSEIPDB_API_KEY = <YOUR_ABUSEIPDB_API_KEY>`

---

### 3) Shuffle — Import Workflow JSON

1. Buka Shuffle (`http://<NODE_IP>:30080`).
2. **Import workflow** JSON yang sudah disiapkan.
3. Periksa koneksi ke TheHive, Cortex, dan Wazuh API.
4. Publish & jalankan workflow untuk uji coba.

---

### 4) Wazuh — Verifikasi Agent & Event

1. Login ke Wazuh Dashboard (`https://<WAZUH_DAHSBOARD_IP>`).
2. Pastikan semua agent (router, endpoint) **Connected**.
3. Cek log Suricata & rules aktif.

---

## 🧪 Alur Uji Cepat

1. Jalankan serangan uji (DoS, Payload Mutation, Shellcode Mutation).
2. **Suricata** mendeteksi event → dikirim ke **Wazuh**.
3. Event memicu **Shuffle Workflow** → membuat case di **TheHive**.
4. **Cortex** melakukan enrichment (VirusTotal/AbuseIPDB).
5. TheHive menampilkan hasil analisis → Wazuh bisa melakukan **Active Response**.

---

---
