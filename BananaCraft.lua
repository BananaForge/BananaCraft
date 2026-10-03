-- BananaCraft -- vormals BananaRepublik Partnerguild
-- Guild profession recipe database with sharing and search functionality
--
-- v1.0.1:
--   * PERF: guild roster is now cached instead of being queried per recipe
--           (GUILD_ROSTER_UPDATE keeps it accurate, 10s TTL as fallback)
--   * FIX:  removed emoji from chat output - the 1.12 client font has no
--           glyphs for them and rendered empty boxes. Replaced with colour codes.
-- Author: Lumihunt
-- Total: 1,513 recipes across 7 professions


-- Recipe maps loaded from BananaCraft_RecipeMaps.lua
-- Access via: BCRAFT_RecipeMaps[professionName][recipeName] = categoryName

-- -------------------------
-- German → English Profession Name Mapping
-- -------------------------
local ProfessionNameMap = {
  -- German → English
  ["Alchemie"] = "Alchemy",
  ["Schmiedekunst"] = "Blacksmithing",
  ["Verzauberkunst"] = "Enchanting",
  ["Verzauberungskunst"] = "Enchanting",
  ["Ingenieurskunst"] = "Engineering",
  ["Juwelierskunst"] = "Jewelcrafting",
  ["Lederverarbeitung"] = "Leatherworking",
  ["Schneiderei"] = "Tailoring",
  -- English names stay the same
  ["Alchemy"] = "Alchemy",
  ["Blacksmithing"] = "Blacksmithing",
  ["Enchanting"] = "Enchanting",
  ["Engineering"] = "Engineering",
  ["Jewelcrafting"] = "Jewelcrafting",
  ["Leatherworking"] = "Leatherworking",
  ["Tailoring"] = "Tailoring",
}

-- Normalize profession name to English
local function normalizeProfessionName(profName)
  return ProfessionNameMap[profName] or profName
end

local ADDON_NAME = "BananaCraft"
local DB_NAME = "BananaCraftDB"
local PREFIX = "BCRAFT0"
local DEBUG = false  -- Debug messages OFF by default (use /bc debug to enable)
local ADDON_VERSION = "2.2.1"  -- keep in sync with the .toc "## Version:" line

-- /bc versioncheck state (see startHashSync section for PING/PONG, this is
-- the separate, simpler VCHECK/VERSION request/response pair)
VersionCheckResponses = VersionCheckResponses or {}
VersionCheckActive = false

local tlen = table.getn
local LastScannedProf = {}  -- Now per-character: LastScannedProf[charName] = profName

-- -------------------------
-- Utility
-- -------------------------
local function msg(text)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd200BananaCraft:|r " .. text)
end

local function debug(text)
  if DEBUG then
    DEFAULT_CHAT_FRAME:AddMessage("|cff888888[BananaCraft Debug]|r " .. text)
  end
end

local function now()
  return date("%Y-%m-%d %H:%M:%S")
end

local function playerName()
  return UnitName("player") or "Unknown"
end

-- -------------------------
-- Gildenbewusste Schluessel
--
-- Frueher war der Schluessel in db.guild einfach der Charaktername. Sobald
-- eine Partnergilde dazukommt, reicht das nicht mehr: zwei Gilden koennen
-- denselben Charakternamen haben (und selbst wenn nicht, muss die UI ja
-- anzeigen, zu welcher Gilde jemand gehoert).
--
-- Neuer Schluessel: "Charname@Gildenname".
-- Dieselbe Zeichenkette wandert auch ueber das Netzwerk, damit Sender und
-- Empfaenger garantiert denselben Schluessel bilden.
-- -------------------------
function BCRAFT_OwnGuild()
  local g = GetGuildInfo and GetGuildInfo("player")
  if g and g ~= "" then return g end

  -- Ohne Gilde: KEIN fester Sammelbegriff wie "Ohne Gilde".
  --
  -- Zwei gildenlose Spieler haetten sonst dieselbe Kennung. Folge waere,
  -- dass jeder die Daten des anderen fuer eigene haelt -- der
  -- Schleifenschutz beim Senden (Gilde == eigene Gilde) greift dann nicht
  -- mehr und beide schicken sich die Daten endlos zurueck. Ausserdem wuerde
  -- "/bc partner remove" alle Gildenlosen auf einmal rauswerfen.
  --
  -- Darum eine pro Charakter eindeutige Kennung. In der Oberflaeche wird
  -- sie ueber BCRAFT_GuildLabel() wieder lesbar gemacht.
  return "Solo:" .. (UnitName("player") or "Unknown")
end

-- Anzeigename einer Gilde. Die Solo-Kennung von oben ist technisch
-- notwendig, aber niemand will "Solo:Thrall" im Fenster lesen.
function BCRAFT_GuildLabel(guild)
  if not guild or guild == "" then return "" end
  if string.sub(guild, 1, 5) == "Solo:" then
    return BCRAFT_L.PARTNER_NO_GUILD .. " (" .. string.sub(guild, 6) .. ")"
  end
  return guild
end

function BCRAFT_MakeKey(player, guild)
  if not player or player == "" then return nil end
  -- Leere Gilde darf nie zu einem Sammel-Schluessel werden (siehe
  -- BCRAFT_OwnGuild): sonst laufen wieder mehrere Spieler unter einer Kennung.
  if not guild or guild == "" then guild = BCRAFT_OwnGuild() end
  return player .. "@" .. guild
end

function BCRAFT_SplitKey(key)
  if not key then return nil, nil end
  local at = string.find(key, "@", 1, true)
  if not at then
    -- Alter Schluessel ohne Gilde (vor der Migration)
    return key, nil
  end
  return string.sub(key, 1, at - 1), string.sub(key, at + 1)
end

local function myKey()
  return BCRAFT_MakeKey(playerName(), BCRAFT_OwnGuild())
end

local function ensureDB()
  if not _G[DB_NAME] then _G[DB_NAME] = {} end
  local db = _G[DB_NAME]
  if not db.guild then db.guild = {} end

  -- Einmalig: Reste der entfernten Testdaten (/bctest) aus alten
  -- SavedVariables loeschen, damit sie nie an echte Gilden gehen.
  if not db.testPurged then
    for key, data in pairs(db.guild) do
      if type(data) == "table" and data.isTestData then db.guild[key] = nil end
    end
    db.testPurged = true
  end

  -- MIGRATION auf gildenbewusste Schluessel.
  -- Laeuft genau einmal (db.schema wird danach gesetzt). Alte Eintraege
  -- ohne "@" bekommen die EIGENE Gilde angehaengt -- das ist die einzig
  -- sinnvolle Annahme, denn vor dieser Version konnten ueberhaupt nur
  -- Daten aus der eigenen Gilde in der DB landen.
  if not db.schema or db.schema < 2 then
    local ownGuild = BCRAFT_OwnGuild()
    local migrated = 0
    local rekeyed = {}

    for key, data in pairs(db.guild) do
      if string.find(key, "@", 1, true) then
        rekeyed[key] = data               -- schon migriert, unveraendert lassen
      else
        local newKey = BCRAFT_MakeKey(key, ownGuild)
        if rekeyed[newKey] then
          -- Kollision: neueren Datensatz behalten, nichts stillschweigend wegwerfen.
          -- "YYYY-MM-DD HH:MM:SS" sortiert als String korrekt chronologisch,
          -- darum reicht hier ein simpler Stringvergleich (parseTimestamp ist
          -- an dieser Stelle im File noch nicht als local sichtbar).
          local oldTs = tostring(rekeyed[newKey].updated or "")
          local newTs = tostring(data.updated or "")
          if newTs > oldTs then rekeyed[newKey] = data end
        else
          rekeyed[newKey] = data
        end
        migrated = migrated + 1
      end
    end

    db.guild = rekeyed
    db.schema = 2

    if migrated > 0 then
      debug("Migration: " .. migrated .. " Eintraege auf Gildenschluessel umgestellt (Gilde: " .. ownGuild .. ")")
    end
  end

  -- MIGRATION 2 -> 3: der alte Sammel-Schluessel "Ohne Gilde" wird durch die
  -- pro Charakter eindeutige Solo-Kennung ersetzt. Betroffen ist nur der
  -- EIGENE Charakter -- fremde Eintraege unter "Ohne Gilde" stammen von
  -- anderen Spielern, deren echte Kennung wir nicht kennen; die bleiben
  -- stehen und verschwinden beim naechsten Sync von selbst.
  if db.schema < 3 then
    local me = playerName()
    local legacyKey = me .. "@Ohne Gilde"
    if db.guild[legacyKey] then
      local newKey = BCRAFT_MakeKey(me, BCRAFT_OwnGuild())
      if newKey ~= legacyKey then
        if not db.guild[newKey] then
          db.guild[newKey] = db.guild[legacyKey]
        end
        db.guild[legacyKey] = nil
        debug("Migration: eigener Solo-Eintrag umgestellt auf " .. newKey)
      end
    end
    db.schema = 3
  end

  -- Partnergilden-Bereich
  if not db.partner then
    db.partner = {
      code = nil,      -- aktueller Einladecode (12 Zeichen)
      channel = nil,   -- abgeleiteter Kanalname, zur Laufzeit gesetzt
      guilds = {},     -- bekannte Partnergilden
      enabled = false, -- Partnerfreigabe aktiv?
    }
  end
  if not db.partner.guilds then db.partner.guilds = {} end
  
  -- MIGRATION: Convert old db.me to per-character storage
  if db.me and db.me.profs and not db.characters then
    local myChar = playerName()
    db.characters = {}
    db.characters[myChar] = {
      profs = db.me.profs,
      updated = db.me.updated or now()
    }
    -- Don't delete db.me yet, just mark as migrated
    db.me._migrated = true
    
    debug("Migration complete! Your profession data has been converted.")
  end
  
  -- NEW: Per-character storage instead of account-wide
  local myChar = playerName()
  if not db.characters then db.characters = {} end
  if not db.characters[myChar] then db.characters[myChar] = {} end
  if not db.characters[myChar].profs then db.characters[myChar].profs = {} end
  if not db.characters[myChar].updated then db.characters[myChar].updated = now() end
  
  -- Keep db.me for backward compatibility (points to current character)
  db.me = db.characters[myChar]
  
  if not db.settings then db.settings = {} end
  if db.settings.onlineOnly == nil then db.settings.onlineOnly = false end
  if not db.bank then db.bank = {} end  -- Bank inventory storage
  if not db.bankScanned then db.bankScanned = nil end  -- Last bank scan timestamp
  return db
end

-- Das Partnermodul liegt in einer eigenen Datei und braucht Zugriff auf
-- dieselbe Datenbank -- ensureDB selbst bleibt local, hier nur die Bruecke.
function BCRAFT_EnsureDB()
  return ensureDB()
end

-- STEP 2: Online status via cached roster lookup
-- PERFORMANCE: The roster is scanned ONCE and cached in a lookup table.
-- Previously this function ran GuildRoster() + a full roster scan for every
-- single recipe of every crafter, on every keystroke in the search box.
local OnlineCache = {}        -- OnlineCache[name] = true/false
local OnlineCacheTime = 0     -- GetTime() of last rebuild
local ONLINE_CACHE_TTL = 10   -- seconds before the cache is considered stale

-- Rebuild the online lookup table from the guild roster (one pass).
local function refreshOnlineCache(force)
  local nowT = GetTime and GetTime() or 0

  if not force and OnlineCacheTime > 0 and (nowT - OnlineCacheTime) < ONLINE_CACHE_TTL then
    return  -- cache still fresh
  end

  OnlineCache = {}
  OnlineCacheTime = nowT

  -- Current player is always online
  OnlineCache[playerName()] = true

  if GetNumGuildMembers then
    GuildRoster()  -- one request per rebuild, not per recipe
    local numGuildMembers = GetNumGuildMembers()
    if numGuildMembers then
      for i = 1, numGuildMembers do
        local guildName, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if guildName then
          OnlineCache[guildName] = (online == 1)
        end
      end
    end
  end
end

-- Cheap lookup: no server request, no roster scan.
local function isPlayerOnline(name)
  if not name then return false end
  if name == playerName() then return true end

  refreshOnlineCache(false)
  return OnlineCache[name] == true
end

local function copyTable(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

local function norm(s)
  if not s then return "" end
  if type(s) ~= "string" then s = tostring(s) end
  return string.lower(s)
end

-- Safe timestamp parsing helper
local function parseTimestamp(timestamp)
  -- Accept epoch timestamps directly
  if type(timestamp) == "number" then
    return timestamp
  end

  if not timestamp then return nil end
  if type(timestamp) ~= "string" then return nil end

  -- trim spaces
  timestamp = string.gsub(timestamp, "^%s+", "")
  timestamp = string.gsub(timestamp, "%s+$", "")

  -- accept ISO-like "YYYY-MM-DDTHH:MM:SS"
  timestamp = string.gsub(timestamp, "T", " ")

  -- Vanilla Lua uses string.find with captures
  local _, _, year, month, day, hour, min, sec =
    string.find(timestamp, "^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$")

  if not (year and month and day and hour and min and sec) then
    return nil
  end

  return time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = tonumber(hour),
    min = tonumber(min),
    sec = tonumber(sec)
  })
end

-- -------------------------
-- Hashing helper (djb2-style, used by the ping/pong sync below)
-- -------------------------
-- Vanilla Lua 5.0 has no bitwise ops, so we keep the hash inside a plain
-- Lua number range using mod() after every multiply/add.
local function hashString(str)
  local hash = 5381
  for i = 1, string.len(str) do
    local c = string.byte(str, i)
    hash = mod(hash * 33 + c, 4294967296)
  end
  return hash
end

-- Cheap content fingerprint for one profession: sorted recipe names + how
-- many crafters we know for each. Doesn't need to be perfect, just needs to
-- change whenever the data actually changes, so two clients can agree
-- "we already have the same thing" without transferring anything.
local function professionHash(profData)
  if not profData or not profData.recipes then return 0 end

  local names = {}
  for i = 1, tlen(profData.recipes) do
    local rec = profData.recipes[i]
    if type(rec) == "table" and rec.name then
      table.insert(names, rec.name)
    end
  end
  table.sort(names)

  local s = tostring(profData.rank or 0) .. ";"
  for i = 1, tlen(names) do
    s = s .. names[i] .. ";"
  end

  return hashString(s)
end

-- -------------------------
-- Protocol safety
-- -------------------------
local SEP = "~"

-- Trenner zwischen den einzelnen Rezepten innerhalb eines Chunks.
--
-- Frueher stand hier "\n". Ueber Addon-Nachrichten (Gildenkanal) geht das
-- problemlos, aber der Partnerkanal laeuft ueber SendChatMessage -- und der
-- Chat schneidet bei einem Zeilenumbruch ab. Darum ein druckbares Zeichen,
-- das der Chat unveraendert durchreicht.
--
-- Bewusst KEIN Steuerzeichen: die filtert der Chat genauso weg wie den
-- Zeilenumbruch. "^" ist druckbar, wird unveraendert durchgereicht und
-- kommt weder in Rezeptnamen noch in Reagenzien noch in Icon-Pfaden
-- ("Interface\\Icons\\INV_...") vor. Auch nicht "~" (Feldtrenner) oder
-- "#" (Trenner innerhalb eines Rezepts).
local LINE_SEP = "^"

local function safe(str)
  if str == nil then return "" end
  if type(str) ~= "string" then str = tostring(str) end
  str = string.gsub(str, "~", "-")
  str = string.gsub(str, "%^", "-")  -- LINE_SEP darf nicht in Nutzdaten stehen
  str = string.gsub(str, "\n", " ")
  str = string.gsub(str, "\r", "")
  return str
end

-- -------------------------
-- Send queue (throttle)
-- -------------------------
local SendQueue = {}
local SendThrottle = CreateFrame("Frame")
SendThrottle:Hide()

-- Broadcast Queue for sequential profession broadcasting
local BroadcastQueue = {}
local BroadcastTimer = CreateFrame("Frame")
BroadcastTimer:Hide()
BroadcastTimer.elapsed = 0
BroadcastTimer.delay = 2.0  -- 2 seconds between broadcasts

local function enqueueSend(chatType, payload)
  table.insert(SendQueue, { chatType = chatType, payload = payload })
  SendThrottle:Show()
end

SendThrottle:SetScript("OnUpdate", function()
  this.elapsed = (this.elapsed or 0) + arg1
  
  -- Send one message every 0.1 seconds (100ms throttle)
  if this.elapsed < 0.1 then
    return
  end
  
  this.elapsed = 0
  
  if tlen(SendQueue) == 0 then
    SendThrottle:Hide()
    return
  end
  
  local item = table.remove(SendQueue, 1)
  
  if SendAddonMessage then
    local payloadSize = string.len(item.payload)
    
    -- Vanilla has 255 byte limit!
    if payloadSize > 255 then
      debug("|cffff8800[SEND] Message zu gross!|r " .. payloadSize .. " bytes (Max: 255)")
      return
    end
    
    -- Vanilla 1.12 uses 4 parameters: (prefix, message, type, target)
    local success = pcall(SendAddonMessage, PREFIX, item.payload, item.chatType, nil)
    
    if not success then
      debug("|cffff0000[SEND] FEHLER beim Senden!|r")
    end
    -- Success messages removed - no spam!
  else
    debug("|cffff0000[SEND] SendAddonMessage nicht verfuegbar!|r")
  end
end)

