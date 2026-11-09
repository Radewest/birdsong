-- Birdsong: world map pins. Shows where tracked birds spawn (or every bird in the zone you're viewing).
-- Spawn points from Spawns.lua (pfQuest). Zone names are matched to map IDs at runtime, so no map IDs
-- are hard-coded. Pins sit on the world map canvas and are scaled against the canvas zoom.

local _, ns = ...
local UI = ns.UI

local overlay, overlayCanvas, pins, used = nil, nil, {}, 0
local mapIDByName

-- Walk the map tree once: zone name -> uiMapID
local function buildMapIndex()
  mapIDByName = {}
  if not (C_Map and C_Map.GetMapChildrenInfo) then return end
  for _, root in ipairs({ 947, 946, 1414, 1415 }) do
    local ok, kids = pcall(C_Map.GetMapChildrenInfo, root, nil, true)
    if ok and type(kids) == "table" then
      for _, info in ipairs(kids) do
        if info.name and not mapIDByName[info.name] then mapIDByName[info.name] = info.mapID end
      end
    end
  end
end

function ns:MapIDForZone(zone)
  if not mapIDByName then buildMapIndex() end
  return mapIDByName[zone]
end

local function zoneOfMap(mapID)
  local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  return info and info.name
end

local function getPin()
  used = used + 1
  local p = pins[used]
  if not p then
    p = CreateFrame("Frame", nil, overlay)
    p:SetSize(20, 20)
    p.tex = p:CreateTexture(nil, "OVERLAY")
    p.tex:SetAllPoints()
    p.tex:SetTexture("Interface\\AddOns\\Birdsong\\media\\pin")
    p.ring = p:CreateTexture(nil, "BACKGROUND") -- gold glow behind rare birds
    p.ring:SetPoint("CENTER")
    p.ring:SetSize(34, 34)
    p.ring:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    p.ring:SetBlendMode("ADD")
    p:EnableMouse(true)
    p:SetScript("OnEnter", function(self)
      local k = ns.KINDS[self.id]
      if not k then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine((k.rare and UI.RARE or "|cffffffff") .. k.n .. "|r")
      GameTooltip:AddLine(ns.BIRD_BY_KEY[k.s].name .. " - " .. UI.levels(k), 0.7, 0.7, 0.7)
      GameTooltip:AddLine(ns.db.kinds[self.id] and "On your life list" or "Not on your life list yet",
        ns.db.kinds[self.id] and 0.25 or 1, ns.db.kinds[self.id] and 1 or 0.44, ns.db.kinds[self.id] and 0.25 or 0.44)
      GameTooltip:AddLine("Birdsong", 0.5, 0.83, 1)
      GameTooltip:Show()
    end)
    p:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p:SetScript("OnMouseUp", function(self) ns:OpenKind(self.id) end)
    pins[used] = p
  end
  return p
end

function ns:RefreshPins()
  if not overlay or not WorldMapFrame or not WorldMapFrame:IsShown() then return end
  for i = 1, used do pins[i]:Hide() end
  used = 0
  local zone = zoneOfMap(WorldMapFrame.GetMapID and WorldMapFrame:GetMapID())
  if not zone then return end
  local canvas = overlayCanvas
  local w, h = canvas:GetWidth(), canvas:GetHeight()
  local scale = 1 / ((WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvasScale and WorldMapFrame.ScrollContainer:GetCanvasScale()) or 1)
  for id, zones in pairs(ns.SPAWNS) do
    local show = self.db.pins[id] or (self.db.pinsAll and ns.KINDS[id])
    local pts = show and zones[zone]
    if pts then
      local k = ns.KINDS[id]
      for i = 1, #pts, 2 do
        local p = getPin()
        p.id = id
        p:SetScale(scale)
        p:ClearAllPoints()
        p:SetPoint("CENTER", canvas, "TOPLEFT", (pts[i] / 100) * w / scale, -(pts[i + 1] / 100) * h / scale)
        p.ring:SetShown(k.rare and true or false)
        p.ring:SetVertexColor(1, 0.67, 0.2)
        p.tex:SetDesaturated(not self.db.kinds[id])
        p:Show()
      end
    end
  end
end

-- Track/untrack one bird and open the map on the best zone for it
function ns:ShowOnMap(id)
  local k = ns.KINDS[id]
  if not k then return end
  self.db.pins[id] = true
  local zone = k.z[1]
  for _, z in ipairs(k.z) do if z == ns.ZoneName() then zone = z end end
  local mapID = self:MapIDForZone(zone)
  if mapID and OpenWorldMap then pcall(OpenWorldMap, mapID)
  elseif ToggleWorldMap then pcall(ToggleWorldMap) end
  if WorldMapFrame and mapID and WorldMapFrame.SetMapID then pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID) end
  self:RefreshPins()
  self:Fire("PINS_CHANGED")
end

function ns:HideFromMap(id)
  self.db.pins[id] = nil
  self:RefreshPins()
  self:Fire("PINS_CHANGED")
end

function ns:ClearPins()
  wipe(self.db.pins)
  self:RefreshPins()
  self:Fire("PINS_CHANGED")
end

ns:Listen("LOGIN", function()
  if not WorldMapFrame then return end
  local canvas = (WorldMapFrame.GetCanvas and WorldMapFrame:GetCanvas())
    or (WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child)
  if not canvas then return end
  overlayCanvas = canvas
  overlay = CreateFrame("Frame", "BirdsongMapOverlay", canvas)
  overlay:SetAllPoints()
  overlay:SetFrameLevel((canvas.GetFrameLevel and canvas:GetFrameLevel() or 1) + 50)
  WorldMapFrame:HookScript("OnShow", function() ns.SafeCall(ns.RefreshPins, ns) end)
  if WorldMapFrame.OnMapChanged then
    hooksecurefunc(WorldMapFrame, "OnMapChanged", function() ns.SafeCall(ns.RefreshPins, ns) end)
  end
  if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.HookScript then
    WorldMapFrame.ScrollContainer:HookScript("OnMouseWheel", function() ns.SafeCall(ns.RefreshPins, ns) end)
  end
end)

ns:Listen("SETTINGS_CHANGED", function() ns:RefreshPins() end)
ns:Listen("SIGHTINGS_CHANGED", function() ns:RefreshPins() end)
