# Webserver_DynDNS

## 1. Klonen des GitHub-Verzeichnisses
```
git clone https://github.com/fabianpingel/Webserver_DynDNS.git Webserver_DynDNS
```
## 2. Skript *setup.sh* ausführen
```
chmod +x setup.sh && sudo ./setup.sh
```
## 3. Einfügen des ```CLOUDFLARE_API_TOKEN```
3.1. Erstellen der ```.env```-Datei:
```
touch /opt/scripts/dyndns/.env
```
3.2 Öffnen der ```.env```-Datei mit einem Texteditor (z.B. nano)
```
nano /opt/scripts/dyndns/.env
```
3.3 API-Token einfügen
```
CLOUDFLARE_API_TOKEN=dein_cloudflare_token
```



