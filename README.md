# 🍌 BananaCraft TEST (Beta)

**Testversion von BananaCraft mit Rezeptkatalog: Beruf → Stufe/Kategorie → Rezept, mit Tooltips und Qualitätsfarben.**

Diese Version läuft **neben** dem normalen BananaCraft. Sie hat einen eigenen Ordner (`BananaCraftTest`), einen eigenen Befehl (`/bct`), eigene gespeicherte Daten (`BananaCraftTestDB`) und ein eigenes Nachrichten-Prefix (`BCT0`). Beide Versionen können gleichzeitig installiert sein, ohne sich zu stören. Die Testversion spricht nur mit anderen Testversionen.

## Neu in dieser Testversion

- **Rezeptkatalog:** links der Beruf (Alchemie, Verzauberkunst, Ingenieurskunst, Lederverarbeitung, Schmiedekunst, Schneiderei, Juwelenschleifen, Kräuterkunde, Bergbau, Kochen, Erste Hilfe, Survival, Gardening, Gifte, Epische Waffen), in der Mitte die Stufe (Apprentice, Journeyman, Expert, Artisan) und die Kategorien (Flasks, Protection Potions, Helm, Shoulders, Chest, … je nach Beruf), rechts die Rezepte.
- **Tooltips:** Mauszeiger auf ein Rezept zeigt den Item-Tooltip (bei Verzauberungen den Verzauberungs-Tooltip), dazu Fertigkeitsstufen (orange/gelb/grün/grau), Reagenzien, Zauberzeit, Werkzeug und **wer in der Gilde es herstellen kann**.
- **Qualitätsfarben:** weiß, grün, blau, lila (Name in der Liste und im Tooltip).
- **Suche nach dem Namen** bleibt: das Suchfeld durchsucht alle Berufe auf einmal. Shift+Klick auf ein Item oder eine Verzauberung schreibt den Namen ins Suchfeld.
- **Filter:** „Nur mit Crafter“ und „Nur online“. In der Testversion sind beide aus, damit alle Rezepte aller Berufe sichtbar sind.
- **Klick auf ein Rezept** öffnet die Detailansicht (Materialien, Hersteller, Whisper). **Rechtsklick** lädt ein Item, das dein Client noch nicht kennt, vom Server (danach zeigt der Tooltip den vollen Item-Text).
- Der Katalog ist das einzige Hauptfenster. Die alte Crafter-Liste gibt es in der Testversion nicht mehr; *Datenbank mit der Gilde teilen* sitzt unten rechts im Katalog.
- Alles Bisherige bleibt: Alts und Main, Export/Import, Einstellungen (Zahnrad).
- **Daten aus dem normalen BananaCraft übernehmen** (nur Testversion, siehe unten).

## Befehle

| Befehl | Wirkung |
|---|---|
| `/bct` | Katalog öffnen/schließen (auch Linksklick auf den Minimap-Button) |
| `/bct importlive` | Daten des normalen BananaCraft in die Testversion kopieren |
| `/bct scan`, `send`, `sync`, … | wie bei BananaCraft, nur mit `/bct` |

## Installation

1. Ordner `BananaCraftTest` nach `Interface/AddOns/` legen (der normale `BananaCraft`-Ordner kann bleiben).
2. Im Spiel `/bct` eingeben.

## Eigene Daten live ansehen

Die Testversion hat eine eigene Datenbank und beginnt leer. Um den Katalog mit deinen echten Crafter-Daten zu sehen:

1. In der Charakterauswahl **beide Addons** aktivieren (`BananaCraft` und `BananaCraftTest`).
2. Einloggen und `/bct importlive` eingeben, oder im Einstellungsfenster auf *Daten aus BananaCraft übernehmen* klicken.
3. Mit dem Haken *Beim Login übernehmen* geschieht das bei jedem Login automatisch.

Dabei wird nur **gelesen**: Das normale BananaCraft bleibt unverändert, und Änderungen in der Testversion gehen nicht zurück.

## Bitte testen

- Passt die Gliederung zu dem, was du erwartest? Fehlen Kategorien oder Rezepte?
- Zeigen die Tooltips etwas an? Bei welchen Rezepten bleibt er leer?
- Stimmen die Qualitätsfarben?
- Zeigen die Hersteller-Zahlen (rechts in der Liste) die richtigen Leute?

Rückmeldungen am besten mit Screenshot und dem Namen des Rezepts.

## Technisches

- Die Kategorien und Rezeptlisten liegen in `BananaCraftTest_Catalog.lua`. Sie wird mit `tools/gen_catalog.py` aus den AtlasLoot-Datenbankdateien erzeugt (`python3 -I tools/gen_catalog.py <AtlasLoot-Ordner> BananaCraftTest_Catalog.lua`).
- Hersteller kommen aus der normalen BananaCraft-Datenbank der Testversion (gescannte Berufe, Gilden-Sync, Alts). Wer die Testversion allein nutzt, sieht nur seine eigenen Rezepte als „Hersteller“.
- Lua 5.0 (WoW 1.12), keine Bibliotheken.
