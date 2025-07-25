#!/bin/bash

# ======================
# Wazuh & Suricata IaC untuk Ubuntu Router
# ======================
# Atur Permission: chmod +x setup-suricata-wazuh.sh
# Jalankan: sudo ./setup-suricata-wazuh.sh


echo "-----------------------------------------------------------------"
echo "     WAZUH  +  SURICATA INSTALLATION INTEGRATION AUTOMATION      "
echo "-----------------------------------------------------------------"


# --- 1. Install Wazuh Agent ---
echo "[*] Instalasi Wazuh Agent"

read -p "Masukkan IP Wazuh Manager (WAZUH_MANAGER): " WAZUH_MANAGER
while [[ -z "$WAZUH_MANAGER" ]]; do
    echo "WAZUH_MANAGER tidak boleh kosong."
    read -p "Masukkan IP Wazuh Manager (WAZUH_MANAGER): " WAZUH_MANAGER
done

read -p "Masukkan IP Wazuh Registration Server (WAZUH_REGISTRATION_SERVER): " WAZUH_REGISTRATION_SERVER
while [[ -z "$WAZUH_REGISTRATION_SERVER" ]]; do
    echo "WAZUH_REGISTRATION_SERVER tidak boleh kosong."
    read -p "Masukkan IP Wazuh Registration Server (WAZUH_REGISTRATION_SERVER): " WAZUH_REGISTRATION_SERVER
done

read -p "Masukkan Registration Password (WAZUH_REGISTRATION_PASSWORD): " WAZUH_REGISTRATION_PASSWORD
while [[ -z "$WAZUH_REGISTRATION_PASSWORD" ]]; do
    echo "WAZUH_REGISTRATION_PASSWORD tidak boleh kosong."
    read -p "Masukkan Registration Password (WAZUH_REGISTRATION_PASSWORD): " WAZUH_REGISTRATION_PASSWORD
done

echo "[*] Download dan install Wazuh Agent..."
wget https://packages.wazuh.com/4.x/apt/pool/main/w/wazuh-agent/wazuh-agent_4.12.0-1_amd64.deb -O wazuh-agent.deb
sudo WAZUH_MANAGER="$WAZUH_MANAGER" WAZUH_REGISTRATION_SERVER="$WAZUH_REGISTRATION_SERVER" WAZUH_REGISTRATION_PASSWORD="$WAZUH_REGISTRATION_PASSWORD" dpkg -i ./wazuh-agent.deb

sudo systemctl daemon-reload
sudo systemctl enable wazuh-agent
sudo systemctl start wazuh-agent
sudo systemctl status wazuh-agent --no-pager

echo ""
echo "===== Wazuh Agent Berhasil Terinstall ====="
echo ""

# --- 2. Install Suricata ---
echo ""
echo ""
echo ""
echo "[*] Menambahkan repository & install Suricata..."
sudo add-apt-repository -y ppa:oisf/suricata-stable
sudo apt-get update
sudo apt-get install -y suricata

