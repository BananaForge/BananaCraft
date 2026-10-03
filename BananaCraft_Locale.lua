-- BananaCraft - Localization
-- ============================================================
--  IMPORTANT ARCHITECTURE NOTE / WICHTIGER HINWEIS:
--
--  EN: Only the DISPLAY is translated. All stored and
--      transmitted data (profession keys, recipe names,
--      category keys) stays in ENGLISH so that German and
--      English clients remain fully compatible over the wire.
--
--  DE: Uebersetzt wird ausschliesslich die ANZEIGE. Alle
--      gespeicherten und gesendeten Daten (Berufsschluessel,
--      Rezeptnamen, Kategorieschluessel) bleiben ENGLISCH,
--      damit deutsche und englische Clients weiterhin
--      miteinander kommunizieren koennen.
-- ============================================================

BCRAFT_Locales = {}
BCRAFT_Locales["enUS"] = {}
BCRAFT_Locales["deDE"] = {}

local en = BCRAFT_Locales["enUS"]
local de = BCRAFT_Locales["deDE"]


-- ---------- Interface strings ----------
en.ALL_SENT = "All professions have been sent!"
de.ALL_SENT = "Alle Berufe wurden gesendet!"

en.SENDING = "Sending:"
de.SENDING = "Sende:"

en.SCANNED = "Scanned:"
de.SCANNED = "Gescannt:"

en.RECIPES_SUFFIX = "recipes"
de.RECIPES_SUFFIX = "Rezepte"

en.TRANSFER_START = "Starting transfer:"
de.TRANSFER_START = "Starte Uebertragung:"

en.PROFS_QUEUED = "professions queued"
de.PROFS_QUEUED = "Berufe in Queue"

en.EST_TIME = "Estimated time: approx."
de.EST_TIME = "Geschaetzte Zeit: ca."

en.SECONDS = "seconds"
de.SECONDS = "Sekunden"

en.NOTHING_TO_SEND = "Nothing to send."
de.NOTHING_TO_SEND = "Keine Berufe zum Senden."

en.SCAN_FIRST = "Scan your professions first!"
de.SCAN_FIRST = "Scanne zuerst deine Berufe!"

en.REMAINING = "remaining"
de.REMAINING = "verbleibend"

en.WINDOW_TITLE = "BananaCraft - Craft Search"
de.WINDOW_TITLE = "BananaCraft - Craft-Suche"

en.SEARCH_LABEL = "Search:"
de.SEARCH_LABEL = "Suche:"

en.SHARE_BUTTON = "Share database with guild"
de.SHARE_BUTTON = "Datenbank mit der Gilde teilen"

en.ABOUT_TOOLTIP = "About this addon"
de.ABOUT_TOOLTIP = "Ueber dieses Addon"

en.LANG_TOOLTIP = "Switch language"
de.LANG_TOOLTIP = "Sprache umschalten"

en.ALL = "ALL"
de.ALL = "ALLE"

en.ONLINE = "Online"
de.ONLINE = "Online"

en.OFFLINE = "Offline"
de.OFFLINE = "Offline"

en.TOTAL = "total"
de.TOTAL = "Gesamt"

en.QUANTITY = "Quantity:"
de.QUANTITY = "Anzahl:"

en.WHISPER = "Whisper..."
de.WHISPER = "Anfluestern..."

en.MISSING = "Missing:"
de.MISSING = "Fehlen:"

en.ALL_MATS = "All materials available!"
de.ALL_MATS = "Alle Materialien vorhanden!"

en.PLAYER = "Player:"
de.PLAYER = "Spieler:"

en.PROFESSION = "Profession:"
de.PROFESSION = "Beruf:"

en.MATERIALS = "Materials"
de.MATERIALS = "Materialien"

en.NEEDED = "Needed"
de.NEEDED = "Benoetigt"

en.HAVE_BAGS_BANK = "Have (bags+bank)"
de.HAVE_BAGS_BANK = "Hast (Taschen+Bank)"

en.CRAFTERS = "Crafters"
de.CRAFTERS = "Hersteller"

en.NOBODY_ONLINE = "Sadly nobody is online right now who could help you here!"
de.NOBODY_ONLINE = "Leider ist derzeit keine Banane Online die dir hier weiterhelfen kann!"

