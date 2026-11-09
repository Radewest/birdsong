-- Birdsong: audio
-- Plays the game's own sound files by FileDataID (nothing is shipped with the add-on).
-- One sound at a time: a new one stops the last. Missing files are remembered so the book can say so.

local _, ns = ...

local current          -- handle of the sound that's playing
ns.missing = {}        -- [fileID] = true when the client couldn't play it

function ns:StopSound()
  if current and StopSound then pcall(StopSound, current, 300) end
  current = nil
end

-- Returns true if the client started the sound.
function ns:PlayFile(fileID)
  if not fileID or not PlaySoundFile then return false end
  self:StopSound()
  local ok, willPlay, handle = pcall(PlaySoundFile, fileID, (ns.db and ns.db.channel) or "Master")
  if ok and willPlay then
    current = handle
    return true
  end
  ns.missing[fileID] = true
  return false
end

-- Play a random variant of one call type; tries the other variants if one is missing.
function ns:PlayBird(key, callType)
  local set = ns.SOUNDS[key]
  local list = set and set[callType]
  if not list or #list == 0 then return false end
  local start = math.random(#list)
  for i = 0, #list - 1 do
    local id = list[((start + i - 1) % #list) + 1]
    if not ns.missing[id] and self:PlayFile(id) then return true end
  end
  return false
end

-- The first call type a bird has, for pop-ups ("call" if it has one)
function ns:SignatureCall(key)
  local set = ns.SOUNDS[key] or {}
  for _, t in ipairs(ns.CALL_TYPES) do
    if set[t.key] and #set[t.key] > 0 then return t.key end
  end
end

function ns:PlayAmbience(key, tod)
  local a = ns.AMBIENCE_IDS[key]
  return a and a[tod] and self:PlayFile(a[tod]) or false
end