# --- 3. Download & Extract Rules ---
echo ""
echo ""
echo ""
echo "[*] Downloading & extracting Emerging Threats ruleset..."
cd /tmp
curl -LO https://rules.emergingthreats.net/open/suricata-6.0.8/emerging.rules.tar.gz
tar -xvzf emerging.rules.tar.gz
SURICATA_RULE_DIR="/etc/suricata/rules"
sudo mkdir -p $SURICATA_RULE_DIR
sudo mv rules/*.rules $SURICATA_RULE_DIR/

# --- 4. Interaktif Tambahkan Custom Rules ---
echo "[*] Apakah ingin menambahkan custom rules sendiri?"

while true; do
    read -p "Tambah custom rule? (yes/no) [no]: " ADD_RULE
    ADD_RULE=${ADD_RULE:-no}
    if [[ "$ADD_RULE" == "yes" || "$ADD_RULE" == "y" ]]; then
        read -p "Nama file rules (tanpa spasi, ex: custom1.rules): " RULE_FILE
        RULE_FILE=${RULE_FILE:-custom.rules}
        RULE_PATH="$SURICATA_RULE_DIR/$RULE_FILE"

        echo "Ketik/masukkan rule (boleh lebih dari satu baris, akhiri dengan Ctrl+D):"
        RULE_CONTENT=$(</dev/stdin)

        echo "$RULE_CONTENT" | sudo tee "$RULE_PATH" >/dev/null

        echo "Custom rule berhasil disimpan ke $RULE_PATH"
    else
        break
    fi
done

sudo chmod 640 $SURICATA_RULE_DIR/*.rules

SURICATA_YAML="/etc/suricata/suricata.yaml"
EVE_JSON_PATH="/var/log/suricata/eve.json"
OSSEC_CONF="/var/ossec/etc/ossec.conf"

# --- 5. Konfigurasi Suricata ---
echo ""
echo ""
echo ""
echo "[*] Siap konfigurasi Suricata."

while [[ -z "$HOME_NET" ]]; do
    read -p "Masukkan HOME_NET (contoh: 192.168.200.1): " HOME_NET
    if [[ -z "$HOME_NET" ]]; then
        echo "HOME_NET tidak boleh kosong!"
    fi
done

read -p "Masukkan EXTERNAL_NET (default: any): " EXTERNAL_NET
EXTERNAL_NET=${EXTERNAL_NET:-any}

read -p "Masukkan nama INTERFACE (default: enp0s8): " INTERFACE
INTERFACE=${INTERFACE:-enp0s8}

# --- 6. Edit suricata.yaml ---
echo "[*] Mengedit konfigurasi suricata.yaml..."

# Backup dulu!
sudo cp $SURICATA_YAML ${SURICATA_YAML}.bak.$(date +%s)

# Update HOME_NET & EXTERNAL_NET pada block address-groups:
sudo sed -i "s|^\([[:space:]]*HOME_NET:\).*|\1 \"$HOME_NET\"|g" $SURICATA_YAML
sudo sed -i "s|^\([[:space:]]*EXTERNAL_NET:\).*|\1 \"$EXTERNAL_NET\"|g" $SURICATA_YAML

# Update default-rule-path:
sudo sed -i "s|^\(default-rule-path:\).*|\1 $SURICATA_RULE_DIR|g" $SURICATA_YAML

# Comment semua block rule-files: yang ada dulu (biar gak double & terdokumentasi)
sudo sed -i '/^rule-files:/,/^[^ ][^:]*:/{
  /^#/! s/^/# /
}' $SURICATA_YAML

# Tambahkan 1 block rule-files setelah default-rule-path, jika belum ada rule-files aktif (tidak di-comment)
if ! sudo grep -qE '^[[:space:]]*rule-files:[[:space:]]*$' "$SURICATA_YAML"; then
  sudo sed -i "/^default-rule-path:/a\\
rule-files:\\n  - \"*.rules\"
" $SURICATA_YAML
fi

# Enable statistik (aktifkan enabled: yes di bawah stats:)
sudo sed -i "/^stats:/,/^[^ ]/ {s/enabled: .*/enabled: yes/}" $SURICATA_YAML

# Konfigurasi af-packet (block ulang)
sudo sed -i "/af-packet:/,/^[^ ]/c\\
af-packet:\n  - interface: $INTERFACE
" $SURICATA_YAML

# Edit eve-log (replace block)
sudo sed -i "/eve-log:/,/^[^ ]/c\\
eve-log:\n  enabled: yes\n  filetype: regular\n  filename: eve.json\n  types:\n    - alert:\n        payload: yes\n        metadata: yes\n        http-body: yes\n        tagged-packets: yes\n    - dns\n    - http\n    - flow\n    - stats
" $SURICATA_YAML



# --- 7. Restart Suricata ---
echo ""
echo ""
echo ""
echo "[*] Cek config dan restart Suricata..."
sudo suricata -T -c $SURICATA_YAML || { echo "[!!] Suricata config error!"; exit 1; }
sudo systemctl restart suricata
sudo systemctl status suricata --no-pager

# --- 8. Integrasi ke Wazuh ---
echo ""
echo ""
echo ""
echo "[*] Integrasi log Suricata ke Wazuh (ossec.conf)..."

# Backup dulu!
sudo cp $OSSEC_CONF ${OSSEC_CONF}.bak.$(date +%s)

# Tambahkan localfile Suricata eve.json ke ossec.conf jika belum ada
if ! sudo grep -q "$EVE_JSON_PATH" $OSSEC_CONF; then
  sudo sed -i "/<\/ossec_config>/i \  <localfile>\n    <log_format>json</log_format>\n    <location>$EVE_JSON_PATH</location>\n  </localfile>" $OSSEC_CONF
fi

sudo systemctl restart wazuh-agent
sudo systemctl status wazuh-agent --no-pager

echo ""
echo "===== DONE! ====="
echo "Suricata dan Wazuh berhasil terinstall & terintegrasi."
echo ""
echo "File backup config tersedia dengan ekstensi .bak.TIMESTAMP"
echo ""
