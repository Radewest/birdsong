-- Birdsong: Core
-- Namespace, saved variables, safe event bus, internal callbacks, chat helpers, slash commands.
-- Same proven structure as Tjommie (from wow-addon-template).

local ADDON, ns = ...
_G.Birdsong = ns -- handy for /dump Birdsong while developing

ns.VERSION = "0.3.7"   -- keep in sync with ## Version in both TOCs

---------------------------------------------------------------------------
-- API shims (Forever runs the modern Midnight-era client; keep fallbacks anyway)
---------------------------------------------------------------------------
ns.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Midnight "secret values": some data is hidden from add-ons in combat/instances.
function ns.IsSecret(v)
  return issecretvalue and issecretvalue(v) or false
end

---------------------------------------------------------------------------
-- Safe calls: every handler runs through this, so errors land in the bug log (Bugs.lua)
---------------------------------------------------------------------------
local function addStack(e)
  return tostring(e) .. "\n" .. (debugstack and debugstack(2, 10, 0) or "")
end

function ns.SafeCall(fn, ...)
  local args, n = { ... }, select("#", ...)
  local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, addStack)
  if not ok then ns:ReportError(err) end
  return ok
end

function ns:ReportError(err, skipHandler)
  if self.LogError then pcall(self.LogError, self, err) end
  if not skipHandler then
    self.reporting = true
    pcall(geterrorhandler(), (tostring(err):match("^[^\n]*")))
    self.reporting = false
  end
end

---------------------------------------------------------------------------
-- Event bus: ns:On("EVENT", fn)  /  internal callbacks: ns:Listen / ns:Fire
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

