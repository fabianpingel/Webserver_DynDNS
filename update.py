#!/usr/bin/env python3

import os
import sys
import re
from datetime import datetime
from typing import List, Optional
import CloudFlare
from dotenv import load_dotenv

LOG_FILE_PATH = "/opt/scripts/dyndns/update.py.log"

# Lade die Umgebungsvariablen aus der .env-Datei
load_dotenv()

# Lese den Cloudflare API-Token
CLOUDFLARE_API_TOKEN = os.getenv('CLOUDFLARE_API_TOKEN')

# Sicherstellen, dass der Token korrekt geladen wurde
if CLOUDFLARE_API_TOKEN is None:
    print("Fehler: Der Cloudflare API-Token ist nicht gesetzt!")
    exit(1)


def load_api_token(zone_name: str) -> Optional[str]:
    """
    Loads the Cloudflare API token from the .env file or environment variables.
    :param zone_name: The name of the DNS zone.
    :return: The API token or None if not found.
    """
    env_var_name = f"CLOUDFLARE_TOKEN_{zone_name.replace('.', '_').upper()}"
    return os.getenv(env_var_name)

# Test: Zugriff auf den Token
print(load_api_token("pingel-ai-solutions.de"))

def file_log(msg: str) -> None:
    """
    Logs a message to a predefined log file with a timestamp.
    :param msg: The message to log.
    """
    with open(LOG_FILE_PATH, "a") as log_file:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_file.write(f"{timestamp} - {msg}\n")

def validate_ip(ip: str) -> bool:
    """
    Validates if the given string is a valid IPv4 address.
    :param ip: The IP address to validate.
    :return: True if valid, False otherwise.
    """
    ip_pattern = r"^(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])){3}$"
    return re.match(ip_pattern, ip) is not None

def get_zone(cf: CloudFlare.CloudFlare, zone_name: str) -> dict:
    """
    Fetches the zone information from Cloudflare for the given zone name.
    :param cf: CloudFlare API client.
    :param zone_name: The name of the DNS zone.
    :return: Zone information as a dictionary.
    :raises: Exception if the zone is not found or the API call fails.
    """
    try:
        zones = cf.zones.get(params={'name': zone_name})
        if len(zones) != 1:
            raise ValueError(f"Zone lookup returned {len(zones)} results for {zone_name}.")
        return zones[0]
    except CloudFlare.exceptions.CloudFlareAPIError as e:
        raise RuntimeError(f"CloudFlare API error while fetching zone '{zone_name}': {e}")
    except Exception as e:
        raise RuntimeError(f"Error fetching zone '{zone_name}': {e}")

def update_dns_records(cf: CloudFlare.CloudFlare, zone_id: str, ip_address: str) -> None:
    """
    Updates all DNS A records in the given zone to the specified IP address.
    :param cf: CloudFlare API client.
    :param zone_id: The ID of the DNS zone.
    :param ip_address: The new IP address to set for A records.
    """
    try:
        dns_records = cf.zones.dns_records.get(zone_id, params={'type': 'A'})
    except CloudFlare.exceptions.CloudFlareAPIError as e:
        raise RuntimeError(f"CloudFlare API error while fetching DNS records: {e}")

    for record in dns_records:
        if record['content'] == ip_address:
            file_log(f"UNCHANGED: {record['name']} already points to {ip_address}.")
            continue

        updated_record = {
            'type': 'A',
            'name': record['name'],
            'content': ip_address,
            'proxied': record.get('proxied', False)
        }

        try:
            cf.zones.dns_records.put(zone_id, record['id'], data=updated_record)
            file_log(f"UPDATED: {record['name']} -> {ip_address}.")
        except CloudFlare.exceptions.CloudFlareAPIError as e:
            file_log(f"ERROR: Failed to update {record['name']} - {e}.")

def load_api_token(zone_name: str) -> Optional[str]:
    """
    Loads the Cloudflare API token from environment variables based on the zone name.
    :param zone_name: The name of the DNS zone.
    :return: The API token or None if not found.
    """
    env_var_name = f"CLOUDFLARE_TOKEN_{zone_name.replace('.', '_').upper()}"
    return os.environ.get(env_var_name)

def main() -> None:
    """
    Main function to update Cloudflare DNS records based on command-line arguments.
    """
    if len(sys.argv) != 5:
        sys.stderr.write("Usage: update.py <username> <password> <domain> <ip_address>\n")
        file_log("ERROR: Incorrect number of arguments.")
        sys.exit(1)

    username, password, domain, ip_address = sys.argv[1:5]

    # Validate the IP address
    if not validate_ip(ip_address):
        file_log(f"ERROR: Invalid IP address: {ip_address}")
        sys.stderr.write(f"ERROR: Invalid IP address: {ip_address}\n")
        sys.exit(1)

    # Load the API token for the domain
    api_token = load_api_token(domain)
    if not api_token:
        file_log(f"ERROR: API token not found for domain {domain}.")
        sys.stderr.write(f"ERROR: API token not found for domain {domain}.\n")
        sys.exit(1)

    cf = CloudFlare.CloudFlare(token=api_token)

    try:
        file_log(f"STARTING UPDATE: {domain}")
        zone = get_zone(cf, domain)
        update_dns_records(cf, zone['id'], ip_address)
        file_log(f"COMPLETED UPDATE: {domain}")
    except Exception as e:
        file_log(f"ERROR: {e}")
        sys.stderr.write(f"ERROR: {e}\n")
        sys.exit(1)

    file_log("==============================================================")
    sys.exit(0)

if __name__ == '__main__':
    main()
