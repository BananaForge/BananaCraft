# Changelog

Alle nennenswerten Änderungen an BananaCraft. Neueste Version oben.

## Unveröffentlicht

- **Partnerkanal ist optional und vom Gilden-Sync getrennt.** „Datenbank mit der Gilde teilen" sendet nur noch in den Gildenkanal und fasst die Partnerschaft nie an. Ohne Partnercode zeigt das Fenster nur diesen einen Button. Mit Code gibt es den Schalter *Partner: AN/AUS* (Kanal schließen und öffnen, Code und Partnerdaten bleiben) und, solange er an ist, *An Partner teilen* und *Gildenmitglieder verbinden*. Neue Befehle: `/bc partner on`, `off` und `share`. `/bc partner off` beendet die Partnerschaft nicht mehr (dafür gibt es weiter `/bc partner leave`). Eigene Scans gehen nicht mehr automatisch an den Partner, nur über *An Partner teilen*.
- **Fix: „Alle Berufe wurden gesendet!" kam zu früh.** Die Meldung erscheint jetzt erst, wenn auch die Sendewarteschlangen (Gilde und Partnerkanal) leer sind. Der Partnerkanal sendet zusätzlich langsamer (1 Nachricht alle 1,5 Sekunden), weil der Server bei schnellerem Tempo weiter „You must wait N seconds before speaking again" meldete.
- **Fix: Versionsanzeige im Fenster.** Links unten stand fest `v1.0.0`, jetzt wird die echte Version (`ADDON_VERSION`) angezeigt.
- **Fix: „You must wait N seconds before speaking again" beim Teilen.** Der Partnerkanal lief mit 2,5 Nachrichten/Sekunde in den Chat-Spamschutz des Servers. Er sendet jetzt höchstens 1 Nachricht/Sekunde. Meldet der Server trotzdem die Sperre, pausiert die Warteschlange für die genannte Zeit und sendet die verworfene Nachricht danach erneut.
- **Fix: Esc schließt BananaCraft.** Hauptfenster, Rezept-Popup und Export-Fenster sind jetzt in `UISpecialFrames` eingetragen.
- **Fix: Eigener Charakter doppelt in der Crafter-Liste.** Wer vor dem Gildenbeitritt gildenlos war, stand als `<no guild (Name)>` (nicht erreichbar) zusätzlich zum echten Eintrag in der Liste. Solche veralteten Solo-Einträge werden jetzt beim Start entfernt, sobald die Gilde bekannt ist.

## 2.2.1

- **Neuer Name: BananaCraft** (vorher BananaRepublik Partnerguild). Addon-Ordner, alle Dateien, Fenstertitel, Minimap-Tooltip und Logo-Dateien heißen jetzt BananaCraft. Auch intern ist alles umbenannt: Befehl `/bc` (statt `/brpp`), gespeicherte Daten `BananaCraftDB`, Netzwerkprefix `BCRAFT0`, Funktionen `BCRAFT_*`. Da das Addon noch nicht veröffentlicht war, gibt es keine Übernahme alter Daten und keine Kompatibilität zu Testständen der alten Version. Den alten Ordner `BananaRepublik_Partnerguild` löschen.
- **Testdaten entfernt.** `BananaRepublik_Partnerguild_TestData.lua` und der Befehl `/brpptest` sind weg, die Tests waren erfolgreich. Reste aus früheren Testläufen werden beim ersten Start automatisch aus der Datenbank gelöscht.
- **Versionsnummer angeglichen.** `.toc`, Addon-Code (`/bc versioncheck`) und Changelog nennen jetzt alle 2.2.1.
- **Fix: Unterkategorie-Dropdown.** Beim Berufswechsel wurde das Dropdown mit `nil` initialisiert.
- **Fix: Oberfläche nach „Datenbank löschen".** Das Fenster wurde nicht neu gezeichnet, weil der Code den nicht vorhandenen Frame `BCRAFT_Frame` prüfte statt `BRPP_MainFrame`.
- **Fix: Minimap-Button ohne Bild.** Der Button wird jetzt komplett in Lua gebaut (ein Button mit Icon und Rahmen) statt per XML mit Frame und Kind-Button, wie bei den anderen BananaForge-Addons. Die XML-Datei entfällt. UI-Addons wie pfUI räumten die alte Bauweise leer.
- **Neues Logo** oben links im Fenster und als Minimap-Button.
- Repository wie die anderen BananaForge-Addons aufgebaut: README, MIT-Lizenz, Release-Workflow.

## 2.0.0

- Partnergilden-Kommunikation über Einladecode.
- Gildenbewusste Datenbankschlüssel (`Charname@Gilde`).
- Partnergilden-Markierung in der Oberfläche.
