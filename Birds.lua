-- Birdsong: the field guide
-- Each species: key (matches ns.SOUNDS), name, family, words used to recognise it from a creature's
-- name (fallback when a creature isn't in the Atlas), and a short field-guide note.
-- Where each bird lives comes from the Atlas (Atlas.lua).
-- "native = false" marks birds from later lands. Their sounds may not exist in the Forever client;
-- the book says so if a sound won't play.

local _, ns = ...

ns.BIRDS = {
  {
    key = "owl", name = "Owl", family = "Owls",
    words = { "owl", "owls" },
    note = "Silent wings, enormous eyes and a hoot that carries through the darkest woods. Listen for them after dusk, when the forest goes quiet.",
    native = true,
  },
  {
    key = "carrion", name = "Carrion Bird", family = "Vultures, buzzards and rocs",
    words = { "vulture", "buzzard", "fleshripper", "carrion", "condor", "roc", "swoop" },
    note = "Patient circlers of the dry lands. Where they gather overhead, something below has had a very bad day.",
    native = true,
  },
  {
    key = "tallstrider", name = "Tallstrider", family = "Striders",
    words = { "plainstrider", "tallstrider", "strider" },
    note = "A long-legged runner of the open plains. More legs than sense, and famously grumpy when disturbed.",
    native = true,
  },
  {
    key = "parrot", name = "Parrot", family = "Parrots",
    words = { "parrot", "macaw", "cockatoo" },
    note = "Bright, loud and fond of sailors. If one starts repeating your name, you've been near the docks too long.",
    native = true,
  },
  {
    key = "chicken", name = "Chicken", family = "Fowl",
    words = { "chicken", "hen", "rooster" },
    note = "The farmyard's bravest bird, as long as nothing is looking at it. Try /chicken nearby and see what happens.",
    native = true,
  },
  {
    key = "gryphon", name = "Gryphon", family = "Gryphons",
    words = { "gryphon", "griffon" },
    note = "Half eagle, half lion, all attitude. The Wildhammer dwarves raise them as mounts, and flight masters keep them saddled.",
    native = true,
  },
  {
    key = "hippogryph", name = "Hippogryph", family = "Hippogryphs",
    words = { "hippogryph" },
    note = "The night elves' sky-steed: an eagle's front and a stag's back, with a cry that echoes through old forests.",
    native = true,
  },
  -- Birds from later lands (may not be in the Forever sound library)
  {
    key = "seagull", name = "Seagull", family = "Gulls",
    words = { "seagull", "gull" },
    note = "Thieves of the shoreline. Never eat a fish sandwich on a pier.", native = false,
  },
  {
    key = "raven", name = "Raven", family = "Corvids",
    words = { "raven", "crow" },
    note = "Clever, watchful and usually first to arrive wherever something unpleasant is about to happen.", native = false,
  },
  {
    key = "stormcrow", name = "Stormcrow", family = "Corvids",
    words = { "stormcrow" },
    note = "A great dark crow said to ride the winds before a storm. Druids know more about this bird than they let on.", native = false,
  },
  {
    key = "turkey", name = "Turkey", family = "Fowl",
    words = { "turkey" },
    note = "A seasonal visitor that's usually in a hurry for some reason.", native = false,
  },
  {
    key = "tickbird", name = "Tickbird", family = "Oxpeckers",
    words = { "tickbird" },
    note = "A tiny companion that rides on bigger beasts and keeps them free of pests. Chatters constantly.", native = false,
  },
}

ns.BIRD_BY_KEY = {}
for i, b in ipairs(ns.BIRDS) do b.index = i; ns.BIRD_BY_KEY[b.key] = b end

-- Call types shown as buttons in the book, in order
ns.CALL_TYPES = {
  { key = "call",   label = "Call" },
  { key = "alarm",  label = "Alarm" },
  { key = "attack", label = "Strike" },
  { key = "wound",  label = "Wounded" },
  { key = "death",  label = "Last cry" },
}

-- Soundscapes: the game's zone ambience beds, by landscape. Zone lists are best guesses to check in-game.
ns.SOUNDSCAPES = {
  { key = "forestnormal",        name = "Temperate forest",  zones = "Elwynn Forest" },
  { key = "westfall",            name = "Farmland",          zones = "Westfall" },
  { key = "grasslands",          name = "Grasslands",        zones = "Mulgore, Arathi Highlands" },
  { key = "plainsdesert",        name = "Dry plains",        zones = "The Barrens" },
  { key = "canyondesert",        name = "Red canyons",       zones = "Durotar, Badlands" },
  { key = "jungle",              name = "Jungle",            zones = "Stranglethorn Vale, Un'Goro Crater" },
  { key = "wetlands",            name = "Wetlands",          zones = "Wetlands" },
  { key = "marsh",               name = "Marsh",             zones = "Dustwallow Marsh, Swamp of Sorrows" },
  { key = "beach",               name = "Coast",             zones = "Coastlines" },
  { key = "foresthigh",          name = "Highland forest",   zones = "Hillsbrad, Alterac" },
  { key = "forestsnow",          name = "Snowy forest",      zones = "Dun Morogh, Winterspring" },
  { key = "enchantedforest",     name = "Enchanted forest",  zones = "Teldrassil, Ashenvale" },
  { key = "forestdarkenchanted", name = "Dark enchanted forest", zones = "Darkshore, Felwood" },
  { key = "forestscary",         name = "Haunted forest",    zones = "Duskwood" },
  { key = "plaguelands",         name = "Plaguelands",       zones = "Western and Eastern Plaguelands" },
  { key = "saltflats",           name = "Salt flats",        zones = "Thousand Needles" },
  { key = "volcanic",            name = "Volcanic",          zones = "Searing Gorge, Burning Steppes" },
  { key = "deadwindpass",        name = "Deadwind",          zones = "Deadwind Pass" },
}

---------------------------------------------------------------------------
-- Atlas indexes: zone -> kinds, species -> kinds, sorted zone list
---------------------------------------------------------------------------
ns.ZONE_KINDS, ns.SPECIES_KINDS, ns.ATLAS_ZONES = {}, {}, {}
local function byLevel(a, b)
  local ka, kb = ns.KINDS[a], ns.KINDS[b]
  if ka.l1 ~= kb.l1 then return ka.l1 < kb.l1 end
  return ka.n < kb.n
end
-- Add one kind to the indexes (also used for birds you discover that aren't in the Atlas data)
function ns:IndexKind(id, k)
  k.id = id
  ns.SPECIES_KINDS[k.s] = ns.SPECIES_KINDS[k.s] or {}
  table.insert(ns.SPECIES_KINDS[k.s], id)
  table.sort(ns.SPECIES_KINDS[k.s], byLevel)
  for _, z in ipairs(k.z) do
    if not ns.ZONE_KINDS[z] then
      ns.ZONE_KINDS[z] = {}
      table.insert(ns.ATLAS_ZONES, z)
      table.sort(ns.ATLAS_ZONES)
    end
    table.insert(ns.ZONE_KINDS[z], id)
    table.sort(ns.ZONE_KINDS[z], byLevel)
  end
end
for id, k in pairs(ns.KINDS or {}) do ns:IndexKind(id, k) end
ns.KIND_COUNT = 0
for _ in pairs(ns.KINDS or {}) do ns.KIND_COUNT = ns.KIND_COUNT + 1 end
ns.ATLAS_KIND_COUNT = ns.KIND_COUNT  -- the shipped data only (buddy comparisons use this)

-- Discoveries: birds you found that the Atlas data didn't have. Saved in db.found and
-- added to the Atlas, so they count everywhere. Added to a zone when you see one there.
local function addFound(id, f)
  if ns.KINDS[id] then return end
  local k = { n = f.n, s = f.s, l1 = f.l1 or 1, l2 = f.l2 or f.l1 or 1, z = {}, found = true }
  for _, z in ipairs(f.z or {}) do k.z[#k.z + 1] = z end
  ns.KINDS[id] = k
  ns:IndexKind(id, k)
  ns.KIND_COUNT = ns.KIND_COUNT + 1
end

function ns:Discover(id, name, key, zone, level)
  local f = self.db.found[id]
  if not f then
    f = { n = name, s = key, l1 = level, l2 = level, z = { zone } }
    self.db.found[id] = f
    addFound(id, f)
    self:Fire("DISCOVERED", id)
    return ns.KINDS[id]
  end
  local k = ns.KINDS[id]
  local known = false
  for _, z in ipairs(f.z) do if z == zone then known = true end end
  if not known then
    table.insert(f.z, zone)
    table.insert(k.z, zone)
    if not ns.ZONE_KINDS[zone] then ns.ZONE_KINDS[zone] = {}; table.insert(ns.ATLAS_ZONES, zone); table.sort(ns.ATLAS_ZONES) end
    table.insert(ns.ZONE_KINDS[zone], id)
  end
  if level then
    f.l1, f.l2 = math.min(f.l1 or level, level), math.max(f.l2 or level, level)
    k.l1, k.l2 = f.l1, f.l2
  end
  return k
end

ns:Listen("DB_READY", function()
  for id, f in pairs(ns.db.found) do addFound(id, f) end
end)

-- Zones a species lives in, most kinds first
function ns:SpeciesZones(key)
  local count, list = {}, {}
  for _, id in ipairs(ns.SPECIES_KINDS[key] or {}) do
    for _, z in ipairs(ns.KINDS[id].z) do
      if not count[z] then list[#list + 1] = z end
      count[z] = (count[z] or 0) + 1
    end
  end
  table.sort(list, function(a, b) if count[a] ~= count[b] then return count[a] > count[b] end return a < b end)
  return list
end

-- Does this species live in this zone?
function ns:LivesIn(key, zone)
  for _, id in ipairs(ns.ZONE_KINDS[zone] or {}) do
    if ns.KINDS[id].s == key then return true end
  end
  return false
end

-- Recognise a bird from a creature name: whole-word match, so "Prowler" or "Howler" never count as owls.
function ns:MatchBird(name)
  if type(name) ~= "string" or name == "" then return nil end
  local words = {}
  for w in name:lower():gmatch("[%a']+") do words[w] = true end
  -- check later lands first so "Stormcrow" isn't read as a plain crow
  for i = #ns.BIRDS, 1, -1 do
    local b = ns.BIRDS[i]
    for _, w in ipairs(b.words) do
      if words[w] then return b end
    end
  end
  return nil
end