en.CSV_EXPORT = "CSV Export"
de.CSV_EXPORT = "CSV Export"

en.CSV_HINT = "Ctrl+A -> Ctrl+C to copy!"
de.CSV_HINT = "Strg+A -> Strg+C zum Kopieren!"

en.CSV_NOTEPAD = "Then paste into Notepad and save as .csv!"
de.CSV_NOTEPAD = "Dann in Notepad einfuegen und als .csv speichern!"

en.CLOSE = "Close"
de.CLOSE = "Schliessen"

en.LINES = "lines"
de.LINES = "Zeilen"

en.THANKS_TITLE = "Thank you for your support!"
de.THANKS_TITLE = "Danke fuer die Unterstuetzung!"

en.THANKS_BODY = "This addon was built in many hours of spare time and stays free.\n\nIf you would like to say thanks, feel free to send me mail - gold, mats or just a few kind words always make my day.\n\n|cff888888Completely optional - the addon works just fine without it.|r"
de.THANKS_BODY = "Dieses Addon ist in vielen Stunden Freizeit entstanden und bleibt kostenlos.\n\nWer sich bedanken moechte, kann mir gerne Post schicken - ueber Gold, Mats oder auch nur ein paar nette Worte freue ich mich immer.\n\n|cff888888Voellig freiwillig - das Addon funktioniert auch ohne komplett.|r"

en.CHARACTER = "Character:"
de.CHARACTER = "Charakter:"

en.FILL_NAME = "Fill in name"
de.FILL_NAME = "Namen eintragen"

en.MAILBOX_OPEN = "Mailbox open - one click fills in the name."
de.MAILBOX_OPEN = "Briefkasten offen - ein Klick traegt den Namen ein."

en.MAILBOX_CLOSED = "Select and press Ctrl+C to copy the name. At a mailbox it is filled in automatically."
de.MAILBOX_CLOSED = "Markieren und Strg+C kopiert den Namen. Am Briefkasten wird er per Knopfdruck eingetragen."

en.RECIPIENT_SET = "Recipient"
de.RECIPIENT_SET = "Empfaenger"

en.RECIPIENT_THANKS = "has been filled in. Thank you very much!"
de.RECIPIENT_THANKS = "wurde eingetragen. Vielen Dank!"

en.NEED_MAILBOX = "You need to stand at a"
de.NEED_MAILBOX = "Dafuer musst du an einem"

en.MAILBOX = "mailbox"
de.MAILBOX = "Briefkasten"

en.NEED_MAILBOX_2 = "for that. You can also select the name and copy it with Ctrl+C."
de.NEED_MAILBOX_2 = "stehen. Der Name laesst sich aber auch markieren und mit Strg+C kopieren."

en.MM_LEFTCLICK = "Left-click: open/close window"
de.MM_LEFTCLICK = "Linksklick: Fenster oeffnen/schliessen"

en.MM_RIGHTCLICK = "Right-click + drag: move button"
de.MM_RIGHTCLICK = "Rechtsklick + Ziehen: Button verschieben"

en.MANAGE_PROFS = "Manage professions"
de.MANAGE_PROFS = "Berufe Verwalten"

en.MANAGE_HINT = "Click a profession to delete it and notify the guild"
de.MANAGE_HINT = "Klicke auf einen Beruf um ihn zu loeschen und an die Gilde zu senden"

en.NO_PROFS_STORED = "No professions stored"
de.NO_PROFS_STORED = "Keine Berufe gespeichert"

en.SHARE_SHORT = "Share database with guild"
de.SHARE_SHORT = "Datenbank an Gilde teilen"

en.CMD_HEADER = "Commands:"
de.CMD_HEADER = "Befehle:"

en.CMD_SHOW = "/bcraft show      - open/close the UI"
de.CMD_SHOW = "/bcraft show      - UI oeffnen/schliessen"

en.CMD_SCAN = "/bcraft scan      - scan the open profession"
de.CMD_SCAN = "/bcraft scan      - aktuell geoeffneten Beruf scannen"