-- Broadcast Timer: Sends one profession every 2 seconds
BroadcastTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  
  if this.elapsed >= this.delay then
    this.elapsed = 0
    
    if tlen(BroadcastQueue) == 0 then
      BroadcastTimer:Hide()
      msg("|cff00ff00" .. BCRAFT_L.ALL_SENT .. "|r")
      return
    end
    
    -- Get next job
    local job = table.remove(BroadcastQueue, 1)
    local remaining = tlen(BroadcastQueue)
    
    msg("|cffffff00" .. BCRAFT_L.SENDING .. "|r " .. job.charName .. " - " .. BCRAFT_ProfName(job.profName) .. " (" .. remaining .. " " .. BCRAFT_L.REMAINING .. ")")
    
    -- Broadcast this profession with direct data
    BCRAFT_BroadcastProfession(job.profName, job.charName, job.profData)
  end
end)

-- -------------------------
-- Pending receive buffer
-- -------------------------
local Pending = {}

local function getPending(player, prof)
  if not Pending[player] then Pending[player] = {} end
  if not Pending[player][prof] then
    Pending[player][prof] = { total = 0, chunks = {}, rank = 0, maxRank = 0 }
  end
  return Pending[player][prof]
end

local function clearPending(player, prof)
  if Pending[player] then Pending[player][prof] = nil end
end

-- -------------------------
-- STEP 1 (Alternative): Cleanup old professions based on timestamp (5 days)
-- -------------------------
local function cleanupOldProfessions()
  -- Wrap in pcall to prevent crashes
  local success, err = pcall(function()
    local db = ensureDB()
    local currentTime = time()
    local maxAge = 14 * 24 * 60 * 60  -- 5 days in seconds
    
    local cleaned = 0
    
    for profName, profData in pairs(db.me.profs) do
      -- Safety checks
      if type(profData) == "table" and profData.scannedAt then
        local scanTime = parseTimestamp(profData.scannedAt)
        
        if scanTime then
          local age = currentTime - scanTime
          
          if age > maxAge then
            -- Older than 2 minutes - remove it
            db.me.profs[profName] = nil
            
            -- Update guild entry
            if db.guild[myKey()] and db.guild[myKey()].profs then
              db.guild[myKey()].profs[profName] = nil
            end
            
            debug("|cffff8800Gelöscht:|r " .. profName .. " (älter als 2 Minuten)")
            
            -- Broadcast deletion to guild
            local delMsg = "DEL" .. SEP .. safe(playerName()) .. SEP .. safe(profName)
            enqueueSend("GUILD", delMsg)
            
            cleaned = cleaned + 1
          end
        end
      end
    end
    
    if cleaned > 0 then
      debug("Cleanup: " .. cleaned .. " alte Berufe entfernt")
    end
  end)
  
  if not success then
    debug("Cleanup Fehler: " .. tostring(err))
  end
end

-- Cleanup old professions from ALL players (called on UI open only)
local function cleanupOldProfessionsFromAllPlayers()
  local db = ensureDB()
  local currentTime = time()
  local maxAge = 14 * 24 * 60 * 60  -- 14 Tage
  local cleaned = 0
  
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if type(profData) == "table" and profData.scannedAt then
          local scanTime = parseTimestamp(profData.scannedAt)
          
          if scanTime then
            local age = currentTime - scanTime
            if age > maxAge then
              -- Remove old profession from this player
              db.guild[player].profs[profName] = nil
              cleaned = cleaned + 1
              debug("UI-Cleanup: " .. player .. " - " .. profName .. " (Alter: " .. math.floor(age/60) .. " min)")
            end
          end
        end
      end
    end
  end
  
  if cleaned > 0 then
    debug("UI-Cleanup: " .. cleaned .. " alte Berufe von allen Spielern entfernt")
  end
end

-- -------------------------
-- Scan TradeSkill
-- -------------------------
local function scanCurrentTradeSkill()
  if not GetTradeSkillLine or not GetNumTradeSkills or not GetTradeSkillInfo then
    debug("TradeSkill API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetTradeSkillLine()
  if not profName or profName == "" then 
    debug("Kein Beruf geöffnet")
    return
  end

  -- IMPORTANT: Normalize profession name (German → English)
  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)
  
  debug("Scanne Beruf: " .. profNameOriginal .. " → " .. profName)

  -- FIXED: Check if this profession was already scanned THIS SESSION for THIS CHARACTER
  local myChar = playerName()
  if LastScannedProf[myChar] and LastScannedProf[myChar] == profName then
    debug("Beruf '" .. profName .. "' wurde bereits in dieser Session gescannt")
    return
  end
  
  LastScannedProf[myChar] = profName

  local n = GetNumTradeSkills()
  if not n or n <= 0 then 
    debug("Keine Rezepte gefunden")
    return false  -- Signal failure for retry
  end

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, skillType = GetTradeSkillInfo(i)
    if name and skillType then
      if skillType == "header" then
        currentHeader = name
        -- Header debug removed for cleaner output
      else
        -- Get item link to extract item ID (optional for Enchanting)
        local itemLink = GetTradeSkillItemLink(i)
        local itemID = nil
        local iconTexture = nil
        
        if itemLink then
          -- Extract item ID from link: |Hitem:12345:0:0:0|h
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then
            itemID = tonumber(id)
            debug("Recipe: " .. name .. " -> Item ID: " .. itemID)
          end
        else
          debug("Recipe: " .. name .. " -> No item link (Enchanting?)")
        end
        
        -- Get icon texture directly from tradeskill window
        iconTexture = GetTradeSkillIcon(i)
        
        local reagents = {}
        local numReagents = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetTradeSkillReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end
        
        -- Get tradeskill description
        local description = nil
        if GetTradeSkillDescription then
          description = GetTradeSkillDescription(i)
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,  -- May be nil for Enchanting
          icon = iconTexture,
          description = description,  -- NEW: Recipe description
        })
        
        -- Simplified debug output (Header/Category removed for cleaner log)
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()

  db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  debug("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))
  
  -- SAFETY: If no recipes found, clear cache so we can try again
  if tlen(recipes) == 0 then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    debug("WARNUNG: Keine Rezepte gefunden - Cache gelöscht für erneuten Versuch")
    return false  -- Signal failure for retry
  end

  -- STEP 1: Cleanup old professions after scan
  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BCRAFT_BroadcastProfession(profName)
  end
  
  msg("|cff00ff00" .. BCRAFT_L.SCANNED .. "|r " .. BCRAFT_ProfName(profName) .. " (" .. tlen(recipes) .. " " .. BCRAFT_L.RECIPES_SUFFIX .. ")")
  return true  -- Signal success
end

local function scanCurrentCraft()
  if not GetCraftDisplaySkillLine or not GetNumCrafts or not GetCraftInfo then
    debug("Craft API nicht verfügbar.")
    return
  end

  local profName, rank, maxRank = GetCraftDisplaySkillLine()
  if not profName or profName == "" then
    debug("Kein Craft-Beruf geöffnet")
    return
  end

  local profNameOriginal = profName
  profName = normalizeProfessionName(profName)
  
  debug("Scanne Craft: " .. profNameOriginal .. " → " .. profName)

  -- FIXED: Check if this craft profession was already scanned THIS SESSION for THIS CHARACTER
  local myChar = playerName()
  if LastScannedProf[myChar] and LastScannedProf[myChar] == profName then
    debug("Beruf '" .. profName .. "' wurde bereits in dieser Session gescannt")
    return
  end
  
  LastScannedProf[myChar] = profName

  local n = GetNumCrafts()
  if not n or n <= 0 then
    debug("Craft: Keine Rezepte gefunden")
    return false  -- Signal failure for retry
  end

  debug("Scanne Craft: " .. profName .. " (Anzahl: " .. n .. ")")

  local recipes = {}
  local currentHeader = nil

  for i = 1, n do
    local name, craftType = GetCraftInfo(i)
    if name and craftType then
      if craftType == "header" then
        currentHeader = name
        -- Header debug removed for cleaner output
      else
        local iconTexture = GetCraftIcon and GetCraftIcon(i)

        -- ItemLink/ID ist bei Enchanting oft nil – also NICHT nötig machen
        local itemLink = GetCraftItemLink and GetCraftItemLink(i)
        local itemID = nil
        if itemLink then
          local _, _, id = string.find(itemLink, "item:(%d+)")
          if id then itemID = tonumber(id) end
        end

        local reagents = {}
        local numReagents = GetCraftNumReagents and GetCraftNumReagents(i)
        if numReagents and numReagents > 0 then
          for r = 1, numReagents do
            local rName, _, rCount = GetCraftReagentInfo(i, r)
            if rName and rName ~= "" and rCount then
              table.insert(reagents, { name = rName, count = rCount })
            end
          end
        end
        
        -- Get craft description (for Enchanting spells)
        local description = nil
        if GetCraftDescription then
          description = GetCraftDescription(i)
        end

        table.insert(recipes, {
          name = name,
          header = currentHeader,
          reagents = reagents,
          itemID = itemID,     -- kann nil sein
          icon = iconTexture,  -- kann nil sein
          description = description,  -- NEW: Enchanting spell description
        })
        
        -- Detailed category debug removed for cleaner output
      end
    end
  end

  local db = ensureDB()
  db.me.profs[profName] = {
    rank = rank or 0,
    maxRank = maxRank or 0,
    recipes = recipes,
    scannedAt = now(),
  }
  db.me.updated = now()
  db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }

  debug("Gescannt: |cff00ff00" .. profName .. "|r (" .. (rank or 0) .. "/" .. (maxRank or 0) .. ") — Rezepte: " .. tostring(tlen(recipes)))
  
  -- SAFETY: If no recipes found, clear cache so we can try again
  if tlen(recipes) == 0 then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    debug("WARNUNG: Keine Rezepte gefunden - Cache gelöscht für erneuten Versuch")
    return false  -- Signal failure for retry
  end

  cleanupOldProfessions()

  local gname = GetGuildInfo and GetGuildInfo("player")
  if gname and gname ~= "" then
    BCRAFT_BroadcastProfession(profName)
  end
  
  msg("|cff00ff00" .. BCRAFT_L.SCANNED .. "|r " .. BCRAFT_ProfName(profName) .. " (" .. tlen(recipes) .. " " .. BCRAFT_L.RECIPES_SUFFIX .. ")")
  return true  -- Signal success
end

-- -------------------------
-- Delayed Scan Timer (MUST be after scan functions!)
-- -------------------------
local ScanTimer = CreateFrame("Frame")
ScanTimer:Hide()
ScanTimer.elapsed = 0
ScanTimer.delay = 0.5  -- 500ms delay
ScanTimer.scanType = nil  -- "tradeskill" or "craft"
ScanTimer.retryCount = 0
ScanTimer.maxRetries = 3

ScanTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  
  if this.elapsed >= this.delay then
    this.elapsed = 0
    ScanTimer:Hide()
    
    -- Execute the scan
    if this.scanType == "tradeskill" then
      local success = scanCurrentTradeSkill()
      
      -- Retry if failed and retries available
      if not success and this.retryCount < this.maxRetries then
        this.retryCount = this.retryCount + 1
        debug("Scan fehlgeschlagen - Retry " .. this.retryCount .. "/" .. this.maxRetries .. " in 1 Sekunde...")
        this.delay = 1.0  -- 1 second for retry
        ScanTimer:Show()
      else
        this.retryCount = 0
        this.delay = 0.5  -- Reset to default
      end
      
    elseif this.scanType == "craft" then
      local success = scanCurrentCraft()
      
      -- Retry if failed and retries available
      if not success and this.retryCount < this.maxRetries then
        this.retryCount = this.retryCount + 1
        debug("Scan fehlgeschlagen - Retry " .. this.retryCount .. "/" .. this.maxRetries .. " in 1 Sekunde...")
        this.delay = 1.0  -- 1 second for retry
        ScanTimer:Show()
      else
        this.retryCount = 0
        this.delay = 0.5  -- Reset to default
      end
    end
  end
end)

local function scheduleScan(scanType)
  ScanTimer.scanType = scanType
  ScanTimer.retryCount = 0
  ScanTimer.elapsed = 0
  ScanTimer.delay = 0.5
  ScanTimer:Show()
  debug("Scan geplant in 0.5 Sekunden...")
end


-- -------------------------
-- UI refresh debounce
--
-- Borrowed from GuildRecipes Octo's handling of UNIT_INVENTORY_CHANGED: that
-- event (and, for us, every single keystroke in the search box) can fire many
-- times in a fraction of a second. uiBuildData() re-scans the whole guild
-- database and the online roster on every call, so without debouncing, typing
-- a five-letter search term means five full rebuilds instead of one. This
-- cancels any pending rebuild and reschedules it 0.15s out, so a burst of
-- keystrokes (or any other rapid trigger) collapses into a single refresh.
-- -------------------------
local UIRefreshTimer = CreateFrame("Frame")
UIRefreshTimer:Hide()
UIRefreshTimer.elapsed = 0
UIRefreshTimer.delay = 0.15

local function scheduleUIRefresh()
  UIRefreshTimer.elapsed = 0
  UIRefreshTimer:Show()
end

UIRefreshTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < this.delay then return end

  this.elapsed = 0
  UIRefreshTimer:Hide()

  if BCRAFT_UI_Refresh then
    BCRAFT_UI_Refresh()
  end
end)

