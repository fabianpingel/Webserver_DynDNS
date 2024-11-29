#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# === Variablen === 
DOMAIN="meine-domain.de"			# muss angepasst werden
FRITZBOX_IP_ADDRESS="192.168.178.1"	# muss angepasst werden
WEBROOT="/var/www/${DOMAIN}"
NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}.conf"
PYTHON_SCRIPT_DIR="/opt/scripts/dyndns"
PYTHON_LOG_FILE="${PYTHON_SCRIPT_DIR}/update.py.log"
ENV_FILE="${PYTHON_SCRIPT_DIR}/.env"

echo "=== Installation von NGINX Webserver/Reverse Proxy und PHP ==="
sudo apt update && sudo apt install -y nginx php8.2-fpm
if [[ $? -eq 0 ]]; then
    echo "NGINX und PHP erfolgreich installiert."
else
    echo "Fehler: Installation von NGINX oder PHP fehlgeschlagen!" >&2
    exit 1
fi

echo "=== Webroot erstellen ==="
sudo mkdir -p "${WEBROOT}"
if [[ -d "${WEBROOT}" ]]; then
    echo "Webroot (${WEBROOT}) erfolgreich erstellt."
else
    echo "Fehler: Webroot konnte nicht erstellt werden!" >&2
    exit 1
fi

echo "=== Default Webroot Index-Datei kopieren ==="
sudo cp /var/www/html/index.nginx-debian.html "${WEBROOT}/"
if [[ -f "${WEBROOT}/index.nginx-debian.html" ]]; then
    echo "Index-Datei erfolgreich kopiert."
else
    echo "Fehler: Index-Datei konnte nicht kopiert werden!" >&2
    exit 1
fi

echo "=== Default NGINX-Konfiguration deaktivieren ==="
sudo rm -f /etc/nginx/sites-enabled/default
if [[ ! -L "/etc/nginx/sites-enabled/default" ]]; then
    echo "Default NGINX-Konfiguration erfolgreich deaktiviert."
else
    echo "Fehler: Default NGINX-Konfiguration konnte nicht deaktiviert werden!" >&2
    exit 1
fi

# === Konfiguration der NGINX-Site erstellen ===
echo "=== NGINX Site Configuration erstellen ==="

# NGINX-Konfiguration für die Domain
NGINX_CONF_FILE="/etc/nginx/sites-available/${DOMAIN}.conf"

# Erstelle die NGINX-Konfiguration mit den angegebenen Variablen
cat > "${NGINX_CONF_FILE}" <<EOL
server {
    listen 80 default;
    server_name _;
    root /var/www/${DOMAIN}/;
    index index.html index.htm index.nginx-debian.html;

    location = /dyndns.php {
        access_log          /var/log/nginx/dyndns_access.log;
        error_log           /var/log/nginx/dyndns_error.log warn;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        include      snippets/fastcgi-php.conf;
        allow ${FRITZBOX_IP_ADDRESS}/32;
        deny all;
    }
    
    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files \$uri \$uri/ =404;
    }
}
EOL

if [[ -f "${NGINX_CONF_FILE}" ]]; then
    echo "NGINX-Konfigurationsdatei erfolgreich erstellt: ${NGINX_CONF_FILE}"
else
    echo "Fehler: NGINX-Konfigurationsdatei konnte nicht erstellt werden!" >&2
    exit 1
fi

# Symlink für die Konfiguration erstellen
echo "=== NGINX Konfiguration aktivieren ==="
sudo ln -s "${NGINX_CONF_FILE}" "/etc/nginx/sites-enabled/"
if [[ -L "/etc/nginx/sites-enabled/${DOMAIN}.conf" ]]; then
    echo "NGINX-Konfiguration erfolgreich aktiviert."
else
    echo "Fehler: NGINX-Konfiguration konnte nicht aktiviert werden!" >&2
    exit 1
fi