en.CMD_RESCAN = "/bcraft rescan    - allow rescanning (clears session cache)"
de.CMD_RESCAN = "/bcraft rescan    - erlaube erneutes Scannen (cleart Session-Cache)"

en.CMD_SEND = "/bcraft send      - send all professions to the guild"
de.CMD_SEND = "/bcraft send      - alle Berufe an Gilde senden"

en.CMD_SYNC = "/bcraft sync      - lightweight sync: only pulls what's outdated"
de.CMD_SYNC = "/bcraft sync      - leichter Abgleich: holt nur veraltete Daten nach"

en.CMD_VERSIONCHECK = "/bcraft versioncheck - see which BananaCraft version guildmates run"
de.CMD_VERSIONCHECK = "/bcraft versioncheck - zeigt BananaCraft-Version der Gildenmitglieder"

en.CMD_DELETE = "/bcraft delete [prof] - delete a profession (e.g. /bcraft delete Alchemy)"
de.CMD_DELETE = "/bcraft delete [prof] - Beruf loeschen (z.B. /bcraft delete Alchemy)"

en.CMD_DELETE_ALL = "/bcraft delete all    - delete ALL professions"
de.CMD_DELETE_ALL = "/bcraft delete all    - ALLE Berufe loeschen"

en.CMD_SCANBANK = "/bcraft scanbank  - scan bank manually"
de.CMD_SCANBANK = "/bcraft scanbank  - Bank manuell scannen"

en.CMD_EXPORT = "/bcraft export    - CSV export for Discord/Excel"
de.CMD_EXPORT = "/bcraft export    - CSV-Export fuer Discord/Excel"

en.CMD_DEBUG = "/bcraft debug     - toggle debug"
de.CMD_DEBUG = "/bcraft debug     - Debug an/aus"

en.CMD_ABOUT = "/bcraft about     - info & support"
de.CMD_ABOUT = "/bcraft about     - Info & Unterstuetzung"

en.CMD_LANG = "/bcraft lang en|de|auto - language"
de.CMD_LANG = "/bcraft lang en|de|auto - Sprache"

en.SYNC_REQUESTING = "Sync: requesting updated data for professions:"
de.SYNC_REQUESTING = "Abgleich: fordere aktualisierte Daten an fuer Berufe:"

en.SYNC_UP_TO_DATE = "Sync: everything already up to date."
de.SYNC_UP_TO_DATE = "Abgleich: bereits alles aktuell."

en.VERSIONCHECK_ASKING = "Asking guild which BananaCraft version they run..."
de.VERSIONCHECK_ASKING = "Frage Gilde nach BananaCraft-Version..."

en.VERSIONCHECK_RUNS = "runs"
de.VERSIONCHECK_RUNS = "nutzt"

en.CACHE_CLEARED = "Session cache cleared. You can rescan all professions now!"
de.CACHE_CLEARED = "Session-Cache geloescht. Du kannst jetzt alle Berufe neu scannen!"

en.DEBUG_LABEL = "Debug:"
de.DEBUG_LABEL = "Debug:"

en.ON = "ON"
de.ON = "AN"

en.OFF = "OFF"
de.OFF = "AUS"

en.USAGE_DELETE = "Usage: /bcraft delete [profession] or /bcraft delete all"
de.USAGE_DELETE = "Benutzung: /bcraft delete [Beruf] oder /bcraft delete all"

en.EXAMPLE_DELETE = "Example: /bcraft delete Alchemy"
de.EXAMPLE_DELETE = "Beispiel: /bcraft delete Alchemy"

en.DB_WIPED = "ENTIRE DATABASE DELETED:"
de.DB_WIPED = "KOMPLETTE DATENBANK GELOESCHT:"

en.CHARACTERS = "character(s)"
de.CHARACTERS = "Character"

en.PROFESSIONS = "profession(s)"
de.PROFESSIONS = "Beruf(e)"

en.GUILD_ENTRIES = "guild entries"
de.GUILD_ENTRIES = "Gilden-Eintraege"

en.DELETED = "Deleted:"
de.DELETED = "Geloescht:"

en.ERROR = "Error:"
de.ERROR = "Fehler:"

en.PROF_NOT_FOUND = "not found"
de.PROF_NOT_FOUND = "nicht gefunden"