-- -------------------------
-- Broadcast
-- -------------------------
function BCRAFT_BroadcastProfession(profName, characterName, profData)
  -- profData is now passed directly instead of using db.me
  if not profData then
    -- Fallback: try to get from db.me (for backward compatibility)
    local db = ensureDB()
    profData = db.me.profs[profName]
  end
  
  if not profData then 
    debug("Keine Daten für " .. profName)
    return 
  end

  -- Uebertragen wird immer der gildenbewusste Schluessel "Name@Gilde".
  -- Kommt schon ein Schluessel mit "@" rein, bleibt er unveraendert --
  -- sonst wuerde beim Weiterreichen von Partnerdaten die fremde Gilde
  -- faelschlich durch die eigene ersetzt.
  local p = characterName or playerName()
  if not string.find(p, "@", 1, true) then
    p = BCRAFT_MakeKey(p, BCRAFT_OwnGuild())
  end
  local rank = profData.rank or 0
  local maxRank = profData.maxRank or 0
  local recipes = profData.recipes or {}

  if tlen(recipes) == 0 then
    debug("Keine Rezepte für " .. profName)
    return
  end

  local recipeData = {}
  for i = 1, tlen(recipes) do
    local rec = recipes[i]
    local recStr = safe(rec.name or "")
    
    if rec.reagents and tlen(rec.reagents) > 0 then
      local reagentStr = ""
      for r = 1, tlen(rec.reagents) do
        local rg = rec.reagents[r]
        reagentStr = reagentStr .. rg.count .. "x" .. safe(rg.name) .. ";"
      end
      recStr = recStr .. "#" .. reagentStr
    end
    
    -- Add item ID at the end (if available)
    if rec.itemID then
      recStr = recStr .. "#" .. tostring(rec.itemID)
    end
    
    -- Add icon texture (if available)
    if rec.icon then
      recStr = recStr .. "#" .. safe(rec.icon)
    end
    
    table.insert(recipeData, recStr)
  end

  local chunks = {}
  local buf = ""
  
  -- Calculate overhead: "C~PlayerName~ProfName~ChunkIndex~"
  local overhead = string.len("C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. "999" .. SEP)
  -- 240 statt 250: der Partnerkanal haengt noch "BCRAFTG1 " (9 Zeichen) davor,
  -- die fertige Zeile darf dort 250 nicht ueberschreiten.
  local maxChunkSize = 240 - overhead
  
  for i = 1, tlen(recipeData) do
    local line = recipeData[i] .. LINE_SEP
    if string.len(buf .. line) > maxChunkSize then
      table.insert(chunks, buf)
      buf = line
    else
      buf = buf .. line
    end
  end
  
  if string.len(buf) > 0 then
    table.insert(chunks, buf)
  end

  local total = tlen(chunks)
  
  debug("[SEND] Broadcasting to GUILD: " .. p .. " - " .. profName .. " (" .. total .. " chunks)")
  
  local startMsg = "S" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(rank) .. SEP .. tostring(maxRank) .. SEP .. tostring(total)
  enqueueSend("GUILD", startMsg)

  for idx = 1, total do
    local chunkMsg = "C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(idx) .. SEP .. chunks[idx]
    enqueueSend("GUILD", chunkMsg)
  end

  local endMsg = "E" .. SEP .. safe(p) .. SEP .. safe(profName)
  enqueueSend("GUILD", endMsg)

  -- Punkt 3.1: dieselben Rezeptdaten zusaetzlich in den Partnerkanal.
  --
  -- Bewusst NUR eigene Daten (Schluessel endet auf die eigene Gilde).
  -- Wuerden wir auch fremde Datensaetze weiterreichen, wuerde jede
  -- empfangene Nachricht erneut gesendet -- eine Schleife, die beide
  -- Gilden zuspammt. Jede Gilde verteilt also ausschliesslich sich selbst.
  --
  -- Bankdaten verlassen den eigenen Client an dieser Stelle NICHT: hier
  -- laufen ausschliesslich Berufs-/Rezeptdaten durch.
  local pdb = ensureDB()
  if pdb.partner and pdb.partner.enabled and BCRAFT_Partner then
    local _, pg = BCRAFT_SplitKey(p)
    if pg == BCRAFT_OwnGuild() then
      BCRAFT_Partner.Enqueue(startMsg)
      for idx = 1, total do
        BCRAFT_Partner.Enqueue("C" .. SEP .. safe(p) .. SEP .. safe(profName) .. SEP .. tostring(idx) .. SEP .. chunks[idx])
      end
      BCRAFT_Partner.Enqueue(endMsg)
    end
  end
end

-- Wrapper to send a profession even if not currently open
function BCRAFT_SendAllRecipesForProfession(profName)
  BCRAFT_BroadcastProfession(profName)
end

local function broadcastAll()
  local db = ensureDB()
  
  -- Clear existing queue
  BroadcastQueue = {}
  
  -- Send ALL professions from guild database (most up-to-date)
  if db.guild then
    for playerName, playerData in pairs(db.guild) do
      if type(playerData) == "table" and playerData.profs then
        for profName, profData in pairs(playerData.profs) do
          if type(profData) == "table" and profData.recipes and tlen(profData.recipes) > 0 then
            table.insert(BroadcastQueue, {
              charName = playerName,
              profName = profName,
              profData = profData  -- Pass the actual profession data directly
            })
            debug("Queued: " .. playerName .. " - " .. profName .. " (" .. tlen(profData.recipes) .. " recipes)")
          end
        end
      end
    end
  end
  
  local totalJobs = tlen(BroadcastQueue)
  
  if totalJobs > 0 then
    msg("|cffffff00" .. BCRAFT_L.TRANSFER_START .. "|r " .. totalJobs .. " " .. BCRAFT_L.PROFS_QUEUED)
    msg("|cff888888" .. BCRAFT_L.EST_TIME .. " " .. (totalJobs * 2) .. " " .. BCRAFT_L.SECONDS .. "|r")
    BroadcastTimer.elapsed = 0
    BroadcastTimer:Show()
  else
    msg("|cffff0000" .. BCRAFT_L.NOTHING_TO_SEND .. "|r " .. BCRAFT_L.SCAN_FIRST)
  end
end

-- -------------------------
-- Hash-based sync (PING/PONG)
--
-- Inspired by GuildRecipes Octo's approach: instead of always broadcasting
-- everything we know (which is what /bc send still does, and which is what
-- gets throttled hard by SendThrottle/BroadcastTimer on big guilds), we first
-- ask "does anyone have a different hash for profession X than me?", wait a
-- couple seconds for replies, and then only pull full data from the single
-- guildmate whose answer looked most current. Cheap ping-pong messages
-- instead of a full recipe dump for data we may already have.
--
-- This does NOT replace the S/C/E chunk format above -- once we decide we
-- need data from someone, we still ask them to run BCRAFT_BroadcastProfession
-- for that profession, and it still goes through the same two throttles.
-- -------------------------
local SyncPinging = false
local SyncBestPing = {}   -- SyncBestPing[profName] = { player = "...", updatedAt = <ts> }

local SyncTimeoutTimer = CreateFrame("Frame")
SyncTimeoutTimer:Hide()
SyncTimeoutTimer.elapsed = 0
SyncTimeoutTimer.delay = 2.0  -- same window GRO uses for ping replies

local function requestProfessionFrom(player, profName)
  debug("[SYNC] Requesting " .. profName .. " from " .. player)
  local reqMsg = "REQ" .. SEP .. safe(player) .. SEP .. safe(profName)
  enqueueSend("GUILD", reqMsg)
end

SyncTimeoutTimer:SetScript("OnUpdate", function()
  this.elapsed = this.elapsed + arg1
  if this.elapsed < this.delay then return end

  this.elapsed = 0
  SyncTimeoutTimer:Hide()

  if not SyncPinging then return end
  SyncPinging = false

  local requested = 0
  for profName, info in pairs(SyncBestPing) do
    if info and info.player then
      requestProfessionFrom(info.player, profName)
      requested = requested + 1
    end
  end

  if requested > 0 then
    msg("|cffffff00" .. BCRAFT_L.SYNC_REQUESTING .. "|r " .. requested)
  else
    msg("|cff00ff00" .. BCRAFT_L.SYNC_UP_TO_DATE .. "|r")
  end

  SyncBestPing = {}
end)

-- Ask the guild "who has newer data than me?" for every profession we track
-- locally (own + everything already in db.guild). Sends ONE small PING
-- message instead of a full broadcast.
local function startHashSync()
  local db = ensureDB()

  if SyncPinging then
    debug("[SYNC] Already pinging, ignoring duplicate /bc sync")
    return
  end

  -- Collect the newest hash+timestamp we currently have for every profession,
  -- across everyone in db.guild (so alts/other crafters are included too).
  local knownProfs = {}  -- knownProfs[profName] = { hash = n, updatedAt = ts }

  for player, data in pairs(db.guild) do
    if type(data) == "table" and data.profs then
      for profName, profData in pairs(data.profs) do
        if type(profData) == "table" and profData.recipes and tlen(profData.recipes) > 0 then
          local h = professionHash(profData)
          local ts = parseTimestamp(profData.scannedAt) or 0
          if not knownProfs[profName] or ts > knownProfs[profName].updatedAt then
            knownProfs[profName] = { hash = h, updatedAt = ts }
          end
        end
      end
    end
  end

  local count = 0
  local pingMsg = "PING"
  for profName, info in pairs(knownProfs) do
    pingMsg = pingMsg .. SEP .. safe(profName) .. SEP .. tostring(info.hash) .. SEP .. tostring(info.updatedAt)
    count = count + 1
  end

  if count == 0 then
    msg("|cffff0000" .. BCRAFT_L.NOTHING_TO_SEND .. "|r " .. BCRAFT_L.SCAN_FIRST)
    return
  end

  SyncPinging = true
  SyncBestPing = {}
  SyncTimeoutTimer.elapsed = 0
  SyncTimeoutTimer:Show()

  debug("[SYNC] Pinging guild for " .. count .. " professions")
  enqueueSend("GUILD", pingMsg)
end

-- Someone pinged us: for each profession where our hash differs, answer with
-- our own hash + timestamp so the requester can decide who has the freshest
-- copy. We never send full recipe data here -- that only happens if we're
-- picked as the "REQ" target afterwards.
local function handlePing(parts)
  local db = ensureDB()
  local sender = parts[2]  -- filled in by caller from the message's `sender`

  local pongMsg = "PONG" .. SEP .. safe(playerName())
  local answered = 0

  -- parts layout from index 2 onward: profName, hash, updatedAt, profName, hash, updatedAt, ...
  local i = 2
  while i + 2 <= tlen(parts) do
    local profName = parts[i]
    local theirHash = tonumber(parts[i + 1]) or 0

    local myProfData = db.guild[myKey()] and db.guild[myKey()].profs and db.guild[myKey()].profs[profName]
    if myProfData then
      local myHash = professionHash(myProfData)
      if myHash ~= theirHash then
        local myTs = parseTimestamp(myProfData.scannedAt) or 0
        pongMsg = pongMsg .. SEP .. safe(profName) .. SEP .. tostring(myTs)
        answered = answered + 1
      end
    end

    i = i + 3
  end

  if answered > 0 then
    enqueueSend("GUILD", pongMsg)
  end
end

-- A guildmate answered our ping. Keep track of whoever has the newest
-- timestamp per profession; once the timeout fires we ask that one player
-- (only) for the full data.
local function handlePong(parts, sender)
  if not SyncPinging then return end

  -- parts layout from index 3 onward: profName, updatedAt, profName, updatedAt, ...
  local i = 3
  while i + 1 <= tlen(parts) do
    local profName = parts[i]
    local theirTs = tonumber(parts[i + 1]) or 0

    if not SyncBestPing[profName] or theirTs > SyncBestPing[profName].updatedAt then
      SyncBestPing[profName] = { player = sender, updatedAt = theirTs }
    end

    i = i + 2
  end
end

-- -------------------------
-- Verteilung des Partnercodes in der eigenen Gilde
--
-- Damit nicht alle gleichzeitig auf eine Anfrage antworten, wartet jeder
-- Client zufaellig 1 bis 4 Sekunden. Hoert er in der Zeit die Antwort eines
-- anderen, schweigt er.
-- -------------------------
local PCodeAnswered = 0
local PCodeAnswerTimer = CreateFrame("Frame")
PCodeAnswerTimer:Hide()
PCodeAnswerTimer.due = 0

PCodeAnswerTimer:SetScript("OnUpdate", function()
  local nowT = GetTime and GetTime() or 0
  if nowT < this.due then return end

  this:Hide()

  -- Hat in der Wartezeit schon jemand geantwortet?
  if PCodeAnswered > 0 and (nowT - PCodeAnswered) < 6 then
    debug("[PCODE] Jemand anderes hat bereits geantwortet - schweige")
    return
  end

  local db = ensureDB()
  if db.partner and db.partner.enabled and db.partner.code then
    enqueueSend("GUILD", "PCODE" .. SEP .. safe(db.partner.code))
    debug("[PCODE] Code an die Gilde gesendet")
  end
end)

-- Wird vom Button "Gildenmitglieder verbinden" aufgerufen.
local function pushPartnerCodeToGuild()
  local db = ensureDB()

  if not (db.partner and db.partner.enabled and db.partner.code) then
    msg("|cffff0000" .. BCRAFT_L.PARTNER_NO_CODE .. "|r")
    return
  end

  enqueueSend("GUILD", "PCODE" .. SEP .. safe(db.partner.code))
  msg("|cff00ff00" .. BCRAFT_L.PARTNER_PUSHED .. "|r")
end

-- -------------------------
-- Receive (STEP 1: Added DELETE handling)
-- -------------------------
local function handleAddonMessage(prefix, text, distrib, sender)
  -- Ignore other addons silently
  if prefix ~= PREFIX then 
    return
  end
  
  -- Ignore own messages silently (BEFORE any debug output!)
  if sender == playerName() then 
    return
  end

  local parts = {}
  local idx = 1
  while idx <= string.len(text) do
    local nextSep = string.find(text, SEP, idx, true)
    if nextSep then
      table.insert(parts, string.sub(text, idx, nextSep - 1))
      idx = nextSep + 1
    else
      table.insert(parts, string.sub(text, idx))
      break
    end
  end

  if tlen(parts) < 1 then return end
  
  local cmd = parts[1]
  local db = ensureDB()

  -- Hash-based sync messages (see startHashSync/handlePing/handlePong above)
  if cmd == "PING" then
    -- parts[2] onward is profName/hash/updatedAt triples; handlePing needs
    -- the sender at parts[2] slot for logging, so pass parts as-is and read
    -- from index 2.
    local fakeParts = { "PING", sender }
    for i = 2, tlen(parts) do
      table.insert(fakeParts, parts[i])
    end
    handlePing(fakeParts)
    return
  end

  if cmd == "PONG" then
    handlePong(parts, sender)
    return
  end

  -- /bc versioncheck: someone is asking who's running what version
  if cmd == "VCHECK" then
    local reply = "VERSION" .. SEP .. safe(sender) .. SEP .. safe(playerName()) .. SEP .. safe(ADDON_VERSION)
    enqueueSend("GUILD", reply)
    return
  end

  if cmd == "VERSION" then
    if tlen(parts) >= 4 then
      local requester = parts[2]
      local respondent = parts[3]
      local version = parts[4]
      if requester == playerName() and VersionCheckActive then
        msg("|cff00ff00" .. respondent .. "|r " .. BCRAFT_L.VERSIONCHECK_RUNS .. " |cffffff00v" .. version .. "|r")
      end
    end
    return
  end

  -- Partnercode an die eigene Gilde verteilen.
  --
  -- Neue Mitglieder sollen den Code nicht abtippen muessen. Da alle in
  -- derselben Gilde sitzen, teilen sie ohnehin schon den Gilden-Addonkanal
  -- -- darueber geht der Code. Er verlaesst die Gilde dabei nicht.
  if cmd == "PCODE" then
    -- Nur aus der EIGENEN Gilde annehmen. Ueber den Partnerkanal koennte
    -- sonst jemand aus der anderen Gilde einen fremden Code hereinschieben
    -- und die Verbindung umlenken.
    if distrib ~= "GUILD" then
      debug("[PCODE] Verworfen: kam nicht ueber den Gildenkanal")
      return
    end

    if tlen(parts) >= 2 then
      local code = parts[2]
      local chan = BCRAFT_Partner.SplitCode(code)
      if not chan then
        debug("[PCODE] Ungueltiger Code von " .. tostring(sender))
        return
      end

      -- Wer die Partnerschaft bewusst verlassen hat, wird nicht wieder
      -- hineingezogen. Sonst wuerde jedes /bc partner leave beim naechsten
      -- Verteilen rueckgaengig gemacht.
      if db.partner.declined then
        debug("[PCODE] Ignoriert (Partnerschaft wurde bewusst verlassen)")
        return
      end

      if db.partner.code == code and db.partner.enabled then
        debug("[PCODE] Code bereits aktiv, nichts zu tun")
        return
      end

      -- Alten Kanal sauber verlassen, bevor der neue betreten wird
      if db.partner.channel then
        BCRAFT_Partner.LeaveChannel(db)
        BCRAFT_Partner.ClearQueue()
      end

      db.partner.code = code
      db.partner.enabled = true
      BCRAFT_Partner.JoinChannel(db)

      msg("|cff00ff00" .. BCRAFT_L.PARTNER_AUTO_JOINED .. "|r " .. sender)
      msg("|cff888888" .. BCRAFT_L.PARTNER_AUTO_HINT .. "|r")
    end

    -- Jemand hat geantwortet: eigene geplante Antwort ist ueberfluessig
    PCodeAnswered = (GetTime and GetTime() or 0)
    PCodeAnswerTimer:Hide()
    return
  end

  -- Ein Gildenmitglied ohne Code fragt nach einem.
  --
  -- Wuerden alle sofort antworten, hagelt es bei 20 Leuten online 20
  -- identische Nachrichten. Darum wartet jeder eine zufaellige Zeit und
  -- bricht ab, sobald jemand anderes schon geantwortet hat.
  if cmd == "PCODEREQ" then
    if distrib ~= "GUILD" then return end
    if db.partner and db.partner.enabled and db.partner.code then
      PCodeAnswerTimer.due = (GetTime and GetTime() or 0) + (random(10, 40) / 10)
      PCodeAnswerTimer:Show()
      debug("[PCODE] " .. tostring(sender) .. " fragt nach dem Partnercode - Antwort geplant")
    end
    return
  end

  if cmd == "REQ" then
    if tlen(parts) >= 3 then
      local targetPlayer = parts[2]
      local profName = parts[3]
      if targetPlayer == playerName() then
        debug("[SYNC] " .. sender .. " requested " .. profName .. " from us")
        local myProfData = db.guild[myKey()] and db.guild[myKey()].profs and db.guild[myKey()].profs[profName]
        if myProfData then
          BCRAFT_BroadcastProfession(profName, playerName(), myProfData)
        end
      end
    end
    return
  end

  -- STEP 1: Handle DELETE messages
  if cmd == "DEL" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      if db.guild[player] and db.guild[player].profs then
        db.guild[player].profs[prof] = nil
        debug("|cffff8800Empfangen:|r " .. player .. " hat " .. prof .. " verlernt")
        debug("DELETE: " .. player .. " - " .. prof)
        
        if BCRAFT_UI and BCRAFT_UI:IsShown() then
          BCRAFT_UI_Refresh()
        end
      end
    end
    return
  end

  if cmd == "S" then
    if tlen(parts) >= 6 then
      local player = parts[2]
      local prof = parts[3]
      local rankS = parts[4]
      local maxS = parts[5]
      local totalS = parts[6]
      
      local pend = getPending(player, prof)
      pend.total = tonumber(totalS) or 0
      pend.rank = tonumber(rankS) or 0
      pend.maxRank = tonumber(maxS) or 0
      pend.chunks = {}
      -- Start message removed - no spam!
    end
    return
  end

  if cmd == "C" then
    if tlen(parts) >= 4 then
      local player = parts[2]
      local prof = parts[3]
      local idxS = parts[4]
      local chunk = parts[5] or ""
      
      local pend = getPending(player, prof)
      local chunkIdx = tonumber(idxS)
      if chunkIdx then
        pend.chunks[chunkIdx] = chunk
        
        -- Calculate total from highest chunk index if not set yet
        if not pend.total or pend.total == 0 then
          local maxIdx = 0
          for idx, _ in pairs(pend.chunks) do
            if idx > maxIdx then maxIdx = idx end
          end
          if maxIdx > 0 then
            pend.total = maxIdx
          end
        end
        
        local totalStr = pend.total and pend.total > 0 and tostring(pend.total) or "?"
        debug("[RECEIVE] Chunk " .. chunkIdx .. "/" .. totalStr .. " (" .. player .. " - " .. prof .. ")")
      end
    end
    return
  end

  if cmd == "E" then
    if tlen(parts) >= 3 then
      local player = parts[2]
      local prof = parts[3]
      
      local pend = getPending(player, prof)
      local total = pend.total or 0
      local got = 0
      for k, v in pairs(pend.chunks) do
        if v then got = got + 1 end
      end

      debug("[RECEIVE] Complete: " .. player .. " - " .. prof .. " (" .. got .. "/" .. total .. " chunks)")

      if got >= total and total > 0 then
        local full = ""
        for i = 1, total do
          if pend.chunks[i] then
            full = full .. pend.chunks[i]
          end
        end

        local recipes = {}
        local lineIdx = 1
        while lineIdx <= string.len(full) do
          local lineEnd = string.find(full, LINE_SEP, lineIdx, true)
          if lineEnd then
            local line = string.sub(full, lineIdx, lineEnd - 1)
            if line and line ~= "" then
              local recipeName = line
              local reagents = {}
              local itemID = nil
              local iconTexture = nil
              
              -- Format: RecipeName#reagents;#itemID#iconTexture
              local firstSep = string.find(line, "#", 1, true)
              if firstSep then
                recipeName = string.sub(line, 1, firstSep - 1)
                local remainder = string.sub(line, firstSep + 1)
                
                -- Check for second # (item ID / icon)
                local secondSep = string.find(remainder, "#", 1, true)
                local reagentPart = remainder
                
                if secondSep then
                  reagentPart = string.sub(remainder, 1, secondSep - 1)
                  local metaPart = string.sub(remainder, secondSep + 1)
                  
                  -- Check for third # (icon texture)
                  local thirdSep = string.find(metaPart, "#", 1, true)
                  if thirdSep then
                    local itemIDStr = string.sub(metaPart, 1, thirdSep - 1)
                    iconTexture = string.sub(metaPart, thirdSep + 1)
                    itemID = tonumber(itemIDStr)
                  else
                    -- Only item ID, no icon
                    itemID = tonumber(metaPart)
                  end
                end
                
                -- Parse reagents
                local rIdx = 1
                while rIdx <= string.len(reagentPart) do
                  local rEnd = string.find(reagentPart, ";", rIdx, true)
                  if rEnd then
                    local rStr = string.sub(reagentPart, rIdx, rEnd - 1)
                    local xPos = string.find(rStr, "x", 1, true)
                    if xPos then
                      local count = tonumber(string.sub(rStr, 1, xPos - 1))
                      local name = string.sub(rStr, xPos + 1)
                      if count and name then
                        table.insert(reagents, { count = count, name = name })
                      end
                    end
                    rIdx = rEnd + 1
                  else
                    break
                  end
                end
              end
              
              table.insert(recipes, { 
                name = recipeName, 
                header = nil, 
                reagents = reagents,
                itemID = itemID,  -- Store item ID
                icon = iconTexture  -- Store icon texture
              })
            end
            lineIdx = lineEnd + 1
          else
            break
          end
        end

        -- `player` ist hier bereits der gildenbewusste Schluessel "Name@Gilde".
        -- Kommt ausnahmsweise ein alter Schluessel ohne "@" an (aeltere
        -- Addon-Version in der Gilde), haengen wir die eigene Gilde an --
        -- ueber den Gildenkanal kann es ohnehin nur die eigene sein.
        if not string.find(player, "@", 1, true) then
          player = BCRAFT_MakeKey(player, BCRAFT_OwnGuild())
        end

        if not db.guild[player] then
          db.guild[player] = { updated = now(), profs = {} }
        end
        db.guild[player].profs[prof] = {
          rank = pend.rank,
          maxRank = pend.maxRank,
          recipes = recipes,
          scannedAt = now(),
        }
        db.guild[player].updated = now()

        -- Fremde Gilde? Dann als Partnergilde vermerken (fuer UI + /bc partner list)
        local _, srcGuild = BCRAFT_SplitKey(player)
        if srcGuild and BCRAFT_Partner then
          BCRAFT_Partner.NoteGuild(db, srcGuild)
        end

        debug("Empfangen: " .. player .. " — " .. prof .. " (" .. tlen(recipes) .. " Rezepte)")

        if BCRAFT_UI and BCRAFT_UI:IsShown() then
          BCRAFT_UI_Refresh()
        end
      end

      clearPending(player, prof)
    end
    return
  end
end

-- -------------------------
-- UI: Data & Filter
-- -------------------------
local UI_Search = ""
local UI_FilterProf = "ALL"
local UI_EnchantSlot = "ALL"  -- For Enchanting filter
local UI_ScrollOffset = 0
local UI_CurrentTab = 1  -- Tab system: 1 = Rezepte, 2 = Admin
local BCRAFT_VISIBLE_ROWS = 12
local BCRAFT_ROW_HEIGHT = 22

local function uiGetProfessionList()
  local db = ensureDB()
  local set = { ALL = true }
  for _, data in pairs(db.guild) do
    if data.profs then
      for pname, _ in pairs(data.profs) do
        set[pname] = true
      end
    end
  end
  local list = { "ALL" }
  for k, _ in pairs(set) do
    if k ~= "ALL" then
      table.insert(list, k)
    end
  end
  table.sort(list)
  return list
end

local function uiBuildData()
  local db = ensureDB()
  local recipeMap = {}  -- Map: recipeName -> list of crafters

  -- PERFORMANCE: refresh the online lookup ONCE per rebuild, not per recipe.
  refreshOnlineCache(false)

  -- Build map of recipes to crafters
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local rec = profData.recipes[i]
            local rname = ""
            if type(rec) == "table" then
              rname = rec.name or ""
            else
              rname = rec or ""
            end
            
            -- Create unique key for recipe
            local key = profName .. ":" .. rname
            
            if not recipeMap[key] then
              recipeMap[key] = {
                recipe = rname,
                prof = profName,
                recipeData = rec,
                crafters = {}  -- List of players who can craft this
              }
            end
            
            -- `player` ist der Schluessel "Name@Gilde" -- fuer Anzeige und
            -- Online-Pruefung brauchen wir den reinen Namen.
            local pName, pGuild = BCRAFT_SplitKey(player)
            local isForeign = (pGuild ~= nil) and (pGuild ~= BCRAFT_OwnGuild())

            -- Online-Status je nach Herkunft:
            --   eigene Gilde   -> Gildenroster
            --   Partnergilde   -> Anwesenheit im Partnerkanal
            -- Bewusst als if/else statt verschachteltem and/or: sobald ein
            -- Zweig false liefert, faellt eine and/or-Kette auf den naechsten
            -- Zweig durch und liefert falsche Ergebnisse.
            local isOnline = false
            if isForeign then
              if BCRAFT_Partner then
                isOnline = BCRAFT_Partner.IsOnline(pName or player)
              end
            else
              isOnline = isPlayerOnline(pName or player)
            end

            table.insert(recipeMap[key].crafters, {
              player = pName or player,
              guild = pGuild,
              foreign = isForeign,
              rank = profData.rank or 0,
              maxRank = profData.maxRank or 0,
              online = isOnline
            })
          end
        end
      end
    end
  end
  
  -- Convert map to list
  local results = {}
  for key, data in pairs(recipeMap) do
    table.insert(results, data)
  end

  return results
end

local function uiFilterData(data)
  local filtered = {}
  local searchL = norm(UI_Search)

  for i = 1, tlen(data) do
    local row = data[i]
    
    -- Filter by profession
    local profMatch = (UI_FilterProf == "ALL") or (row.prof == UI_FilterProf)
    
    if profMatch then
      local searchMatch = false
      if searchL == "" then
        searchMatch = true
      else
        local rL = norm(row.recipe)
        if string.find(rL, searchL, 1, true) then
          searchMatch = true
        end
      end
      
      -- Subcategory filter
      local slotMatch = true
      if UI_EnchantSlot ~= "ALL" and UI_EnchantSlot ~= "" then
        -- Use recipe-to-category mapping (loaded from BCRAFT_RecipeMaps)
        local recipeCategory = nil
        
        if BCRAFT_RecipeMaps and BCRAFT_RecipeMaps[row.prof] then
          recipeCategory = BCRAFT_RecipeMaps[row.prof][row.recipe]
          
          -- DEBUG: Show what's not matching
          if not recipeCategory then
            debug("MISSING RECIPE MAP: prof='" .. tostring(row.prof) .. "' recipe='" .. tostring(row.recipe) .. "'")
          end
        end
        
        if recipeCategory and recipeCategory == UI_EnchantSlot then
          slotMatch = true
        else
          slotMatch = false
        end
      end
      
      -- Always show all recipes (no online filter)
      if searchMatch and slotMatch then
        table.insert(filtered, row)
      end
    end
  end

  return filtered
end

-- -------------------------
-- STEP 3: Inventory check for reagents (Bags + Bank)
-- -------------------------
local function getItemCountInBags(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local total = 0
  local searchName = string.lower(itemName)
  
  -- Search all bags (0 = backpack, 1-4 = bags)
  for bag = 0, 4 do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name and string.lower(name) == searchName then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              total = total + count
            end
          end
        end
      end
    end
  end
  
  return total
end

local function getItemCountInBank(itemName)
  if not itemName or itemName == "" then return 0 end
  
  local db = ensureDB()
  local searchName = string.lower(itemName)
  
  return db.bank[searchName] or 0
end

local function scanBank()
  local db = ensureDB()
  db.bank = {}  -- Clear old data
  
  -- Scan bank slots (bags -1, 5, 6, 7, 8, 9, 10, 11)
  -- Bag -1 is the main bank (28 slots)
  local bankBags = {-1, 5, 6, 7, 8, 9, 10, 11}
  local itemCount = {}
  
  for _, bag in pairs(bankBags) do
    local numSlots = GetContainerNumSlots(bag)
    if numSlots and numSlots > 0 then
      for slot = 1, numSlots do
        local itemLink = GetContainerItemLink(bag, slot)
        if itemLink then
          local _, _, name = string.find(itemLink, "%[(.+)%]")
          if name then
            local _, count = GetContainerItemInfo(bag, slot)
            if count then
              local searchName = string.lower(name)
              if not itemCount[searchName] then
                itemCount[searchName] = 0
              end
              itemCount[searchName] = itemCount[searchName] + count
            end
          end
        end
      end
    end
  end
  
  db.bank = itemCount
  db.bankScanned = now()
  
  local totalItems = 0
  for k, v in pairs(itemCount) do
    totalItems = totalItems + 1
  end
  
  debug("Bank gescannt: " .. totalItems .. " verschiedene Items gefunden")
end

-- -------------------------
-- UI: Recipe Popup
-- -------------------------
local BCRAFT_RecipePopup = nil
local BCRAFT_RecipeQuantity = 1  -- Default quantity

function BCRAFT_ShowRecipePopup(data)
  if not BCRAFT_RecipePopup then
    local pop = CreateFrame("Frame", "BCRAFT_RecipePopup", UIParent)
    BCRAFT_RecipePopup = pop
    pop:SetWidth(400)  -- Wider for table layout
    pop:SetHeight(380)  -- Taller for editbox + summary
    pop:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    pop:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    pop:SetMovable(true)
    pop:EnableMouse(true)
    pop:RegisterForDrag("LeftButton")
    pop:SetScript("OnDragStart", function() this:StartMoving() end)
    pop:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    pop:SetFrameStrata("DIALOG")

    local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", pop, "TOP", 0, -18)
    pop.title = title

    -- Recipe icon (top right, centered between title and content)
    local icon = CreateFrame("Button", nil, pop)
    icon:SetWidth(40)
    icon:SetHeight(40)
    icon:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -60, -32)  -- More right spacing (-60), lower position (-32)
    pop.icon = icon
    
    local iconTexture = icon:CreateTexture(nil, "ARTWORK")
    iconTexture:SetAllPoints(icon)
    iconTexture:SetTexture("Interface\\Icons\\Trade_Engineering")  -- Default icon
    pop.iconTexture = iconTexture
    
    -- Icon border
    local iconBorder = icon:CreateTexture(nil, "OVERLAY")
    iconBorder:SetAllPoints(icon)
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    
    -- Enable tooltip on hover
    icon:SetScript("OnEnter", function()
      if pop.currentRecipeName and type(pop.currentRecipeName) == "string" and string.len(pop.currentRecipeName) > 0 then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        
        pcall(function()
          -- Only use SetHyperlink if it's a valid item link (starts with "item:")
          if string.find(pop.currentRecipeName, "^item:") then
            GameTooltip:SetHyperlink(pop.currentRecipeName)
          else
            -- For Enchanting recipes (no item), just show the name
            GameTooltip:SetText(pop.currentRecipeName, 1, 1, 1)
          end
          GameTooltip:Show()
        end)
      end
    end)
    
    icon:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    local close = CreateFrame("Button", nil, pop, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", pop, "TOPRIGHT", -6, -6)

    -- STEP 3: Quantity EditBox
    local qtyLabel = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    qtyLabel:SetPoint("TOPLEFT", pop, "TOPLEFT", 22, -50)
    qtyLabel:SetText(BCRAFT_L.QUANTITY)
    pop.qtyLabelFS = qtyLabel
    
    local qtyBox = CreateFrame("EditBox", "BCRAFT_QuantityBox", pop, "InputBoxTemplate")
    qtyBox:SetWidth(60)
    qtyBox:SetHeight(20)
    qtyBox:SetPoint("LEFT", qtyLabel, "RIGHT", 10, 0)
    qtyBox:SetAutoFocus(false)
    qtyBox:SetNumeric(true)
    qtyBox:SetMaxLetters(3)
    qtyBox:SetText(tostring(BCRAFT_RecipeQuantity))
    pop.qtyBox = qtyBox
    
    qtyBox:SetScript("OnEnterPressed", function() 
      this:ClearFocus()
      local qty = tonumber(this:GetText()) or 1
      if qty < 1 then qty = 1 end
      if qty > 100 then qty = 100 end
      BCRAFT_RecipeQuantity = qty
      this:SetText(tostring(qty))
      -- Refresh display
      if pop.currentData then
        BCRAFT_UpdateRecipePopupContent(pop, pop.currentData)
      end
    end)
    
    qtyBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)

    local scrollBg = CreateFrame("Frame", nil, pop)
    scrollBg:SetPoint("TOPLEFT", pop, "TOPLEFT", 18, -80)
    scrollBg:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -38, 80)
    scrollBg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    scrollBg:SetBackdropColor(0, 0, 0, 0.8)
    
    -- Logo removed for clean background

    local scroll = CreateFrame("ScrollFrame", "BCRAFT_RecipePopupScrollFrame", pop, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", scrollBg, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", scrollBg, "BOTTOMRIGHT", -28, 8)
    pop.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(320)
    content:SetHeight(400)
    scroll:SetScrollChild(content)
    pop.content = content

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(320)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetFont("Fonts\\ARIALN.TTF", 13)  -- Use Arial Narrow for better alignment
    pop.text = text

    -- STEP 3: Missing summary
    local missingSummary = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    missingSummary:SetPoint("BOTTOMLEFT", pop, "BOTTOMLEFT", 22, 50)
    missingSummary:SetPoint("BOTTOMRIGHT", pop, "BOTTOMRIGHT", -22, 50)
    missingSummary:SetJustifyH("LEFT")
    missingSummary:SetHeight(20)
    pop.missingSummary = missingSummary

    -- Whisper dropdown button (centered at bottom, no checkbox)
    local whisperBtn = CreateFrame("Button", nil, pop, "UIPanelButtonTemplate")
    whisperBtn:SetWidth(200)
    whisperBtn:SetHeight(24)
    whisperBtn:SetPoint("BOTTOM", pop, "BOTTOM", 0, 18)
    whisperBtn:SetText(BCRAFT_L.WHISPER)
    pop.whisperBtn = whisperBtn
    
    whisperBtn:SetScript("OnClick", function()
      if not pop.currentData or not pop.currentData.crafters then return end
      
      -- Build menu with ONLY online crafters
      local menu = {}
      local hasOnline = false
      
      for i = 1, tlen(pop.currentData.crafters) do
        local crafter = pop.currentData.crafters[i]
        if crafter.online then
          hasOnline = true
          local info = {}
          info.text = crafter.player .. " (" .. crafter.rank .. "/" .. crafter.maxRank .. ")"
          info.notCheckable = true
          info.func = function()
            local editbox = DEFAULT_CHAT_FRAME.editBox or ChatFrameEditBox
            if editbox then
              editbox:SetText("/w " .. crafter.player .. " ")
              editbox:Show()
              editbox:SetFocus()
            end
          end
          table.insert(menu, info)
        end
      end
      
      -- If no one online, show banana message
      if not hasOnline then
        debug("|cffff8800Leider ist derzeit keine Banane Online die dir hier weiterhelfen kann!|r")
        return
      end
      
      -- Show dropdown menu with online crafters
      if tlen(menu) > 0 then
        local dropdown = CreateFrame("Frame", "BCRAFT_WhisperMenu", pop, "UIDropDownMenuTemplate")
        UIDropDownMenu_Initialize(dropdown, function()
          for i = 1, tlen(menu) do
            UIDropDownMenu_AddButton(menu[i])
          end
        end, "MENU")
        ToggleDropDownMenu(1, nil, dropdown, whisperBtn, 0, 0)
      end
    end)

    pop:Hide()
  end

  local pop = BCRAFT_RecipePopup
  pop.currentData = data
  pop.title:SetText(data.recipe or "Rezept")
  
  -- Use item ID if available (from recipeData)
  local itemID = nil
  local iconTexture = nil
  
  if data.recipeData then
    itemID = data.recipeData.itemID
    iconTexture = data.recipeData.icon
  end
  
  -- PRIORITY 1: Use stored icon texture (from scan) - NO CACHING!
  if iconTexture and type(iconTexture) == "string" and string.len(iconTexture) > 0 then
    pop.iconTexture:SetTexture(iconTexture)
    debug("Icon: Using stored texture: " .. iconTexture)
  -- PRIORITY 2: Try GetItemInfo WITHOUT caching
  elseif itemID then
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(itemID)
    
    if texture then
      pop.iconTexture:SetTexture(texture)
      debug("Icon: Loaded from ItemID: " .. tostring(itemID))
    else
      -- Fallback to profession icon - NO CACHING!
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon")
    end
  else
    -- PRIORITY 3: Legacy - try by name WITHOUT caching
    local _, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(data.recipe)
    
    if itemTexture then
      pop.iconTexture:SetTexture(itemTexture)
      debug("Icon: Loaded from name: " .. (data.recipe or "nil"))
    else
      -- Fallback to profession icon
      local professionIcons = {
        ["Alchemy"] = "Interface\\Icons\\Trade_Alchemy",
        ["Blacksmithing"] = "Interface\\Icons\\Trade_BlackSmithing",
        ["Enchanting"] = "Interface\\Icons\\Trade_Engraving",
        ["Engineering"] = "Interface\\Icons\\Trade_Engineering",
        ["Leatherworking"] = "Interface\\Icons\\Trade_LeatherWorking",
        ["Tailoring"] = "Interface\\Icons\\Trade_Tailoring",
        ["Cooking"] = "Interface\\Icons\\INV_Misc_Food_15",
        ["First Aid"] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
      }
      local iconPath = professionIcons[data.prof] or "Interface\\Icons\\INV_Misc_QuestionMark"
      pop.iconTexture:SetTexture(iconPath)
      debug("Icon: Fallback to profession icon (no name match)")
    end
  end
  
  -- Set tooltip item for hover
  if itemID then
    pop.currentRecipeName = "item:" .. tostring(itemID)
  else
    pop.currentRecipeName = data.recipe
  end
  
  -- Reset quantity box
  pop.qtyBox:SetText(tostring(BCRAFT_RecipeQuantity))
  
  BCRAFT_UpdateRecipePopupContent(pop, data)

  pop:Show()
