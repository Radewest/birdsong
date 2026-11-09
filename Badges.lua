-- Birdsong: badges (achievements). Worked out from your life list and journal; earned dates are saved.

local _, ns = ...

local function count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end

-- Stats used by the badge checks (recomputed when something changes)
local function stats()
  local db = ns.db
  local s = { kinds = ns:KindsSeen(), native = 0, rares = 0, rareTotal = 0, zonesDone = 0, bigDay = 0,
    nightOwl = false, dawn = false, notes = 0, spots = db.spots or 0, shared = 0, family = {} }
  for _, b in ipairs(ns.BIRDS) do if b.native and db.sightings[b.key] then s.native = s.native + 1 end end
  for id, k in pairs(ns.KINDS) do
    if k.rare then
      s.rareTotal = s.rareTotal + 1
      if db.kinds[id] then s.rares = s.rares + 1 end
    end
    if db.kinds[id] and db.buddyKinds[id] then s.shared = s.shared + 1 end
  end
  for _, z in ipairs(ns.ATLAS_ZONES) do
    local list = ns.ZONE_KINDS[z]
    if #list > 0 and ns:KindsSeen(list) == #list then s.zonesDone = s.zonesDone + 1 end
  end
  for key, list in pairs(ns.SPECIES_KINDS) do s.family[key] = { ns:KindsSeen(list), #list } end
  local perDay = {}
  for _, e in ipairs(db.log) do
    if not e.page then
      local d = date("%Y-%m-%d", e.t)
      perDay[d] = perDay[d] or {}
      perDay[d][(e.n or e.s or "?"):lower()] = true
      local h = e.h or 12
      if e.s == "owl" and (h >= 21 or h < 5) then s.nightOwl = true end
      if h >= 5 and h < 7 then s.dawn = true end
    end
    if e.note and e.note:match("%S") then s.notes = s.notes + 1 end
  end
  for _, set in pairs(perDay) do s.bigDay = math.max(s.bigDay, count(set)) end
  return s
end

-- Each badge: id, name, desc, progress(s) -> current, goal
ns.BADGES = {
  { id = "first",    name = "First Feathers",   desc = "Log your first bird.",                      p = function(s) return s.kinds, 1 end },
  { id = "kinds5",   name = "Notebook Filling",  desc = "See 5 kinds of bird.",                      p = function(s) return s.kinds, 5 end },
  { id = "kinds15",  name = "Keen Eye",          desc = "See 15 kinds of bird.",                     p = function(s) return s.kinds, 15 end },
  { id = "kinds30",  name = "Seasoned Birder",   desc = "See 30 kinds of bird.",                     p = function(s) return s.kinds, 30 end },
  { id = "kindsall", name = "Master of the Atlas", desc = "See every bird in the Atlas.",            p = function(s) return s.kinds, ns.KIND_COUNT end },
  { id = "species",  name = "Every Feather",     desc = "See all seven bird families of these lands.", p = function(s) return s.native, 7 end },
}
for _, b in ipairs(ns.BIRDS) do
  if b.native and ns.SPECIES_KINDS[b.key] then
    local key = b.key
    table.insert(ns.BADGES, { id = "fam_" .. key, name = b.name .. " Expert", desc = "See every kind of " .. b.name:lower() .. ".",
      p = function(s) return s.family[key][1], s.family[key][2] end })
  end
end
for _, b in ipairs({
  { id = "rare1",    name = "Rare Find",         desc = "Spot a rare bird.",                         p = function(s) return s.rares, 1 end },
  { id = "rareall",  name = "Legend Hunter",     desc = "Spot every rare bird.",                     p = function(s) return s.rares, s.rareTotal end },
  { id = "zone1",    name = "Local Patch",       desc = "See every bird in one zone.",               p = function(s) return s.zonesDone, 1 end },
  { id = "zone5",    name = "Patchwork",         desc = "See every bird in five zones.",             p = function(s) return s.zonesDone, 5 end },
  { id = "bigday5",  name = "Big Day",           desc = "See 5 kinds in one day.",                   p = function(s) return s.bigDay, 5 end },
  { id = "bigday10", name = "Bigger Day",        desc = "See 10 kinds in one day.",                  p = function(s) return s.bigDay, 10 end },
  { id = "nightowl", name = "Night Owl",         desc = "See an owl at night (9pm to 5am game time).", p = function(s) return s.nightOwl and 1 or 0, 1 end },
  { id = "dawn",     name = "Dawn Chorus",       desc = "Log a bird between 5 and 7am game time.",   p = function(s) return s.dawn and 1 or 0, 1 end },
  { id = "notes5",   name = "Field Notes",       desc = "Write 5 journal notes.",                    p = function(s) return s.notes, 5 end },
  { id = "spots10",  name = "Binoculars Out",    desc = "Spot 10 birds with your binoculars.",       p = function(s) return s.spots, 10 end },
  { id = "shared10", name = "Birds of a Feather", desc = "You and your buddy have both seen 10 kinds.", p = function(s) return s.shared, 10 end },
}) do table.insert(ns.BADGES, b) end

ns.BADGE_BY_ID = {}
for _, b in ipairs(ns.BADGES) do ns.BADGE_BY_ID[b.id] = b end

-- Progress for the Badges tab: list of { badge, cur, goal, earned }
function ns:BadgeProgress()
  local s, out = stats(), {}
  for _, b in ipairs(ns.BADGES) do
    local cur, goal = b.p(s)
    out[#out + 1] = { badge = b, cur = math.min(cur, goal), goal = goal, earned = self.db.badges[b.id] }
  end
  return out
end

function ns:BadgesEarned() return count(self.db.badges) end

-- Award anything newly complete
function ns:CheckBadges(quiet)
  if not self.db then return end
  local s = stats()
  for _, b in ipairs(ns.BADGES) do
    local cur, goal = b.p(s)
    if goal > 0 and cur >= goal and not self.db.badges[b.id] then
      self.db.badges[b.id] = time()
      if not quiet then self:Fire("BADGE_EARNED", b) end
    end
  end
end

for _, e in ipairs({ "SIGHTINGS_CHANGED", "SPOTTED", "NOTE_CHANGED", "BUDDY_UPDATED" }) do
  ns:Listen(e, function() ns:CheckBadges() end)
end
ns:Listen("LOGIN", function() ns:CheckBadges(true) end) -- quietly catch up on old life lists
