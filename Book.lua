-- Birdsong: the book window (/birds)
-- Tabs: Field Guide, Atlas, Zones, Journal, Badges, Soundscapes, Settings.

local _, ns = ...
local UI = ns.UI
local GOLD, GREY, GREEN, BLUE, RED, RARE = UI.GOLD, UI.GREY, UI.GREEN, UI.BLUE, UI.RED, UI.RARE
local button, label, wrapped = UI.button, UI.label, UI.wrapped

local W, H = 780, 560
local book
local state = { tab = "guide", species = "owl", zone = nil, kind = nil, notesZone = nil, entry = nil }
local TABS = {
  { key = "guide",    label = "Field Guide" },
  { key = "atlas",    label = "Atlas" },
  { key = "zones",    label = "Zones" },
  { key = "journal",  label = "Journal" },
  { key = "badges",   label = "Badges" },
  { key = "sounds",   label = "Soundscapes" },
  { key = "settings", label = "Settings" },
}

local function setStatus(text) UI.status(text) end
local function kindName(k) return (k.rare and RARE or "") .. k.n .. (k.rare and "|r" or "") end
local function buddyMark(id) return (ns.db.buddy and ns.db.buddyKinds[id]) and (BLUE .. " +|r") or "" end

-- Which creature to show for a species: one you've seen, else one living here, else the first
local function representativeKind(key, zone)
  local list = ns.SPECIES_KINDS[key] or {}
  for _, id in ipairs(list) do if ns.db.kinds[id] then return id end end
  for _, id in ipairs(list) do
    for _, z in ipairs(ns.KINDS[id].z) do if z == zone then return id end end
  end
  return list[1]
end

---------------------------------------------------------------------------
-- Field Guide
---------------------------------------------------------------------------
local function buildGuide(content)
  local g = CreateFrame("Frame", nil, content)
  g:SetAllPoints()

  g.list = UI.makeList(g, 190, 430, 28, function(r, b)
    local seen = ns.db.sightings[b.key]
    r.left:SetText((seen and GREEN .. "* |r" or "  ") .. (b.native and b.name or (GREY .. b.name .. "|r")))
    local here = ns:LivesIn(b.key, ns.ZoneName()) or (ns.db.zones[ns.ZoneName()] or {})[b.key]
    r.right:SetText(here and (GOLD .. "here|r") or (not b.native and GREY .. "far|r") or "")
    r.hl:SetShown(b.key == state.species)
  end, function(b) state.species = b.key; ns:RefreshBook() end)
  g.list:SetPoint("TOPLEFT", 0, 0)

  local page = CreateFrame("Frame", nil, g)
  page:SetPoint("TOPLEFT", 206, 0)
  page:SetPoint("BOTTOMRIGHT", 0, 0)
  g.page = page

  page.model = ns:CreateModelView(page, 230, 230)
  page.model:SetPoint("TOPRIGHT", 0, 0)
  page.modelName = label(page, "GameFontHighlightSmall")
  page.modelName:SetPoint("TOP", page.model, "BOTTOM", 0, -4)
  page.noModel = label(page.model, "GameFontDisableSmall", "Not found in these lands")
  page.noModel:SetPoint("CENTER")

  local TW = 300
  page.name = label(page, "GameFontNormalHuge")
  page.name:SetPoint("TOPLEFT", 0, -4)
  page.family = label(page, "GameFontHighlightSmall")
  page.family:SetPoint("TOPLEFT", page.name, "BOTTOMLEFT", 0, -4)
  page.seen = wrapped(page, "GameFontHighlight", TW)
  page.seen:SetPoint("TOPLEFT", page.family, "BOTTOMLEFT", 0, -12)
  page.note = wrapped(page, "GameFontHighlight", TW)
  page.note:SetPoint("TOPLEFT", page.seen, "BOTTOMLEFT", 0, -10)
  page.note:SetSpacing(3)
  page.where = wrapped(page, "GameFontHighlightSmall", TW)
  page.where:SetPoint("TOPLEFT", page.note, "BOTTOMLEFT", 0, -10)
  page.where:SetSpacing(2)

  page.kinds = label(page, "GameFontHighlightSmall")
  page.kinds:SetPoint("TOPLEFT", page.model, "BOTTOMLEFT", 0, -26)
  page.toAtlas = button(page, "Open in Atlas", 120, 22)
  page.toAtlas:SetPoint("TOPRIGHT", page.model, "BOTTOMRIGHT", 0, -46)
  page.toAtlas:SetScript("OnClick", function() if page.kindID then ns:OpenKind(page.kindID) end end)

  local listen = label(page, "GameFontNormal", "Listen")
  listen:SetPoint("BOTTOMLEFT", 0, 30)
  local calls = CreateFrame("Frame", nil, page)
  calls:SetPoint("BOTTOMLEFT", 0, 0)
  calls:SetSize(546, 24)
  UI.makeCalls(calls, 100)
  page.calls = calls
  return g