end

-- STEP 3: Update popup content with inventory check first, then crafter list at bottom
function BCRAFT_UpdateRecipePopupContent(pop, data)
  local qty = BCRAFT_RecipeQuantity
  local db = ensureDB()
  
  local infoText = ""
  local missing = {}
  
  -- Show last bank scan
  if db.bankScanned then
    infoText = infoText .. "|cffaaaaaa(Bank: " .. db.bankScanned .. ")|r\n\n"
  end
  
  -- NEW: Show recipe description (for Enchanting spells)
  if type(data.recipeData) == "table" and data.recipeData.description and data.recipeData.description ~= "" then
    infoText = infoText .. "|cff00ff00" .. data.recipeData.description .. "|r\n\n"
  end
  
  if type(data.recipeData) == "table" and data.recipeData.reagents then
    local reagents = data.recipeData.reagents
    if tlen(reagents) > 0 then
      infoText = infoText .. "|cffffff00Materialien (x" .. qty .. "):|r\n\n"
      infoText = infoText .. "|cffaaaaaa Benötigt:|r\n"
      
      -- First: Show all required items
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        infoText = infoText .. string.format("• %dx %s\n", needed, r.name or "?")
      end
      
      infoText = infoText .. "\n|cffaaaaaa Verfügbar (Bank):|r\n"
      
      -- Second: Show inventory for each item
      for i = 1, tlen(reagents) do
        local r = reagents[i]
        local needed = (r.count or 1) * qty
        local haveBags = getItemCountInBags(r.name or "")
        local haveBank = getItemCountInBank(r.name or "")
        local haveTotal = haveBags + haveBank
        
        local status = ""
        local haveColor = ""
        
        if haveTotal >= needed then
          status = " |cff00ff00✓|r"
          haveColor = "|cff00ff00"
        else
          status = " |cffff0000✗|r"
          haveColor = "|cffff0000"
          local missingCount = needed - haveTotal
          table.insert(missing, missingCount .. "x " .. (r.name or "?"))
        end
        
        -- Show: Name: Total (Bank only)
        local countStr = ""
        if haveBank > 0 then
          countStr = string.format("%d (%d)", haveTotal, haveBank)
        else
          countStr = tostring(haveTotal)
        end
        
        infoText = infoText .. "• " .. (r.name or "?") .. ": " .. haveColor .. countStr .. "|r" .. status .. "\n"
      end
    end
  end
  
  -- NOW: Add crafter list at the bottom
  infoText = infoText .. "\n|cffffff00━━━━━━━━━━━━━━━━━━━━━━|r\n"
  infoText = infoText .. "|cffffff00Kann hergestellt werden von:|r\n\n"
  
  if data.crafters and tlen(data.crafters) > 0 then
    -- Sort crafters: online first, then by name
    local sortedCrafters = {}
    for i = 1, tlen(data.crafters) do
      table.insert(sortedCrafters, data.crafters[i])
    end
    table.sort(sortedCrafters, function(a, b)
      if a.online ~= b.online then
        return a.online  -- online first
      end
      return a.player < b.player
    end)
    
    -- Display ALL crafters (online and offline)
    for i = 1, tlen(sortedCrafters) do
      local crafter = sortedCrafters[i]
      local statusColor = crafter.online and "|cff00ff00" or "|cff888888"
      local statusText = crafter.online and BCRAFT_L.ONLINE or BCRAFT_L.OFFLINE
      
      infoText = infoText .. "• " .. statusColor .. crafter.player .. "|r"

      -- Partnergilde sichtbar kennzeichnen
      if crafter.foreign and crafter.guild then
        infoText = infoText .. " |cff66ccff<" .. BCRAFT_GuildLabel(crafter.guild) .. ">|r"
      end

      infoText = infoText .. " |cffaaaaaa(" .. (data.prof or "") .. " " .. crafter.rank .. "/" .. crafter.maxRank .. ")"
      if crafter.foreign then
        -- Online = sitzt im Partnerkanal. Offline heisst hier genauer:
        -- nicht im Kanal -- also entweder ausgeloggt oder ohne Addon.
        if crafter.online then
          infoText = infoText .. " " .. BCRAFT_L.ONLINE .. "|r\n"
        else
          infoText = infoText .. " " .. BCRAFT_L.PARTNER_NOT_IN_CHANNEL .. "|r\n"
        end
      else
        infoText = infoText .. " " .. statusText .. "|r\n"
      end
    end
  else
    infoText = infoText .. "|cffff0000Keine Hersteller gefunden|r\n"
  end

  pop.text:SetText(infoText)
  local textHeight = pop.text:GetHeight()
  pop.content:SetHeight(math.max(textHeight + 20, 400))
  
  -- Update missing summary
  if tlen(missing) > 0 then
    pop.missingSummary:SetText("|cffff0000Fehlen:|r " .. table.concat(missing, ", "))
  else
    pop.missingSummary:SetText("|cff00ff00" .. BCRAFT_L.ALL_MATS .. "|r")
  end
