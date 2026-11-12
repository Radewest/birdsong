-- Birdsong: pop-ups. New species ("Lifer!"), new kind, rare bird, badge earned, buddy's lifer.
-- On screen only (never echoes to chat by default). Click opens the page; "Spot" does the binoculars emote.

local _, ns = ...
local UI = ns.UI

local toast
local nextInQueue

local function build()
  local f = CreateFrame("Button", "BirdsongToast", UIParent, "BackdropTemplate")
  f:SetSize(340, 64)
  f:SetPoint("TOP", UIParent, "TOP", 0, -140)
  f:SetFrameStrata("HIGH")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0.06, 0.09, 0.07, 0.95)

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(40, 40)
  f.icon:SetPoint("LEFT", 12, 0)
  f.icon:SetTexture("Interface\\AddOns\\Birdsong\\media\\icon")
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2)
  f.lifer = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.lifer:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.lifer:SetText("|cff40ff40Lifer!|r")
  f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.body:SetJustifyH("LEFT")

  f.spot = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.spot:SetSize(54, 20)
  f.spot:SetPoint("TOPRIGHT", -8, -8)
  f.spot:SetText("Spot")
  f.spot:SetScript("OnClick", function(self)
    ns:Spot(f.creatureName, f.rare)
    self:Disable()
  end)

  f:SetScript("OnClick", function(self)
    self:Hide()
    if self.badge then ns:OpenBook(nil, "badges")
    elseif self.kindID then ns:OpenKind(self.kindID)
    elseif self.birdKey then ns:OpenBook(self.birdKey) end
  end)
  f:SetScript("OnHide", function()
    if C_Timer then C_Timer.After(0.4, nextInQueue) else nextInQueue() end
  end)
  f:Hide()
  return f
end

-- opts: title, body, lifer, sound (species key), kindID, birdKey, creatureName, rare, badge, spot, border {r,g,b}
local queue = {}
local showNow

-- Queue pop-ups so a badge doesn't cover a "Lifer!"
local function show(o)
  toast = toast or build()
  if toast:IsShown() then
    if #queue < 5 then queue[#queue + 1] = o end
    return
  end
  showNow(o)
end

nextInQueue = function()
  local o = table.remove(queue, 1)
  if o then showNow(o) end
end

showNow = function(o)
  toast.kindID, toast.birdKey, toast.creatureName, toast.rare, toast.badge = o.kindID, o.birdKey, o.creatureName, o.rare, o.badge
  toast.title:SetText(o.title)
  toast.lifer:SetShown(o.lifer and true or false)
  toast.body:ClearAllPoints()
  toast.body:SetPoint("TOPLEFT", o.lifer and toast.lifer or toast.title, "BOTTOMLEFT", 0, -4)
  toast.body:SetPoint("RIGHT", -10, 0)
  toast.body:SetText(o.body or "")
  toast:SetHeight(o.lifer and 82 or 64)
  toast.icon:SetTexture(o.icon or "Interface\\AddOns\\Birdsong\\media\\icon")
  local c = o.border or { 0.5, 0.83, 1 }
  toast:SetBackdropBorderColor(c[1], c[2], c[3])
  toast.spot:SetShown(o.spot and true or false)
  toast.spot:Enable()
  toast:Show()
  if o.sound and ns.db.toastSound then
    local t = ns:SignatureCall(o.sound)
    if t then
      -- after a Lifer reaction, let the gasp finish before the bird calls
      if o.callDelay and C_Timer then
        C_Timer.After(o.callDelay, function() ns:PlayBird(o.sound, t) end)
      else
        ns:PlayBird(o.sound, t)
      end
    end
  end
  local shownAt = GetTime()
  toast.shownAt = shownAt
  if C_Timer then
    C_Timer.After(o.rare and 10 or 7, function() if toast.shownAt == shownAt then toast:Hide() end end)
  end
end
ns.ShowToast = show

---------------------------------------------------------------------------
-- Lifer reaction: Harry's gasp sound clip, plus the /gasp emote (setting: off | sound | emote)
---------------------------------------------------------------------------
local LIFER_SOUND = "Interface\\AddOns\\Birdsong\\media\\lifer.ogg"
local LIFER_LENGTH = 3.2  -- seconds; the bird's call waits this long

-- Returns how long to wait before the bird's call (0 if no sound played)
function ns:LiferReaction()
  local mode = self.db.liferReaction or "emote"
  if mode == "off" then return 0 end
  local played = false
  if PlaySoundFile then
    local ok, willPlay = pcall(PlaySoundFile, LIFER_SOUND, self.db.channel or "Master")
    played = ok and willPlay and true or false
  end
  if mode == "emote" and not (InCombatLockdown and InCombatLockdown()) then
    -- may be blocked by the client's add-on rules; never let that break anything
    if DoEmote then pcall(DoEmote, "GASP")
    elseif C_ChatInfo and C_ChatInfo.PerformEmote then pcall(C_ChatInfo.PerformEmote, "GASP") end
  end
  return played and LIFER_LENGTH or 0
end

local function where(bird, zone) return string.format("|cffaaaaaa(%s, %s)|r", bird.name, zone or "?") end
local function isRare(kindID) return kindID and ns.KINDS[kindID] and ns.KINDS[kindID].rare end

ns:Listen("RARE_SEEN", function(bird, creatureName, zone, kindID, isNewKind)
  local delay = isNewKind and ns:LiferReaction() or 0
  if not ns.db.toast then return end
  show({ title = UI.RARE .. "Rare bird!|r", lifer = isNewKind, body = creatureName .. "  " .. where(bird, zone),
    sound = bird.key, callDelay = delay > 0 and delay or nil, kindID = kindID, creatureName = creatureName, rare = true, spot = true, border = { 1, 0.67, 0.2 } })
end)

ns:Listen("NEW_SPECIES", function(bird, creatureName, zone, kindID)
  if isRare(kindID) then return end -- RARE_SEEN handles rares
  local delay = ns:LiferReaction()
  if not ns.db.toast then return end
  show({ title = UI.BLUE .. "New species!|r", lifer = true, body = (creatureName or bird.name) .. "  " .. where(bird, zone),
    sound = bird.key, callDelay = delay > 0 and delay or nil, kindID = kindID, birdKey = bird.key, creatureName = creatureName, spot = true })
end)

ns:Listen("NEW_KIND", function(bird, creatureName, zone, kindID)
  if not (ns.db.toast and ns.db.toastKinds) or isRare(kindID) then return end
  show({ title = UI.BLUE .. "New for your life list|r", body = (creatureName or bird.name) .. "  " .. where(bird, zone),
    kindID = kindID, birdKey = bird.key, creatureName = creatureName, spot = true })
end)

ns:Listen("BADGE_EARNED", function(b)
  if not ns.db.toast then return end
  show({ title = UI.GOLD .. "Badge earned!|r", body = b.name .. "  |cffaaaaaa" .. b.desc .. "|r", badge = b.id, icon = ns:BadgeIcon(b.id), border = { 1, 0.82, 0 } })
end)

ns:Listen("BUDDY_LIFER", function(kindID)
  if not (ns.db.toast and ns.db.buddyToasts) then return end
  local k = ns.KINDS[kindID]
  if not k then return end
  local seen = ns.db.kinds[kindID] and "you have it too" or "you haven't seen one yet"
  show({ title = UI.BLUE .. ns:BuddyShortName() .. " spotted a lifer!|r", body = k.n .. "  |cffaaaaaa(" .. seen .. ")|r",
    kindID = kindID, border = { 0.5, 0.83, 1 } })
end)
