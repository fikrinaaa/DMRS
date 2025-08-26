# Wazuh IaC untuk Kali Linux Target
# ======================
# Atur Permission: chmod +x setup_agent.sh
# Jalankan: sudo ./setup_agent.sh


echo "-----------------------------------------"
echo "     WAZUH  INSTALLATION AUTOMATION      "
echo "-----------------------------------------"


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