en.NO_PROF_OPEN = "No profession window open"
de.NO_PROF_OPEN = "Kein Beruf geoeffnet"

en.NO_RECIPES = "No recipes found"
de.NO_RECIPES = "Keine Rezepte gefunden"

en.NO_DATA_FOR = "No data for"
de.NO_DATA_FOR = "Keine Daten fuer"

en.LANG_SWITCHED = "Language set to English."
de.LANG_SWITCHED = "Sprache auf Deutsch gestellt."


-- ---------- Category names (keys stay English!) ----------
en.CAT = {}
de.CAT = {}
en.CAT["ALL"] = "ALL"
de.CAT["ALL"] = "ALLE"
en.CAT["2HWeapon"] = "Two-Handed Weapons"
de.CAT["2HWeapon"] = "Zweihandwaffen"
en.CAT["Amulets"] = "Amulets"
de.CAT["Amulets"] = "Amulette"
en.CAT["Axes"] = "Axes"
de.CAT["Axes"] = "Aexte"
en.CAT["Bags"] = "Bags"
de.CAT["Bags"] = "Taschen"
en.CAT["Belt"] = "Belts"
de.CAT["Belt"] = "Guertel"
en.CAT["Boots"] = "Boots"
de.CAT["Boots"] = "Stiefel"
en.CAT["Bracer"] = "Bracers"
de.CAT["Bracer"] = "Armschienen"
en.CAT["Bracers"] = "Bracers"
de.CAT["Bracers"] = "Armschienen"
en.CAT["Buckles"] = "Buckles"
de.CAT["Buckles"] = "Schnallen"
en.CAT["Cloth"] = "Cloth"
de.CAT["Cloth"] = "Stoffballen"
en.CAT["Chest"] = "Chest"
de.CAT["Chest"] = "Brustruestung"
en.CAT["Cloak"] = "Cloaks"
de.CAT["Cloak"] = "Umhaenge"
en.CAT["Daggers"] = "Daggers"
de.CAT["Daggers"] = "Dolche"
en.CAT["Defensive Potions and Elixirs"] = "Defensive Potions and Elixirs"
de.CAT["Defensive Potions and Elixirs"] = "Defensive Traenke und Elixiere"
en.CAT["Equipment"] = "Equipment"
de.CAT["Equipment"] = "Ausruestung"
en.CAT["Explosives"] = "Explosives"
de.CAT["Explosives"] = "Sprengstoffe"
en.CAT["Fist"] = "Fist Weapons"
de.CAT["Fist"] = "Faustwaffen"
en.CAT["Flasks"] = "Flasks"
de.CAT["Flasks"] = "Flaschen"
en.CAT["Gemstones"] = "Gemstones"
de.CAT["Gemstones"] = "Edelsteine"
en.CAT["Glove"] = "Gloves"
de.CAT["Glove"] = "Handschuhe"
en.CAT["Gloves"] = "Gloves"
de.CAT["Gloves"] = "Handschuhe"
en.CAT["Gnomish"] = "Gnomish"
de.CAT["Gnomish"] = "Gnomisch"
en.CAT["Goblin"] = "Goblin"
de.CAT["Goblin"] = "Goblin"
en.CAT["Health and Mana Potions"] = "Health and Mana Potions"
de.CAT["Health and Mana Potions"] = "Gesundheits- und Manatraenke"
en.CAT["Helm"] = "Helmets"
de.CAT["Helm"] = "Helme"
en.CAT["Maces"] = "Maces"
de.CAT["Maces"] = "Streitkolben"
en.CAT["Misc"] = "Miscellaneous"
de.CAT["Misc"] = "Verschiedenes"
en.CAT["Miscellaneous"] = "Miscellaneous"
de.CAT["Miscellaneous"] = "Verschiedenes"
en.CAT["OffHands"] = "Off-Hands"
de.CAT["OffHands"] = "Schildhand"
en.CAT["Offensive Potions and Elixirs"] = "Offensive Potions and Elixirs"
de.CAT["Offensive Potions and Elixirs"] = "Offensive Traenke und Elixiere"
en.CAT["Pants"] = "Pants"
de.CAT["Pants"] = "Hosen"
en.CAT["Parts"] = "Parts"
de.CAT["Parts"] = "Bauteile"
en.CAT["Protection Potions"] = "Protection Potions"
de.CAT["Protection Potions"] = "Schutztraenke"
en.CAT["Rings"] = "Rings"
de.CAT["Rings"] = "Ringe"
en.CAT["Shield"] = "Shields"
de.CAT["Shield"] = "Schilde"
en.CAT["Shirt"] = "Shirts"
de.CAT["Shirt"] = "Hemden"
en.CAT["Shoulders"] = "Shoulders"
de.CAT["Shoulders"] = "Schultern"
en.CAT["Smelting"] = "Smelting"
de.CAT["Smelting"] = "Schmelzen"
en.CAT["Staves"] = "Staves"
de.CAT["Staves"] = "Staebe"
en.CAT["Swords"] = "Swords"
de.CAT["Swords"] = "Schwerter"
en.CAT["Transmutes"] = "Transmutes"
de.CAT["Transmutes"] = "Transmutationen"
en.CAT["Trinkets"] = "Trinkets"
de.CAT["Trinkets"] = "Schmuck"
en.CAT["Weapon"] = "Weapons"
de.CAT["Weapon"] = "Waffen"
en.CAT["Weapons"] = "Weapons"
de.CAT["Weapons"] = "Waffen"
en.CAT["Weaponsmith"] = "Weaponsmith"
de.CAT["Weaponsmith"] = "Waffenschmied"