end

-- -------------------------
-- UI: Refresh
-- -------------------------
function BCRAFT_UI_Refresh()
  local f = BCRAFT_UI
  if not f or not f:IsShown() then return end

  local allData = uiBuildData()
  local filtered = uiFilterData(allData)
  local totalItems = tlen(filtered)

  local sb = f.scrollbar
  if sb then
    local maxScroll = math.max(0, totalItems - f.visibleRows)
    sb:SetMinMaxValues(0, maxScroll)
    
    if UI_ScrollOffset > maxScroll then UI_ScrollOffset = maxScroll end
    if UI_ScrollOffset < 0 then UI_ScrollOffset = 0 end
    
    sb:SetValue(UI_ScrollOffset)
    
    if maxScroll > 0 then sb:Show() else sb:Hide() end
  end

  for i = 1, f.visibleRows do
    local row = f.rows[i]
    local dataIndex = UI_ScrollOffset + i

    if dataIndex <= totalItems then
      local data = filtered[dataIndex]
      
      -- Count online vs total crafters
      local onlineCount = 0
      local totalCount = tlen(data.crafters)
      
      for c = 1, totalCount do
        if data.crafters[c].online then
          onlineCount = onlineCount + 1
        end
      end
      
      -- Display recipe name
      row.recipe:SetText(data.recipe or "")
      
      -- Display crafter info
      local crafterText = ""
      if onlineCount > 0 then
        crafterText = "|cff00ff00" .. onlineCount .. " " .. BCRAFT_L.ONLINE .. "|r"
      else
        crafterText = "|cff888888" .. totalCount .. " " .. BCRAFT_L.OFFLINE .. "|r"
      end
      
      if totalCount > 1 then
        crafterText = crafterText .. " |cffaaaaaa(" .. totalCount .. " " .. BCRAFT_L.TOTAL .. ")|r"
      end
      
      crafterText = crafterText .. " |cff888888- " .. BCRAFT_ProfName(data.prof or "") .. "|r"
      row.who:SetText(crafterText)
      
      row.data = data
      row:Show()
    else
      row:Hide()
    end
  end
  
  -- Update statistics (bottom center)
  if f.statsText then
    local db = ensureDB()
    local totalPlayers = 0
    local totalRecipes = 0
    
    -- Count unique players and total recipes
    for playerName, playerData in pairs(db.guild) do
      if playerData.profs then
        local hasRecipes = false
        for profName, profData in pairs(playerData.profs) do
          if profData.recipes and tlen(profData.recipes) > 0 then
            totalRecipes = totalRecipes + tlen(profData.recipes)
            hasRecipes = true
          end
        end
        if hasRecipes then
          totalPlayers = totalPlayers + 1
        end
      end
    end
    
    f.statsText:SetText(totalPlayers .. " Spieler | " .. totalRecipes .. " Rezepte")
  end
end