echo "=== NGINX-Konfiguration testen und neu laden ==="
sudo nginx -t && sudo nginx -s reload
if [[ $? -eq 0 ]]; then
    echo "NGINX-Konfiguration erfolgreich getestet und neu geladen."
else
    echo "Fehler: Test oder Reload der NGINX-Konfiguration fehlgeschlagen!" >&2
    exit 1
fi

echo "=== PHP-Skript kopieren ==="
sudo cp dyndns.php "${WEBROOT}/"
if [[ -f "${WEBROOT}/dyndns.php" ]]; then
    echo "PHP-Skript erfolgreich kopiert."
else
    echo "Fehler: PHP-Skript konnte nicht kopiert werden!" >&2
    exit 1
fi

echo "=== Cloudflare Python-Bibliothek installieren ==="
pip3 install cloudflare
if [[ $? -eq 0 ]]; then
    echo "Cloudflare Python-Bibliothek erfolgreich installiert."
else
    echo "Fehler: Installation der Cloudflare Python-Bibliothek fehlgeschlagen!" >&2
    exit 1
fi

echo "=== Ordner für das Python-Skript erstellen ==="
sudo mkdir -p "${PYTHON_SCRIPT_DIR}"
if [[ -d "${PYTHON_SCRIPT_DIR}" ]]; then
    echo "Ordner für Python-Skript erfolgreich erstellt."
else
    echo "Fehler: Ordner konnte nicht erstellt werden!" >&2
    exit 1
fi

echo "=== Python-Skript kopieren und Log-Datei erstellen ==="
sudo cp update.py "${PYTHON_SCRIPT_DIR}/"
sudo touch "${PYTHON_LOG_FILE}"
if [[ -f "${PYTHON_SCRIPT_DIR}/update.py" && -f "${PYTHON_LOG_FILE}" ]]; then
    echo "Python-Skript und Log-Datei erfolgreich eingerichtet."
else
    echo "Fehler: Python-Skript oder Log-Datei konnte nicht erstellt werden!" >&2
    exit 1
fi

echo "=== Berechtigungen setzen ==="
sudo chown -R $(whoami):www-data "${PYTHON_SCRIPT_DIR}"
if [[ $? -eq 0 ]]; then
    echo "Berechtigungen erfolgreich gesetzt."
else
    echo "Fehler: Berechtigungen konnten nicht gesetzt werden!" >&2
    exit 1
fi

echo "=== python-dotenv Python-Bibliothek installieren ==="
pip3 install python-dotenv
if [[ $? -eq 0 ]]; then
    echo "python-dotenv Python-Bibliothek erfolgreich installiert."
else
    echo "Fehler: Installation der python-dotenv Python-Bibliothek fehlgeschlagen!" >&2
    exit 1
fi

echo "=== Überprüfen und Erstellen der .env Datei ==="
# Prüfen, ob die .env Datei existiert
if [[ ! -f "$ENV_FILE" ]]; then
    echo ".env Datei existiert nicht, erstelle sie jetzt..."
    
    # .env Datei mit dem Cloudflare API Token füllen
    echo "CLOUDFLARE_API_TOKEN=dein_cloudflare_token" > "$ENV_FILE"
    
    if [[ $? -eq 0 ]]; then
        echo ".env Datei erfolgreich erstellt und mit Cloudflare API Token gefüllt."
    else
        echo "Fehler: .env Datei konnte nicht erstellt werden!" >&2
        exit 1
    fi
else
    echo ".env Datei existiert bereits."
    
    # Öffnen der .env Datei, um den Token zu überprüfen und zu setzen
    echo "=== Öffne .env Datei zur Überprüfung des Tokens ==="
    sudo nano "$ENV_FILE"
    
    # Hinweis: Hier könnte auch eine weitere Automatisierung erfolgen, aber momentan wird der Benutzer gebeten, manuell zu prüfen
fi

echo "=== Skript abgeschlossen ==="