-- ---------- Profession names (keys stay English!) ----------
en.PROF = {}
de.PROF = {}
en.PROF["ALL"] = "ALL"
de.PROF["ALL"] = "ALLE"
en.PROF["Alchemy"] = "Alchemy"
de.PROF["Alchemy"] = "Alchemie"
en.PROF["Blacksmithing"] = "Blacksmithing"
de.PROF["Blacksmithing"] = "Schmiedekunst"
en.PROF["Enchanting"] = "Enchanting"
de.PROF["Enchanting"] = "Verzauberkunst"
en.PROF["Engineering"] = "Engineering"
de.PROF["Engineering"] = "Ingenieurskunst"
en.PROF["Jewelcrafting"] = "Jewelcrafting"
de.PROF["Jewelcrafting"] = "Juwelierskunst"
en.PROF["Leatherworking"] = "Leatherworking"
de.PROF["Leatherworking"] = "Lederverarbeitung"
en.PROF["Tailoring"] = "Tailoring"
de.PROF["Tailoring"] = "Schneiderei"
en.PROF["Cooking"] = "Cooking"
de.PROF["Cooking"] = "Kochkunst"
en.PROF["First Aid"] = "First Aid"
de.PROF["First Aid"] = "Erste Hilfe"
en.PROF["Mining"] = "Mining"
de.PROF["Mining"] = "Bergbau"
en.PROF["Survival"] = "Survival"
de.PROF["Survival"] = "Ueberleben"
en.PROF["Poisons"] = "Poisons"
de.PROF["Poisons"] = "Gifte"


-- ---------- Runtime language handling ----------
-- BCRAFT_L is the active table used everywhere in the addon.
BCRAFT_L = BCRAFT_Locales["enUS"]

-- Detect a sensible default from the game client
function BCRAFT_DetectLocale()
  local loc = "enUS"
  if GetLocale then
    local g = GetLocale()
    if g == "deDE" then loc = "deDE" end
  end
  return loc
end

-- Apply a language: "enUS", "deDE" or "auto"
function BCRAFT_SetLocale(which)
  if which == "auto" or which == nil then
    which = BCRAFT_DetectLocale()
  end
  if not BCRAFT_Locales[which] then which = "enUS" end

  BCRAFT_L = BCRAFT_Locales[which]

  if BananaCraftDB then
    if not BananaCraftDB.settings then BananaCraftDB.settings = {} end
    BananaCraftDB.settings.locale = which
  end

  return which
end

-- Current language code
function BCRAFT_GetLocale()
  if BananaCraftDB and BananaCraftDB.settings and BananaCraftDB.settings.locale then
    return BananaCraftDB.settings.locale
  end
  return BCRAFT_DetectLocale()
end

