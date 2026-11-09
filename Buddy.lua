-- Birdsong: birding buddy. Compare life lists with one friend.
-- Same transport as Tjommie: Battle.net game data if they're an online BNet friend (cross-realm/faction),
-- otherwise a hidden addon whisper (same realm + faction). Messages from anyone else are ignored.
-- Both players set each other as buddy; nothing is shared with anyone else.
--
-- Wire format (append-only; "~" separator, never "|"):
--   Q~version                      please send me your list
--   L~version~atlasCount~hexmask   my seen kinds, as a bitmask over the Atlas's sorted creature IDs
--   N~npcID                        I just logged a lifer

local _, ns = ...

local PREFIX = "Birdsong"
local SEP = "~"
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end

---------------------------------------------------------------------------
-- Names
---------------------------------------------------------------------------
local function normRealm(r) return r and (r:gsub("[%s%-']", "")) or nil end

function ns.FullName(name)
  if type(name) ~= "string" or name == "" or ns.IsSecret(name) then return nil end
  if not name:find("-", 1, true) then
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm then name = name .. "-" .. realm end
  end
  return name
end

function ns:BuddyShortName()
  local b = self.db and self.db.buddy
  return b and (strsplit("-", b)) or "Your buddy"
end

local function isBuddy(sender)
  local b = ns.db and ns.db.buddy
  local full = ns.FullName(sender)
  return b and full and full:lower() == b:lower()
end

