# Changelog

Alle nennenswerten Änderungen an BananaCraft. Neueste Version oben.

## Unveröffentlicht

- **Neu: Alts des Accounts.** „Datenbank mit der Gilde teilen" nimmt jetzt auch die Berufe aller anderen Charaktere deines Accounts mit (die Daten liegen schon account-weit in `BananaCraftDB`; der Alt muss einmal mit dem Addon eingeloggt gewesen sein und seine Berufsfenster geöffnet haben). Sie erscheinen in der Gilde als Mitglied mit dem Zusatz „Alt von <Charakter>", unabhängig davon, ob der Alt in einer anderen Gilde oder gildenlos ist. Ist der Alt offline, aber der Besitzer online, gilt er als erreichbar und der Whisper geht an den Besitzer. Alts anderer Realms werden nicht geteilt. Im Einstellungsfenster lässt sich jeder Alt abwählen („Haken = wird geteilt"). Ohne Gilde werden keine Alts veröffentlicht.
- **Fix: Rezepte unter „UNKNOWN".** Öffnete man ein Berufsfenster, bevor das Spiel den Berufsnamen geladen hatte, lieferte es den Platzhalter `UNKNOWN`, und die Rezepte landeten unter diesem Beruf (Anzeige „UNKNOWN 0/0"). Der Scan wartet jetzt und versucht es erneut, eingehende Daten mit diesem Beruf werden verworfen. Vorhandene Einträge repariert der Addon beim Start anhand seiner Rezeptdatenbank (7 Berufe). Rezepte anderer Berufe (Kochen, Erste Hilfe) unter UNKNOWN werden gelöscht und beim nächsten Öffnen des Berufsfensters neu gescannt.
- **Neu: Haken „Nur online"** über der Liste.
- **Neu: Einstellungsfenster (Zahnrad)** mit Sprache, Nur-online, Minimap-Button, Debug, Berufe neu scannen, Alles senden, Abgleich, CSV-Export, Bank scannen, Versionen prüfen und Löschen (mit Rückfrage). Die `/bc`-Befehle bleiben.
- **Partnermodus ist nach jedem Login aus** und wird nur per `/bc partner on` (oder `create`/`add`) eingeschaltet. Das Hauptfenster hat nur noch den Button „Datenbank mit der Gilde teilen". Der Partner-Bereich (Code erstellen, Mit Code verbinden, An Partner teilen, Gildenmitglieder verbinden, Modus ausschalten) steht im Einstellungsfenster und ist nur sichtbar, solange der Modus an ist. Bei ausgeschaltetem Modus werden Codes anderer ignoriert, und nach dem Login wird nicht mehr automatisch nach einem Code gefragt.
- **Fix: Beruf löschen** entfernt jetzt auch den Eintrag in der Gildenliste (`Name@Gilde`).
- **Partnerkanal getrennt vom Gilden-Sync.** „Datenbank mit der Gilde teilen" sendet nur noch in den Gildenkanal. Der Partner-Sync (`/bc partner share` oder Einstellungsfenster) sendet nur eigene Daten und nur auf Knopfdruck, eigene Scans gehen nicht mehr automatisch an den Partner. `/bc partner off` beendet die Partnerschaft nicht mehr (dafür `/bc partner leave`).
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
