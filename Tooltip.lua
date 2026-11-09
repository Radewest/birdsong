-- Birdsong: a line in unit tooltips for birds ("Lifer waiting!" / "Seen 3 times").

local _, ns = ...
local UI = ns.UI

function ns:TooltipLines(guid, name)
  if guid and ns.IsSecret(guid) then guid = nil end
  if name and ns.IsSecret(name) then name = nil end
  local id = ns.NpcIDFromGUID(guid)
  local kind = id and ns.KINDS[id]
  local bird = kind and ns.BIRD_BY_KEY[kind.s] or (name and ns:MatchBird(name))
  if not bird then return nil end
  local lines = {}
  local seen = kind and ns.db.kinds[id] or (not kind and ns.db.sightings[bird.key])
  local head = UI.BLUE .. "Birdsong:|r " .. bird.name .. (kind and kind.rare and ("  " .. UI.RARE .. "Rare!|r") or "")
  lines[#lines + 1] = head
  if seen then
    lines[#lines + 1] = UI.GREEN .. "On your life list|r " .. UI.GREY .. "(seen " .. (seen.count or 1) .. "x)|r"
  else
    lines[#lines + 1] = UI.GOLD .. "Lifer waiting!|r " .. UI.GREY .. "Not on your life list yet|r"
  end
  if kind and ns.db.buddy and ns.db.buddyKinds[id] then
    lines[#lines + 1] = UI.GREY .. ns:BuddyShortName() .. " has seen this one|r"
  end
  return lines
end

local function addTo(tt, guid, name)
  if not ns.db or not ns.db.tooltip then return end
  local ok, lines = pcall(ns.TooltipLines, ns, guid, name)
  if not ok or not lines then return end
  for _, l in ipairs(lines) do tt:AddLine(l) end
  if tt.Show then tt:Show() end
end

ns:Listen("LOGIN", function()
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt, data)
      if tt ~= GameTooltip then return end
      local guid = data and data.guid
      local _, unit = tt:GetUnit()
      local name = unit and UnitName(unit)
      if unit and UnitIsPlayer(unit) then return end
      addTo(tt, guid, name)
    end)
  elseif GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tt)
      local _, unit = tt:GetUnit()
      if not unit or UnitIsPlayer(unit) then return end
      addTo(tt, UnitGUID(unit), UnitName(unit))
    end)
  end
end)