-- Translate a category key for display (falls back to the key itself)
function BCRAFT_CatName(key)
  if not key then return "" end
  if BCRAFT_L and BCRAFT_L.CAT and BCRAFT_L.CAT[key] then return BCRAFT_L.CAT[key] end
  return key
end

-- Translate a profession key for display (falls back to the key itself)
function BCRAFT_ProfName(key)
  if not key then return "" end
  if BCRAFT_L and BCRAFT_L.PROF and BCRAFT_L.PROF[key] then return BCRAFT_L.PROF[key] end
  return key
end
-- -------------------------
-- Partnergilden
-- -------------------------
en.CMD_PARTNER = "/bcraft partner   - partner guild setup (invite code)"
de.CMD_PARTNER = "/bcraft partner   - Partnergilde einrichten (Einladecode)"

en.CMD_PARTNER_CREATE = "  /bcraft partner create        - create a new invite code"
de.CMD_PARTNER_CREATE = "  /bcraft partner create        - neuen Einladecode erzeugen"

en.CMD_PARTNER_ADD = "  /bcraft partner add <code>    - join with a code you received"
de.CMD_PARTNER_ADD = "  /bcraft partner add <Code>    - mit erhaltenem Code verbinden"

en.CMD_PARTNER_CODE = "  /bcraft partner code          - show the current code"
de.CMD_PARTNER_CODE = "  /bcraft partner code          - aktuellen Code anzeigen"

en.CMD_PARTNER_NEWCODE = "  /bcraft partner newcode       - generate a new code (old one stops working)"
de.CMD_PARTNER_NEWCODE = "  /bcraft partner newcode       - neuen Code erzeugen (alter wird ungueltig)"

en.CMD_PARTNER_LIST = "  /bcraft partner list          - list known partner guilds"
de.CMD_PARTNER_LIST = "  /bcraft partner list          - bekannte Partnergilden auflisten"

en.CMD_PARTNER_REMOVE = "  /bcraft partner remove <guild> - drop that guild's data"
de.CMD_PARTNER_REMOVE = "  /bcraft partner remove <Gilde> - Daten dieser Gilde rauswerfen"

en.CMD_PARTNER_LEAVE = "  /bcraft partner leave         - end partnership, remove all foreign data"
de.CMD_PARTNER_LEAVE = "  /bcraft partner leave         - Partnerschaft beenden, alle Fremddaten loeschen"

en.PARTNER_CREATED = "Partnership opened."
de.PARTNER_CREATED = "Partnerschaft eroeffnet."

en.PARTNER_CODE_IS = "Invite code:"
de.PARTNER_CODE_IS = "Einladecode:"

en.PARTNER_SHARE_HINT = "Share this code with the partner guild. They enter: /bcraft partner add <code>"
de.PARTNER_SHARE_HINT = "Diesen Code an die Partnergilde geben. Dort eingeben: /bcraft partner add <Code>"

en.PARTNER_NEED_CODE = "Please provide a code: /bcraft partner add <code>"
de.PARTNER_NEED_CODE = "Bitte Code angeben: /bcraft partner add <Code>"

en.PARTNER_BAD_CODE = "Invalid code. A code has 12 characters."
de.PARTNER_BAD_CODE = "Ungueltiger Code. Ein Code hat 12 Zeichen."

en.PARTNER_JOINED = "Connected. Recipes will now be shared with the partner guild."
de.PARTNER_JOINED = "Verbunden. Rezepte werden ab jetzt mit der Partnergilde geteilt."

en.PARTNER_NO_CODE = "No code set yet. Use /bcraft partner create"
de.PARTNER_NO_CODE = "Noch kein Code gesetzt. Nutze /bcraft partner create"

en.PARTNER_NEWCODE = "New code generated."
de.PARTNER_NEWCODE = "Neuer Code erzeugt."

en.PARTNER_NEWCODE_WARN = "The old code no longer works. Everyone has to re-enter the new one."
de.PARTNER_NEWCODE_WARN = "Der alte Code funktioniert nicht mehr. Alle muessen den neuen eintragen."

en.PARTNER_NONE = "No partner guilds known yet."
de.PARTNER_NONE = "Noch keine Partnergilden bekannt."

