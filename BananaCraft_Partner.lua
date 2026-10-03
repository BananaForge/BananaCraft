-- =========================================================================
-- BananaCraft -- Partnergilden-Modul
--
-- Stellt die Verbindung zwischen zwei Gilden her. Wichtig zum Verstaendnis:
-- WoW 1.12 kann Addon-Nachrichten NUR an die eigene Gilde schicken
-- (SendAddonMessage mit "GUILD"). Es gibt kein Gilde-zu-Gilde-Messaging.
-- Der einzige Weg, der beide Gilden erreicht, ist ein gemeinsamer
-- Chat-Kanal, den beide Seiten betreten.
--
-- Genau das ist der "Einladecode": er enthaelt Kanalname + Passwort.
-- Wer den Code hat, kommt in den Kanal. Wer ihn nicht hat, nicht.
--
-- Weil Kanalnachrichten normaler Chat-Text sind (kein Addon-Kanal), werden
-- sie hier zusaetzlich aus dem sichtbaren Chat herausgefiltert, damit
-- niemand eine Textwand sieht.
-- =========================================================================

BCRAFT_Partner = {}

local PARTNER_TAG = "BCRAFTG1"   -- Kennung am Anfang jeder Partner-Nachricht
local CHANNEL_BASE = "BCRAFTG"   -- Kanalname = CHANNEL_BASE .. <6 Zeichen>
local CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  -- ohne I/O/0/1 (Verwechslung)

local tlen = table.getn

local function pmsg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BananaCraft:|r " .. text)
end

-- -------------------------------------------------------------------------
-- Code-Erzeugung
--
-- Ein Code ist 12 Zeichen lang: die ersten 6 bilden den Kanalnamen,
-- die letzten 6 sind das Kanalpasswort. So reicht EIN String zum Teilen.
-- -------------------------------------------------------------------------
local function randomCode(len)
  local s = ""
  local n = string.len(CODE_CHARS)
  for i = 1, len do
    local idx = random(1, n)
    s = s .. string.sub(CODE_CHARS, idx, idx)
  end
  return s
end

function BCRAFT_Partner.GenerateCode()
  return randomCode(12)
end

-- Code -> Kanalname + Passwort
function BCRAFT_Partner.SplitCode(code)
  if not code then return nil, nil end
  code = string.upper(code)
  code = string.gsub(code, "%s", "")
  code = string.gsub(code, "-", "")
  if string.len(code) ~= 12 then return nil, nil end
  local chan = CHANNEL_BASE .. string.sub(code, 1, 6)
  local pass = string.sub(code, 7, 12)
  return chan, pass
end

-- Huebsche Darstellung mit Bindestrich, leichter vorzulesen
function BCRAFT_Partner.FormatCode(code)
  if not code or string.len(code) ~= 12 then return code or "" end
  return string.sub(code, 1, 4) .. "-" .. string.sub(code, 5, 8) .. "-" .. string.sub(code, 9, 12)
end

-- -------------------------------------------------------------------------
-- Kanal betreten / verlassen
-- -------------------------------------------------------------------------
function BCRAFT_Partner.JoinChannel(db)
  local p = db.partner
  if not p or not p.code then return false end

  local chan, pass = BCRAFT_Partner.SplitCode(p.code)
  if not chan then return false end

  if JoinChannelByName then
    JoinChannelByName(chan, pass)
    p.channel = chan
    return true
  end
  return false
end

function BCRAFT_Partner.LeaveChannel(db)
  local p = db.partner
  if p and p.channel and LeaveChannelByName then
    LeaveChannelByName(p.channel)
  end
  if p then p.channel = nil end
end

-- Aktuellen Kanalindex holen (wird zum Senden gebraucht)
function BCRAFT_Partner.GetChannelIndex(db)
  local p = db.partner
  if not p or not p.channel then return nil end
  if not GetChannelName then return nil end
  local id = GetChannelName(p.channel)
  if id and id > 0 then return id end
  return nil
end

-- -------------------------------------------------------------------------
-- Senden
--
-- Bewusst eine eigene, LANGSAMERE Warteschlange als die Gilden-Drossel:
-- Chat-Kanaele haengen am serverseitigen Spam-Schutz. 0.1s wie im
-- Gildenkanal wuerde hier zuverlaessig Disconnects/Mutes ausloesen.
-- -------------------------------------------------------------------------
local PartnerQueue = {}
local PartnerThrottle = CreateFrame("Frame")
PartnerThrottle:Hide()
PartnerThrottle.elapsed = 0
PartnerThrottle.delay = 0.4   -- max 2,5 Nachrichten/Sekunde

-- Zeilenumbrueche vertragen sich nicht mit SendChatMessage: der Chat
-- schneidet bei "\n" ab. Die Chunk-Daten des Kerns benutzen "\n" aber als
-- Trenner zwischen den Rezepten. Darum wird beim Senden kodiert und beim
-- Empfangen wieder zurueckgewandelt.
--
-- Das Token muss ohne "~" auskommen (das ist der Feldtrenner im Protokoll)
-- und darf in Rezeptnamen, Reagenzien oder Icon-Pfaden nicht vorkommen.
local NL_TOKEN = "@@NL@@"

