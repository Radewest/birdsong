-- Birdsong: minimap button. Left-click opens the book, right-click opens Settings, drag to move.

local _, ns = ...

local btn

local function place()
  local a = math.rad(ns.db.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 6
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function build()
  btn = CreateFrame("Button", "BirdsongMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  local icon = btn:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture("Interface\\AddOns\\Birdsong\\media\\icon")
  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  btn:SetScript("OnClick", function(_, mouse)
    if mouse == "RightButton" then ns:OpenBook(nil, "settings") else ns:ToggleBook() end
  end)
  btn:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      ns.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      place()
    end)
  end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff7fd4ffBirdsong|r")
    GameTooltip:AddLine(string.format("Life list: %d species, %d kinds", ns:SpeciesSeen(), ns:KindsSeen()), 1, 1, 1)
    GameTooltip:AddLine("Left-click: field guide   Right-click: settings", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function update()
  if not btn then build() end
  if ns.db.minimap.hide then btn:Hide() else btn:Show(); place() end
end

ns:Listen("LOGIN", update)
ns:Listen("SETTINGS_CHANGED", update)
