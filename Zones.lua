-- Birdsong: zone notes data
-- Soundscape and music theme per zone are BEST GUESSES (Blizzard's zone -> music table isn't in our sources);
-- the book labels them that way. Credits are only what a published source says, with the source named.

local _, ns = ...

-- Classic zone music themes: FileDataIDs from the community listfile (sound/music/zonemusic/<theme>/)
ns.MUSIC = {
  forest          = { name = "Forest",           day = { 53492, 53493, 53494 }, night = { 53495, 53496, 53497, 53498 } },
  plains          = { name = "Plains",           day = { 53680, 53681 },        night = { 53682, 53683 } },
  mountain        = { name = "Mountain",         day = { 53577, 53578, 53579 }, night = { 53580, 53581, 53582, 53583 } },
  jungle          = { name = "Jungle",           day = { 53541, 53542, 53543 }, night = { 53544, 53545, 53546 } },
  desert          = { name = "Desert",           day = { 53432, 53433, 53434 }, night = { 53435, 53436, 53437 } },
  barrendry       = { name = "Barrens",          day = { 53299, 53300, 53301 }, night = { 53302, 53303, 53304 } },
  evilforest      = { name = "Haunted forest",   day = { 53486, 53487, 53488 }, night = { 53489, 53490, 53491 } },
  enchantedforest = { name = "Enchanted forest", day = { 53453, 53454, 53455, 53456, 53457 }, night = {} },
  soggyplace      = { name = "Swamp",            day = { 53695, 53696, 53697, 53698, 53699 }, night = {} },
  volcanic        = { name = "Volcanic",         day = { 53812, 53813 },        night = { 53814, 53815 } },
  cursedland      = { name = "Cursed lands",     day = { 53426, 53427, 53428, 53429, 53430, 53431 }, night = {} },
}

-- zone = { soundscape key, music theme key, note (sourced only) }
ns.ZONE_NOTES = {
  ["Elwynn Forest"]          = { "forestnormal", "forest" },
  ["Westfall"]               = { "westfall", "plains" },
  ["Redridge Mountains"]     = { "foresthigh", "mountain" },
  ["Duskwood"]               = { "forestscary", "evilforest" },
  ["Stranglethorn Vale"]     = { "jungle", "jungle" },
  ["Dun Morogh"]             = { "forestsnow", "mountain" },
  ["Ironforge"]              = { "forestsnow", "mountain",
    note = "Jason Hayes wrote the Ironforge theme, along with much of the original game's ambient music (Engadget, 2007)." },
  ["Loch Modan"]             = { "foresthigh", "mountain" },
  ["Wetlands"]               = { "wetlands", "soggyplace" },
  ["Arathi Highlands"]       = { "grasslands", "plains" },
  ["Hillsbrad Foothills"]    = { "foresthigh", "forest" },
  ["Alterac Mountains"]      = { "foresthigh", "mountain" },
  ["The Hinterlands"]        = { "foresthigh", "forest" },
  ["Tirisfal Glades"]        = { "forestscary", "evilforest" },
  ["Silverpine Forest"]      = { "forestscary", "evilforest" },
  ["Western Plaguelands"]    = { "plaguelands", "cursedland" },
  ["Eastern Plaguelands"]    = { "plaguelands", "cursedland" },
  ["Badlands"]               = { "canyondesert", "desert" },
  ["Searing Gorge"]          = { "volcanic", "volcanic" },
  ["Burning Steppes"]        = { "volcanic", "volcanic" },
  ["Swamp of Sorrows"]       = { "marsh", "soggyplace" },
  ["Blasted Lands"]          = { "canyondesert", "cursedland" },
  ["Deadwind Pass"]          = { "deadwindpass", "cursedland" },
  ["Durotar"]                = { "canyondesert", "desert" },
  ["Mulgore"]                = { "grasslands", "plains" },
  ["The Barrens"]            = { "plainsdesert", "barrendry" },
  ["Teldrassil"]             = { "enchantedforest", "enchantedforest" },
  ["Darnassus"]              = { "enchantedforest", "enchantedforest" },
  ["Darkshore"]              = { "forestdarkenchanted", "enchantedforest" },
  ["Ashenvale"]              = { "enchantedforest", "enchantedforest" },
  ["Stonetalon Mountains"]   = { "canyondesert", "mountain" },
  ["Desolace"]               = { "canyondesert", "desert" },
  ["Thousand Needles"]       = { "saltflats", "desert" },
  ["Feralas"]                = { "jungle", "jungle" },
  ["Dustwallow Marsh"]       = { "marsh", "soggyplace" },
  ["Tanaris"]                = { "plainsdesert", "desert" },
  ["Un'Goro Crater"]         = { "jungle", "jungle" },
  ["Azshara"]                = { "enchantedforest", "forest" },
  ["Felwood"]                = { "forestdarkenchanted", "evilforest" },
  ["Winterspring"]           = { "forestsnow", "mountain" },
  ["Moonglade"]              = { "enchantedforest", "enchantedforest" },
  ["Silithus"]               = { "plainsdesert", "desert" },
}

ns.MUSIC_CREDIT = "Most of World of Warcraft's original soundtrack was written by Jason Hayes; Glenn Stafford and Tracy W. Bush also wrote a lot of it (Engadget, 2007). Blizzard hasn't published which composer wrote which zone's music, so we don't guess."

ns.NOTE_ZONES = {}
for z in pairs(ns.ZONE_NOTES) do table.insert(ns.NOTE_ZONES, z) end
table.sort(ns.NOTE_ZONES)
