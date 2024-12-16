#!/usr/bin/env python3

import os
import sys
import re
from datetime import datetime
import traceback
import cloudflare
from cloudflare import Cloudflare
from dotenv import load_dotenv

# Log-Datei Pfad
LOG_FILE_PATH = "/opt/scripts/dyndns/update.py.log"

# Lade die Umgebungsvariablen aus der .env-Datei
load_dotenv()

def file_log(msg: str) -> None:
    """
    Schreibt eine Lognachricht mit Zeitstempel in die vordefinierte Log-Datei.
    :param msg: Die zu loggende Nachricht.
    """
    try:
        with open(LOG_FILE_PATH, "a") as log_file:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            log_file.write(f"{timestamp} - {msg}\n")
    except IOError as e:
        sys.stderr.write(f"Log-Fehler: {e}\n")

def log_error(exception: Exception) -> None:
    """
    Protokolliert Fehler mit vollständigem Stacktrace.
    :param exception: Der aufgetretene Fehler.
    """
    with open(LOG_FILE_PATH, "a") as log_file:
        log_file.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - FEHLER: {exception}\n")
        log_file.write(traceback.format_exc() + "\n")

def validate_ip(ip: str) -> bool:
    """
    Validiert, ob die gegebene Zeichenkette eine gültige IPv4-Adresse ist.
    :param ip: Die zu überprüfende IP-Adresse.
    :return: True, wenn die IP-Adresse gültig ist, sonst False.
    """
    ip_pattern = r"^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$"
    return re.match(ip_pattern, ip) is not None

def load_env_variable(var_name: str) -> str:
    """
    Lädt eine Umgebungsvariable und prüft, ob sie gültig ist.
    :param var_name: Der Name der Umgebungsvariable.
    :return: Der Wert der Umgebungsvariable.
    :raises RuntimeError: Wenn die Variable nicht gesetzt ist.
    """
    value = os.environ.get(var_name)
    if not value:
        raise RuntimeError(f"Fehlende Umgebungsvariable: {var_name}")
    return value
        
def update_dns_records(cf: Cloudflare, zone_id: str, ip_address: str) -> bool:
    """
    Aktualisiert alle DNS-A-Records einer Zone mit der angegebenen IP-Adresse.
    :param cf: Cloudflare API-Client.
    :param zone_id: Die ID der DNS-Zone.
    :param ip_address: Die neue IP-Adresse für A-Records.
    :return: True, wenn mindestens ein Record aktualisiert wurde, False sonst.
    """
    updated_any = False
    try:
        dns_records = cf.dns.records.list(zone_id=zone_id)
    except cloudflare._exceptions.APIError as e:
        raise RuntimeError(f"Cloudflare API-Fehler bei der Abfrage von DNS-Records: {e}")

    for record in dns_records.result:
        if record.type != "A":
            continue  # Nur A-Records aktualisieren

        if record.content == ip_address:
            file_log(f"UNCHANGED: {record.name} zeigt bereits auf {ip_address}.")
            continue

        updated_record = {
            'zone_id': zone_id,
            'content': ip_address,
            'name': record.name,
            'type': record.type,
            'proxied': record.proxied
        }

        try:
            cf.dns.records.update(dns_record_id=record.id, **updated_record)
            file_log(f"UPDATED: {record.name} -> {ip_address}.")
            updated_any = True
        except cloudflare._exceptions.APIError as e:
            file_log(f"ERROR: Aktualisierung von {record.name} fehlgeschlagen - {e}.")
    return updated_any

def main() -> None:
    """
    Hauptfunktion zur Aktualisierung der Cloudflare DNS-Records.
    """
    if len(sys.argv) != 5:
        sys.stderr.write("Usage: update.py <username> <password> <domain> <ip_address>\n")
        file_log("ERROR: Falsche Anzahl von Argumenten.")
        sys.exit(1)

    username, password, domain, ip_address = sys.argv[1:5]

    # Validate the IP address
    if not ip_address or not validate_ip(ip_address):
        file_log(f"ERROR: Ungültige oder fehlende IP-Adresse: {ip_address}")
        sys.stderr.write(f"ERROR: Ungültige oder fehlende IP-Adresse: {ip_address}\n")
        sys.exit(1)

    try:
        # Lade notwendige Umgebungsvariablen
        API_TOKEN = load_env_variable("API_TOKEN")
        ZONE_ID = load_env_variable("ZONE_ID")
        
        cf = Cloudflare(api_token=API_TOKEN)

        file_log(f"STARTING UPDATE: {domain}")
        if update_dns_records(cf, ZONE_ID, ip_address):
            file_log(f"COMPLETED UPDATE: {domain}")
        else:
            file_log(f"NO CHANGES MADE: {domain}")
    except Exception as e:
        log_error(e)
        sys.stderr.write(f"ERROR: {e}\n")
        sys.exit(1)
    finally:
        file_log("==============================================================")
        sys.exit(0)

if __name__ == '__main__':
    main()

