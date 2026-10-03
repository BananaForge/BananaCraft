# BananaCraft — Technical Documentation

(Vormals BananaRepublik Partnerguild. Die internen Namen `BRPP_*`, `BRPPDB`, `BRPP0` und `/brpp` sind bewusst geblieben.)

Zweite Variante von BananaRepublicProfs mit Partnergilden-Unterstuetzung.

## Wichtig zuerst

Das ist ein **eigenstaendiges Addon**, kein Update. Es hat:
- eigene SavedVariables (`BRPPDB`) -- ruehrt `BRPDB` des Originals nicht an
- eigenen Netzwerkprefix (`BRPP0`) -- redet nicht mit dem Original-Addon
- eigener Befehl (`/brpp`)

Du kannst beide parallel installiert lassen. Sie stoeren sich nicht, teilen
aber auch keine Daten. Wenn beide laufen, hast du zwei Minimap-Buttons und
zwei Fenster -- zum Vergleichen praktisch, auf Dauer verwirrend.

## Die drei umgesetzten Punkte

### 1. DB-Migration auf Gildenschluessel

Der Schluessel in `db.guild` ist jetzt `"Charname@Gildenname"` statt nur
`"Charname"`. Dieselbe Zeichenkette geht auch ueber das Netz, damit Sender
und Empfaenger garantiert denselben Schluessel bilden.

Die Migration laeuft genau einmal (`db.schema = 2`):
- Alte Eintraege ohne `@` bekommen die eigene Gilde angehaengt. Das ist die
  einzig richtige Annahme -- vor dieser Version konnten ueberhaupt nur Daten
  aus der eigenen Gilde in der DB landen.
- Bei Namenskollision gewinnt der neuere Datensatz, nichts wird still
  weggeworfen.
- Bereits migrierte Eintraege bleiben unangetastet.

Getestet: 3 von 3 Eintraegen ueberleben, Fremdgilden-Eintrag unveraendert,
Kollision loest zugunsten des neueren Datensatzes auf.

### 2. Partnerkanal ueber Einladecode

**Technische Einschraenkung, die du kennen solltest:** WoW 1.12 kann
Addon-Nachrichten nur an die eigene Gilde schicken. `SendAddonMessage`
unterstuetzt dort kein `"CHANNEL"`. Der einzige Weg, der beide Gilden
erreicht, ist ein gemeinsamer Chat-Kanal.

Die Daten gehen also als normaler Kanaltext raus und werden per Hook auf
`ChatFrame_OnEvent` aus dem sichtbaren Chat gefiltert
(`ChatFrame_AddMessageEventFilter` gibt es in Vanilla noch nicht).

Der Code ist 12 Zeichen: die ersten 6 bilden den Kanalnamen, die letzten 6
das Passwort. Ein String reicht zum Teilen. Verwechselbare Zeichen (I, O, 0,
1) sind ausgeschlossen. Kleinschreibung, Leerzeichen und Bindestriche werden
beim Eingeben toleriert.

Der Partnerkanal hat eine **eigene, langsamere Drossel** (0,4s statt 0,1s
im Gildenkanal). Chat-Kanaele haengen am serverseitigen Spam-Schutz -- mit
Gildentempo faengst du dir zuverlaessig einen Mute oder Disconnect ein.

**Schleifenschutz:** Es werden nur eigene Daten in den Partnerkanal gesendet
(Schluessel endet auf die eigene Gilde). Ohne das wuerde jede empfangene
Nachricht erneut gesendet und beide Gilden zuspammen.

**Protokollaenderung:** Der Trenner zwischen Rezepten innerhalb eines Chunks
war `"\n"`. Ueber Addon-Nachrichten geht das, aber `SendChatMessage`
schneidet bei einem Zeilenumbruch ab. Er ist jetzt `"^"` -- druckbar, wird
vom Chat durchgereicht, kommt in Rezeptnamen und Icon-Pfaden nicht vor.
`safe()` entfernt das Zeichen zusaetzlich aus allen Nutzdaten.

### 3. UI-Kennzeichnung

Crafter aus der Partnergilde erscheinen mit `<Gildenname>` in Blau.

Ihr Online-Status wird bewusst **nicht** angezeigt, sondern als
"Partnergilde" markiert: sie stehen nicht in deinem Gildenroster, der Status
ist nicht ermittelbar, und ein vorgetaeuschtes "offline" waere irrefuehrend.

## Deine Punkte 3.1 bis 3.3

- **3.1 Rezeptsharing zur Partnergilde:** umgesetzt. Bankdaten gehen NICHT
  mit -- durch diesen Pfad laufen ausschliesslich Berufs- und Rezeptdaten.