---------------------------------------------------------------------------
-- Life list bitmask (sorted Atlas IDs, 4 bits per hex char)
---------------------------------------------------------------------------
local SORTED = {}
for id, k in pairs(ns.KINDS) do if not k.found then SORTED[#SORTED + 1] = id end end
table.sort(SORTED)

function ns.EncodeKinds(set)
  local out = {}
  for i = 1, #SORTED, 4 do
    local v = 0
    for b = 0, 3 do
      local id = SORTED[i + b]
      if id and set[id] then v = v + 2 ^ b end
    end
    out[#out + 1] = string.format("%x", v)
  end
  return table.concat(out)
end

function ns.DecodeKinds(hex)
  local set = {}
  for c = 1, #hex do
    local v = tonumber(hex:sub(c, c), 16) or 0
    for b = 0, 3 do
      local id = SORTED[(c - 1) * 4 + b + 1]
      if id and math.floor(v / 2 ^ b) % 2 == 1 then set[id] = true end
    end
  end
  return set
end

---------------------------------------------------------------------------
-- Sending (Battle.net if possible)
---------------------------------------------------------------------------
local function findBNet(fullName)
  if not fullName or not BNGetNumFriends or not C_BattleNet or not C_BattleNet.GetFriendNumGameAccounts then return nil end
  local name, realm = strsplit("-", fullName, 2)
  for i = 1, (BNGetNumFriends() or 0) do
    for j = 1, (C_BattleNet.GetFriendNumGameAccounts(i) or 0) do
      local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
      if g and g.isOnline and g.characterName and g.characterName:lower() == name:lower() then
        local r = normRealm(g.realmName)
        if not realm or not r or r:lower() == realm:lower() then return g.gameAccountID end
      end
    end
  end
end

function ns:SendBuddy(...)
  local target = self.db.buddy
  if not target then return end
  local parts = { ... }
  for i = 1, select("#", ...) do parts[i] = tostring(parts[i] or ""):gsub("[~|]", "") end
  local msg = table.concat(parts, SEP)
  if #msg > 250 then msg = msg:sub(1, 250) end
  local gid = findBNet(target)
  if gid and BNSendGameData then
    pcall(BNSendGameData, gid, PREFIX, msg)
  elseif C_ChatInfo and C_ChatInfo.SendAddonMessage then
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target) -- blocked in some instances: pcall
  end
end

function ns:SendList() self:SendBuddy("L", ns.VERSION, #SORTED, ns.EncodeKinds(self.db.kinds)) end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------
local handlers = {}
handlers.Q = function() ns:SendList() end
handlers.L = function(version, count, hex)
  local info = ns.db.buddyInfo
  info.version, info.at = version, time()
  if tonumber(count) == #SORTED and hex then
    ns.db.buddyKinds = ns.DecodeKinds(hex)
    local n = 0
    for _ in pairs(ns.db.buddyKinds) do n = n + 1 end
    info.kinds, info.sameAtlas = n, true
  else
    info.sameAtlas = false -- different Birdsong versions: show nothing rather than wrong ticks
  end
  ns:Fire("BUDDY_UPDATED")
end
handlers.N = function(id)
  id = tonumber(id)
  if not id or not ns.KINDS[id] then return end
  if not ns.db.buddyKinds[id] then
    ns.db.buddyKinds[id] = true
    ns.db.buddyInfo.kinds = (ns.db.buddyInfo.kinds or 0) + 1
  end
  ns:Fire("BUDDY_LIFER", id)
  ns:Fire("BUDDY_UPDATED")
end

function ns:HandleBuddyMessage(msg)
  if type(msg) ~= "string" or ns.IsSecret(msg) then return end
  local fields = { strsplit(SEP, msg) }
  local kind = table.remove(fields, 1)
  if handlers[kind] then handlers[kind](unpack(fields)) end
end

ns:On("CHAT_MSG_ADDON", function(prefix, text, _, sender)
  if prefix ~= PREFIX or not isBuddy(sender) then return end
  ns:HandleBuddyMessage(text)
end)

ns:On("BN_CHAT_MSG_ADDON", function(prefix, text, _, senderID)
  if prefix ~= PREFIX or not C_BattleNet or not C_BattleNet.GetGameAccountInfoByID then return end
  local g = C_BattleNet.GetGameAccountInfoByID(senderID)
  if not (g and g.characterName) then return end
  if not isBuddy(g.characterName .. "-" .. (normRealm(g.realmName) or "")) then return end
  ns:HandleBuddyMessage(text)
end)

-- Tell the buddy about lifers (new kinds) as they happen
local function announce(_, _, _, kindID) if kindID and ns.db.buddy then ns:SendBuddy("N", kindID) end end
ns:Listen("NEW_SPECIES", announce)
ns:Listen("NEW_KIND", announce)

---------------------------------------------------------------------------
-- Setting the buddy
---------------------------------------------------------------------------
function ns:SetBuddy(name)
  local full = name and ns.FullName(name)
  self.db.buddy = full
  wipe(self.db.buddyKinds)
  wipe(self.db.buddyInfo)
  if full then
    self:Print("Your birding buddy is now |cffffff00" .. full .. "|r. Ask them to set you as theirs too.")
    self:SendList(); self:SendBuddy("Q", ns.VERSION)
  else
    self:Print("Birding buddy cleared.")
  end
  self:Fire("BUDDY_UPDATED")
  self:Fire("SETTINGS_CHANGED")
end

function ns:SetBuddyFromTarget()
  if UnitExists and UnitExists("target") and UnitIsPlayer("target") then
    local name, realm = UnitName("target")
    if name and not ns.IsSecret(name) then
      return self:SetBuddy(realm and realm ~= "" and (name .. "-" .. realm) or name)
    end
  end
  self:Print("Target your friend first, then try again.")
end

function ns:TjommieBuddy()
  return TjommieDB and type(TjommieDB.buddy) == "string" and TjommieDB.buddy or nil
end

function ns:SetBuddyFromTjommie()
  local b = self:TjommieBuddy()
  if b then self:SetBuddy(b) else self:Print("No tjommie found. Is Tjommie installed and linked?") end
end

ns:Listen("LOGIN", function()
  if C_Timer then
    C_Timer.After(8, function()
      if ns.db.buddy then ns:SendList(); ns:SendBuddy("Q", ns.VERSION) end
    end)
  end
end)

-- Hide "No player named X is currently playing." when the buddy is offline
local function systemFilter(_, _, msg)
  local b = ns.db and ns.db.buddy
  if not b or type(msg) ~= "string" or ns.IsSecret(msg) or not ERR_CHAT_PLAYER_NOT_FOUND_S then return false end
  return msg == ERR_CHAT_PLAYER_NOT_FOUND_S:format(ns:BuddyShortName()) or msg == ERR_CHAT_PLAYER_NOT_FOUND_S:format(b)
end
local addFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
if addFilter then addFilter("CHAT_MSG_SYSTEM", systemFilter) end
