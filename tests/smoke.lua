-- Birdsong smoke tests: load the add-on against stubbed WoW APIs and check the basics.
-- Run: python3 tests/run_tests.py   (add a check for every new feature)

local root = arg[1]
dofile(root .. "/tests/stubs.lua")

local failures, checks = 0, 0
local function check(cond, label)
  checks = checks + 1
  if cond then print("  ok   " .. label) else failures = failures + 1; print("  FAIL " .. label) end
end

local handlerErrors = 0
geterrorhandler = function() return function(e) handlerErrors = handlerErrors + 1; print("  (error) " .. tostring(e)) end end

-- Load files in TOC order (a file missing from the TOC = a failing test)
local ns = {}
for line in io.lines(root .. "/Birdsong.toc") do
  local file = line:match("^([%w_]+%.lua)%s*$")
  if file then assert(loadfile(root .. "/" .. file))("Birdsong", ns) end
end

local function fire(e, ...) assert(events[e], "event not registered: " .. e)._OnEvent(events[e], e, ...) end

print("Loading")
fire("ADDON_LOADED", "Birdsong")
fire("PLAYER_LOGIN")
check(ns.db and ns.cdb, "saved variables initialised")

print("Bug log")
ns:On("BIRDSONG_TEST_ERROR", function() local x; return x.y end)
fire("BIRDSONG_TEST_ERROR"); fire("BIRDSONG_TEST_ERROR")
local last = ns.db.errors[#ns.db.errors]
check(last and last.count == 2, "errors are logged and de-duplicated")
handlerErrors = handlerErrors - 2
ns:ShowBugs()

-- Add feature checks here --------------------------------------------------
print("Data")
for _, b in ipairs(ns.BIRDS) do
  check(ns.SOUNDS[b.key] and ns:SignatureCall(b.key), "sounds exist for " .. b.key)
end
for _, s in ipairs(ns.SOUNDSCAPES) do
  check(ns.AMBIENCE_IDS[s.key] and ns.AMBIENCE_IDS[s.key].day, "ambience exists for " .. s.key)
end

print("Atlas")
check(ns.KIND_COUNT >= 50, "atlas has " .. ns.KIND_COUNT .. " bird kinds")
check(ns.KINDS[1995] and ns.KINDS[1995].s == "owl", "Strigid Owl (1995) is in the atlas")
check(ns.KINDS[9526] == nil, "event-only Enraged Gryphon left out")
for id, k in pairs(ns.KINDS) do
  if not (ns.BIRD_BY_KEY[k.s] and k.d and k.d > 0 and #k.z > 0 and k.l1 <= k.l2) then check(false, "bad atlas entry " .. id) end
end
check(#ns.ATLAS_ZONES > 20, #ns.ATLAS_ZONES .. " zones with birds")
check(ns:LivesIn("tallstrider", "Mulgore") and not ns:LivesIn("owl", "Mulgore"), "LivesIn works")
check(ns:SpeciesZones("owl")[1] ~= nil, "species zones derived from atlas")
check(ns.NpcIDFromGUID("Creature-0-1-2-3-1995-0001") == 1995 and ns.NpcIDFromGUID("Player-1-1") == nil, "npc id from GUID")

print("Recognising birds")
check(ns:MatchBird("Strigid Owl").key == "owl", "Strigid Owl is an owl")
check(ns:MatchBird("Prowler") == nil and ns:MatchBird("Howling Owlbeast") == nil, "no false owls")
check(ns:MatchBird("Fleshripper").key == "carrion", "Fleshripper is a carrion bird")
check(ns:MatchBird("Greater Plainstrider").key == "tallstrider", "Plainstrider is a tallstrider")
check(ns:MatchBird("Stormcrow").key == "stormcrow", "Stormcrow is not a plain crow")

print("Sightings")
local newSpecies = 0
ns:Listen("NEW_SPECIES", function() newSpecies = newSpecies + 1 end)
UNITS.target = { name = "Strigid Owl", type = "Beast", guid = "Creature-0-1-2-3-1995-0001" }
fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.owl and ns.db.sightings.owl.count == 1, "targeting an owl logs it")
check(newSpecies == 1, "new species fires once")
check(ns.db.zones["Elwynn Forest"].owl == 1, "zone count recorded")

fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.owl.count == 1, "same bird isn't counted twice")
UNITS.mouseover = { name = "Strigid Owl", type = "Beast", guid = "Creature-0-1-2-3-1995-0002" }
fire("UPDATE_MOUSEOVER_UNIT")
check(ns.db.sightings.owl.count == 2 and newSpecies == 1, "another owl counts, no new-species pop-up")
UNITS.target = { name = "Gryphon Master Talonaxe", type = "Humanoid", guid = "Creature-0-1-2-3-9-1" }
fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.gryphon == nil, "flight masters aren't gryphons")
UNITS.target = { name = "Raven", player = true, guid = "Player-1-1" }
fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.raven == nil, "players named Raven don't count")
IN_COMBAT = true
UNITS.target = { name = "Fleshripper", type = "Beast", guid = "Creature-0-1-2-3-9-2" }
fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.carrion == nil, "nothing logged in combat")
IN_COMBAT = false
fire("PLAYER_TARGET_CHANGED")
check(ns.db.sightings.carrion ~= nil, "logged after combat")
check(ns.db.kinds[1995] and ns.db.kinds[1995].count == 2, "exact kind logged by creature ID")
local newKinds = 0
ns:Listen("NEW_KIND", function() newKinds = newKinds + 1 end)
UNITS.target = { name = "Strigid Screecher", type = "Beast", guid = "Creature-0-1-2-3-1996-0001" }
fire("PLAYER_TARGET_CHANGED")
check(newKinds == 1 and newSpecies == 2 and ns.db.sightings.owl.count == 3, "new kind of a known species: kind pop-up only")
UNITS.target = { name = "Swoop", type = "Beast", guid = "Creature-0-1-2-3-2970-0001" }
IN_COMBAT = true; fire("PLAYER_TARGET_CHANGED"); IN_COMBAT = false