- **3.2 Gildendaten rauswerfen:** `/brpp partner remove <Gilde>` loescht
  Rezeptdaten und Partnereintrag. `/brpp partner leave` beendet alles und
  entfernt saemtliche Fremddaten.
- **3.3 Code aenderbar:** `/brpp partner newcode` erzeugt einen neuen Code,
  verlaesst den alten Kanal und warnt, dass alle den neuen eintragen muessen.

## Befehle

```
/brpp partner                  Status + Hilfe
/brpp partner create           neuen Einladecode erzeugen
/brpp partner add <Code>       mit erhaltenem Code verbinden
/brpp partner push             Code an die eigene Gilde verteilen
/brpp partner code             aktuellen Code anzeigen
/brpp partner newcode          neuen Code erzeugen (alter wird ungueltig)
/brpp partner list             bekannte Partnergilden auflisten
/brpp partner remove <Gilde>   Daten dieser Gilde rauswerfen
/brpp partner leave            Partnerschaft beenden, alle Fremddaten weg
```

Alle bisherigen Befehle funktionieren weiter, nur mit `/brpp` statt `/brp`
(also auch `/brpp sync`, `/brpp versioncheck`, `/brpp export` usw.).

## Praxistest

Die Oberflaeche wurde mit Testdaten geprueft; die Testdaten (`/brpptest`) sind seit 2.2.1 entfernt.

### Zu zweit

Das ist der Teil, der sich nur im Spiel verifizieren laesst.

1. Beide Seiten installieren das Addon
2. Gilde A: `/brpp partner create`, Code notieren
3. Code an Gilde B geben (Whisper, Discord, egal)
4. Gilde B: `/brpp partner add <Code>`
5. Beide: `/brpp debug` einschalten
6. Gilde A: `/brpp send`
7. Gilde B muss die Rezepte bekommen, markiert mit `<Gilde A>`
8. `/brpp partner status` auf beiden Seiten -- muss "Partnerkanal verbunden"
   melden

## Geprueft

- Syntax aller fuenf Lua-Dateien: fehlerfrei (`luac5.1 -p`)
- Max. Upvalues pro Funktion: 20 (Limit 32)
- Alle Locale-Keys in DE und EN vorhanden
- Namensraum vollstaendig getrennt (kein `BRP_`, `BRPDB` oder `BRP0` mehr)
- Stub-Tests bestanden: Code-Format inkl. Kleinschreibung/Bindestriche,
  Schluessel-Roundtrip mit Apostroph/Leerzeichen/`&`, Migration inkl.
  Kollision, Gilden-Purge, Schleifenschutz, kompletter Chunk-Roundtrip
  ueber simulierten Chat-Transport mit boesartigen Rezeptnamen

## Was NICHT geprueft werden konnte

Ehrliche Einordnung: der Kanalversand liess sich nur bis zur Logikebene
testen. Ob `JoinChannelByName`, der Hook auf `ChatFrame_OnEvent` und
`SendChatMessage` auf deinem konkreten Server genau so funktionieren, zeigt
erst der Praxistest mit zwei Clients. Private Server weichen hier
gelegentlich vom Original-Vanilla-Verhalten ab.

Mogliche Stolpersteine im Praxistest:
- Der Kanal wird erst 5 Sekunden nach dem Login betreten (vorher ist das
  Kanalsystem nicht bereit). `/brpp partner status` sagt dir, ob es geklappt
  hat.
- Wenn der Server Chat-Nachrichten mit `^` oder langen Strings filtert,
  kommen Chunks kaputt an. Dann meldet sich der Debug-Modus.
- Serverseitiger Spam-Schutz: bei sehr vielen Rezepten dauert ein
  Partner-Sync deutlich laenger als ein Gilden-Sync. Das ist Absicht.

## Neue Mitglieder ohne Aufwand verbinden

Niemand muss den Code abtippen. Es gibt zwei Wege, und beide laufen ueber
den Gilden-Addonkanal -- den teilen Gildenmitglieder ohnehin schon, der Code
verlaesst die Gilde dabei nicht.

**Button "Gildenmitglieder verbinden"** (im Fenster unten rechts, neben
"Datenbank an Gilde teilen"): schickt den Partnercode an alle in deiner
Gilde, die das Addon haben. Sie sind sofort verbunden und bekommen eine
Meldung im Chat. Direkt danach kannst du auf "Datenbank an Gilde teilen"
klicken. Als Befehl: `/brpp partner push`.

