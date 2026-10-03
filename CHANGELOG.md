# Changelog

Alle nennenswerten Änderungen an BananaRepublik Partnerguild. Neueste Version oben.

## 2.2.1

- **Testdaten entfernt.** `BananaRepublik_Partnerguild_TestData.lua` und der Befehl `/brpptest` sind weg, die Tests waren erfolgreich. Reste aus früheren Testläufen werden beim ersten Start automatisch aus der Datenbank gelöscht.
- **Versionsnummer angeglichen.** `.toc`, Addon-Code (`/brpp versioncheck`) und Changelog nennen jetzt alle 2.2.1.
- **Fix: Unterkategorie-Dropdown.** Beim Berufswechsel wurde das Dropdown mit `nil` initialisiert.
- **Fix: Oberfläche nach „Datenbank löschen".** Das Fenster wurde nicht neu gezeichnet, weil der Code den nicht vorhandenen Frame `BRPP_Frame` prüfte statt `BRPP_MainFrame`.
- **Neues Logo** oben links im Fenster und als Minimap-Button.
- Repository wie die anderen BananaForge-Addons aufgebaut: README, MIT-Lizenz, Release-Workflow.

## 2.0.0

- Partnergilden-Kommunikation über Einladecode.
- Gildenbewusste Datenbankschlüssel (`Charname@Gilde`).
- Partnergilden-Markierung in der Oberfläche.
