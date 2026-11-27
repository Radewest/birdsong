-- Birdsong: settings
-- ns:BuildSettingsPanel(parent) builds the panel for the book's Settings tab. Blizzard's Options -> AddOns
-- gets a short page with a button to it. Plain frames, not fragile templates (see the playbook).

local _, ns = ...

local GREY = "|cff9d9d9d"
local panels = {}

local function checkbox(parent, text, tip, get, set)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(300, 24)
  local box = b:CreateTexture(nil, "ARTWORK")
  box:SetSize(24, 24)
  box:SetPoint("LEFT")
  box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  local tick = b:CreateTexture(nil, "OVERLAY")
  tick:SetAllPoints(box)
  tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints(box)
  hl:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
  hl:SetBlendMode("ADD")
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", box, "RIGHT", 4, 0)
  fs:SetText(text)
  if tip then
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    t:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    t:SetText(tip)
  end
  function b:Refresh() tick:SetShown(get() and true or false) end
  b:SetScript("OnClick", function(self)
    set(not get())
    self:Refresh()
    ns:Fire("SETTINGS_CHANGED")
  end)
  return b
end

local function cycle(parent, text, options, get, set)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(400, 24)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", 4, 0)
  fs:SetText(text)
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetSize(120, 22)
  b:SetPoint("LEFT", 190, 0)
  function f:Refresh()
    local v = get()
    for _, o in ipairs(options) do if o[1] == v then b:SetText(o[2]) end end
  end
  b:SetScript("OnClick", function()
    local v, idx = get(), 1
    for i, o in ipairs(options) do if o[1] == v then idx = i end end
    set(options[(idx % #options) + 1][1])
    f:Refresh()
    ns:Fire("SETTINGS_CHANGED")
  end)
  return f
end

local function header(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetText(text)
  return fs
end

StaticPopupDialogs["BIRDSONG_RESET"] = {
  text = "Clear your whole Birdsong life list? This can't be undone.",
  button1 = ACCEPT or "Accept",
  button2 = CANCEL or "Cancel",
  OnAccept = function()
    wipe(ns.db.sightings); wipe(ns.db.zones); wipe(ns.db.kinds); wipe(ns.db.log); wipe(ns.db.badges)
    ns:Print("Life list cleared.")
    ns:Fire("SIGHTINGS_CHANGED")
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function ns:BuildSettingsPanel(parent)
  local p = CreateFrame("Frame", nil, parent)
  p:SetAllPoints()
  local items = {}
  local col = { x = 8, y = -4 }
  local function column(x) col.x, col.y = x, -4 end
  local function place(widget, gap)
    widget:SetPoint("TOPLEFT", col.x, col.y)
    col.y = col.y - (gap or 26)
    items[#items + 1] = widget
    return widget
  end
  local function head(text)
    if col.y < -10 then col.y = col.y - 6 end
    local h = header(p, text)
    h:SetPoint("TOPLEFT", col.x - 4, col.y)
    col.y = col.y - 22
  end
  local db = function() return ns.db end

  -- Left column
  head("Pop-ups")
  place(checkbox(p, "New species (Lifer!)", nil,
    function() return db().toast end, function(v) db().toast = v end))
  place(checkbox(p, "New kinds", nil,
    function() return db().toastKinds end, function(v) db().toastKinds = v end))
  place(checkbox(p, "Play the bird's call", nil,
    function() return db().toastSound end, function(v) db().toastSound = v end))
  place(cycle(p, "Lifer reaction", { { "emote", "Gasp + /gasp" }, { "sound", "Gasp sound" }, { "off", "Off" } },
    function() return db().liferReaction end, function(v) db().liferReaction = v end))
  local testRow = CreateFrame("Frame", nil, p)
  testRow:SetSize(360, 24)
  local testGasp = CreateFrame("Button", nil, testRow, "UIPanelButtonTemplate")
  testGasp:SetSize(120, 22); testGasp:SetPoint("LEFT", 186, 0); testGasp:SetText("Test the gasp")
  local testMsg = testRow:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  testMsg:SetPoint("LEFT", testGasp, "RIGHT", 8, 0)
  testGasp:SetScript("OnClick", function()
    if ns:PlayLiferSound() then testMsg:SetText("|cff40ff40Playing|r")
    else testMsg:SetText("|cffff7070Not found: restart WoW|r") end
  end)
  place(testRow, 26)
  place(checkbox(p, "Buddy's lifers", nil,
    function() return db().buddyToasts end, function(v) db().buddyToasts = v end))

  head("Sound and models")
  place(cycle(p, "Sound channel", { { "Master", "Master" }, { "SFX", "Effects" }, { "Ambience", "Ambience" } },
    function() return db().channel end, function(v) db().channel = v end))
  place(checkbox(p, "Models turn slowly", nil,
    function() return db().spin end, function(v) db().spin = v end))

  head("Interface")
  place(checkbox(p, "Minimap button", nil,
    function() return not db().minimap.hide end, function(v) db().minimap.hide = not v end))
  place(checkbox(p, "Birdsong line in tooltips", nil,
    function() return db().tooltip end, function(v) db().tooltip = v end))
  place(cycle(p, "Chat messages", { { "off", "Off" }, { "important", "Important" }, { "all", "Everything" } },
    function() return db().chat end, function(v) db().chat = v end))

  -- Right column
  column(380)
  head("World map")
  place(checkbox(p, "Pin every bird in the zone you view", nil,
    function() return db().pinsAll end, function(v) db().pinsAll = v end))
  local clearPins = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
  clearPins:SetSize(170, 22); clearPins:SetText("Clear tracked birds")
  clearPins:SetScript("OnClick", function() ns:ClearPins(); ns:Print("Map pins cleared.") end)
  place(clearPins, 30)

  head("Birding buddy")
  local status = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetWidth(360); status:SetJustifyH("LEFT")
  function status:Refresh()
    local b = ns.db.buddy
    local info = ns.db.buddyInfo or {}
    if not b then
      self:SetText(GREY .. "No buddy yet. Both of you set each other to compare life lists.|r")
    else
      local heard = info.at and ("last heard " .. date("%d %b %H:%M", info.at)) or "not heard from yet"
      local warn = info.sameAtlas == false and "  |cffff7070(different Birdsong version)|r" or ""
      self:SetText("|cff7fd4ff" .. ns:BuddyShortName() .. "|r  " .. GREY .. (info.kinds and (info.kinds .. " kinds, ") or "") .. heard .. "|r" .. warn)
    end
  end
  place(status, 22)
  local row1 = CreateFrame("Frame", nil, p)
  row1:SetSize(360, 24)
  local fromT = CreateFrame("Button", nil, row1, "UIPanelButtonTemplate")
  fromT:SetSize(118, 22); fromT:SetPoint("LEFT"); fromT:SetText("Set from target")
  fromT:SetScript("OnClick", function() ns:SetBuddyFromTarget() end)
  local fromTj = CreateFrame("Button", nil, row1, "UIPanelButtonTemplate")
  fromTj:SetSize(118, 22); fromTj:SetPoint("LEFT", fromT, "RIGHT", 4, 0); fromTj:SetText("Use my tjommie")
  fromTj:SetScript("OnClick", function() ns:SetBuddyFromTjommie() end)
  local clr = CreateFrame("Button", nil, row1, "UIPanelButtonTemplate")
  clr:SetSize(80, 22); clr:SetPoint("LEFT", fromTj, "RIGHT", 4, 0); clr:SetText("Clear")
  clr:SetScript("OnClick", function() ns:SetBuddy(nil) end)
  function row1:Refresh()
    fromTj:SetEnabled(ns:TjommieBuddy() ~= nil)
    clr:SetEnabled(ns.db.buddy ~= nil)
  end
  place(row1, 30)

  head("Your data")
  local row = CreateFrame("Frame", nil, p)
  row:SetSize(360, 24)
  local reset = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  reset:SetSize(118, 22); reset:SetPoint("LEFT", 0, 0); reset:SetText("Clear life list")
  reset:SetScript("OnClick", function() StaticPopup_Show("BIRDSONG_RESET") end)
  local pos = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  pos:SetSize(118, 22); pos:SetPoint("LEFT", reset, "RIGHT", 4, 0); pos:SetText("Reset window")
  pos:SetScript("OnClick", function()
    ns.db.window = {}
    if BirdsongBook then BirdsongBook:ClearAllPoints(); BirdsongBook:SetPoint("CENTER") end
  end)
  local bugs = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  bugs:SetSize(80, 22); bugs:SetPoint("LEFT", pos, "RIGHT", 4, 0); bugs:SetText("Bug log")
  bugs:SetScript("OnClick", function() ns:ShowBugs() end)
  place(row, 34)

  local about = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  about:SetPoint("TOPLEFT", col.x, col.y - 4)
  about:SetWidth(360); about:SetJustifyH("LEFT")
  about:SetText("Birdsong v" .. ns.VERSION .. ". Sounds are the game's own files. Bird data from the cmangos classic-db and pfQuest projects. Type /birds help for commands.")

  function p:Refresh()
    for _, w in ipairs(items) do if w.Refresh then w:Refresh() end end
  end
  p:SetScript("OnShow", function(self) self:Refresh() end)
  panels[#panels + 1] = p
  return p
end

-- Keep every copy of the panel in sync
ns:Listen("BUDDY_UPDATED", function() ns:Fire("SETTINGS_CHANGED") end)
ns:Listen("SETTINGS_CHANGED", function()
  for _, p in ipairs(panels) do if p:IsShown() then p:Refresh() end end
end)

-- Blizzard Options -> AddOns: a pointer to the Settings tab (the full panel is wider than Blizzard's frame)
ns:Listen("LOGIN", function()
  local canvas = CreateFrame("Frame")
  canvas.name = "Birdsong"
  local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("|cff7fd4ffBirdsong|r")
  local text = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
  text:SetText("All of Birdsong's settings live in its field guide.")
  local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
  open:SetSize(200, 26)
  open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
  open:SetText("Open Birdsong settings")
  open:SetScript("OnClick", function()
    if SettingsPanel and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
    ns:OpenBook(nil, "settings")
  end)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "Birdsong")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat); ns.settingsCategory = cat end
  elseif InterfaceOptions_AddCategory then
    pcall(InterfaceOptions_AddCategory, canvas)
  end
end)