print("Audio")
PLAYED = {}
check(ns:PlayBird("owl", "call") and #PLAYED == 1, "plays an owl call")
for _, id in ipairs(ns.SOUNDS.raven.call) do MISSING_FILES[id] = true end
check(ns:PlayBird("raven", "call") == false, "missing sounds report false")
check(ns:PlayAmbience("jungle", "night"), "plays a soundscape")

print("Book and commands")
SlashCmdList.BIRDSONG("")
SlashCmdList.BIRDSONG("test")
check(ns:SpeciesSeen() == 3, "/birds test logs a new species (" .. ns:SpeciesSeen() .. ")")
SlashCmdList.BIRDSONG("atlas"); SlashCmdList.BIRDSONG("settings")
ns:OpenKind(1995); ns:OpenKind(428); ns:OpenBook("raven"); ns:OpenBook("owl")
StaticPopupDialogs.BIRDSONG_RESET.OnAccept()
check(ns:SpeciesSeen() == 0 and next(ns.db.kinds) == nil, "settings reset clears life list")
ns:LogSighting(ns.BIRD_BY_KEY.owl, "Strigid Owl", nil, 1995); ns:LogSighting(ns.BIRD_BY_KEY.carrion, "Fleshripper")
SlashCmdList.BIRDSONG("minimap"); check(ns.db.minimap.hide == true, "/birds minimap hides the button")
SlashCmdList.BIRDSONG("minimap")
SlashCmdList.BIRDSONG("help"); SlashCmdList.BIRDSONG("stop"); SlashCmdList.BIRDSONG("toast")
check(ns.db.toast == false, "/birds toast toggles pop-ups")
SlashCmdList.BIRDSONG("reset")
check(ns:SpeciesSeen() == 2, "reset needs confirm")
SlashCmdList.BIRDSONG("reset confirm")
check(ns:SpeciesSeen() == 0, "reset confirm clears life list")
Birdsong_OnCompartmentClick()
for _, fn in ipairs(timers) do fn() end


print("Journal")
local logBefore = #ns.db.log
ns:LogSighting(ns.BIRD_BY_KEY.owl, "Strigid Owl", "Teldrassil", 1995)
ns:LogSighting(ns.BIRD_BY_KEY.owl, "Strigid Owl", "Teldrassil", 1995)
check(#ns.db.log == logBefore + 1 and ns.db.log[#ns.db.log].c == 2, "one journal entry per bird, zone and day")
local page = ns:AddPage()
page.note = "Misty morning by the lake."
ns:Fire("NOTE_CHANGED")
check(ns.db.log[#ns.db.log] == page, "write a page")

print("Rares and spotting")
local rares = 0
ns:Listen("RARE_SEEN", function() rares = rares + 1 end)
UNITS.target = { name = "Vultros", type = "Beast", guid = "Creature-0-1-2-3-462-0001" }
fire("PLAYER_TARGET_CHANGED")
check(rares == 1 and ns.db.kinds[462], "rare bird fires RARE_SEEN and is logged")
ns:SpotTarget()
check(EMOTES[#EMOTES] == "EMOTE:raises a pair of binoculars and spots Vultros.", "binoculars emote, no article for a rare: " .. tostring(EMOTES[#EMOTES]))
ns:Spot("Owl")
check(EMOTES[#EMOTES]:find("spots an Owl") and ns.db.spots == 2, "a/an article and spot count")
UNITS.target = { name = "Kobold", type = "Humanoid", guid = "Creature-0-1-2-3-6-1" }
local before = #EMOTES; ns:SpotTarget()
check(#EMOTES == before, "won't spot a non-bird")

print("Tooltip")
check(TOOLTIP_HOOK ~= nil, "tooltip hook registered")
local lines = ns:TooltipLines("Creature-0-1-2-3-462-0001", "Vultros")
check(lines and lines[1]:find("Rare") and lines[2]:find("life list"), "tooltip for a seen rare")
lines = ns:TooltipLines("Creature-0-1-2-3-5430-0001", "Searing Roc")
check(lines and lines[2]:find("Lifer waiting"), "tooltip for an unseen bird")
check(ns:TooltipLines("Creature-0-1-2-3-6-1", "Kobold") == nil, "no line for non-birds")
GameTooltip.GetUnit = function() return "Searing Roc", "mouseover" end
UNITS.mouseover = { name = "Searing Roc", type = "Beast", guid = "Creature-0-1-2-3-5430-0001" }
TOOLTIP_HOOK(GameTooltip, { guid = "Creature-0-1-2-3-5430-0001" })

print("Map pins")
check(ns:MapIDForZone("Teldrassil") == 1438, "zone name -> map ID from the map tree")
ns:ShowOnMap(1995)
check(ns.db.pins[1995] and OPENED_MAP == 1438, "show on map tracks the bird and opens its zone")
WorldMapFrame.GetMapID = function() return 1438 end
ns:RefreshPins()
ns.db.pinsAll = true; ns:RefreshPins(); ns.db.pinsAll = false
ns:HideFromMap(1995)
check(not ns.db.pins[1995], "hide from map")

print("Buddy")
local set = { [1995] = true, [462] = true, [428] = true }
local back = ns.DecodeKinds(ns.EncodeKinds(set))
check(back[1995] and back[462] and back[428] and not back[620], "life list bitmask round-trips")
check(#ns.EncodeKinds(ns.KINDS) <= 20, "bitmask is short enough for one message")
TjommieDB = { buddy = "Friend-Realm" }
ns:SetBuddyFromTjommie()
check(ns.db.buddy == "Friend-Realm", "use my tjommie")
check(#ADDON_SENT >= 2 and ADDON_SENT[#ADDON_SENT].t == "Friend-Realm", "list sent to buddy")
for _, m in ipairs(ADDON_SENT) do check(#m.m <= 250 and not m.m:find("|", 1, true), "message size and no pipes: " .. m.m) end
local buddyLifers = 0
ns:Listen("BUDDY_LIFER", function() buddyLifers = buddyLifers + 1 end)
fire("CHAT_MSG_ADDON", "Birdsong", "L~" .. ns.VERSION .. "~" .. ns.KIND_COUNT .. "~" .. ns.EncodeKinds({ [1995] = true, [620] = true }), "WHISPER", "Stranger-Realm")
check(next(ns.db.buddyKinds) == nil, "strangers are ignored")
fire("CHAT_MSG_ADDON", "Birdsong", "L~" .. ns.VERSION .. "~" .. ns.ATLAS_KIND_COUNT .. "~" .. ns.EncodeKinds({ [1995] = true, [620] = true }), "WHISPER", "Friend-Realm")
check(ns.db.buddyKinds[1995] and ns.db.buddyKinds[620] and ns.db.buddyInfo.kinds == 2, "buddy list received")
fire("CHAT_MSG_ADDON", "Birdsong", "N~428", "WHISPER", "Friend-Realm")
check(buddyLifers == 1 and ns.db.buddyKinds[428], "buddy lifer received")
fire("CHAT_MSG_ADDON", "Birdsong", "L~9.9.9~3~ff", "WHISPER", "Friend-Realm")
check(ns.db.buddyInfo.sameAtlas == false, "different atlas versions don't show wrong ticks")
local sentBefore = #ADDON_SENT
ns:LogSighting(ns.BIRD_BY_KEY.carrion, "Dire Condor", "Redridge Mountains", 428)
check(ADDON_SENT[#ADDON_SENT].m == "N~428" and #ADDON_SENT == sentBefore + 1, "my lifer is announced once")

print("Badges")
ns.db.badges = {}
local earned = {}
ns:Listen("BADGE_EARNED", function(b) earned[b.id] = true end)
GAME_HOUR = 23
ns:LogSighting(ns.BIRD_BY_KEY.owl, "Strigid Hunter", "Teldrassil", 1997)
GAME_HOUR = 12
check(earned.first and earned.rare1 and earned.nightowl, "first, rare and night owl badges earned")
check(ns.db.badges.first and not ns.db.badges.kindsall, "unearned badges stay unearned")
local f = io.open
for _, b in ipairs(ns.BADGES) do
  local h = f(root .. "/media/badges/" .. b.id .. ".tga", "rb")
  check(h ~= nil, "badge art exists for " .. b.id)
  if h then h:close() end
end
local prog = ns:BadgeProgress()
check(#prog == #ns.BADGES and #ns.BADGES >= 20, #ns.BADGES .. " badges with progress")

print("Discoveries")
local countBefore = ns.KIND_COUNT
UnitLevel = function() return 42 end
UNITS.target = { name = "Green Wing Macaw", type = "Beast", guid = "Creature-0-1-2-3-999001-0001" }
fire("PLAYER_TARGET_CHANGED")
check(ns.db.found[999001] and ns.KINDS[999001] and ns.KINDS[999001].found, "unknown bird becomes a discovery")
check(ns.KIND_COUNT == countBefore + 1 and ns.db.kinds[999001], "discovery counts as a kind on your life list")
check(ns.ZONE_KINDS["Elwynn Forest"] and (function() for _, id in ipairs(ns.ZONE_KINDS["Elwynn Forest"]) do if id == 999001 then return true end end end)(), "discovery listed in its zone")
GetZoneText = function() return "Stranglethorn Vale" end
UNITS.target = { name = "Green Wing Macaw", type = "Beast", guid = "Creature-0-1-2-3-999001-0002" }
fire("PLAYER_TARGET_CHANGED")
GetZoneText = function() return "Elwynn Forest" end
check(#ns.KINDS[999001].z == 2 and ns.KIND_COUNT == countBefore + 1, "seen in a second zone: zone added, not a second kind")
check(#ns.EncodeKinds(ns.db.kinds) == math.ceil(ns.ATLAS_KIND_COUNT / 4), "buddy bitmask ignores discoveries")
ns:OpenKind(999001)

print("Lifer reaction")
PLAYED = {}; EMOTED = {}
ns.db.liferReaction = "emote"
check(ns:LiferReaction() > 0 and PLAYED[#PLAYED]:find("lifer.ogg") and EMOTED[1] == "GASP", "gasp sound plays and /gasp emote fires")
PLAYED = {}; EMOTED = {}
ns.db.liferReaction = "sound"
check(ns:LiferReaction() > 0 and #PLAYED == 1 and #EMOTED == 0, "sound-only setting: no emote")
PLAYED = {}; EMOTED = {}
ns.db.liferReaction = "off"
check(ns:LiferReaction() == 0 and #PLAYED == 0 and #EMOTED == 0, "off: nothing")
IN_COMBAT = true; ns.db.liferReaction = "emote"; EMOTED = {}
ns:LiferReaction()
check(#EMOTED == 0, "no emote in combat")
IN_COMBAT = false
EMOTED = {}
UNITS.target = { name = "Ironbeak Owl", type = "Beast", guid = "Creature-0-1-2-3-7097-0001" }
ns.db.sightings.owl = nil
fire("PLAYER_TARGET_CHANGED")
check(EMOTED[1] == "GASP", "a real lifer triggers the reaction")
local h = io.open(root .. "/media/lifer.ogg", "rb"); check(h ~= nil, "lifer.ogg is shipped"); if h then h:close() end

print("Every tab")
for _, t in ipairs({ "guide", "atlas", "zones", "journal", "badges", "sounds", "settings" }) do ns:OpenBook(nil, t) end
ns:OpenKind(462); ns:OpenBook("owl")
for _, fn in ipairs(timers) do fn() end
check(next(ns.ZONE_NOTES) and ns.MUSIC.forest.day[1] == 53492, "zone notes data")
for z, n in pairs(ns.ZONE_NOTES) do
  local okScape = false
  for _, s in ipairs(ns.SOUNDSCAPES) do if s.key == n[1] then okScape = true end end
  if not (okScape and ns.MUSIC[n[2]]) then check(false, "zone note " .. z .. " points at missing data") end
end
for id in pairs(ns.SPAWNS) do if not ns.KINDS[id] then check(false, "spawn for unknown kind " .. id) end end
for id, k in pairs(ns.KINDS) do if not k.found and not ns.SPAWNS[id] then check(false, "no spawns for " .. id) end end

check(handlerErrors == 0, "no unexpected errors (" .. handlerErrors .. ")")
print(string.format("\n%d checks, %d failed", checks, failures))
if failures > 0 then error("tests failed") end
