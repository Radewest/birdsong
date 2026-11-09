-- Birdsong: shared UI helpers (buttons, labels, scrolling lists, call buttons, colours)

local _, ns = ...

local UI = {}
ns.UI = UI

UI.GOLD, UI.GREY, UI.GREEN, UI.BLUE, UI.RED = "|cffffd100", "|cff9d9d9d", "|cff40ff40", "|cff7fd4ff", "|cffff7070"
UI.RARE = "|cffffaa33"

function UI.button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 80, h or 22)
  b:SetText(text)
  return b
end

function UI.label(parent, font, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
  if text then fs:SetText(text) end
  return fs
end

function UI.wrapped(parent, font, width)
  local fs = UI.label(parent, font)
  fs:SetWidth(width)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  return fs
end

function UI.panelBg(parent)
  local t = parent:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(1, 1, 1, 0.04)
  return t
end

function UI.fmtDate(t) return t and date("%d %b %Y", t) or "?" end
function UI.levels(k) return (k.l1 == k.l2) and ("Level " .. k.l1) or ("Level " .. k.l1 .. "-" .. k.l2) end

-- Status line at the bottom of the book
function UI.status(text) if ns.bookStatus then ns.bookStatus:SetText(text or "") end end

-- Scrolling list: fixed rows, mouse wheel moves an offset. render(row, item, index) fills a row.
function UI.makeList(parent, width, height, rowH, render, onClick, rightWidth)
  local list = CreateFrame("Frame", nil, parent)
  list:SetSize(width, height)
  UI.panelBg(list)
  list.rows, list.items, list.offset = {}, {}, 0
  local n = math.floor((height - 8) / rowH)
  for i = 1, n do
    local r = CreateFrame("Button", nil, list)
    r:SetSize(width - 8, rowH - 2)
    r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * rowH)
    r.hl = r:CreateTexture(nil, "BACKGROUND")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(0.5, 0.83, 1, 0.18)
    r.hover = r:CreateTexture(nil, "HIGHLIGHT")
    r.hover:SetAllPoints()
    r.hover:SetColorTexture(1, 1, 1, 0.06)
    r.left = UI.label(r, "GameFontHighlight")
    r.left:SetPoint("LEFT", 6, 0)
    r.left:SetPoint("RIGHT", -(rightWidth or 40), 0)
    r.left:SetJustifyH("LEFT")
    r.left:SetWordWrap(false)
    r.right = UI.label(r, "GameFontHighlightSmall")
    r.right:SetPoint("RIGHT", -6, 0)
    r:SetScript("OnClick", function(self) if self.item ~= nil then onClick(self.item) end end)
    list.rows[i] = r
  end
  list.more = UI.label(list, "GameFontDisableSmall")
  list.more:SetPoint("BOTTOMRIGHT", -6, 2)

  function list:Render()
    local maxOff = math.max(0, #self.items - #self.rows)
    self.offset = math.max(0, math.min(self.offset, maxOff))
    for i, r in ipairs(self.rows) do
      local item = self.items[i + self.offset]
      r.item = item
      if item ~= nil then r:Show(); render(r, item, i + self.offset) else r:Hide() end
    end
    self.more:SetText((maxOff > 0 and self.offset < maxOff) and "scroll for more" or "")
  end
  function list:SetItems(items) self.items = items; self:Render() end
  function list:ScrollTo(item)
    for i, it in ipairs(self.items) do
      if it == item and (i <= self.offset or i > self.offset + #self.rows) then self.offset = i - 1 end
    end
    self:Render()
  end
  list:EnableMouseWheel(true)
  list:SetScript("OnMouseWheel", function(self, delta) self.offset = self.offset - delta * 2; self:Render() end)
  return list
end

-- A row of call buttons. parent:SetCallsFor(speciesKey) picks the bird.
function UI.makeCalls(parent, w, small)
  local calls = {}
  for i, t in ipairs(ns.CALL_TYPES) do
    local b = UI.button(parent, t.label, w, 24)
    if small then
      -- set on the button itself: the template re-applies its own font on state changes
      if b.SetNormalFontObject then b:SetNormalFontObject("GameFontNormalSmall") end
      if b.SetHighlightFontObject then b:SetHighlightFontObject("GameFontHighlightSmall") end
      if b.SetDisabledFontObject then b:SetDisabledFontObject("GameFontDisableSmall") end
    end
    if i == 1 then b:SetPoint("BOTTOMLEFT", 0, 0) else b:SetPoint("LEFT", calls[i - 1], "RIGHT", 4, 0) end
    b.callType, b.callLabel = t.key, t.label
    b:SetScript("OnClick", function(self)
      local key = parent.speciesKey
      if ns:PlayBird(key, self.callType) then
        UI.status(UI.GREY .. "Playing: " .. ns.BIRD_BY_KEY[key].name .. " - " .. self.callLabel .. "|r")
      else
        UI.status(UI.RED .. "That sound isn't in this game client's sound library.|r")
      end
    end)
    calls[i] = b
  end
  function parent:SetCallsFor(key)
    self.speciesKey = key
    local set = ns.SOUNDS[key] or {}
    for _, b in ipairs(calls) do
      if set[b.callType] and #set[b.callType] > 0 then b:Enable() else b:Disable() end
    end
  end
  return calls
end

-- Multi-line text box in a scroll frame. onChange(text) on user edits.
function UI.makeTextBox(parent, w, h, onChange)
  local bg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  bg:SetSize(w, h)
  bg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  bg:SetBackdropColor(0, 0, 0, 0.6)
  local scroll = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(w - 40)
  edit:SetMaxLetters(2000)
  edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  edit:SetScript("OnTextChanged", function(self, user) if user and onChange then onChange(self:GetText()) end end)
  scroll:SetScrollChild(edit)
  bg:EnableMouse(true)
  bg:SetScript("OnMouseDown", function() edit:SetFocus() end)
  bg.edit = edit
  return bg
end
