-- Birdsong: 3D model viewer
-- ns:CreateModelView(parent, w, h) -> a framed PlayerModel that shows a creature by display ID
-- (falls back to creature ID), turns slowly, and can be dragged to rotate or wheeled to zoom.

local _, ns = ...

function ns:CreateModelView(parent, w, h)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetSize(w, h)
  box:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  box:SetBackdropColor(0.02, 0.05, 0.06, 0.9)
  box:SetBackdropBorderColor(0.5, 0.83, 1, 0.6)

  local ok, m = pcall(CreateFrame, "PlayerModel", nil, box)
  if not ok or not m then
    local fs = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    fs:SetPoint("CENTER"); fs:SetText("3D models aren't available")
    box.Show3D = function() end
    return box
  end
  m:SetPoint("TOPLEFT", 4, -4)
  m:SetPoint("BOTTOMRIGHT", -4, 4)
  box.model = m

  local hint = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", 0, 6)
  hint:SetText("drag to turn, scroll to zoom")
  box.hint = hint

  local rot, zoom, dragging, lastX = 0.6, 1.0, false, 0
  local function apply()
    pcall(m.SetRotation, m, rot)
    if m.SetCamDistanceScale then pcall(m.SetCamDistanceScale, m, zoom) end
  end

  m:EnableMouse(true)
  m:EnableMouseWheel(true)
  m:SetScript("OnMouseDown", function() dragging = true; lastX = GetCursorPosition() end)
  m:SetScript("OnMouseUp", function() dragging = false end)
  m:SetScript("OnMouseWheel", function(_, delta)
    zoom = math.max(0.5, math.min(3, zoom - delta * 0.15)); apply()
  end)
  m:SetScript("OnUpdate", function(_, elapsed)
    if dragging then
      local x = GetCursorPosition()
      rot = rot + (x - lastX) * 0.02
      lastX = x
      apply()
    elseif ns.db and ns.db.spin then
      rot = rot + elapsed * 0.4
      apply()
    end
  end)

  -- Show a creature. displayID first (works without having seen it); creature ID as a fallback.
  function box:Show3D(displayID, npcID)
    pcall(m.ClearModel, m)
    local shown = false
    if displayID and m.SetDisplayInfo then
      shown = pcall(m.SetDisplayInfo, m, displayID)
      if shown and m.GetModelFileID then
        local fid = m:GetModelFileID()
        if not fid or fid == 0 then shown = false end
      end
    end
    if not shown and npcID and m.SetCreature then
      shown = pcall(m.SetCreature, m, npcID)
    end
    rot, zoom = 0.6, 1.0
    apply()
    return shown
  end

  return box
end