end

local function refreshGuide(g)
  local zone = ns.ZoneName()
  local items = {}
  for _, b in ipairs(ns.BIRDS) do items[#items + 1] = b end
  local function rank(b)
    if ns:LivesIn(b.key, zone) or (ns.db.zones[zone] or {})[b.key] then return 1 end
    return b.native and 2 or 3
  end
  table.sort(items, function(a, b)
    local ra, rb = rank(a), rank(b)
    if ra ~= rb then return ra < rb end
    return a.index < b.index
  end)
  g.list:SetItems(items)

  local b = ns.BIRD_BY_KEY[state.species] or ns.BIRDS[1]
  local p = g.page
  p.name:SetText(b.name)
  p.family:SetText(GREY .. b.family .. (b.native and "" or "  -  from later lands") .. "|r")
  local s = ns.db.sightings[b.key]
  if s then
    p.seen:SetText(string.format("%sSeen %d time%s.|r First: %s in %s (%s).", GREEN, s.count, s.count == 1 and "" or "s",
      UI.fmtDate(s.first), s.firstZone or "?", s.firstName or "?"))
  else
    p.seen:SetText(GREY .. "Not yet seen. Target or mouse over one to log it.|r")
  end
  p.note:SetText(b.note)

  local lines = {}
  local zones = ns:SpeciesZones(b.key)
  if #zones > 0 then
    local shown = {}
    for i = 1, math.min(8, #zones) do shown[i] = zones[i] end
    lines[#lines + 1] = GOLD .. "Lives in:|r " .. table.concat(shown, ", ") .. (#zones > 8 and (" and " .. (#zones - 8) .. " more") or "")
  end
  local seenIn = {}
  for z, t in pairs(ns.db.zones) do if t[b.key] then seenIn[#seenIn + 1] = z .. " (" .. t[b.key] .. ")" end end
  table.sort(seenIn)
  if #seenIn > 0 then lines[#lines + 1] = GOLD .. "Your sightings:|r " .. table.concat(seenIn, ", ") end
  p.where:SetText(table.concat(lines, "\n\n"))

  local kinds = ns.SPECIES_KINDS[b.key] or {}
  local id = representativeKind(b.key, zone)
  p.kindID = id
  if id then
    local k = ns.KINDS[id]
    p.model:Show3D(k.d, id)
    p.noModel:Hide()
    p.modelName:SetText(kindName(k) .. GREY .. "  (" .. UI.levels(k) .. ")|r")
    p.kinds:SetText(string.format("%s%d|r of %d kinds seen", GREEN, ns:KindsSeen(kinds), #kinds))
    p.toAtlas:Show()
  else
    if p.model.model then pcall(p.model.model.ClearModel, p.model.model) end
    p.noModel:Show()
    p.modelName:SetText("")
    p.kinds:SetText(GREY .. "No kinds recorded in the classic world.|r")
    p.toAtlas:Hide()
  end
  p.calls:SetCallsFor(b.key)
end

---------------------------------------------------------------------------
-- Atlas
---------------------------------------------------------------------------
local function buildAtlas(content)
  local a = CreateFrame("Frame", nil, content)
  a:SetAllPoints()

  local zh = label(a, "GameFontNormal", "Zones")
  zh:SetPoint("TOPLEFT", 4, 0)
  a.myZone = button(a, "My zone", 80, 20)
  a.myZone:SetPoint("TOPLEFT", 96, 2)
  a.myZone:SetScript("OnClick", function()
    state.zone, state.kind = ns.ZoneName(), nil
    a.zones:ScrollTo(state.zone)
    ns:RefreshBook()
  end)

  a.zones = UI.makeList(a, 180, 404, 22, function(r, z)
    local list = ns.ZONE_KINDS[z] or {}
    local here = (z == ns.ZoneName())
    r.left:SetText((here and GOLD or "") .. z .. (here and "|r" or ""))
    local seen = ns:KindsSeen(list)
    r.right:SetText((seen == #list and #list > 0 and GREEN or GREY) .. seen .. "/" .. #list .. "|r")
    r.hl:SetShown(z == state.zone)
  end, function(z) state.zone, state.kind = z, nil; ns:RefreshBook() end)
  a.zones:SetPoint("TOPLEFT", 0, -26)

  a.zoneTitle = label(a, "GameFontNormal")
  a.zoneTitle:SetPoint("TOPLEFT", 194, 0)
  a.zoneTitle:SetWidth(240); a.zoneTitle:SetJustifyH("LEFT"); a.zoneTitle:SetWordWrap(false)
  a.kinds = UI.makeList(a, 240, 404, 30, function(r, id)
    local k = ns.KINDS[id]
    r.left:SetText((ns.db.kinds[id] and GREEN .. "* |r" or "  ") .. kindName(k) .. buddyMark(id))
    r.right:SetText(GREY .. (k.l1 == k.l2 and k.l1 or (k.l1 .. "-" .. k.l2)) .. "|r")
    r.hl:SetShown(id == state.kind)
  end, function(id) state.kind = id; ns:RefreshBook() end)
  a.kinds:SetPoint("TOPLEFT", 194, -26)
  a.empty = wrapped(a.kinds, "GameFontDisable", 200)
  a.empty:SetPoint("TOP", 0, -20)
  a.empty:SetJustifyH("CENTER")
  a.empty:SetText("No wild birds recorded in this zone.")
  a.legend = label(a, "GameFontDisableSmall")
  a.legend:SetPoint("BOTTOMLEFT", a.kinds, "BOTTOMLEFT", 6, 4)

  local d = CreateFrame("Frame", nil, a)
  d:SetPoint("TOPLEFT", 446, 0)
  d:SetPoint("BOTTOMRIGHT", 0, 0)
  a.detail = d
  d.model = ns:CreateModelView(d, 306, 190)
  d.model:SetPoint("TOPLEFT", 0, 0)
  d.name = label(d, "GameFontNormalLarge")
  d.name:SetPoint("TOPLEFT", d.model, "BOTTOMLEFT", 0, -8)
  d.sub = label(d, "GameFontHighlightSmall")
  d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -3)
  d.seen = wrapped(d, "GameFontHighlightSmall", 306)
  d.seen:SetPoint("TOPLEFT", d.sub, "BOTTOMLEFT", 0, -8)
  d.zones = wrapped(d, "GameFontHighlightSmall", 306)
  d.zones:SetPoint("TOPLEFT", d.seen, "BOTTOMLEFT", 0, -6)

  d.map = button(d, "Show on map", 100, 22)
  d.map:SetPoint("BOTTOMLEFT", 0, 32)
  d.map:SetScript("OnClick", function()
    if ns.db.pins[state.kind] then ns:HideFromMap(state.kind) else ns:ShowOnMap(state.kind) end
    ns:RefreshBook()
  end)
  d.spot = button(d, "Spot", 60, 22)
  d.spot:SetPoint("LEFT", d.map, "RIGHT", 4, 0)
  d.spot:SetScript("OnClick", function()
    local k = ns.KINDS[state.kind]
    if k then ns:Spot(k.n, k.rare) end
  end)
  d.guide = button(d, "Field Guide", 100, 22)
  d.guide:SetPoint("LEFT", d.spot, "RIGHT", 4, 0)
  d.guide:SetScript("OnClick", function()
    local k = ns.KINDS[state.kind]
    if k then ns:OpenBook(k.s) end
  end)
  local calls = CreateFrame("Frame", nil, d)
  calls:SetPoint("BOTTOMLEFT", 0, 0)
  calls:SetSize(306, 24)
  UI.makeCalls(calls, 58, true)
  d.calls = calls
  d.pick = wrapped(d, "GameFontDisable", 280)
  d.pick:SetPoint("CENTER", 0, 30)
  d.pick:SetJustifyH("CENTER")
  d.pick:SetText("Pick a bird to see it.")
  return a
end

local function refreshAtlas(a)
  state.zone = state.zone or ns.ZoneName()
  local zones = {}
  if not ns.ZONE_KINDS[state.zone] then zones[1] = state.zone end
  for _, z in ipairs(ns.ATLAS_ZONES) do zones[#zones + 1] = z end
  a.zones:SetItems(zones)

  local list = ns.ZONE_KINDS[state.zone] or {}
  a.zoneTitle:SetText(state.zone .. GREY .. "  (" .. ns:KindsSeen(list) .. "/" .. #list .. " seen)|r")
  if not state.kind or not ns.KINDS[state.kind] then state.kind = list[1] end
  a.kinds:SetItems(list)
  a.empty:SetShown(#list == 0)
  a.legend:SetText(GREEN .. "*|r seen  " .. RARE .. "orange|r rare" .. (ns.db.buddy and ("  " .. BLUE .. "+|r buddy") or ""))

  local d, id = a.detail, state.kind
  local k = id and ns.KINDS[id]
  for _, region in ipairs({ d.model, d.name, d.sub, d.seen, d.zones, d.map, d.spot, d.guide, d.calls }) do region:SetShown(k ~= nil) end
  d.pick:SetShown(k == nil)
  if not k then return end
  local b = ns.BIRD_BY_KEY[k.s]
  d.model:Show3D(k.d, id)
  d.name:SetText(kindName(k))
  d.sub:SetText(GREY .. b.name .. "  -  " .. UI.levels(k) .. (k.rare and "  -  rare" or "") .. (k.found and "  -  |r" .. GOLD .. "your discovery|r" or "|r"))
  local s = ns.db.kinds[id]
  local seen = s and string.format("%sSeen %d time%s.|r First: %s in %s.", GREEN, s.count, s.count == 1 and "" or "s", UI.fmtDate(s.first), s.zone or "?")
    or (GOLD .. "Lifer waiting!|r " .. GREY .. "Not yet seen.|r")
  if ns.db.buddy and ns.db.buddyKinds[id] then seen = seen .. "\n" .. BLUE .. ns:BuddyShortName() .. " has seen this one.|r" end
  d.seen:SetText(seen)
  d.zones:SetText(GOLD .. "Found in:|r " .. table.concat(k.z, ", "))
  d.map:SetText(ns.db.pins[id] and "Hide from map" or "Show on map")
  if not ns.SPAWNS[id] then d.map:Hide() end
  d.calls:SetCallsFor(k.s)
end

---------------------------------------------------------------------------
-- Zones (zone notes: soundscape, music, credits, birds)
---------------------------------------------------------------------------
local function buildZones(content)
  local z = CreateFrame("Frame", nil, content)
  z:SetAllPoints()
  local zh = label(z, "GameFontNormal", "Zones")
  zh:SetPoint("TOPLEFT", 4, 0)
  local my = button(z, "My zone", 80, 20)
  my:SetPoint("TOPLEFT", 96, 2)
  my:SetScript("OnClick", function() state.notesZone = ns.ZoneName(); z.list:ScrollTo(state.notesZone); ns:RefreshBook() end)
  z.list = UI.makeList(z, 180, 404, 22, function(r, name)
    local here = (name == ns.ZoneName())
    r.left:SetText((here and GOLD or "") .. name .. (here and "|r" or ""))
    r.right:SetText("")
    r.hl:SetShown(name == state.notesZone)
  end, function(name) state.notesZone = name; ns:RefreshBook() end, 8)
  z.list:SetPoint("TOPLEFT", 0, -26)

  local d = CreateFrame("Frame", nil, z)
  d:SetPoint("TOPLEFT", 196, 0)
  d:SetPoint("BOTTOMRIGHT", 0, 0)
  z.detail = d
  d.title = label(d, "GameFontNormalHuge")
  d.title:SetPoint("TOPLEFT", 0, -4)

  d.scapeHead = label(d, "GameFontNormal", "Soundscape")
  d.scapeHead:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -16)
  d.scape = label(d, "GameFontHighlight")
  d.scape:SetPoint("TOPLEFT", d.scapeHead, "BOTTOMLEFT", 0, -6)
  d.scapeDay = button(d, "Day", 64, 22)
  d.scapeDay:SetPoint("TOPLEFT", d.scape, "BOTTOMLEFT", 0, -6)
  d.scapeNight = button(d, "Night", 64, 22)
  d.scapeNight:SetPoint("LEFT", d.scapeDay, "RIGHT", 4, 0)
  for _, pair in ipairs({ { d.scapeDay, "day" }, { d.scapeNight, "night" } }) do
    pair[1]:SetScript("OnClick", function()
      local n = ns.ZONE_NOTES[state.notesZone]
      if n and ns:PlayAmbience(n[1], pair[2]) then setStatus(GREY .. "Playing: " .. state.notesZone .. " soundscape (" .. pair[2] .. ")|r")
      else setStatus(RED .. "That soundscape isn't in this game client's sound library.|r") end
    end)
  end

  d.musicHead = label(d, "GameFontNormal", "Music")
  d.musicHead:SetPoint("TOPLEFT", d.scapeDay, "BOTTOMLEFT", 0, -16)
  d.music = label(d, "GameFontHighlight")
  d.music:SetPoint("TOPLEFT", d.musicHead, "BOTTOMLEFT", 0, -6)
  d.tracks = {}
  for i = 1, 9 do
    local b = button(d, "", 72, 22)
    if i == 1 then b:SetPoint("TOPLEFT", d.music, "BOTTOMLEFT", 0, -6)
    elseif i == 6 then b:SetPoint("TOPLEFT", d.tracks[1], "BOTTOMLEFT", 0, -4)
    else b:SetPoint("LEFT", d.tracks[i - 1], "RIGHT", 4, 0) end
    b:SetScript("OnClick", function(self)
      if ns:PlayFile(self.fileID) then setStatus(GREY .. "Playing: " .. self.trackName .. "|r")
      else setStatus(RED .. "That track isn't in this game client's library.|r") end
    end)
    d.tracks[i] = b
  end
  d.guess = label(d, "GameFontDisableSmall", "Soundscape and music are best guesses for this zone.")
  d.guess:SetPoint("TOPLEFT", d.tracks[6], "BOTTOMLEFT", 0, -8)

  d.creditHead = label(d, "GameFontNormal", "Credits")
  d.creditHead:SetPoint("TOPLEFT", d.guess, "BOTTOMLEFT", 0, -14)
  d.credit = wrapped(d, "GameFontHighlightSmall", 540)
  d.credit:SetPoint("TOPLEFT", d.creditHead, "BOTTOMLEFT", 0, -6)
  d.credit:SetSpacing(2)

  d.birds = wrapped(d, "GameFontHighlight", 400)
  d.birds:SetPoint("BOTTOMLEFT", 0, 6)
  d.atlas = button(d, "Open in Atlas", 120, 22)
  d.atlas:SetPoint("BOTTOMRIGHT", 0, 2)
  d.atlas:SetScript("OnClick", function() state.zone, state.kind, state.tab = state.notesZone, nil, "atlas"; ns:RefreshBook() end)
  return z
end

local function refreshZones(z)
  state.notesZone = state.notesZone or ns.ZoneName()
  local items = {}
  if not ns.ZONE_NOTES[state.notesZone] then items[1] = state.notesZone end
  for _, name in ipairs(ns.NOTE_ZONES) do items[#items + 1] = name end
  z.list:SetItems(items)

  local d, name = z.detail, state.notesZone
  local n = ns.ZONE_NOTES[name]
  d.title:SetText(name)
  local scape
  for _, s in ipairs(ns.SOUNDSCAPES) do if n and s.key == n[1] then scape = s end end
  d.scape:SetText(scape and scape.name or (GREY .. "No soundscape noted for this zone.|r"))
  d.scapeDay:SetEnabled(scape ~= nil); d.scapeNight:SetEnabled(scape ~= nil)

  local theme = n and ns.MUSIC[n[2]]
  d.music:SetText(theme and (theme.name .. GREY .. " theme|r") or (GREY .. "No music noted for this zone.|r"))
  local list = {}
  if theme then
    for i, id in ipairs(theme.day) do list[#list + 1] = { id, (#theme.night > 0 and "Day " or "Track ") .. i } end
    for i, id in ipairs(theme.night) do list[#list + 1] = { id, "Night " .. i } end
  end
  for i, b in ipairs(d.tracks) do
    local t = list[i]
    b:SetShown(t ~= nil)
    if t then b.fileID, b.trackName = t[1], (theme.name .. " - " .. t[2]); b:SetText(t[2]) end
  end

  d.credit:SetText((n and n.note and (n.note .. "\n\n") or "") .. ns.MUSIC_CREDIT)
  local kinds = ns.ZONE_KINDS[name] or {}
  d.birds:SetText(#kinds > 0 and string.format("Birds here: %d kinds, %s%d|r seen", #kinds, GREEN, ns:KindsSeen(kinds))
    or (GREY .. "No wild birds recorded here.|r"))
  d.atlas:SetShown(#kinds > 0)
end

---------------------------------------------------------------------------
-- Journal
---------------------------------------------------------------------------
local function entryTitle(e)
  if e.page then return "Field notes" end
  local k = e.id and ns.KINDS[e.id]
  return k and kindName(k) or e.n or (ns.BIRD_BY_KEY[e.s] and ns.BIRD_BY_KEY[e.s].name) or "?"
end

local function buildJournal(content)
  local j = CreateFrame("Frame", nil, content)
  j:SetAllPoints()
  local head = label(j, "GameFontNormal", "Your birding journal")
  head:SetPoint("TOPLEFT", 4, 0)
  j.count = label(j, "GameFontDisableSmall")
  j.count:SetPoint("LEFT", head, "RIGHT", 8, 0)
  j.list = UI.makeList(j, 320, 404, 26, function(r, e)
    r.left:SetText(GREY .. date("%d %b", e.t) .. "|r  " .. entryTitle(e) .. ((e.note and e.note:match("%S")) and (GOLD .. "  *|r") or ""))
    r.right:SetText(GREY .. (e.c and e.c > 1 and ("x" .. e.c) or "") .. "|r")
    r.hl:SetShown(e == state.entry)
  end, function(e) state.entry = e; ns:RefreshBook() end, 30)
  j.list:SetPoint("TOPLEFT", 0, -26)

  local d = CreateFrame("Frame", nil, j)
  d:SetPoint("TOPLEFT", 336, 0)
  d:SetPoint("BOTTOMRIGHT", 0, 0)
  j.detail = d
  d.title = label(d, "GameFontNormalLarge")
  d.title:SetPoint("TOPLEFT", 0, -2)
  d.meta = wrapped(d, "GameFontHighlightSmall", 410)
  d.meta:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -6)
  d.noteHead = label(d, "GameFontNormal", "Your notes")
  d.noteHead:SetPoint("TOPLEFT", d.meta, "BOTTOMLEFT", 0, -14)
  d.box = UI.makeTextBox(d, 416, 250, function(text)
    if state.entry then
      state.entry.note = text
      j.list:Render()
      ns:Fire("NOTE_CHANGED")
    end
  end)
  d.box:SetPoint("TOPLEFT", d.noteHead, "BOTTOMLEFT", 0, -6)
  d.hint = label(d, "GameFontDisableSmall", "What was it doing? The weather? Who were you with? It saves as you type.")
  d.hint:SetPoint("TOPLEFT", d.box, "BOTTOMLEFT", 2, -4)

  d.page = button(d, "Write a page", 120, 22)
  d.page:SetPoint("BOTTOMLEFT", 0, 0)
  d.page:SetScript("OnClick", function()
    state.entry = ns:AddPage()
    ns:RefreshBook()
    d.box.edit:SetFocus()
  end)
  d.open = button(d, "Open bird", 100, 22)
  d.open:SetPoint("LEFT", d.page, "RIGHT", 4, 0)
  d.open:SetScript("OnClick", function()
    local e = state.entry
    if e and e.id then ns:OpenKind(e.id) elseif e and e.s then ns:OpenBook(e.s) end
  end)
  d.delete = button(d, "Delete entry", 110, 22)
  d.delete:SetPoint("BOTTOMRIGHT", 0, 0)
  d.delete:SetScript("OnClick", function()
    local e = state.entry
    if not e then return end
    for i, x in ipairs(ns.db.log) do if x == e then table.remove(ns.db.log, i) break end end
    state.entry = nil
    ns:Fire("NOTE_CHANGED")
    ns:RefreshBook()
  end)
  d.empty = wrapped(j, "GameFontDisable", 380)
  d.empty:SetPoint("CENTER", d, "CENTER", 0, 40)
  d.empty:SetJustifyH("CENTER")
  d.empty:SetText("Your journal fills itself as you spot birds. Pick an entry to add your own notes, or write a page.")
  return j
end

local function refreshJournal(j)
  local items = {}
  for i = #ns.db.log, 1, -1 do items[#items + 1] = ns.db.log[i] end
  local found = false
  for _, e in ipairs(items) do if e == state.entry then found = true end end
  if not found then state.entry = items[1] end
  j.list:SetItems(items)
  j.count:SetText(#items .. " entries")

  local d, e = j.detail, state.entry
  for _, r in ipairs({ d.title, d.meta, d.noteHead, d.box, d.hint, d.open, d.delete }) do r:SetShown(e ~= nil) end
  d.empty:SetShown(e == nil)
  if not e then return end
  d.title:SetText(entryTitle(e))
  local hour = e.h and string.format("%02d:00 game time", e.h) or ""
  local what = e.page and "A page of field notes." or
    string.format("Seen%s.", (e.c and e.c > 1) and (" " .. e.c .. " times that day") or "")
  d.meta:SetText(string.format("%s%s|r  -  %s  -  %s\n%s", GOLD, e.zone or "?", date("%A %d %B %Y, %H:%M", e.t), hour, what))
  if not d.box.edit:HasFocus() then d.box.edit:SetText(e.note or "") end
  d.open:SetShown(not e.page)
end

---------------------------------------------------------------------------
-- Badges
---------------------------------------------------------------------------
local function buildBadges(content)
  local b = CreateFrame("Frame", nil, content)
  b:SetAllPoints()
  b.head = label(b, "GameFontNormal")
  b.head:SetPoint("TOPLEFT", 4, 0)
  b.list = UI.makeList(b, 752, 404, 30, function(r, p)
    local done = p.earned
    r.left:SetText((done and (GOLD .. "* ") or (GREY .. "  ")) .. p.badge.name .. "|r  " .. GREY .. p.badge.desc .. "|r")
    r.right:SetText(done and (GREEN .. UI.fmtDate(p.earned) .. "|r") or (GREY .. p.cur .. " / " .. p.goal .. "|r"))
    r.hl:SetShown(false)
  end, function() end, 110)
  b.list:SetPoint("TOPLEFT", 0, -26)
  return b
end

local function refreshBadges(b)
  local items = ns:BadgeProgress()
  table.sort(items, function(x, y)
    if (x.earned ~= nil) ~= (y.earned ~= nil) then return x.earned ~= nil end
    local fx, fy = x.goal > 0 and x.cur / x.goal or 0, y.goal > 0 and y.cur / y.goal or 0
    if fx ~= fy then return fx > fy end
    return x.badge.name < y.badge.name
  end)
  b.list:SetItems(items)
  b.head:SetText(string.format("Badges  %s%d|r / %d earned", GREEN, ns:BadgesEarned(), #ns.BADGES))
end

---------------------------------------------------------------------------
-- Soundscapes (library)
---------------------------------------------------------------------------
local function buildSounds(content)
  local sframe = CreateFrame("Frame", nil, content)
  sframe:SetAllPoints()
  local intro = wrapped(sframe, "GameFontHighlightSmall", 740)
  intro:SetPoint("TOPLEFT", 4, 0)
  intro:SetText("The ambience beds the game lays under each landscape (birdsong, wind, insects). Zone lists are best guesses: tell us if one sounds wrong.")
  local half = math.ceil(#ns.SOUNDSCAPES / 2)
  for i, s in ipairs(ns.SOUNDSCAPES) do
    local col = (i <= half) and 0 or 1
    local row = (i <= half) and i or (i - half)
    local y = -26 - (row - 1) * 44
    local x = 4 + col * 378
    local n = label(sframe, "GameFontNormal", s.name)
    n:SetPoint("TOPLEFT", x, y)
    local zl = label(sframe, "GameFontHighlightSmall", GREY .. s.zones .. "|r")
    zl:SetPoint("TOPLEFT", n, "BOTTOMLEFT", 0, -2)
    zl:SetWidth(220); zl:SetJustifyH("LEFT"); zl:SetWordWrap(false)
    local amb = ns.AMBIENCE_IDS[s.key] or {}
    local day = button(sframe, "Day", 64, 22)
    day:SetPoint("TOPLEFT", x + 228, y + 2)
    local night = button(sframe, "Night", 64, 22)
    night:SetPoint("LEFT", day, "RIGHT", 4, 0)
    for _, pair in ipairs({ { "day", day }, { "night", night } }) do
      local tod, b = pair[1], pair[2]
      if not amb[tod] then b:Disable() end
      b:SetScript("OnClick", function()
        if ns:PlayAmbience(s.key, tod) then setStatus(GREY .. "Playing: " .. s.name .. " (" .. tod .. ")|r")
        else setStatus(RED .. "That soundscape isn't in this game client's sound library.|r") end
      end)
    end
  end
  return sframe
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function build()
  local f = CreateFrame("Frame", "BirdsongBook", UIParent, "BackdropTemplate")
  f:SetSize(W, H)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.07, 0.06, 0.04, 0.97)
  local solid = f:CreateTexture(nil, "BACKGROUND", nil, -8) -- stop names in the world showing through
  solid:SetPoint("TOPLEFT", 6, -6); solid:SetPoint("BOTTOMRIGHT", -6, 6)
  solid:SetColorTexture(0.06, 0.05, 0.035, 1)
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    ns.db.window = { p = p, rp = rp, x = x, y = y }
  end)
  local wpos = ns.db.window or {}
  if wpos.p then f:SetPoint(wpos.p, UIParent, wpos.rp, wpos.x, wpos.y) else f:SetPoint("CENTER") end
  table.insert(UISpecialFrames, "BirdsongBook")
  f:SetScript("OnHide", function() ns:StopSound() end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local icon = f:CreateTexture(nil, "ARTWORK")
  icon:SetSize(32, 32)
  icon:SetPoint("TOPLEFT", 14, -12)
  icon:SetTexture("Interface\\AddOns\\Birdsong\\media\\icon")
  f.title = label(f, "GameFontNormalLarge", BLUE .. "Birdsong|r  " .. GREY .. "a field guide to Azeroth|r")
  f.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
  f.sub = label(f, "GameFontHighlightSmall")
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4)
  f.buddy = label(f, "GameFontHighlightSmall")
  f.buddy:SetPoint("TOPRIGHT", -40, -22)

  -- Tab bar: a full-width row under the header
  f.tabs = {}
  local tw = math.floor((W - 28 - (#TABS - 1) * 4) / #TABS)
  for i, t in ipairs(TABS) do
    local b = button(f, t.label, tw, 24)
    b:SetPoint("TOPLEFT", 14 + (i - 1) * (tw + 4), -52)
    b:SetScript("OnClick", function() state.tab = t.key; ns:RefreshBook() end)
    f.tabs[i] = b
  end

  -- Footer
  f.stop = button(f, "Stop sound", 100, 22)
  f.stop:SetPoint("BOTTOMRIGHT", -16, 14)
  f.stop:SetScript("OnClick", function() ns:StopSound(); setStatus("") end)
  f.status = label(f, "GameFontHighlightSmall")
  f.status:SetPoint("BOTTOMLEFT", 18, 20)
  f.status:SetPoint("RIGHT", f.stop, "LEFT", -10, 0)
  f.status:SetJustifyH("LEFT")
  ns.bookStatus = f.status

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", 14, -86)
  content:SetPoint("BOTTOMRIGHT", -14, 44)
  f.content = content

  book = f
  f.panes = {
    guide = buildGuide(content),
    atlas = buildAtlas(content),
    zones = buildZones(content),
    journal = buildJournal(content),
    badges = buildBadges(content),
    sounds = buildSounds(content),
    settings = ns:BuildSettingsPanel(content),
  }
  return f
end

function ns:RefreshBook()
  if not book or not book:IsShown() then return end
  local zone = ns.ZoneName()
  book.sub:SetText(string.format("%s%s|r   Life list: %s%d|r/%d species, %s%d|r/%d kinds   Badges: %s%d|r",
    GOLD, zone, GREEN, ns:SpeciesSeen(), #ns.BIRDS, GREEN, ns:KindsSeen(), ns.KIND_COUNT, GREEN, ns:BadgesEarned()))
  book.buddy:SetText(ns.db.buddy and (BLUE .. ns:BuddyShortName() .. "|r " .. GREY .. (ns.db.buddyInfo.kinds and (ns.db.buddyInfo.kinds .. " kinds") or "not heard from yet") .. "|r") or "")
  for i, t in ipairs(TABS) do
    local active = (t.key == state.tab)
    book.panes[t.key]:SetShown(active)
    if active then book.tabs[i]:Disable() else book.tabs[i]:Enable() end
  end
  local p = book.panes[state.tab]
  if state.tab == "guide" then refreshGuide(p)
  elseif state.tab == "atlas" then refreshAtlas(p)
  elseif state.tab == "zones" then refreshZones(p)
  elseif state.tab == "journal" then refreshJournal(p)
  elseif state.tab == "badges" then refreshBadges(p)
  elseif state.tab == "settings" and p.Refresh then p:Refresh() end
end

-- OpenBook(speciesKey, tab)
function ns:OpenBook(key, tab)
  if not book then build() end
  if key then state.species = key; state.tab = "guide" end
  if tab then state.tab = tab end
  book:Show()
  setStatus(GREY .. "Tip: target or mouse over a bird out of combat to add it to your life list.|r")
  self:RefreshBook()
end

-- Open the Atlas on one creature (prefers your current zone if it lives here)
function ns:OpenKind(id)
  local k = ns.KINDS[id]
  if not k then return self:OpenBook() end
  local zone = ns.ZoneName()
  state.zone = k.z[1]
  for _, z in ipairs(k.z) do if z == zone then state.zone = z end end
  state.kind, state.tab = id, "atlas"
  self:OpenBook()
  book.panes.atlas.zones:ScrollTo(state.zone)
end

function ns:ToggleBook()
  if book and book:IsShown() then book:Hide() else self:OpenBook() end
end

for _, e in ipairs({ "SIGHTINGS_CHANGED", "SETTINGS_CHANGED", "BUDDY_UPDATED", "PINS_CHANGED", "BADGE_EARNED", "LOG_CHANGED" }) do
  ns:Listen(e, function() ns:RefreshBook() end)
end
ns:On("ZONE_CHANGED_NEW_AREA", function() ns:RefreshBook() end)