en.PARTNER_LIST_HEADER = "Known partner guilds:"
de.PARTNER_LIST_HEADER = "Bekannte Partnergilden:"

en.PARTNER_CHARS = "characters"
de.PARTNER_CHARS = "Charaktere"

en.PARTNER_GUILDS = "guilds"
de.PARTNER_GUILDS = "Gilden"

en.PARTNER_NEED_GUILD = "Please provide a guild name: /bcraft partner remove <guild>"
de.PARTNER_NEED_GUILD = "Bitte Gildennamen angeben: /bcraft partner remove <Gilde>"

en.PARTNER_CANT_REMOVE_OWN = "That's your own guild - not removing it."
de.PARTNER_CANT_REMOVE_OWN = "Das ist deine eigene Gilde - wird nicht entfernt."

en.PARTNER_REMOVED = "Removed data of:"
de.PARTNER_REMOVED = "Daten entfernt von:"

en.PARTNER_LEFT = "Partnership ended."
de.PARTNER_LEFT = "Partnerschaft beendet."

en.PARTNER_STATUS_ON = "Partner sharing: |cff00ff00active|r"
de.PARTNER_STATUS_ON = "Partnerfreigabe: |cff00ff00aktiv|r"

en.PARTNER_STATUS_OFF = "Partner sharing: |cff888888inactive|r"
de.PARTNER_STATUS_OFF = "Partnerfreigabe: |cff888888inaktiv|r"

en.PARTNER_CHANNEL_OK = "Partner channel connected."
de.PARTNER_CHANNEL_OK = "Partnerkanal verbunden."

en.PARTNER_CHANNEL_MISSING = "Partner channel not joined yet (try again in a few seconds)."
de.PARTNER_CHANNEL_MISSING = "Partnerkanal noch nicht betreten (in ein paar Sekunden nochmal)."

en.PARTNER_UNKNOWN_SUB = "Unknown subcommand:"
de.PARTNER_UNKNOWN_SUB = "Unbekannter Unterbefehl:"

en.PARTNER_NEW_GUILD = "New partner guild detected:"
de.PARTNER_NEW_GUILD = "Neue Partnergilde erkannt:"

en.PARTNER_UNKNOWN_STATUS = "partner guild"
de.PARTNER_UNKNOWN_STATUS = "Partnergilde"

en.PARTNER_NO_GUILD = "no guild"
de.PARTNER_NO_GUILD = "ohne Gilde"

en.BTN_CONNECT_MEMBERS = "Connect guild members"
de.BTN_CONNECT_MEMBERS = "Gildenmitglieder verbinden"

en.BTN_CONNECT_TIP1 = "Sends the partner code to everyone in your guild who has this addon."
de.BTN_CONNECT_TIP1 = "Schickt den Partnercode an alle in deiner Gilde, die dieses Addon haben."

en.BTN_CONNECT_TIP2 = "They join automatically - nobody has to type the code."
de.BTN_CONNECT_TIP2 = "Sie werden automatisch verbunden - niemand muss den Code eintippen."

en.PARTNER_AUTO_JOINED = "Automatically connected to the partnership. Code received from:"
de.PARTNER_AUTO_JOINED = "Automatisch mit der Partnerschaft verbunden. Code erhalten von:"

en.PARTNER_AUTO_HINT = "Leave any time with /bcraft partner leave"
de.PARTNER_AUTO_HINT = "Jederzeit verlassen mit /bcraft partner leave"

en.PARTNER_PUSHED = "Partner code sent to the guild. Members with the addon join automatically."
de.PARTNER_PUSHED = "Partnercode an die Gilde gesendet. Mitglieder mit dem Addon verbinden sich automatisch."

en.CMD_PARTNER_PUSH = "  /bcraft partner push          - send the code to your own guild"
de.CMD_PARTNER_PUSH = "  /bcraft partner push          - Code an die eigene Gilde senden"

en.PARTNER_NOT_IN_CHANNEL = "not reachable"
de.PARTNER_NOT_IN_CHANNEL = "nicht erreichbar"

en.PARTNER_ONLINE_COUNT = "Partner guild members reachable right now:"
de.PARTNER_ONLINE_COUNT = "Aktuell erreichbare Partnergilden-Mitglieder:"
