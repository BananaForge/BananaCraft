--[[
  BananaActivity - tiny shared tracker (Lua 5.0 / WoW 1.12)

  Counts how many guild members are online, once per ~10 minutes, and keeps the PEAK per server hour
  (all members + level 60 only). Every client with BananaBank or BananaGuild measures and shares the finished
  hours over the guild addon channel, so the BananaGuild dashboard gets a gap-free activity heatmap.

  HOW TO USE IN ANOTHER ADDON (e.g. BananaBank)
    1. Copy this file next to the addon's .lua files and list it in the .toc (the first loaded copy wins).
    2. Give it a table inside your SavedVariables once your saved data is loaded:
         BananaBankDB.activity = BananaBankDB.activity or {}
         if BananaActivity then BananaActivity.Init(BananaBankDB.activity) end
    Nothing else is needed. Data format of that table: a[hourIndex] = online peak, b[hourIndex] = level 60 peak.

  Messages (prefix BGLD, no pipe char):
    A;idx;all;l60;now        a finished hour (accepted only for the last 2 hours, and only when the sender's clock hour 'now'
                             matches ours: a client with a wrong clock cannot push shifted hours into the others' data)
    AQ;have                  "I have data up to hour 'have', send me newer ones" (login, once)
    AT;target;now;base;d:a:b,..  answer, one chunk (hour = base + d), ignored when 'now' differs from ours by more than 1
    (the old answer AS carries no clock hour and is ignored)
]]

local LIBVER = 2

if BananaActivity and BananaActivity.libVersion and BananaActivity.libVersion >= LIBVER then
	return
end

-- an older copy (version 1) is already running: switch its frame off, this copy replaces it
if BananaActivity and BananaActivityFrame then
	BananaActivityFrame:UnregisterAllEvents()
	BananaActivityFrame:SetScript("OnEvent", nil)
	BananaActivityFrame:SetScript("OnUpdate", nil)
end

BananaActivity = BananaActivity or {}
local A = BananaActivity

A.libVersion = LIBVER
A.PREFIX     = "BGLD"
A.KEEP       = 84 * 24      -- hours kept (12 weeks)
A.CATCHUP    = 28 * 24      -- hours sent to a new client
A.stores     = A.stores or {}
A.queue      = {}
A.lastSample = -10000
A.pending    = {}           -- idx -> true (own A message waiting)
A.answering  = {}           -- target -> true (own AS answer waiting)

--------------------------------------------------------------------- time (server hours, no date() needed)

-- server hour minus UTC hour, from GetGameTime() (server clock) against time() (UTC epoch)
function A.Offset()
	if not GetGameTime or not time then return A.off or 0 end
	local sh, sm = GetGameTime()
	if not sh then return A.off or 0 end
	local t = time()
	local um = math.mod(math.floor(t / 60), 1440)
	local d = (sh * 60 + (sm or 0) - um) / 60
	d = math.floor(d + 0.5)
	if d > 12 then d = d - 24 elseif d < -12 then d = d + 24 end
	A.off = d
	return d
end

function A.HourIndex(t)
	return math.floor((t or time()) / 3600) + A.Offset()
end

-- weekday 0 = Monday .. 6 = Sunday, hour 0..23 (epoch day 0 was a Thursday)
function A.WeekHour(idx)
	return math.mod(math.floor(idx / 24) + 3, 7), math.mod(idx, 24)
end

--------------------------------------------------------------------- storage

function A.Init(store)
	if type(store) ~= "table" then return end
	store.a = store.a or {}
	store.b = store.b or {}
	for i = 1, table.getn(A.stores) do
		if A.stores[i] == store then return end
	end
	table.insert(A.stores, store)
	A.Prune(store)
end

function A.Prune(store)
	local lim = A.HourIndex() - A.KEEP
	for idx in pairs(store.a) do
		if idx < lim then store.a[idx] = nil; store.b[idx] = nil; if store.src then store.src[idx] = nil end end
	end
end

local function Valid(idx, a, b)
	if not idx or not a then return false end
	local now = A.HourIndex()
	if idx < now - A.KEEP or idx > now then return false end
	if a < 0 or a > 600 or (b and (b < 0 or b > 600)) then return false end
	return true
end

-- returns true when something new was stored
function A.Merge(idx, a, b, src)
	local changed = false
	for i = 1, table.getn(A.stores) do
		local s = A.stores[i]
		s.src = s.src or {}
		if a > (s.a[idx] or -1) then s.a[idx] = a; s.src[idx] = src or "n"; changed = true end
		if (b or 0) > (s.b[idx] or -1) then s.b[idx] = b or 0; changed = true end
	end
	return changed
end

-- the clock hour of another client must match ours (+-1), otherwise its hours would land in the wrong cells
local function SameClock(n)
	if not n then return false end
	return math.abs(n - A.HourIndex()) <= 1
end

-- lines for /bgd activity
function A.Dump(store)
	local out = {}
	local sh, sm = 0, 0
	if GetGameTime then sh, sm = GetGameTime() end
	table.insert(out, "server " .. tostring(sh) .. ":" .. tostring(sm) .. "  utc-hour " .. math.mod(math.floor(time() / 3600), 24)
		.. "  offset " .. A.Offset() .. "  hour index " .. A.HourIndex())
	local keys = {}
	for idx in pairs(store.a) do table.insert(keys, idx) end
	table.sort(keys)
	for i = math.max(1, table.getn(keys) - 23), table.getn(keys) do
		local idx = keys[i]
		local d, h = A.WeekHour(idx)
		table.insert(out, idx .. "  day " .. d .. " " .. h .. ":00  online " .. store.a[idx] .. "  l60 " .. (store.b[idx] or 0) .. "  " .. ((store.src and store.src[idx]) == "o" and "own" or "received"))
	end
	return out
end

--------------------------------------------------------------------- measuring

local function Later(delay, fn)
	table.insert(A.queue, { at = GetTime() + delay, fn = fn })
end

local function Send(msg)
	if SendAddonMessage and IsInGuild and IsInGuild() then
		SendAddonMessage(A.PREFIX, msg, "GUILD")
	end
end

function A.Sample()
	if not IsInGuild or not IsInGuild() or not GetNumGuildMembers then return end
	local n = GetNumGuildMembers(true)
	if not n or n < 1 then return end
	local all, l60 = 0, 0
	for i = 1, n do
		local _, _, _, lvl, _, _, _, _, online = GetGuildRosterInfo(i)
		if online then
			all = all + 1
			if lvl and lvl >= 60 then l60 = l60 + 1 end
		end
	end
	A.lastSample = GetTime()
	local idx = A.HourIndex()
	A.Merge(idx, all, l60, "o")
	-- the hour that just ended is final now: tell the others (after a random delay, skipped when somebody was faster)
	local prev = A.lastIdx
	A.lastIdx = idx
	if prev and prev < idx and idx - prev <= 2 and A.stores[1] and A.stores[1].a[prev] then
		A.pending[prev] = true
		Later(1 + math.random() * 40, function()
			if A.pending[prev] then
				A.pending[prev] = nil
				local s = A.stores[1]
				if s and s.a[prev] then Send("A;" .. prev .. ";" .. s.a[prev] .. ";" .. (s.b[prev] or 0) .. ";" .. A.HourIndex()) end
			end
		end)
	end
	if A.lastPrune ~= idx then
		A.lastPrune = idx
		for i = 1, table.getn(A.stores) do A.Prune(A.stores[i]) end
	end
end

function A.RequestSync()
	local s = A.stores[1]
	if not s then return end
	local have = 0
	for idx in pairs(s.a) do if idx > have then have = idx end end
	Send("AQ;" .. have .. ";" .. A.HourIndex())
end

-- answer a request: newer hours in chunks, one per ~1.3 s
function A.Answer(target, have)
	local s = A.stores[1]
	if not s then return end
	local from = math.max(have, A.HourIndex() - A.CATCHUP)
	local keys = {}
	for idx in pairs(s.a) do
		if idx > from then table.insert(keys, idx) end
	end
	if table.getn(keys) == 0 then return end
	table.sort(keys)
	local chunk, base, count, delay = nil, nil, 0, 0
	local function Flush()
		if chunk and count > 0 then
			local msg = "AT;" .. target .. ";" .. A.HourIndex() .. ";" .. base .. ";" .. table.concat(chunk, ",")
			Later(delay, function() Send(msg) end)
			delay = delay + 1.3
		end
		chunk, base, count = nil, nil, 0
	end
	local total = 0
	for i = 1, table.getn(keys) do
		local idx = keys[i]
		if not base then base = idx; chunk = {} end
		table.insert(chunk, (idx - base) .. ":" .. s.a[idx] .. ":" .. (s.b[idx] or 0))
		count = count + 1
		total = total + 1
		if count >= 16 then Flush() end
		if total >= 600 then break end
	end
	Flush()
end

--------------------------------------------------------------------- events

local function Num(x) return tonumber(x) end

local function OnAddon(sender, msg)
	local _, _, kind, rest = string.find(msg, "^(%a+);?(.*)$")
	if kind == "A" then
		local _, _, i, a, b, n = string.find(rest, "^(%d+);(%d+);(%d+);?(%d*)")
		i, a, b, n = Num(i), Num(a), Num(b), Num(n)
		-- live message of a finished hour: only the last 2 hours, and the sender's clock must match (when it tells it)
		local now = A.HourIndex()
		if Valid(i, a, b) and i < now and now - i <= 2 and (n == nil or SameClock(n)) then
			A.Merge(i, a, b, "n")
			local s = A.stores[1]
			if A.pending[i] and s and (s.a[i] or 0) >= a then A.pending[i] = nil end
		end
	elseif kind == "AQ" then
		local _, _, h, n = string.find(rest, "^(%d*);?(%d*)")
		local have = Num(h) or 0
		if n ~= "" and not SameClock(Num(n)) then return end
		local s = A.stores[1]
		if not s or A.answering[sender] then return end
		local newer = false
		for idx in pairs(s.a) do if idx > have then newer = true break end end
		if not newer then return end
		A.answering[sender] = true
		Later(3 + math.random() * 25, function()
			if A.answering[sender] then
				A.answering[sender] = nil
				A.Answer(sender, have)
			end
		end)
	elseif kind == "AT" then
		local _, _, target, n, base, list = string.find(rest, "^([^;]*);(%d+);(%d+);(.*)$")
		base = Num(base)
		if not base or not SameClock(Num(n)) then return end
		-- somebody else answers this client already
		if target and A.answering[target] then A.answering[target] = nil end
		for d, a, b in string.gfind(list or "", "(%d+):(%d+):(%d+)") do
			local idx, av, bv = base + tonumber(d), tonumber(a), tonumber(b)
			if Valid(idx, av, bv) then A.Merge(idx, av, bv, "n") end
		end
		if A.onData then pcall(A.onData) end
	end
end

local frame = CreateFrame("Frame", "BananaActivityFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function()
	local ev, a1, a2, a3, a4 = event, arg1, arg2, arg3, arg4
	if ev == "PLAYER_LOGIN" then
		A.me = UnitName("player")
		A.loginAt = GetTime()
		Later(75, function() A.RequestSync() end)
	elseif ev == "GUILD_ROSTER_UPDATE" then
		if A.loginAt and GetTime() - A.loginAt > 45 and GetTime() - A.lastSample >= 570 then
			A.Sample()
		end
	elseif ev == "CHAT_MSG_ADDON" then
		if a1 == A.PREFIX and a2 and a3 == "GUILD" and a4 ~= A.me then
			OnAddon(a4, a2)
		end
	end
end)

local sinceCheck = 0
frame:SetScript("OnUpdate", function()
	local now = GetTime()
	local n = table.getn(A.queue)
	for i = n, 1, -1 do
		local item = A.queue[i]
		if item and now >= item.at then
			table.remove(A.queue, i)
			pcall(item.fn)
		end
	end
	if now - sinceCheck >= 60 then
		sinceCheck = now
		-- no roster update came by itself for 10 minutes: ask for one
		if A.loginAt and now - A.loginAt > 45 and now - A.lastSample >= 600 and GuildRoster and IsInGuild and IsInGuild() then
			GuildRoster()
		end
	end
end)
