## Setup scripts für Forticlient VPN

* Verwendung des FortiClient Configuration Tools - verfügbar nach Installation von FortiClient VPN
* Config Files -> xml

### export_vpn_settings.sh

* Exportiert und speichert die Config File des FortiClient VPN im Download Folder des aktuellen Benutzers. (erst sinnvoll nach dem Einrichten, da die Config File ansonsten leer ist)


### import_vpn_settings.sh
* Liest eine vorhandene Config Datei aus und Importiert die VPN Einstellungen in den FortiClient VPN.
* benötigt zum Ausführen Adminrechte (sudo)
* FortiClient Prozesse müssen zum Ausführen nicht zwangsläufig gestoppt werden

### vpn_full_setup.sh
* für einheitliches Setup von FortiClient VPN
* Variablen in Skript definiert
* Skript kopiert die aktuelle Config Datei des Clients und ergänzt diese um die angegebene Verbindung und die zugehörigen Optionen.
* benötigte Files werden im /tmp Ordner gespeichert