function ns:On(event, fn)
  if not eventHandlers[event] then
    eventHandlers[event] = {}
    eventFrame:RegisterEvent(event)
  end
  table.insert(eventHandlers[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  for _, fn in ipairs(list) do ns.SafeCall(fn, ...) end
end)

local callbacks = {}
function ns:Listen(name, fn)
  callbacks[name] = callbacks[name] or {}
  table.insert(callbacks[name], fn)
end
function ns:Fire(name, ...)
  local list = callbacks[name]
  if not list then return end
  for _, fn in ipairs(list) do ns.SafeCall(fn, ...) end
end

---------------------------------------------------------------------------
-- Saved variables (defaults are merged in, so new settings appear for existing users)
---------------------------------------------------------------------------
local DEFAULTS = {
  errors = {},          -- bug log (Bugs.lua)
  chat = "important",   -- "off" | "important" | "all"
  sightings = {},       -- [speciesKey] = { first, firstZone, firstName, count, last }
  zones = {},           -- [zoneName] = { [speciesKey] = count }
  kinds = {},           -- [npcID] = { first, zone, count, last }  (Atlas kinds)
  toastKinds = true,    -- smaller pop-up for a new kind of a species you already have
  channel = "Master",   -- sound channel: "Master" | "SFX" | "Ambience"
  spin = true,          -- models turn slowly
  minimap = { hide = false, angle = 215 },
  found = {},           -- [npcID] = { n, s, l1, l2, z }: birds you discovered that the Atlas lacked
  log = {},             -- journal: { t, zone, h (game hour), id (kind) or s (species), n (name), note }
  badges = {},          -- [badgeID] = time earned
  spots = 0,            -- binocular emotes used
  pins = {},            -- [npcID] = true: birds tracked on the world map
  pinsAll = false,      -- pin every bird of the zone you're viewing
  tooltip = true,       -- Birdsong line in unit tooltips
  buddy = nil,          -- birding buddy "Name-Realm"
  buddyKinds = {},      -- [npcID] = true: what the buddy has seen
  buddyInfo = {},       -- { kinds, species, at, version }
  buddyToasts = true,   -- pop-up when the buddy logs a lifer
  toast = true,         -- pop-up on a new species
  toastSound = true,    -- play the bird's call with the pop-up
  liferReaction = "emote", -- on a lifer: "off" | "sound" (gasp clip) | "emote" (gasp clip + /gasp)
  welcomed = false,
  window = {},          -- saved position
}
local CHAR_DEFAULTS = {}

local function applyDefaults(dst, src)
  for k, v in pairs(src) do
    if dst[k] == nil then
      if type(v) == "table" then dst[k] = {}; applyDefaults(dst[k], v) else dst[k] = v end
    elseif type(v) == "table" and type(dst[k]) == "table" then
      applyDefaults(dst[k], v)
    end
  end
end

ns:On("ADDON_LOADED", function(name)
  if name ~= ADDON then return end
  BirdsongDB = BirdsongDB or {}
  BirdsongCharDB = BirdsongCharDB or {}
  applyDefaults(BirdsongDB, DEFAULTS)
  applyDefaults(BirdsongCharDB, CHAR_DEFAULTS)
  ns.db, ns.cdb = BirdsongDB, BirdsongCharDB
  ns:Fire("DB_READY")
end)

ns:On("PLAYER_LOGIN", function() ns:Fire("LOGIN") end)

---------------------------------------------------------------------------
-- Chat: ns:Print for direct replies to slash commands; ns:Chat respects the chat setting
---------------------------------------------------------------------------
function ns:Print(msg)
  print("|cff33ff99Birdsong|r: " .. tostring(msg))
end

function ns:Chat(msg, level)
  local setting = self.db and self.db.chat or "important"
  if setting == "off" then return end
  if level == "all" and setting ~= "all" then return end
  self:Print(msg)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_BIRDSONG1 = "/birdsong"
SLASH_BIRDSONG2 = "/birds"
SlashCmdList.BIRDSONG = function(msg)
  local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "bugs" then
    if rest == "clear" then ns:ClearErrors() else ns:ShowBugs() end
  elseif cmd == "test" then
    ns:TestSighting()
  elseif cmd == "spot" then
    ns:SpotTarget()
  elseif cmd == "buddy" then
    if rest == "" or rest == "target" then ns:SetBuddyFromTarget()
    elseif rest == "clear" then ns:SetBuddy(nil)
    elseif rest == "tjommie" then ns:SetBuddyFromTjommie()
    else ns:SetBuddy(rest) end
  elseif cmd == "journal" then
    ns:OpenBook(nil, "journal")
  elseif cmd == "badges" then
    ns:OpenBook(nil, "badges")
  elseif cmd == "stop" then
    ns:StopSound()
  elseif cmd == "atlas" then
    ns:OpenBook(nil, "atlas")
  elseif cmd == "settings" or cmd == "options" then
    ns:OpenBook(nil, "settings")
  elseif cmd == "minimap" then
    ns.db.minimap.hide = not ns.db.minimap.hide
    ns:Fire("SETTINGS_CHANGED")
    ns:Print("Minimap button " .. (ns.db.minimap.hide and "hidden" or "shown") .. ".")
  elseif cmd == "toast" then
    ns.db.toast = not ns.db.toast
    ns:Print("New-species pop-ups " .. (ns.db.toast and "on" or "off") .. ".")
  elseif cmd == "reset" then
    if rest == "confirm" then
      wipe(ns.db.sightings); wipe(ns.db.zones); wipe(ns.db.kinds); wipe(ns.db.log); wipe(ns.db.badges)
      ns:Print("Life list cleared.")
      ns:Fire("SIGHTINGS_CHANGED")
    else
      ns:Print("This wipes your whole life list. Type |cffffff00/birds reset confirm|r to do it.")
    end
  elseif cmd == "help" then
    ns:Print("v" .. ns.VERSION .. " - /birds (open the book), /birds atlas | journal | badges | settings, /birds spot (binoculars on your target), /birds buddy [name|target|tjommie|clear], /birds stop, /birds test, /birds minimap, /birds reset, /birds bugs")
  else
    ns:ToggleBook()
  end
end

-- Addon compartment (the add-ons button by the minimap); named in the TOC
function Birdsong_OnCompartmentClick() ns.SafeCall(function() ns:ToggleBook() end) end

ns:Listen("LOGIN", function()
  if not ns.db.welcomed then
    ns.db.welcomed = true
    ns:Print("Welcome, birder. Type |cffffff00/birds|r to open your field guide. Target or mouse over a bird to log a sighting.")
  end
end)