-- ACHTUNG: string.gsub liefert ZWEI Werte zurueck (Text + Anzahl der
-- Ersetzungen). Wird das Ergebnis direkt weitergereicht, landen beide beim
-- Aufrufer -- aus table.insert(queue, text) wurde so ungewollt
-- table.insert(queue, text, anzahl), also die Drei-Argument-Form mit
-- Positionsangabe. Darum hier ueber eine lokale Variable, damit garantiert
-- nur der Text zurueckkommt.
local function encodeNewlines(s)
  if not s then return s end
  local out = string.gsub(s, "\n", NL_TOKEN)
  return out
end

local function decodeNewlines(s)
  if not s then return s end
  local out = string.gsub(s, NL_TOKEN, "\n")
  return out
end

function BCRAFT_Partner.Enqueue(payload)
  table.insert(PartnerQueue, encodeNewlines(payload))
  PartnerThrottle:Show()
end

function BCRAFT_Partner.QueueLength()
  return tlen(PartnerQueue)
end

function BCRAFT_Partner.ClearQueue()
  PartnerQueue = {}
  PartnerThrottle:Hide()
end

PartnerThrottle:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  if this.elapsed < this.delay then return end
  this.elapsed = 0

  if tlen(PartnerQueue) == 0 then
    PartnerThrottle:Hide()
    return
  end

  local db = BCRAFT_EnsureDB and BCRAFT_EnsureDB() or nil
  if not db then PartnerThrottle:Hide(); return end

  local idx = BCRAFT_Partner.GetChannelIndex(db)
  if not idx then
    -- Kanal (noch) nicht verfuegbar: Warteschlange verwerfen statt ewig
    -- weiterzulaufen, sonst staut sich beim naechsten Login alles auf.
    BCRAFT_Partner.ClearQueue()
    return
  end

  local payload = table.remove(PartnerQueue, 1)
  local line = PARTNER_TAG .. " " .. payload

  if string.len(line) > 250 then
    -- Darf eigentlich nicht passieren, der Kern chunked schon auf 250.
    return
  end

  if SendChatMessage then
    pcall(SendChatMessage, line, "CHANNEL", nil, idx)
  end
end)

-- -------------------------------------------------------------------------
-- Empfangen
--
-- Rueckgabe: payload (String) oder nil, wenn es keine Partner-Nachricht ist.
-- -------------------------------------------------------------------------
function BCRAFT_Partner.ParseIncoming(text)
  if not text then return nil end
  local tagLen = string.len(PARTNER_TAG)
  if string.sub(text, 1, tagLen) ~= PARTNER_TAG then return nil end
  return decodeNewlines(string.sub(text, tagLen + 2))  -- +2 wegen Leerzeichen
end

function BCRAFT_Partner.IsPartnerText(text)
  if not text then return false end
  return string.sub(text, 1, string.len(PARTNER_TAG)) == PARTNER_TAG
end

-- -------------------------------------------------------------------------
-- Chat-Filter
--
-- Vanilla 1.12 hat kein ChatFrame_AddMessageEventFilter (kam erst mit 2.1).
-- Also wird ChatFrame_OnEvent gehookt und die Partner-Zeilen werden
-- geschluckt, bevor sie im Chatfenster landen.
-- -------------------------------------------------------------------------
local origChatFrame_OnEvent = ChatFrame_OnEvent

function BCRAFT_Partner.InstallChatFilter()
  if BCRAFT_Partner._filterInstalled then return end
  BCRAFT_Partner._filterInstalled = true

  ChatFrame_OnEvent = function(chatEvent)
    if chatEvent == "CHAT_MSG_CHANNEL" and BCRAFT_Partner.IsPartnerText(arg1) then
      return  -- Datenverkehr nicht anzeigen
    end

    -- Beitritts-, Austritts- und Listenmeldungen des Partnerkanals ebenfalls
    -- schlucken. Der Kanal ist reine Technik -- niemand will lesen, wer
    -- gerade eingeloggt hat, und die Kanalliste schon gar nicht.
    if chatEvent == "CHAT_MSG_CHANNEL_JOIN"
      or chatEvent == "CHAT_MSG_CHANNEL_LEAVE"
      or chatEvent == "CHAT_MSG_CHANNEL_LIST"
      or chatEvent == "CHAT_MSG_CHANNEL_NOTICE"
      or chatEvent == "CHAT_MSG_CHANNEL_NOTICE_USER" then
      if BCRAFT_Partner.IsOwnChannel(arg9) then
        return
      end
    end

    return origChatFrame_OnEvent(chatEvent)
  end
end

