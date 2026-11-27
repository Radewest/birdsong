-- Birdsong: life list
-- Target or mouse over a bird (out of combat) and it's logged.
-- Exact match by creature ID against the Atlas first; creature-name words as a fallback.
-- Only reads names, creature types and GUIDs, which add-ons may show; skips secret values and players.

local _, ns = ...

local recent = {}   -- [guid] = time, so hovering the same bird doesn't count twice
local RECENT_SECONDS = 600

local function zoneName()
  local z = GetZoneText and GetZoneText() or ""
  if z == "" or ns.IsSecret(z) then return "Unknown lands" end
  return z
end
ns.ZoneName = zoneName

-- "Creature-0-1234-0-5678-1995-0000ABCDEF" -> 1995
function ns.NpcIDFromGUID(guid)
  if type(guid) ~= "string" then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end -- not "Pet": hunter pets aren't wild birds
end

-- Record a sighting. kindID is optional (an Atlas creature ID). Returns true for a new species.
function ns:LogSighting(bird, creatureName, zone, kindID)
  zone = zone or zoneName()
  local now = time()
  local s = self.db.sightings[bird.key]
  local isNewSpecies = s == nil
  if isNewSpecies then
    s = { first = now, firstZone = zone, firstName = creatureName, count = 0 }
    self.db.sightings[bird.key] = s
  end
  s.count = s.count + 1
  s.last = now

  local isNewKind = false
  if kindID then
    local k = self.db.kinds[kindID]
    if not k then
      isNewKind = true
      k = { first = now, zone = zone, count = 0 }
      self.db.kinds[kindID] = k
    end
    k.count = k.count + 1
    k.last = now
  end

  self.db.zones[zone] = self.db.zones[zone] or {}
  local zt = self.db.zones[zone]
  zt[bird.key] = (zt[bird.key] or 0) + 1

  self:AddLogEntry(bird, creatureName, zone, kindID, now)
  local kind = kindID and ns.KINDS[kindID]
  if kind and kind.rare then self:Fire("RARE_SEEN", bird, creatureName, zone, kindID, isNewKind) end

  if isNewSpecies then
    self:Fire("NEW_SPECIES", bird, creatureName, zone, kindID)
  elseif isNewKind then
    self:Fire("NEW_KIND", bird, creatureName, zone, kindID)
  end
  self:Fire("SIGHTINGS_CHANGED")
  return isNewSpecies
end

---------------------------------------------------------------------------
-- Journal: one entry per bird, zone and day (more sightings bump its count)
---------------------------------------------------------------------------
local MAX_LOG = 1000
local function gameHour()
  local h = GetGameTime and GetGameTime()
  return tonumber(h) or 12
end
ns.GameHour = gameHour

function ns:AddLogEntry(bird, creatureName, zone, kindID, now)
  local log = self.db.log
  local day = date("%Y-%m-%d", now)
  for i = #log, math.max(1, #log - 50), -1 do
    local e = log[i]
    if date("%Y-%m-%d", e.t) ~= day then break end
    if e.zone == zone and ((kindID and e.id == kindID) or (not kindID and e.s == bird.key and not e.id)) then
      e.c = (e.c or 1) + 1
      return e
    end
  end
  local e = { t = now, zone = zone, h = gameHour(), id = kindID, s = bird.key, n = creatureName }
  table.insert(log, e)
  -- trim the oldest entries without a note
  local i = 1
  while #log > MAX_LOG and i <= #log do
    if not log[i].note or log[i].note == "" then table.remove(log, i) else i = i + 1 end
  end
  self:Fire("LOG_CHANGED", e)
  return e
end

-- A free journal page (no bird): "Write page" in the Journal
function ns:AddPage()
  local e = { t = time(), zone = zoneName(), h = gameHour(), n = "Field notes", page = true, note = "" }
  table.insert(self.db.log, e)
  self:Fire("LOG_CHANGED", e)
  return e
end

---------------------------------------------------------------------------
-- Binoculars: a roleplay emote. Only ever from a click or a slash command.
---------------------------------------------------------------------------
local function article(name, rare)
  if rare then return "" end
  return name:match("^[AEIOUaeiou]") and "an " or "a "
end

