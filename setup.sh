#!/bin/bash

# Sofortiges Beenden, wenn ein Befehl fehlschlägt
set -e

# Überprüfen, ob dpkg korrekt arbeitet
if ! sudo dpkg --configure -a >/dev/null 2>&1; then
    echo "Fehler: dpkg ist blockiert. Bitte führen Sie 'sudo dpkg --configure -a' manuell aus und starten Sie das Skript neu."
    exit 1
fi

# === Prüfen auf Domain-Eingabe ===
if [ -z "$1" ]; then
    echo "Fehler: Bitte geben Sie eine Domain als ersten Parameter an."
    echo "Beispiel: $0 meine-domain.de"
    exit 1
fi

# === Variablen ===
DOMAIN="$1"                                   # Muss bei Aufruf eingegeben werden
FRITZBOX_IP_ADDRESS="192.168.178.1"           # Werkseinstellung FRITZ!Box, muss ggf. angepasst werden
WEBROOT="/var/www/${DOMAIN}"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"
SYMLINK_PATH="/etc/nginx/sites-enabled/${DOMAIN}.conf"
PYTHON_SCRIPT_DIR="/opt/scripts/dyndns"
PYTHON_LOG_FILE="${PYTHON_SCRIPT_DIR}/update.py.log"
ENV_FILE="${PYTHON_SCRIPT_DIR}/.env"

# === Funktionen ===
# Funktion zum Exit bei Fehler
function handle_error {
    echo "Fehler: $1" >&2
    exit 1
}

# === Funktionen ===
# Prüfen, ob ein Paket installiert ist, und es bei Bedarf installieren
function check_and_install {
    local package="$1"
    echo "=== Prüfe, ob ${package} installiert ist ==="
    if ! dpkg -l | grep -qw "${package}"; then
        echo "${package} ist nicht installiert. Installation wird durchgeführt..."
        sudo apt update && sudo apt install -y "${package}" || handle_error "Installation von ${package} fehlgeschlagen"
    else
        echo "${package} ist bereits installiert."
    fi
}

# === Installation von erforderlichen Tools ===
check_and_install nano
check_and_install curl


# Installation von Software
function install_software {
    echo "=== Installation von $1 ==="
    sudo apt update && sudo apt install -y "$1" || handle_error "Installation von $1 fehlgeschlagen"
}

# === Installationen ===
echo "=== Installation von NGINX und PHP ==="
sudo add-apt-repository ppa:ondrej/php -y
install_software nginx
install_software php8.2-fpm

# === Webroot und Basisdateien ===
echo "=== Webroot erstellen ==="
sudo mkdir -p "${WEBROOT}" || handle_error "Webroot konnte nicht erstellt werden"
echo "=== Default Webroot Index-Datei kopieren ==="
sudo cp /var/www/html/index.nginx-debian.html "${WEBROOT}/" || handle_error "Index-Datei konnte nicht kopiert werden"

# === NGINX Konfiguration ===
echo "=== Default NGINX-Konfiguration deaktivieren ==="
sudo rm -f /etc/nginx/sites-enabled/default || handle_error "Default NGINX-Konfiguration konnte nicht deaktiviert werden"

echo "=== NGINX Site Configuration erstellen ==="
cat <<EOL | sudo tee "${NGINX_CONF}" > /dev/null
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/${DOMAIN}/;
    index index.html index.htm index.nginx-debian.html;

    location = /dyndns.php {
        access_log /var/log/nginx/dyndns_access.log;
        error_log /var/log/nginx/dyndns_error.log warn;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        include snippets/fastcgi-php.conf;
        allow ${FRITZBOX_IP_ADDRESS}/32;
        deny all;
    }
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOL

echo "=== NGINX Konfiguration aktivieren ==="
sudo ln -sf "${NGINX_CONF}" "${SYMLINK_PATH}" || handle_error "Symbolischer Link konnte nicht erstellt werden"

echo "=== NGINX-Konfiguration testen und neu laden ==="
sudo nginx -t && sudo systemctl reload nginx || handle_error "NGINX-Test oder Reload fehlgeschlagen"

# === PHP Skript einrichten ===
echo "=== PHP-Skript kopieren ==="
sudo cp dyndns.php "${WEBROOT}/" || handle_error "PHP-Skript konnte nicht kopiert werden"

# === Python Skript Setup ===
echo "=== Python-Skript und Abhängigkeiten einrichten ==="
sudo mkdir -p "${PYTHON_SCRIPT_DIR}" || handle_error "Ordner für Python-Skript konnte nicht erstellt werden"
sudo cp update.py "${PYTHON_SCRIPT_DIR}/" || handle_error "Python-Skript konnte nicht kopiert werden"
sudo touch "${PYTHON_LOG_FILE}" || handle_error "Log-Datei konnte nicht erstellt werden"
sudo chown -R "$(whoami):www-data" "${PYTHON_SCRIPT_DIR}" || handle_error "Berechtigungen konnten nicht gesetzt werden"

# === Python Bibliotheken ===
echo "=== Python-Bibliotheken installieren ==="
pip3 install cloudflare python-dotenv || handle_error "Python-Bibliotheken konnten nicht installiert werden"

# === .env Datei ===
echo "=== .env Datei überprüfen/erstellen ==="
if [[ ! -f "${ENV_FILE}" ]]; then
    cat <<EOL | sudo tee "${ENV_FILE}" > /dev/null
API_TOKEN=dein_cloudflare_api_token
ZONE_ID=deine_zonen_id
EOL
    echo ".env Datei wurde erstellt. Bitte die Werte anpassen."
    sudo nano "${ENV_FILE}"
else
    echo ".env Datei existiert bereits. Öffne zur Überprüfung."
    sudo nano "${ENV_FILE}"
fi

# === Abschluss ===
echo "=== Installation abgeschlossen ==="