-- -------------------------
-- UI: Create
-- -------------------------
local function uiCreate()
  -- Defensive check: if a previous session already built BCRAFT_UI but somehow
  -- without the info/language buttons (e.g. an older cached UI state after
  -- a partial reload), rebuild from scratch instead of silently keeping a
  -- half-built frame around. This is what caused the info/language buttons
  -- to "disappear" even though the button-creation code was present.
  if BCRAFT_UI then
    if BCRAFT_UI.infoBtn and BCRAFT_UI.deBtn and BCRAFT_UI.enBtn and BCRAFT_UI.connectBtn then
      return
    else
      debug("[UI] BCRAFT_UI existierte bereits, aber ohne Info/Sprach-Buttons - baue Fenster neu auf.")
      BCRAFT_UI:Hide()
      BCRAFT_UI:SetParent(nil)
      BCRAFT_UI = nil
    end
  end

  local f = CreateFrame("Frame", "BCRAFT_MainFrame", UIParent)
  BCRAFT_UI = f
  f:SetWidth(650)
  f:SetHeight(480)  -- Extended for statistics display
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

  -- Logo oben links. Der 1.12-Client liest nur BLP und unkomprimierte TGA
  -- mit Zweierpotenz-Kantenlaengen, daher BananaCraft_Logo.tga (128x128).
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetWidth(48)
  logo:SetHeight(48)
  logo:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -10)
  logo:SetTexture("Interface\\AddOns\\BananaCraft\\BananaCraft_Logo")

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText(BCRAFT_L.WINDOW_TITLE)
  f.titleFS = title

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)

  -- Small, unobtrusive "thank you" button left of the close button
  local infoBtn = CreateFrame("Button", nil, f)
  infoBtn:SetWidth(16)
  infoBtn:SetHeight(16)
  infoBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)

  local infoTex = infoBtn:CreateTexture(nil, "ARTWORK")
  infoTex:SetAllPoints(infoBtn)
  infoTex:SetTexture("Interface\\common\\friendship-heart")
  -- Fallback if the texture is missing on this client build
  if not infoTex:GetTexture() then
    infoTex:SetTexture("Interface\\Icons\\INV_ValentinesCard01")
  end
  infoTex:SetVertexColor(1, 0.75, 0.3)
  infoBtn.tex = infoTex

  infoBtn:SetScript("OnEnter", function()
    this.tex:SetVertexColor(1, 1, 1)
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText(BCRAFT_L.ABOUT_TOOLTIP)
    GameTooltip:Show()
  end)
  infoBtn:SetScript("OnLeave", function()
    this.tex:SetVertexColor(1, 0.75, 0.3)
    GameTooltip:Hide()
  end)
  infoBtn:SetScript("OnClick", function() BCRAFT_ShowThanksFrame() end)
  f.infoBtn = infoBtn

  -- Language buttons: EN / DE, left of the heart
  local function makeLangButton(code, label, anchorTo, xoff)
    local b = CreateFrame("Button", nil, f)
    b:SetWidth(22)
    b:SetHeight(16)
    b:SetPoint("RIGHT", anchorTo, "LEFT", xoff, 0)

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints(b)
    fs:SetText(label)
    b.fs = fs
    b.code = code

    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(this, "ANCHOR_LEFT")
      GameTooltip:SetText(BCRAFT_L.LANG_TOOLTIP)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
      BCRAFT_SetLocale(this.code)
      BCRAFT_ApplyLocale()
      msg(BCRAFT_L.LANG_SWITCHED)
    end)
    return b
  end

  local deBtn = makeLangButton("deDE", "DE", infoBtn, -4)
  local enBtn = makeLangButton("enUS", "EN", deBtn, -2)
  f.deBtn = deBtn
  f.enBtn = enBtn

  -- Clean background - no logos

  local searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  searchLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 22, -62)
  searchLabel:SetText(BCRAFT_L.SEARCH_LABEL)
  f.searchLabelFS = searchLabel

  local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  search:SetWidth(180)  -- Made narrower to fit checkbox
  search:SetHeight(20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 10, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEnterPressed", function() this:ClearFocus() end)
  search:SetScript("OnTextChanged", function()
    UI_Search = this:GetText() or ""
    UI_ScrollOffset = 0
    scheduleUIRefresh()  -- debounced: collapses fast keystrokes into one rebuild
  end)

  local BCRAFT_SubDD_Initialize  -- forward declaration (defined below, used by the filter dropdown)
  local dd = CreateFrame("Frame", "BCRAFT_FilterDropDown", f, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -54)
  f.filterDD = dd

  local function BCRAFT_FilterDD_OnClick()
    UI_FilterProf = this.value or "ALL"
    UIDropDownMenu_SetSelectedValue(dd, UI_FilterProf)
    UIDropDownMenu_SetText(BCRAFT_ProfName(UI_FilterProf), dd)
    UI_ScrollOffset = 0
    
    -- Show/hide subcategory filter for professions with categories
    local profsWithSubs = {
      ["Enchanting"] = true,
      ["Leatherworking"] = true,
      ["Alchemy"] = true,
      ["Blacksmithing"] = true,
      ["Engineering"] = true,
      ["Jewelcrafting"] = true,
      ["Tailoring"] = true
    }
    
    if profsWithSubs[UI_FilterProf] then
      BCRAFT_UI.subDD:Show()
      -- Reinitialize dropdown for new profession
      UIDropDownMenu_Initialize(BCRAFT_UI.subDD, BCRAFT_SubDD_Initialize)
      UI_EnchantSlot = "ALL"
      UIDropDownMenu_SetSelectedValue(BCRAFT_UI.subDD, UI_EnchantSlot)
      UIDropDownMenu_SetText(BCRAFT_CatName(UI_EnchantSlot), BCRAFT_UI.subDD)
    else
      BCRAFT_UI.subDD:Hide()
      UI_EnchantSlot = "ALL"  -- Reset subcategory filter
    end
    
    BCRAFT_UI_Refresh()
  end

  local function BCRAFT_FilterDD_Initialize()
    local list = uiGetProfessionList()
    local info
    for i = 1, tlen(list) do
      info = {}
      info.text = BCRAFT_ProfName(list[i])   -- display only
      info.value = list[i]                -- key stays English!
      info.func = BCRAFT_FilterDD_OnClick
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(dd, BCRAFT_FilterDD_Initialize)
  UIDropDownMenu_SetWidth(150, dd)
  UIDropDownMenu_SetSelectedValue(dd, UI_FilterProf)
  UIDropDownMenu_SetText(BCRAFT_ProfName(UI_FilterProf), dd)

  -- Subcategory Filter (visible for professions with categories)
  local subDD = CreateFrame("Frame", "BCRAFT_SubcategoryDropDown", f, "UIDropDownMenuTemplate")
  subDD:SetPoint("TOPRIGHT", dd, "BOTTOMRIGHT", 0, 6)
  f.subDD = subDD
  subDD:Hide()  -- Hidden by default
  
  local function BCRAFT_SubDD_OnClick()
    UI_EnchantSlot = this.value or "ALL"
    UIDropDownMenu_SetSelectedValue(subDD, UI_EnchantSlot)
    UIDropDownMenu_SetText(BCRAFT_CatName(UI_EnchantSlot), subDD)
    UI_ScrollOffset = 0
    BCRAFT_UI_Refresh()
  end
  
  BCRAFT_SubDD_Initialize = function()
    -- Define subcategories for each profession
    -- IMPORTANT: These must match EXACT header names from WoW profession window!
    -- Category list is derived from BCRAFT_RecipeMaps at runtime.
    -- This guarantees the dropdown can never drift out of sync with the
    -- actual data (previously several entries were typos or plural
    -- mismatches and silently returned zero results).
    local categories = {}
    if BCRAFT_RecipeMaps then
      for prof, recipes in pairs(BCRAFT_RecipeMaps) do
        local seen, list = {}, { "ALL" }
        for recipeName, catName in pairs(recipes) do
          if catName and catName ~= "" and not seen[catName] then
            seen[catName] = true
            table.insert(list, catName)
          end
        end
        -- Sort by translated label so the dropdown reads alphabetically
        -- in whichever language is active ("ALL" always stays on top).
        table.sort(list, function(a, b)
          if a == "ALL" then return true end
          if b == "ALL" then return false end
          return BCRAFT_CatName(a) < BCRAFT_CatName(b)
        end)
        categories[prof] = list
      end
    end
    
    local slots = categories[UI_FilterProf] or {"ALL"}
    local info
    for i = 1, tlen(slots) do
      info = {}
      info.text = BCRAFT_CatName(slots[i])   -- display only
      info.value = slots[i]               -- key stays English!
      info.func = BCRAFT_SubDD_OnClick
      UIDropDownMenu_AddButton(info)
    end
  end
  
  UIDropDownMenu_Initialize(subDD, BCRAFT_SubDD_Initialize)
  UIDropDownMenu_SetWidth(150, subDD)
  UIDropDownMenu_SetSelectedValue(subDD, UI_EnchantSlot)
  UIDropDownMenu_SetText(BCRAFT_CatName(UI_EnchantSlot), subDD)

  -- Clean UI - no logos

  -- Share button (bottom center)
  local shareBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  shareBtn:SetWidth(200)
  shareBtn:SetHeight(28)
  shareBtn:SetPoint("BOTTOM", f, "BOTTOM", -103, 30)  -- Higher for statistics space
  shareBtn:SetText(BCRAFT_L.SHARE_BUTTON)
  shareBtn:SetScript("OnClick", function()
    broadcastAll()
  end)
  f.shareBtn = shareBtn

  -- "Gildenmitglieder verbinden": schickt den Partnercode ueber den
  -- Gilden-Addonkanal an alle, die das Addon haben. Neue Mitglieder muessen
  -- dadurch nichts abtippen und koennen direkt danach beteilt werden.
  --
  -- Bewusst hier am Hauptfenster und NICHT auf der adminPage: die wird
  -- zwar angelegt, aber nie eingeblendet (kein Tab fuehrt dorthin), waere
  -- also unsichtbar.
  local connectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  connectBtn:SetWidth(200)
  connectBtn:SetHeight(28)
  connectBtn:SetPoint("BOTTOM", f, "BOTTOM", 103, 30)
  connectBtn:SetText(BCRAFT_L.BTN_CONNECT_MEMBERS)
  connectBtn:SetScript("OnClick", function()
    pushPartnerCodeToGuild()
  end)
  connectBtn:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(BCRAFT_L.BTN_CONNECT_MEMBERS, 1, 1, 1)
    GameTooltip:AddLine(BCRAFT_L.BTN_CONNECT_TIP1, 0.8, 0.8, 0.8, 1)
    GameTooltip:AddLine(BCRAFT_L.BTN_CONNECT_TIP2, 1, 0.6, 0.2, 1)
    GameTooltip:Show()
  end)
  connectBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.connectBtn = connectBtn
  
  -- Version text (bottom left, small font)
  local versionText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  versionText:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 12)
  versionText:SetText("v1.0.0")
  versionText:SetTextColor(0.5, 0.5, 0.5, 1)  -- Gray color
  
  -- Statistics text (bottom center, small font - below share button)
  local statsText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  statsText:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)  -- Below share button
  statsText:SetTextColor(0.5, 0.5, 0.5, 1)  -- Gray color
  f.statsText = statsText  -- Store reference for updates
  
  -- Copyright text (bottom right, small font)
  local copyrightText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  copyrightText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 12)
  copyrightText:SetText("© by Lumihunt")
  copyrightText:SetTextColor(0.5, 0.5, 0.5, 1)  -- Gray color

  -- Recipe page (existing list)
  local recipePage = CreateFrame("Frame", nil, f)
  recipePage:SetAllPoints(f)
  f.recipePage = recipePage

  local listBg = CreateFrame("Frame", nil, recipePage)
  listBg:SetPoint("TOPLEFT", recipePage, "TOPLEFT", 18, -115)
  listBg:SetPoint("BOTTOMRIGHT", recipePage, "BOTTOMRIGHT", -38, 68)  -- More space for share button + stats
  listBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  listBg:SetBackdropColor(0, 0, 0, 0.80)  -- Match popup brightness for better readability
  f.listBg = listBg
  
  -- Clean background - no watermarks

  f.visibleRows = BCRAFT_VISIBLE_ROWS
  f.rowHeight = BCRAFT_ROW_HEIGHT
  f.rows = {}

  local sb = CreateFrame("Slider", "BCRAFT_Scrollbar", recipePage)
  f.scrollbar = sb
  sb:SetOrientation("VERTICAL")
  sb:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -6, -6)
  sb:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -6, 6)
  sb:SetWidth(16)
  sb:SetMinMaxValues(0, 0)
  sb:SetValue(0)
  sb:SetValueStep(1)
  
  sb:SetBackdrop({
    bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
    edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
    tile = true, tileSize = 8, edgeSize = 8,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  
  local thumb = sb:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  thumb:SetWidth(16)
  thumb:SetHeight(24)
  sb:SetThumbTexture(thumb)
  
  sb:SetScript("OnValueChanged", function()
    UI_ScrollOffset = math.floor(this:GetValue() + 0.5)
    BCRAFT_UI_Refresh()
  end)

  local function DoScroll(delta)
    if type(delta) ~= "number" then return end
    
    local allData = uiBuildData()
    local filtered = uiFilterData(allData)
    local totalItems = tlen(filtered)
    local maxScroll = math.max(0, totalItems - f.visibleRows)
    
    UI_ScrollOffset = UI_ScrollOffset - (delta * 3)
    if UI_ScrollOffset < 0 then UI_ScrollOffset = 0 end
    if UI_ScrollOffset > maxScroll then UI_ScrollOffset = maxScroll end
    
    BCRAFT_UI_Refresh()
  end

  listBg:EnableMouseWheel(true)
  listBg:SetScript("OnMouseWheel", function()
    DoScroll(arg1)
  end)

  for i = 1, f.visibleRows do
    local row = CreateFrame("Button", nil, f)
    row:SetHeight(f.rowHeight)
    row:SetPoint("TOPLEFT", listBg, "TOPLEFT", 10, -8 - (i-1)*f.rowHeight)
    row:SetPoint("TOPRIGHT", listBg, "TOPRIGHT", -30, -8 - (i-1)*f.rowHeight)

    row.recipe = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.recipe:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.recipe:SetWidth(300)
    row.recipe:SetJustifyH("LEFT")
    row.recipe:SetTextColor(1, 1, 1, 1)  -- WHITE (R, G, B, Alpha) - like "ALL" dropdown

    row.who = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.who:SetPoint("LEFT", row, "LEFT", 310, 0)
    row.who:SetWidth(280)  -- Adjusted for wider window
    row.who:SetJustifyH("LEFT")
    row.who:SetTextColor(0.9, 0.9, 0.9, 1)  -- Light gray for better contrast

    row:SetScript("OnClick", function()
      if this and this.data then
        BCRAFT_ShowRecipePopup(this.data)
      end
    end)

    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function()
      DoScroll(arg1)
    end)

    f.rows[i] = row
  end

  -- Admin Page
  local adminPage = CreateFrame("Frame", nil, f)
  adminPage:SetAllPoints(f)
  adminPage:Hide()
  f.adminPage = adminPage
  
  local adminBg = CreateFrame("Frame", nil, adminPage)
  adminBg:SetPoint("TOPLEFT", adminPage, "TOPLEFT", 18, -130)
  adminBg:SetPoint("BOTTOMRIGHT", adminPage, "BOTTOMRIGHT", -38, 40)  -- 40 from bottom for tabs
  adminBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  adminBg:SetBackdropColor(0,0,0,0.65)
  
  local adminTitle = adminPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  adminTitle:SetPoint("TOP", adminBg, "TOP", 0, -15)
  adminTitle:SetText("Berufe Verwalten")
  
  local adminInfo = adminPage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  adminInfo:SetPoint("TOP", adminTitle, "BOTTOM", 0, -10)
  adminInfo:SetWidth(450)
  adminInfo:SetJustifyH("CENTER")
  adminInfo:SetText("Klicke auf einen Beruf um ihn zu löschen und an die Gilde zu senden")
  
  -- Create profession delete buttons (dynamically)
  f.adminButtons = {}
  
  local function refreshAdminPage()
    -- Hide all buttons first
    for i = 1, 10 do
      if f.adminButtons[i] then
        f.adminButtons[i]:Hide()
      end
    end
    
    local db = ensureDB()
    local profList = {}
    for profName, _ in pairs(db.me.profs) do
      table.insert(profList, profName)
    end
    table.sort(profList)
    
    for i = 1, tlen(profList) do
      local profName = profList[i]
      
      if not f.adminButtons[i] then
        local btn = CreateFrame("Button", nil, adminPage, "UIPanelButtonTemplate")
        btn:SetWidth(200)
        btn:SetHeight(28)
        if i == 1 then
          btn:SetPoint("TOP", adminInfo, "BOTTOM", 0, -20)
        else
          btn:SetPoint("TOP", f.adminButtons[i-1], "BOTTOM", 0, -5)
        end
        f.adminButtons[i] = btn
      end
      
      local btn = f.adminButtons[i]
      btn:SetText(profName .. " löschen")
      btn:Show()
      
      btn:SetScript("OnClick", function()
        local db = ensureDB()
        
        -- Remove profession
        db.me.profs[profName] = nil
        
        -- Update guild entry
        if db.guild[myKey()] and db.guild[myKey()].profs then
          db.guild[myKey()].profs[profName] = nil
        end
        
        debug("|cffff0000Gelöscht:|r " .. profName)
        
        -- Broadcast deletion
        local delMsg = "DEL" .. SEP .. safe(playerName()) .. SEP .. safe(profName)
        enqueueSend("GUILD", delMsg)
        
        -- Refresh admin page
        refreshAdminPage()
      end)
    end
    
    if tlen(profList) == 0 then
      adminInfo:SetText("Keine Berufe gespeichert")
    else
      adminInfo:SetText("Klicke auf einen Beruf um ihn zu löschen und an die Gilde zu senden")
    end
  end
  
  f.refreshAdminPage = refreshAdminPage
  
  -- "Datenbank an Gilde teilen" button
  local shareBtn = CreateFrame("Button", nil, adminPage, "UIPanelButtonTemplate")
  shareBtn:SetWidth(220)
  shareBtn:SetHeight(30)
  shareBtn:SetPoint("BOTTOM", adminBg, "BOTTOM", 0, 15)
  shareBtn:SetText("Datenbank an Gilde teilen")
  shareBtn:SetScript("OnClick", function()
    broadcastAll()
  end)

  -- Hinweis: "Gildenmitglieder verbinden" sitzt am Hauptfenster, nicht hier.
  -- Diese adminPage wird nie eingeblendet (kein Tab fuehrt dorthin).
  
  -- No tabs - just show recipe page
  recipePage:Show()

  f:Hide()
end

local function uiToggle()
  uiCreate()
  if BCRAFT_UI:IsShown() then
    BCRAFT_UI:Hide()
  else
    -- Cleanup old professions from all players when opening UI
    cleanupOldProfessionsFromAllPlayers()
    
    UI_ScrollOffset = 0
    BCRAFT_UI:Show()

    -- Anwesenheitsliste des Partnerkanals auffrischen. Beitritts- und
    -- Austrittsmeldungen halten sie waehrend der Sitzung aktuell, aber wer
    -- schon vor unserem Login drin sass, taucht dort nie auf.
    local d = ensureDB()
    if BCRAFT_Partner and d.partner and d.partner.enabled then
      BCRAFT_Partner.RequestRoster(d)
    end

    BCRAFT_UI_Refresh()
  end
end

-- -------------------------
-- CSV Export
-- -------------------------
local function exportToCSV()
  local db = ensureDB()
  local csv = "Spieler,Beruf,Rank,Rezept,Reagenzien\n"
  
  -- Build CSV data
  for player, data in pairs(db.guild) do
    if data.profs then
      for profName, profData in pairs(data.profs) do
        local rank = (profData.rank or 0) .. "/" .. (profData.maxRank or 0)
        
        if profData.recipes then
          for i = 1, tlen(profData.recipes) do
            local recipe = profData.recipes[i]
            local recipeName = recipe.name or "Unknown"
            
            -- Build reagent string
            local reagentStr = ""
            if recipe.reagents then
              for r = 1, tlen(recipe.reagents) do
                local rg = recipe.reagents[r]
                if r > 1 then reagentStr = reagentStr .. "; " end
                reagentStr = reagentStr .. (rg.count or 1) .. "x " .. (rg.name or "?")
              end
            end
            
            -- Escape quotes in strings
            recipeName = string.gsub(recipeName, '"', '""')
            reagentStr = string.gsub(reagentStr, '"', '""')
            
            -- Add row
            csv = csv .. string.format('%s,%s,%s,"%s","%s"\n', 
              player, profName, rank, recipeName, reagentStr)
          end
        end
      end
    end
  end
  
  -- Count lines
  local lineCount = 0
  for _ in string.gmatch(csv, "[^\n]+") do
    lineCount = lineCount + 1
  end
  
  -- Save to global variable
  BCRAFT_CSV_Export = csv
  BCRAFT_CSV_Timestamp = date("%Y-%m-%d %H:%M:%S")
  BCRAFT_CSV_Lines = lineCount
  
  -- Create export popup with copyable text
  if not BCRAFT_ExportFrame then
    local f = CreateFrame("Frame", "BCRAFT_ExportFrame", UIParent)
    f:SetWidth(600)
    f:SetHeight(400)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    
    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -20)
    title:SetText("CSV Export")
    f.title = title
    
    -- Info text
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    info:SetPoint("TOP", title, "BOTTOM", 0, -10)
    info:SetWidth(550)
    info:SetJustifyH("CENTER")
    info:SetText("|cff00ff00Strg+A → Strg+C zum Kopieren!|r")
    f.info = info
    
    -- ScrollFrame for EditBox
    local scroll = CreateFrame("ScrollFrame", "BCRAFT_ExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -80)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 50)
    
    -- EditBox (copyable!)
    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetWidth(520)
    editBox:SetHeight(280)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontWhite)
    editBox:SetFont("Fonts\\ARIALN.TTF", 11)
    editBox:SetMaxLetters(0)  -- Unlimited
    scroll:SetScrollChild(editBox)
    f.editBox = editBox
    
    editBox:SetScript("OnEscapePressed", function()
      BCRAFT_ExportFrame:Hide()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetWidth(100)
    closeBtn:SetHeight(22)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 15)
    closeBtn:SetText("Schließen")
    closeBtn:SetScript("OnClick", function()
      BCRAFT_ExportFrame:Hide()
    end)
    
    BCRAFT_ExportFrame = f
  end
  
  -- Set CSV text
  BCRAFT_ExportFrame.editBox:SetText(csv)
  BCRAFT_ExportFrame.editBox:HighlightText()  -- Pre-select all
  BCRAFT_ExportFrame.info:SetText(string.format("|cff00ff00%d Zeilen | %s|r\n|cffffff00Strg+A → Strg+C zum Kopieren!|r", lineCount, BCRAFT_CSV_Timestamp))
  BCRAFT_ExportFrame:Show()
  
  debug("|cff00ff00CSV Export-Fenster geöffnet!|r")
  debug("|cffffff00Strg+A|r → ganzen Text markieren")
  debug("|cffffff00Strg+C|r → kopieren")
  debug("Dann in Notepad einfügen und als .csv speichern!")