**Automatisch beim Login:** Wer das Addon neu installiert und noch keinen
Code hat, fragt 8 Sekunden nach dem Einloggen selbst in der Gilde nach.
Ein Mitglied mit Code antwortet, der Rest ist erledigt. Damit muss nicht
einmal jemand den Button druecken.

Damit bei 20 Leuten online nicht 20 identische Antworten kommen, wartet
jeder zufaellig 1 bis 4 Sekunden und schweigt, sobald jemand anderes
geantwortet hat. Im Ergebnis geht genau eine Antwort raus.

### Grenzen, die du kennen solltest

- Jedes Gildenmitglied mit dem Addon bekommt den Code. Das ist genau der
  Zweck, heisst aber auch: jeder koennte ihn weitergeben. Wenn der Code
  irgendwo landet, wo er nicht hingehoert, hilft
  `/brpp partner newcode` -- danach muessen allerdings beide Gilden neu
  verteilen.
- Wer `/brpp partner leave` benutzt hat, wird NICHT wieder automatisch
  hineingezogen. Das Addon merkt sich den Austritt. Zurueck geht es nur per
  Hand mit `/brpp partner add <Code>`.
- Ein Code, der ueber den Partnerkanal ankommt, wird abgewiesen. Nur der
  eigene Gildenkanal zaehlt -- sonst koennte jemand aus der Partnergilde die
  Verbindung auf einen anderen Kanal umlenken.

## Ist jemand aus der Partnergilde online?

Ja, das siehst du im Addon -- und niemand muss dafuer in deiner
Freundesliste stehen.

Mitglieder der Partnergilde tauchen nicht in deinem Gildenroster auf, ihr
Status ist darueber also nicht zu bekommen. Stattdessen dient der
Partnerkanal selbst als Anwesenheitsliste: wer dort sitzt, ist online, hat
das Addon und ist verbunden. Genau das will man wissen, bevor man jemanden
wegen eines Crafts anschreibt.

In der Crafterliste steht deshalb bei Partnern entweder "online" oder
"nicht erreichbar". Die zweite Formulierung ist bewusst gewaehlt: sie
heisst "sitzt nicht im Kanal" -- also ausgeloggt ODER ohne Addon. Ein
schlichtes "offline" waere an der Stelle eine Behauptung, die das Addon
nicht belegen kann.

Online-Partner erscheinen automatisch im "Anfluestern"-Menue des
Rezeptfensters. Anfluestern funktioniert gildenuebergreifend ohne
Freundschaft, solange ihr auf demselben Realm seid.

Aktualisiert wird der Status so:
- beim Betreten und Verlassen des Kanals sofort
- beim Oeffnen des Addon-Fensters wird die komplette Kanalliste geholt
- `/brpp partner status` zeigt die Zahl der aktuell Erreichbaren

Der letzte Punkt ist noetig, weil wer schon vor deinem Login im Kanal sass,
kein Beitrittsereignis mehr ausloest.

Einschraenkung: Erkannt wird der Charakter, der im Kanal sitzt. Loggt
jemand auf einen Twink um, der das Rezept kann, gilt der Twink nur dann als
erreichbar, wenn er selbst im Kanal ist.

## Partner ohne Gilde

Ein Partner muss keine Gilde haben -- ein gildenloser Account funktioniert.

Intern bekommt so jemand die Kennung `Solo:<Charname>` statt eines
Gildennamens. Das ist kein Schoenheitsdetail, sondern noetig: mit einem
festen Sammelbegriff wie "Ohne Gilde" haetten alle gildenlosen Spieler
dieselbe Kennung. Zwei davon wuerden sich gegenseitig fuer "eigene Gilde"
halten, der Schleifenschutz beim Senden wuerde nicht greifen, und sie
haetten sich die Daten bei jedem `/brpp send` gegenseitig zurueckgeschickt.

In der Oberflaeche steht statt der Kennung `<ohne Gilde (Name)>`.

Zum Rauswerfen reicht der Charaktername, die interne Kennung musst du nicht
kennen:

```
/brpp partner remove Alice
```

Einschraenkung: Der Gildenkanal faellt fuer einen gildenlosen Spieler
natuerlich weg. Er teilt seine Rezepte nur ueber den Partnerkanal, und er
bekommt auch nur von dort etwas. Innerhalb einer Gilde laeuft weiterhin
alles wie gewohnt.

## Nicht enthalten

- Bankdaten werden bewusst nicht mit Partnergilden geteilt.

## ToDo

- [ ] Die ~20 fehlenden Enchanting-Rezepte (Runed Rods, Wands, Oils) in
      `BananaCraft_RecipeMaps.lua` ergaenzen. Reine
      Datenluecke, unabhaengig vom Partnergilden-Modul.