-- Gehoert der Kanalname zu unserem Partnerkanal?
function BCRAFT_Partner.IsOwnChannel(chanName)
  if not chanName or chanName == "" then return false end
  local db = BCRAFT_EnsureDB and BCRAFT_EnsureDB() or nil
  if not db or not db.partner or not db.partner.channel then return false end
  return string.lower(chanName) == string.lower(db.partner.channel)
end

-- -------------------------------------------------------------------------
-- Anwesenheit der Partnergilde
--
-- Mitglieder der Partnergilde stehen nicht im eigenen Gildenroster, ihr
-- Online-Status ist darueber also nicht zu bekommen. Die Freundesliste
-- waere Handarbeit und in Vanilla knapp begrenzt.
--
-- Stattdessen wird der Partnerkanal selbst als Anwesenheitsliste benutzt:
-- wer im Kanal sitzt, ist online UND hat das Addon UND ist verbunden.
-- Genau das will man wissen, bevor man jemanden wegen eines Crafts
-- anschreibt.
--
-- Datenquellen:
--   CHAT_MSG_CHANNEL_JOIN   jemand betritt den Kanal
--   CHAT_MSG_CHANNEL_LEAVE  jemand verlaesst ihn
--   CHAT_MSG_CHANNEL_LIST   vollstaendige Liste nach ListChannelByName()
-- -------------------------------------------------------------------------
local Presence = {}

function BCRAFT_Partner.SetOnline(name)
  if name and name ~= "" then Presence[name] = true end
end

function BCRAFT_Partner.SetOffline(name)
  if name and name ~= "" then Presence[name] = nil end
end

function BCRAFT_Partner.IsOnline(name)
  if not name then return false end
  return Presence[name] == true
end

function BCRAFT_Partner.ClearPresence()
  Presence = {}
end

function BCRAFT_Partner.PresenceCount()
  local n = 0
  for _ in pairs(Presence) do n = n + 1 end
  return n
end

-- Vollstaendige Kanalliste anfordern. Die Antwort kommt als
-- CHAT_MSG_CHANNEL_LIST und wird von ParseList verarbeitet.
function BCRAFT_Partner.RequestRoster(db)
  if not db.partner or not db.partner.channel then return false end
  if not ListChannelByName then return false end
  ListChannelByName(db.partner.channel)
  return true
end

-- "Name1, Name2, Name3" -> Anwesenheitsliste.
-- Namen koennen mit Praefixen wie "@" (Moderator) oder "+" ankommen.
function BCRAFT_Partner.ParseList(text)
  if not text then return 0 end

  Presence = {}
  local count = 0

  -- An Komma trennen; ohne Komma ist es ein einzelner Name
  local rest = text .. ","
  local idx = 1
  while idx <= string.len(rest) do
    local comma = string.find(rest, ",", idx, true)
    if not comma then break end

    local name = string.sub(rest, idx, comma - 1)
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    name = string.gsub(name, "^[@+%%]+", "")   -- Moderator-/Besitzerzeichen

    if name ~= "" then
      Presence[name] = true
      count = count + 1
    end
    idx = comma + 1
  end

  return count
end


-- -------------------------------------------------------------------------
-- Partnergilden-Verwaltung
-- -------------------------------------------------------------------------

-- Merkt sich, welche fremden Gilden ueber den Kanal gesehen wurden.
function BCRAFT_Partner.NoteGuild(db, guildName)
  if not guildName or guildName == "" then return end
  local own = BCRAFT_OwnGuild and BCRAFT_OwnGuild() or nil
  if guildName == own then return end

  if not db.partner then return end
  if not db.partner.guilds then db.partner.guilds = {} end

  if not db.partner.guilds[guildName] then
    db.partner.guilds[guildName] = { firstSeen = date("%Y-%m-%d %H:%M:%S") }
    pmsg("|cff00ff00" .. BCRAFT_L.PARTNER_NEW_GUILD .. "|r " .. (BCRAFT_GuildLabel and BCRAFT_GuildLabel(guildName) or guildName))
  end
  db.partner.guilds[guildName].lastSeen = date("%Y-%m-%d %H:%M:%S")
end

-- Punkt 3.2: Alle Daten einer Partnergilde rauswerfen.
-- Loescht sowohl die Rezeptdaten als auch den Partnereintrag.
function BCRAFT_Partner.PurgeGuild(db, guildName)
  if not guildName or guildName == "" then return 0 end

  local removed = 0
  for key, _ in pairs(db.guild) do
    local _, g = BCRAFT_SplitKey(key)
    if g == guildName then
      db.guild[key] = nil
      removed = removed + 1
    end
  end

  if db.partner and db.partner.guilds then
    db.partner.guilds[guildName] = nil
  end

  return removed
end

-- Liste aller bekannten Partnergilden
function BCRAFT_Partner.ListGuilds(db)
  local list = {}
  if db.partner and db.partner.guilds then
    for g, _ in pairs(db.partner.guilds) do
      table.insert(list, g)
    end
  end
  table.sort(list)
  return list
end