end

-- -------------------------
-- Slash commands
-- -------------------------
SLASH_BCRAFT1 = "/bc"
SlashCmdList["BCRAFT"] = function(input)
  input = input or ""
  
  if type(input) ~= "string" then input = "" end

  local cmd = ""
  if input ~= "" and string.len(input) > 0 then
    local success, _, _, c = pcall(string.find, input, "^(%S+)")
    if success and c then
      cmd = c
    end
  end
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "help" then
    msg(BCRAFT_L.CMD_HEADER)
    msg(BCRAFT_L.CMD_SHOW)
    msg(BCRAFT_L.CMD_SCAN)
    msg(BCRAFT_L.CMD_RESCAN)
    msg(BCRAFT_L.CMD_SEND)
    msg(BCRAFT_L.CMD_SYNC)
    msg(BCRAFT_L.CMD_VERSIONCHECK)
    msg(BCRAFT_L.CMD_PARTNER)
    msg(BCRAFT_L.CMD_DELETE)
    msg(BCRAFT_L.CMD_DELETE_ALL)
    msg(BCRAFT_L.CMD_SCANBANK)
    msg(BCRAFT_L.CMD_EXPORT)
    msg(BCRAFT_L.CMD_DEBUG)
    msg(BCRAFT_L.CMD_ABOUT)
    msg(BCRAFT_L.CMD_LANG)
    return
  end

  if cmd == "about" or cmd == "danke" or cmd == "info" then
    BCRAFT_ShowThanksFrame()
    return
  end

  if string.sub(cmd, 1, 4) == "lang" then
    local which = string.sub(cmd, 6)
    if which == "de" then which = "deDE" end
    if which == "en" then which = "enUS" end
    if which ~= "deDE" and which ~= "enUS" and which ~= "auto" then
      which = "auto"
    end
    BCRAFT_SetLocale(which)
    BCRAFT_ApplyLocale()
    msg(BCRAFT_L.LANG_SWITCHED)
    return
  end

  if cmd == "show" then uiToggle(); return end
  if cmd == "scan" then 
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    scanCurrentTradeSkill()
    return 
  end
  if cmd == "rescan" then
    local myChar = playerName()
    LastScannedProf[myChar] = nil
    msg(BCRAFT_L.CACHE_CLEARED)
    return
  end
  -- -------------------------
  -- Partnergilden-Befehle
  -- -------------------------
  if cmd == "partner" then
    local db = ensureDB()

    -- Unterbefehl + Argument aus der Eingabe holen (cmd enthaelt nur das erste Wort)
    local rest = string.sub(input, string.len("partner") + 2)
    rest = string.gsub(rest or "", "^%s+", "")
    local sub = ""
    local arg = ""
    local _, _, s, a = string.find(rest, "^(%S+)%s*(.*)$")
    if s then sub = string.lower(s) end
    if a then arg = a end
    arg = string.gsub(arg, "%s+$", "")

    -- Code erzeugen und Partnerschaft eroeffnen
    if sub == "create" then
      db.partner.code = BCRAFT_Partner.GenerateCode()
      db.partner.enabled = true
      db.partner.declined = nil   -- bewusster Wiedereintritt
      BCRAFT_Partner.JoinChannel(db)
      msg("|cff00ff00" .. BCRAFT_L.PARTNER_CREATED .. "|r")
      msg(BCRAFT_L.PARTNER_CODE_IS .. " |cffffff00" .. BCRAFT_Partner.FormatCode(db.partner.code) .. "|r")
      msg(BCRAFT_L.PARTNER_SHARE_HINT)
      return
    end

    -- Code der Partnergilde eintragen
    if sub == "add" or sub == "join" then
      if arg == "" then
        msg("|cffff0000" .. BCRAFT_L.PARTNER_NEED_CODE .. "|r")
        return
      end
      local chan = BCRAFT_Partner.SplitCode(arg)
      if not chan then
        msg("|cffff0000" .. BCRAFT_L.PARTNER_BAD_CODE .. "|r")
        return
      end
      local clean = string.upper(string.gsub(string.gsub(arg, "%s", ""), "-", ""))
      db.partner.code = clean
      db.partner.enabled = true
      db.partner.declined = nil   -- bewusster Wiedereintritt
      BCRAFT_Partner.JoinChannel(db)
      msg("|cff00ff00" .. BCRAFT_L.PARTNER_JOINED .. "|r")
      return
    end

    -- Code an die eigene Gilde verteilen (identisch zum Button)
    if sub == "push" or sub == "connect" then
      pushPartnerCodeToGuild()
      return
    end

    -- Punkt 3.3: Code anzeigen / neu erzeugen
    if sub == "code" then
      if db.partner.code then
        msg(BCRAFT_L.PARTNER_CODE_IS .. " |cffffff00" .. BCRAFT_Partner.FormatCode(db.partner.code) .. "|r")
      else
        msg(BCRAFT_L.PARTNER_NO_CODE)
      end
      return
    end

    if sub == "newcode" then
      BCRAFT_Partner.LeaveChannel(db)
      BCRAFT_Partner.ClearQueue()
      db.partner.code = BCRAFT_Partner.GenerateCode()
      db.partner.enabled = true
      db.partner.declined = nil   -- bewusster Wiedereintritt
      BCRAFT_Partner.JoinChannel(db)
      msg("|cff00ff00" .. BCRAFT_L.PARTNER_NEWCODE .. "|r")
      msg(BCRAFT_L.PARTNER_CODE_IS .. " |cffffff00" .. BCRAFT_Partner.FormatCode(db.partner.code) .. "|r")
      msg("|cffff8800" .. BCRAFT_L.PARTNER_NEWCODE_WARN .. "|r")
      return
    end

    -- Bekannte Partnergilden auflisten
    if sub == "list" then
      local list = BCRAFT_Partner.ListGuilds(db)
      if tlen(list) == 0 then
        msg(BCRAFT_L.PARTNER_NONE)
        return
      end
      msg(BCRAFT_L.PARTNER_LIST_HEADER)
      for i = 1, tlen(list) do
        local g = list[i]
        local cnt = 0
        for key, _ in pairs(db.guild) do
          local _, kg = BCRAFT_SplitKey(key)
          if kg == g then cnt = cnt + 1 end
        end
        msg("  |cff66ccff" .. BCRAFT_GuildLabel(g) .. "|r - " .. cnt .. " " .. BCRAFT_L.PARTNER_CHARS)
      end
      return
    end

    -- Punkt 3.2: Daten einer Partnergilde rauswerfen
    if sub == "remove" or sub == "kick" then
      if arg == "" then
        msg("|cffff0000" .. BCRAFT_L.PARTNER_NEED_GUILD .. "|r")
        return
      end
      if arg == BCRAFT_OwnGuild() then
        msg("|cffff0000" .. BCRAFT_L.PARTNER_CANT_REMOVE_OWN .. "|r")
        return
      end

      -- Gildenlose Partner laufen intern unter "Solo:<Charname>". Niemand
      -- soll diese Kennung kennen muessen: wenn der eingegebene Name keine
      -- bekannte Gilde ist, wird zusaetzlich die Solo-Form probiert.
      local target = arg
      local known = db.partner.guilds and db.partner.guilds[target]
      if not known and db.partner.guilds and db.partner.guilds["Solo:" .. arg] then
        target = "Solo:" .. arg
      end

      local removed = BCRAFT_Partner.PurgeGuild(db, target)
      msg("|cff00ff00" .. BCRAFT_L.PARTNER_REMOVED .. "|r " .. BCRAFT_GuildLabel(target) .. " (" .. removed .. " " .. BCRAFT_L.PARTNER_CHARS .. ")")
      if BCRAFT_UI and BCRAFT_UI:IsShown() then BCRAFT_UI_Refresh() end
      return
    end

    -- Partnerschaft komplett beenden: Kanal verlassen, alle Fremddaten weg
    if sub == "leave" or sub == "off" then
      local removedGuilds = 0
      local removedChars = 0
      local list = BCRAFT_Partner.ListGuilds(db)
      for i = 1, tlen(list) do
        removedChars = removedChars + BCRAFT_Partner.PurgeGuild(db, list[i])
        removedGuilds = removedGuilds + 1
      end
      BCRAFT_Partner.LeaveChannel(db)
      BCRAFT_Partner.ClearQueue()
      db.partner.enabled = false
      db.partner.code = nil
      -- Merken, dass die Partnerschaft bewusst beendet wurde. Sonst wuerde
      -- der naechste verteilte Code (Button oder Login-Anfrage anderer)
      -- den Austritt sofort wieder rueckgaengig machen.
      db.partner.declined = true
      msg("|cff00ff00" .. BCRAFT_L.PARTNER_LEFT .. "|r (" .. removedGuilds .. " " .. BCRAFT_L.PARTNER_GUILDS .. ", " .. removedChars .. " " .. BCRAFT_L.PARTNER_CHARS .. ")")
      if BCRAFT_UI and BCRAFT_UI:IsShown() then BCRAFT_UI_Refresh() end
      return
    end

    -- Status
    if sub == "" or sub == "status" then
      if db.partner.enabled and db.partner.code then
        msg(BCRAFT_L.PARTNER_STATUS_ON)
        msg(BCRAFT_L.PARTNER_CODE_IS .. " |cffffff00" .. BCRAFT_Partner.FormatCode(db.partner.code) .. "|r")
        local idx = BCRAFT_Partner.GetChannelIndex(db)
        if idx then
          msg("|cff00ff00" .. BCRAFT_L.PARTNER_CHANNEL_OK .. "|r")
          BCRAFT_Partner.RequestRoster(db)
          msg(BCRAFT_L.PARTNER_ONLINE_COUNT .. " |cffffff00" .. BCRAFT_Partner.PresenceCount() .. "|r")
        else
          msg("|cffff8800" .. BCRAFT_L.PARTNER_CHANNEL_MISSING .. "|r")
        end
      else
        msg(BCRAFT_L.PARTNER_STATUS_OFF)
      end
      msg(BCRAFT_L.CMD_PARTNER_CREATE)
      msg(BCRAFT_L.CMD_PARTNER_ADD)
      msg(BCRAFT_L.CMD_PARTNER_PUSH)
      msg(BCRAFT_L.CMD_PARTNER_CODE)
      msg(BCRAFT_L.CMD_PARTNER_NEWCODE)
      msg(BCRAFT_L.CMD_PARTNER_LIST)
      msg(BCRAFT_L.CMD_PARTNER_REMOVE)
      msg(BCRAFT_L.CMD_PARTNER_LEAVE)
      return
    end

    msg("|cffff0000" .. BCRAFT_L.PARTNER_UNKNOWN_SUB .. "|r " .. sub)
    return
  end

  if cmd == "send" then broadcastAll(); return end
  if cmd == "sync" then startHashSync(); return end
  if cmd == "versioncheck" then
    VersionCheckResponses = {}
    VersionCheckActive = true
    msg("|cffffff00" .. BCRAFT_L.VERSIONCHECK_ASKING .. "|r")
    enqueueSend("GUILD", "VCHECK" .. SEP .. safe(playerName()))
    return
  end
  if cmd == "scanbank" then
    scanBank()
    return
  end
  if cmd == "export" then
    exportToCSV()
    return
  end
  if cmd == "debug" then
    DEBUG = not DEBUG
    msg("Debug: " .. (DEBUG and "|cff00ff00AN|r" or "|cffff0000AUS|r"))  -- Always show this
    return
  end
  
  if cmd == "delete" then
    -- Get profession name from input
    local _, _, profName = string.find(input, "^%S+%s+(.+)")
    
    if not profName or profName == "" then
      msg(BCRAFT_L.USAGE_DELETE)
      msg(BCRAFT_L.EXAMPLE_DELETE)
      return
    end
    
    profName = string.gsub(profName, "^%s*(.-)%s*$", "%1")  -- Trim spaces
    
    local db = ensureDB()
    local myChar = playerName()
    
    if string.lower(profName) == "all" then
      -- Delete EVERYTHING - complete database wipe
      local totalChars = 0
      local totalProfs = 0
      local totalGuild = 0
      
      -- Count before deleting
      if db.characters then
        for charName, charData in pairs(db.characters) do
          totalChars = totalChars + 1
          if charData.profs then
            for prof, _ in pairs(charData.profs) do
              totalProfs = totalProfs + 1
            end
          end
        end
      end
      
      if db.guild then
        for playerName, _ in pairs(db.guild) do
          totalGuild = totalGuild + 1
        end
      end
      
      -- WIPE EVERYTHING
      db.characters = {}
      db.guild = {}
      db.me = { profs = {} }
      db.bankItems = {}
      db.bankScanned = nil
      
      -- Clear all scan caches
      LastScannedProf = {}
      
      msg("|cffff0000" .. BCRAFT_L.DB_WIPED .. "|r")
      msg("  • " .. totalChars .. " Character(e)")
      msg("  • " .. totalProfs .. " Beruf(e)")
      msg("  • " .. totalGuild .. " Gilden-Einträge")
      
      if BCRAFT_MainFrame and BCRAFT_MainFrame:IsShown() then
        BCRAFT_UI_Refresh()
      end
    else
      -- Delete specific profession (normalize name)
      local normalizedProf = normalizeProfessionName(profName)
      
      if db.characters[myChar] and db.characters[myChar].profs and db.characters[myChar].profs[normalizedProf] then
        db.characters[myChar].profs[normalizedProf] = nil
        
        -- Also clear from guild
        if db.guild[myChar] and db.guild[myChar].profs then
          db.guild[myChar].profs[normalizedProf] = nil
        end
        
        msg("|cffff0000" .. BCRAFT_L.DELETED .. "|r " .. normalizedProf)
        
        if BCRAFT_MainFrame and BCRAFT_MainFrame:IsShown() then
          BCRAFT_UI_Refresh()
        end
      else
        msg("|cffff0000Fehler:|r Beruf '" .. normalizedProf .. "' nicht gefunden")
      end
    end
    return
  end

  debug("Unbekannter Befehl. /bc help")
end

-- -------------------------
-- Events
-- -------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRADE_SKILL_SHOW")  -- Only scan when window OPENS
eventFrame:RegisterEvent("CRAFT_SHOW")         -- Only scan when window OPENS
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("BANKFRAME_OPENED")   -- Auto-scan bank
eventFrame:RegisterEvent("GUILD_ROSTER_UPDATE") -- Keep online cache accurate
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")    -- Partnerkanal
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL_JOIN")   -- Anwesenheit Partnergilde
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL_LEAVE")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL_LIST")

