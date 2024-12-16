# Webserver_DynDNS

## 1. Klonen des GitHub-Verzeichnisses
```
git clone https://github.com/fabianpingel/Webserver_DynDNS.git Webserver_DynDNS
```
## 2. Skript *setup.sh* ausführen
```
chmod +x setup.sh && sudo ./setup.sh <meine-domain.de>
```
## 3. Erstellen der ```Umgebungsvariablen```
3.1. Erstellen der ```.env```-Datei:
```
sudo touch /opt/scripts/dyndns/.env
```
3.2 Öffnen der ```.env```-Datei mit einem Texteditor (z.B. nano)
```
sudo nano /opt/scripts/dyndns/.env
```
3.3 Token einfügen
```
API_TOKEN=dein_cloudflare_token
```
```
ZONE_ID =deine_cloudflare_zonen_id
```
