# Changelog

Alle nennenswerten Änderungen an BananaCraft. Neueste Version oben.

## 2.2.1

- **Neuer Name: BananaCraft** (vorher BananaRepublik Partnerguild). Addon-Ordner, alle Dateien, Fenstertitel, Minimap-Tooltip und Logo-Dateien heißen jetzt BananaCraft. Auch intern ist alles umbenannt: Befehl `/bc` (statt `/brpp`), gespeicherte Daten `BananaCraftDB`, Netzwerkprefix `BCRAFT0`, Funktionen `BCRAFT_*`. Da das Addon noch nicht veröffentlicht war, gibt es keine Übernahme alter Daten und keine Kompatibilität zu Testständen der alten Version. Den alten Ordner `BananaRepublik_Partnerguild` löschen.
- **Testdaten entfernt.** `BananaRepublik_Partnerguild_TestData.lua` und der Befehl `/brpptest` sind weg, die Tests waren erfolgreich. Reste aus früheren Testläufen werden beim ersten Start automatisch aus der Datenbank gelöscht.
- **Versionsnummer angeglichen.** `.toc`, Addon-Code (`/bc versioncheck`) und Changelog nennen jetzt alle 2.2.1.
- **Fix: Unterkategorie-Dropdown.** Beim Berufswechsel wurde das Dropdown mit `nil` initialisiert.
- **Fix: Oberfläche nach „Datenbank löschen".** Das Fenster wurde nicht neu gezeichnet, weil der Code den nicht vorhandenen Frame `BCRAFT_Frame` prüfte statt `BRPP_MainFrame`.
- **Neues Logo** oben links im Fenster und als Minimap-Button.
- Repository wie die anderen BananaForge-Addons aufgebaut: README, MIT-Lizenz, Release-Workflow.

## 2.0.0

- Partnergilden-Kommunikation über Einladecode.
- Gildenbewusste Datenbankschlüssel (`Charname@Gilde`).
- Partnergilden-Markierung in der Oberfläche.