eventFrame:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" then
    if arg1 == ADDON_NAME then
      ensureDB()
      -- Vanilla 1.12 doesn't need RegisterAddonMessagePrefix!
      -- Addon messages work automatically
      debug("Addon geladen - Kommunikation aktiv")
      
      -- Check if send function exists
      if SendAddonMessage then
        debug("|cff00ff00SendAddonMessage verfuegbar|r")
      else
        debug("|cffff0000FEHLER: SendAddonMessage NICHT verfuegbar!|r")
      end
    end
    return
  end

  if event == "PLAYER_LOGIN" then
    ensureDB()
    local db = ensureDB()
    
    -- Data migration: Fix old corrupted profession data
    local cleaned = 0
    for profName, profData in pairs(db.me.profs) do
      if type(profData) ~= "table" then
        -- Corrupted data - remove it
        db.me.profs[profName] = nil
        cleaned = cleaned + 1
        debug("Migration: Entferne korrupte Daten für " .. profName)
      elseif not profData.scannedAt then
        -- Old data without timestamp - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Timestamp hinzugefügt für " .. profName)
      elseif parseTimestamp(profData.scannedAt) == nil then
        -- Invalid timestamp format - add current timestamp
        profData.scannedAt = now()
        debug("Migration: Invaliden Timestamp ersetzt für " .. profName)
      end
    end
    
    -- Clean ALL guild players' invalid timestamps
    for player, data in pairs(db.guild) do
      if data.profs then
        for profName, profData in pairs(data.profs) do
          if type(profData) == "table" then
            if not profData.scannedAt then
              profData.scannedAt = now()
              debug("Migration: Timestamp für " .. player .. " - " .. profName)
              elseif parseTimestamp(profData.scannedAt) == nil then
              -- Invalid timestamp format - repair instead of deleting
              profData.scannedAt = now()
              cleaned = cleaned + 1
              debug("Migration: Invaliden Timestamp repariert für " .. player .. " - " .. profName)
            end
          end
        end
      end
    end
    
    if cleaned > 0 then
      debug("Datenbank bereinigt: " .. cleaned .. " korrupte Einträge entfernt")
    end
    
    db.guild[myKey()] = { updated = db.me.updated, profs = copyTable(db.me.profs) }
    
    -- Cleanup old professions on login (2 minutes)
    cleanupOldProfessions()
    
    -- Restore the saved language (or auto-detect from the client)
    local db = ensureDB()
    BCRAFT_SetLocale(db.settings.locale or "auto")

    -- Initialize Minimap Button
    BCRAFT_MinimapButton_Init()

    -- Partnerkanal automatisch betreten, damit niemand manuell /join tippen muss.
    -- Leicht verzoegert: direkt bei PLAYER_LOGIN ist das Kanalsystem noch nicht
    -- bereit und JoinChannelByName laeuft ins Leere.
    if BCRAFT_Partner then
      BCRAFT_Partner.InstallChatFilter()

      if db.partner and db.partner.enabled and db.partner.code then
        local joiner = CreateFrame("Frame")
        joiner:Hide()
        joiner.elapsed = 0
        joiner:SetScript("OnUpdate", function()
          this.elapsed = this.elapsed + arg1
          if this.elapsed < 5.0 then return end
          this:Hide()
          this:SetScript("OnUpdate", nil)
          local d = ensureDB()
          if BCRAFT_Partner.JoinChannel(d) then
            debug("Partnerkanal betreten: " .. tostring(d.partner.channel))
            -- Kurz danach die Anwesenheitsliste holen: wer schon vor uns im
            -- Kanal sass, loest kein JOIN-Ereignis mehr aus.
            local roster = CreateFrame("Frame")
            roster:Hide()
            roster.elapsed = 0
            roster:SetScript("OnUpdate", function()
              this.elapsed = this.elapsed + arg1
              if this.elapsed < 3.0 then return end
              this:Hide()
              this:SetScript("OnUpdate", nil)
              BCRAFT_Partner.RequestRoster(ensureDB())
            end)
            roster:Show()
          end
        end)
        joiner:Show()

      elseif db.partner and not db.partner.code and not db.partner.declined then
        -- Noch kein Code vorhanden und die Partnerschaft wurde nie bewusst
        -- verlassen: einmalig in der Gilde nachfragen. Damit muss ein neues
        -- Mitglied gar nichts tun -- weder Code eintippen noch warten, bis
        -- jemand den Button drueckt.
        local asker = CreateFrame("Frame")
        asker:Hide()
        asker.elapsed = 0
        asker:SetScript("OnUpdate", function()
          this.elapsed = this.elapsed + arg1
          if this.elapsed < 8.0 then return end
          this:Hide()
          this:SetScript("OnUpdate", nil)
          enqueueSend("GUILD", "PCODEREQ" .. SEP .. safe(playerName()))
          debug("[PCODE] Partnercode in der Gilde angefragt")
        end)
        asker:Show()
      end
    end
    
    debug("geladen. /bc show")
    return
  end

  if event == "TRADE_SKILL_SHOW" then
    scheduleScan("tradeskill")
    return
  end

  if event == "CRAFT_SHOW" then
    scheduleScan("craft")
    return
  end

  -- Do NOT scan on UPDATE events - they fire constantly!
  -- Only scan when window OPENS (SHOW events above)

  if event == "GUILD_ROSTER_UPDATE" then
    -- Roster data changed: rebuild the online lookup and repaint if visible.
    refreshOnlineCache(true)
    if BCRAFT_UI and BCRAFT_UI:IsShown() then
      BCRAFT_UI_Refresh()
    end
    return
  end

  if event == "CHAT_MSG_ADDON" then
    handleAddonMessage(arg1, arg2, arg3, arg4)
    return
  end

  -- Partnerkanal: Nachrichten kommen als normaler Kanaltext an und werden
  -- hier in dieselbe Verarbeitung gefuettert wie Gilden-Addonnachrichten.
  -- arg1 = Text, arg2 = Absender, arg9 = Kanalname
  if event == "CHAT_MSG_CHANNEL" then
    local db = ensureDB()
    if not (db.partner and db.partner.enabled and db.partner.channel) then return end
    if not arg9 or string.lower(arg9) ~= string.lower(db.partner.channel) then return end

    local payload = BCRAFT_Partner.ParseIncoming(arg1)
    if not payload then return end
    if arg2 == playerName() then return end  -- eigene Nachrichten ignorieren

    handleAddonMessage(PREFIX, payload, "CHANNEL", arg2)
    return
  end

  -- Anwesenheit im Partnerkanal: wer drin sitzt, ist online und erreichbar.
  if event == "CHAT_MSG_CHANNEL_JOIN" then
    if BCRAFT_Partner.IsOwnChannel(arg9) and arg2 then
      BCRAFT_Partner.SetOnline(arg2)
      if BCRAFT_UI and BCRAFT_UI:IsShown() then scheduleUIRefresh() end
    end
    return
  end

  if event == "CHAT_MSG_CHANNEL_LEAVE" then
    if BCRAFT_Partner.IsOwnChannel(arg9) and arg2 then
      BCRAFT_Partner.SetOffline(arg2)
      if BCRAFT_UI and BCRAFT_UI:IsShown() then scheduleUIRefresh() end
    end
    return
  end

  -- Vollstaendige Kanalliste (Antwort auf ListChannelByName)
  if event == "CHAT_MSG_CHANNEL_LIST" then
    if BCRAFT_Partner.IsOwnChannel(arg9) then
      local n = BCRAFT_Partner.ParseList(arg1)
      debug("[PRESENCE] " .. n .. " Spieler im Partnerkanal")
      if BCRAFT_UI and BCRAFT_UI:IsShown() then scheduleUIRefresh() end
    end
    return
  end

  if event == "BANKFRAME_OPENED" then
    -- Auto-scan bank when opened
    scanBank()
    return
  end
end)

-- -------------------------
-- Apply the active language to every already-created widget.
-- Called after switching language so no /reload is needed.
-- -------------------------
function BCRAFT_ApplyLocale()
  local f = BCRAFT_UI

  if f then
    if f.titleFS then f.titleFS:SetText(BCRAFT_L.WINDOW_TITLE) end
    if f.searchLabelFS then f.searchLabelFS:SetText(BCRAFT_L.SEARCH_LABEL) end
    if f.shareBtn then f.shareBtn:SetText(BCRAFT_L.SHARE_BUTTON) end
    if f.connectBtn then f.connectBtn:SetText(BCRAFT_L.BTN_CONNECT_MEMBERS) end

    -- Highlight the active language button
    local cur = BCRAFT_GetLocale()
    if f.deBtn and f.deBtn.fs then
      if cur == "deDE" then f.deBtn.fs:SetTextColor(1, 0.82, 0) else f.deBtn.fs:SetTextColor(0.5, 0.5, 0.5) end
    end
    if f.enBtn and f.enBtn.fs then
      if cur == "enUS" then f.enBtn.fs:SetTextColor(1, 0.82, 0) else f.enBtn.fs:SetTextColor(0.5, 0.5, 0.5) end
    end

    -- Dropdown captions use translated text but keep English values
    if f.filterDD then
      UIDropDownMenu_SetText(BCRAFT_ProfName(UI_FilterProf), f.filterDD)
    end
    if f.subDD then
      UIDropDownMenu_SetText(BCRAFT_CatName(UI_EnchantSlot), f.subDD)
    end

    if f:IsShown() then
      BCRAFT_UI_Refresh()
    end
  end

  -- Thanks window, if it was already built
  local tf = BCRAFT_ThanksFrame
  if tf then
    if tf.titleFS then tf.titleFS:SetText(BCRAFT_L.THANKS_TITLE) end
    if tf.bodyFS then tf.bodyFS:SetText(BCRAFT_L.THANKS_BODY) end
    if tf.nameLabelFS then tf.nameLabelFS:SetText(BCRAFT_L.CHARACTER) end
    if tf.mailBtn then tf.mailBtn:SetText(BCRAFT_L.FILL_NAME) end
    if tf.okBtn then tf.okBtn:SetText(BCRAFT_L.CLOSE) end
  end

  -- The recipe popup rebuilds its text on open, so nothing to do there.
end

-- -------------------------
-- "Thank you" / support window
-- -------------------------
local BCRAFT_AUTHOR_CHAR = "Lumihunt"

function BCRAFT_ShowThanksFrame()
  local tf = BCRAFT_ThanksFrame

  if not tf then
    tf = CreateFrame("Frame", "BCRAFT_ThanksFrame", UIParent)
    tf:SetWidth(340)
    tf:SetHeight(275)
    tf:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    tf:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tf:SetMovable(true)
    tf:EnableMouse(true)
    tf:RegisterForDrag("LeftButton")
    tf:SetScript("OnDragStart", function() this:StartMoving() end)
    tf:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    tf:SetFrameStrata("DIALOG")

    local tt = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tt:SetPoint("TOP", tf, "TOP", 0, -18)
    tt:SetText(BCRAFT_L.THANKS_TITLE)
    tf.titleFS = tt

    local tclose = CreateFrame("Button", nil, tf, "UIPanelCloseButton")
    tclose:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -6, -6)

    local body = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -52)
    body:SetWidth(292)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(BCRAFT_L.THANKS_BODY)
    tf.bodyFS = body

    local nameLabel = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -158)
    nameLabel:SetText(BCRAFT_L.CHARACTER)
    tf.nameLabelFS = nameLabel

    -- Selectable box so the name can be copied with Ctrl+C
    local nameBox = CreateFrame("EditBox", nil, tf, "InputBoxTemplate")
    nameBox:SetWidth(150)
    nameBox:SetHeight(20)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 12, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetText(BCRAFT_AUTHOR_CHAR)
    -- Keep the value fixed: undo any edit the user makes
    nameBox:SetScript("OnTextChanged", function()
      if this:GetText() ~= BCRAFT_AUTHOR_CHAR then
        this:SetText(BCRAFT_AUTHOR_CHAR)
      end
    end)
    nameBox:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    tf.nameBox = nameBox

    local hint = tf:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", tf, "TOPLEFT", 24, -184)
    hint:SetWidth(292)
    hint:SetJustifyH("LEFT")
    tf.hint = hint

    -- Fills the recipient field when a mailbox is open
    local mailBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    mailBtn:SetWidth(150)
    mailBtn:SetHeight(24)
    mailBtn:SetPoint("BOTTOMLEFT", tf, "BOTTOMLEFT", 24, 22)
    mailBtn:SetText(BCRAFT_L.FILL_NAME)
    mailBtn:SetScript("OnClick", function()
      if MailFrame and MailFrame:IsVisible() and SendMailNameEditBox then
        -- Switch to the "send mail" tab, then prefill the recipient
        if MailFrameTab2 and MailFrameTab_OnClick then
          MailFrameTab_OnClick(2)
        end
        SendMailNameEditBox:SetText(BCRAFT_AUTHOR_CHAR)
        if SendMailSubjectEditBox and SendMailSubjectEditBox:GetText() == "" then
          SendMailSubjectEditBox:SetText("BananaCraft")
        end
        msg(BCRAFT_L.RECIPIENT_SET .. " |cff00ff00" .. BCRAFT_AUTHOR_CHAR .. "|r " .. BCRAFT_L.RECIPIENT_THANKS)
        BCRAFT_ThanksFrame:Hide()
      else
        msg(BCRAFT_L.NEED_MAILBOX .. " |cffffff00" .. BCRAFT_L.MAILBOX .. "|r " .. BCRAFT_L.NEED_MAILBOX_2)
      end
    end)
    tf.mailBtn = mailBtn

    local okBtn = CreateFrame("Button", nil, tf, "UIPanelButtonTemplate")
    okBtn:SetWidth(110)
    okBtn:SetHeight(24)
    okBtn:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -24, 22)
    okBtn:SetText(BCRAFT_L.CLOSE)
    tf.okBtn = okBtn
    okBtn:SetScript("OnClick", function() BCRAFT_ThanksFrame:Hide() end)

    BCRAFT_ThanksFrame = tf
  end

  -- Adapt the hint and the button to the current situation
  if MailFrame and MailFrame:IsVisible() then
    tf.hint:SetText(BCRAFT_L.MAILBOX_OPEN)
    tf.mailBtn:Enable()
  else
    tf.hint:SetText(BCRAFT_L.MAILBOX_CLOSED)
    tf.mailBtn:Disable()
  end

  tf.nameBox:SetText(BCRAFT_AUTHOR_CHAR)

  if tf:IsShown() then tf:Hide() else tf:Show() end
end

-- -------------------------
-- Minimap Button Functions
-- -------------------------
local MINIMAP_ICON = "Interface\\AddOns\\BananaCraft\\BananaCraft_MinimapIcon"

function BCRAFT_MinimapButton_OnClick(button)
  if button == "LeftButton" then
    uiToggle()
  end
end

function BCRAFT_MinimapButton_OnEnter()
  GameTooltip:SetOwner(this, "ANCHOR_LEFT")
  GameTooltip:SetText("BananaCraft")
  GameTooltipTextLeft1:SetTextColor(1, 1, 1)
  GameTooltip:AddLine(BCRAFT_L.MM_LEFTCLICK)
  GameTooltip:AddLine(BCRAFT_L.MM_RIGHTCLICK)
  GameTooltip:Show()
end

-- Position als Winkel (Grad, 0 = rechts, gegen den Uhrzeigersinn) um die Kartenmitte.
function BCRAFT_MinimapButton_UpdatePosition()
  local b = BCRAFT_MinimapButtonFrame
  if not b then return end
  local db = ensureDB()
  local a = math.rad(db.settings.minimapButtonPos or 315)
  local radius = db.settings.minimapButtonRadius or 80
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
end

function BCRAFT_MinimapButton_OnDrag()
  local mx, my = Minimap:GetCenter()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  BCRAFT_MinimapButton_SetPosition(math.deg(math.atan2(cy / scale - my, cx / scale - mx)))
end

function BCRAFT_MinimapButton_SetPosition(v)
  if v < 0 then
    v = v + 360
  end

  local db = ensureDB()
  db.settings.minimapButtonPos = v
  BCRAFT_MinimapButton_UpdatePosition()
end

-- Der Button wird komplett in Lua gebaut (ein Button, Icon und Rahmen direkt
-- darauf), genau wie bei den anderen BananaForge-Addons. Die fruehere
-- XML-Variante mit Frame + Kind-Button wurde von UI-Addons (pfUI & Co.)
-- beim Umgestalten der Minimap-Buttons leergeraeumt.
function BCRAFT_MinimapButton_Init()
  local db = ensureDB()

  if db.settings.minimapButton == nil then
    db.settings.minimapButton = true
  end
  if db.settings.minimapButtonPos == nil then
    db.settings.minimapButtonPos = 315
  end
  if db.settings.minimapButtonRadius == nil then
    db.settings.minimapButtonRadius = 80
  end

  if not BCRAFT_MinimapButtonFrame then
    local b = CreateFrame("Button", "BCRAFT_MinimapButtonFrame", Minimap)
    b:SetWidth(33)
    b:SetHeight(33)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("RightButton")

    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture(MINIMAP_ICON)
    icon:SetWidth(24)
    icon:SetHeight(24)
    icon:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.icon = icon

    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetWidth(56)
    border:SetHeight(56)
    border:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)

    b:SetScript("OnClick", function() BCRAFT_MinimapButton_OnClick(arg1) end)
    b:SetScript("OnEnter", function() BCRAFT_MinimapButton_OnEnter() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function()
      this:SetScript("OnUpdate", function() BCRAFT_MinimapButton_OnDrag() end)
    end)
    b:SetScript("OnDragStop", function()
      this:SetScript("OnUpdate", nil)
    end)
  end

  if db.settings.minimapButton == true then
    BCRAFT_MinimapButtonFrame:Show()
  else
    BCRAFT_MinimapButtonFrame:Hide()
  end

  BCRAFT_MinimapButton_UpdatePosition()
end