function ns:Spot(name, rare)
  if not name or name == "" then return end
  local text = "raises a pair of binoculars and spots " .. article(name, rare) .. name .. "."
  local ok = SendChatMessage and pcall(SendChatMessage, text, "EMOTE")
  if ok then
    self.db.spots = (self.db.spots or 0) + 1
    self:Fire("SPOTTED")
  end
end

function ns:SpotTarget()
  if not UnitExists or not UnitExists("target") or UnitIsPlayer("target") then
    self:Print("Target a bird first.")
    return
  end
  local name = UnitName("target")
  if not name or ns.IsSecret(name) then return end
  local id = ns.NpcIDFromGUID(UnitGUID("target"))
  local kind = id and ns.KINDS[id]
  if not kind and not ns:MatchBird(name) then self:Print(name .. " isn't a bird. Probably."); return end
  self:Spot(name, kind and kind.rare)
end

local function check(unit)
  if not UnitExists or not UnitExists(unit) then return end
  if UnitIsPlayer and UnitIsPlayer(unit) then return end
  -- hunter pets, companions and anything else a player controls aren't wild birds
  if UnitPlayerControlled and UnitPlayerControlled(unit) then return end
  if UnitIsOtherPlayersPet and UnitIsOtherPlayersPet(unit) then return end
  if UnitIsBattlePetCompanion and UnitIsBattlePetCompanion(unit) then return end
  if (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
  local name = UnitName(unit)
  if not name or ns.IsSecret(name) then return end

  local guid = UnitGUID and UnitGUID(unit)
  if guid and ns.IsSecret(guid) then guid = nil end
  local npcID = ns.NpcIDFromGUID(guid)
  local kind = npcID and ns.KINDS[npcID]
  local bird
  if kind then
    bird = ns.BIRD_BY_KEY[kind.s]
  else
    -- Name fallback only for beasts and critters: "Shore Strider" is a giant, "Gryphon Master" a person
    local ctype = UnitCreatureType and UnitCreatureType(unit)
    if ctype and not ns.IsSecret(ctype) and ctype ~= "Beast" and ctype ~= "Critter" then return end
    bird = ns:MatchBird(name)
  end
  if not bird then return end

  if guid then
    local t = recent[guid]
    if t and GetTime() - t < RECENT_SECONDS then return end
    recent[guid] = GetTime()
  end
  -- A bird the Atlas doesn't know: add it as your own discovery (needs a creature ID)
  if (not kind or kind.found) and npcID and ns.db.found then
    local lvl = UnitLevel and UnitLevel(unit)
    if ns.IsSecret(lvl) or type(lvl) ~= "number" or lvl < 1 then lvl = nil end
    kind = ns:Discover(npcID, name, bird.key, zoneName(), lvl)
  end
  ns:LogSighting(bird, name, nil, kind and npcID or nil)
end

ns:On("PLAYER_TARGET_CHANGED", function() check("target") end)
ns:On("UPDATE_MOUSEOVER_UNIT", function() check("mouseover") end)

-- /birds test: fake a sighting of a kind you haven't seen yet (in your zone if possible)
function ns:TestSighting()
  local zone = zoneName()
  local pickID
  for _, id in ipairs(ns.ZONE_KINDS[zone] or {}) do
    if not self.db.kinds[id] then pickID = id; break end
  end
  if not pickID then
    for id in pairs(ns.KINDS) do
      if not self.db.kinds[id] then pickID = id; break end
    end
  end
  if not pickID then self:Print("You've seen every bird in the Atlas. Impressive."); return end
  local k = ns.KINDS[pickID]
  self:LogSighting(ns.BIRD_BY_KEY[k.s], k.n, zone, pickID)
  self:Print("Test sighting logged: " .. k.n .. " in " .. zone .. ".")
end

function ns:SpeciesSeen()
  local n = 0
  for _ in pairs(self.db.sightings) do n = n + 1 end
  return n
end

function ns:KindsSeen(list)
  local n = 0
  if list then
    for _, id in ipairs(list) do if self.db.kinds[id] then n = n + 1 end end
  else
    for id in pairs(self.db.kinds) do if ns.KINDS[id] then n = n + 1 end end
  end
  return n
end
