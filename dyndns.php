<?php

    // Pfad zum Python-Skript
    $scriptPath = "/opt/scripts/dyndns/update.py";

    // Überprüfen, ob das Python-Skript existiert
    if (!file_exists($scriptPath)) {
        die("Fehler: Das Skript '$scriptPath' wurde nicht gefunden.");
    }

    // Nur POST-Anfragen erlauben, um sensible Daten sicher zu übermitteln
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        die("Fehler: Nur POST-Anfragen sind erlaubt.");
    }

    // Funktion zur Validierung einer Domain
    function validateDomain($domain) {
        return preg_match('/^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/', $domain);
    }

    // Funktion zur Validierung einer IP-Adresse
    function validateIP($ip) {
        return filter_var($ip, FILTER_VALIDATE_IP);
    }

    // Eingabeparameter lesen und validieren
    $domain = isset($_POST['domain']) ? htmlspecialchars($_POST['domain']) : null;
    $username = isset($_POST['username']) ? htmlspecialchars($_POST['username']) : null;
    $password = isset($_POST['password']) ? htmlspecialchars($_POST['password']) : null;
    $ipaddress = isset($_POST['ip']) ? htmlspecialchars($_POST['ip']) : null;

    // Überprüfung der Pflichtfelder
    if (!$domain || !$username || !$password || !$ipaddress) {
        die("Fehler: Alle Felder (domain, username, password, ip) sind erforderlich.");
    }

    // Validierung der Eingaben
    if (!validateDomain($domain)) {
        die("Fehler: Ungültige Domain.");
    }
    if (!validateIP($ipaddress)) {
        die("Fehler: Ungültige IP-Adresse.");
    }

    // Sicherheitsmaßnahmen: Shell-Injektionen verhindern
    $domain = escapeshellarg($domain);
    $username = escapeshellarg($username);
    $password = escapeshellarg($password);
    $ipaddress = escapeshellarg($ipaddress);

    // Debugging-Befehl zur Sicherheit auskommentiert (nur für Testzwecke verwenden)
    // echo $scriptPath . " ${username} ${password} ${domain} ${ipaddress} </br>";

    // Python-Skript ausführen
    $output = [];
    $retval = null;

    // try-catch-ähnliche Fehlerbehandlung für die Ausführung
    try {
        $result = exec("$scriptPath $username $password $domain $ipaddress", $output, $retval);

        // Ergebnisse ausgeben
        echo "Result: " . htmlspecialchars($result) . " </br>";
        echo "Retval: " . htmlspecialchars($retval) . " </br>";
        echo "Output: <pre>" . htmlspecialchars(print_r($output, true)) . "</pre>";
    } catch (Exception $e) {
        // Fehler behandeln
        die("Fehler bei der Ausführung des Skripts: " . htmlspecialchars($e->getMessage()));
    }

?>
