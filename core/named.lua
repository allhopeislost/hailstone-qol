-- Named tracker: the data side of the /named window. The generated database
-- (core/named_data.lua, see tools/gen_named_data.py) lists the named NPCs of every zone
-- with their loot; the names a player actually tracks live in a small persistent store
-- (qol_named.lua). init.lua wires these functions to the client and the window
-- (ui/modern/named.lua) only draws what crosses over.
local findwalk = require('core.findwalk')

local M = {}

M.MAX_NAME = 64 -- longest tracked name we keep
M.MAX_ZONE = 32 -- longest zone short name we accept

local FILE = 'qol_named.lua'
local VERSION = 1
local SHORT_PATTERN = '^[a-z0-9_]+$'
local TRIM = '^%s*(.-)%s*$'

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- nil when the generated database is missing or does not have the expected shape.
-- Loaded with require: in the client a script's dofile/loadfile read from the config
-- directory, while require finds module files next to the script (as core/named itself).
function M.loadData()
  local ok, data = pcall(require, 'core.named_data')
  if not ok or type(data) ~= 'table' then ok, data = pcall(dofile, 'core/named_data.lua') end
  if not ok or type(data) ~= 'table' then return nil end
  if type(data.zones) ~= 'table' or type(data.items) ~= 'table' then return nil end
  return data
end

-- A name as we keep and show it: trimmed, underscores read as spaces, inner whitespace
-- collapsed, capped at M.MAX_NAME. nil when nothing readable is left.
function M.normalizeName(raw)
  if type(raw) ~= 'string' then return nil end
  local name = raw:match(TRIM)
  if not name or name == '' then return nil end
  name = (name:gsub('_', ' '):gsub('%s+', ' ')):match(TRIM)
  if not name or name == '' then return nil end
  return name:sub(1, M.MAX_NAME)
end

-- The comparison key of a name: trimmed and lowercased; nil when there is no name.
function M.keyOf(name)
  if type(name) ~= 'string' then return nil end
  local trimmed = name:match(TRIM)
  if not trimmed or trimmed == '' then return nil end
  return trimmed:lower()
end

local function displayOf(name)
  return (name:gsub('_', ' '))
end

-- The identity of a name: like keyOf, but underscores and spaces are the same, so a name
-- can be handed back in any spelling (the data keeps underscores, the store keeps the
-- display form with spaces).
function M.nameKey(name)
  if type(name) ~= 'string' then return nil end
  return M.keyOf((name:gsub('_', ' ')))
end

local nameKey = M.nameKey

-- Every zone in the data, the current one first, then A to Z by short name.
function M.zoneList(data, currentShort)
  local list = {}
  if type(data) ~= 'table' or type(data.zones) ~= 'table' then return list end
  local current = M.keyOf(currentShort or '')
  for short, zone in pairs(data.zones) do
    if type(short) == 'string' and type(zone) == 'table' then
      local namedZoned = type(zone.named) == 'table' and zone.named or {}
      list[#list + 1] = {
        short = short,
        long = type(zone.long) == 'string' and zone.long or short,
        count = #namedZoned,
        current = short == current,
      }
    end
  end
  table.sort(list, function(a, b)
    if a.current ~= b.current then return a.current end
    return a.short < b.short
  end)
  return list
end

-- The named NPCs of one zone: {name, display, level, drops}, sorted by display name.
-- The drops carry the item name from the database, or the id when it is unknown.
-- nil when the zone is not in the data.
-- The drops of a placeholder-style name the named rule excludes (a hand-tracked name resolves
-- its drops through the data's loot index), as { {id=, chance=, item=}, ... }, or nil when the
-- name is unknown to the index.
function M.lootOf(data, name)
  if type(data) ~= 'table' or type(data.loot) ~= 'table' then return nil end
  local key = M.nameKey(name)
  if not key then return nil end
  local raw = data.loot[key]
  if type(raw) ~= 'table' then return nil end
  local items = type(data.items) == 'table' and data.items or {}
  local out = {}
  for _, drop in ipairs(raw) do
    if type(drop) == 'table' and type(drop[1]) == 'number' and type(drop[2]) == 'number' then
      out[#out + 1] = { id = drop[1], chance = drop[2], item = items[drop[1]] or tostring(drop[1]) }
    end
  end
  return out
end

function M.namedOfZone(data, short)
  if type(data) ~= 'table' or type(data.zones) ~= 'table' then return nil end
  local zone = data.zones[M.keyOf(short or '') or '']
  if type(zone) ~= 'table' or type(zone.named) ~= 'table' then return nil end
  local items = type(data.items) == 'table' and data.items or {}
  local list = {}
  for _, entry in ipairs(zone.named) do
    if type(entry) == 'table' and type(entry.name) == 'string' and nameKey(entry.name) then
      local drops = {}
      if type(entry.drops) == 'table' then
        for _, drop in ipairs(entry.drops) do
          if type(drop) == 'table' and type(drop[1]) == 'number' and type(drop[2]) == 'number' then
            drops[#drops + 1] = {
              id = drop[1],
              chance = drop[2],
              item = items[drop[1]] or tostring(drop[1]),
            }
          end
        end
      end
      list[#list + 1] = {
        name = entry.name,
        display = displayOf(entry.name),
        level = type(entry.level) == 'number' and entry.level or nil,
        drops = drops,
      }
    end
  end
  table.sort(list, function(a, b)
    return a.display:lower() < b.display:lower()
  end)
  return list
end

-- The tracked names are given either as an array of names (the store's list) or as a
-- set keyed by name keys. Returns a matcher that takes any spelling of a name.
local function trackedMatcher(tracked)
  local listed = {}
  if type(tracked) == 'table' then
    for _, name in ipairs(tracked) do
      local key = nameKey(name)
      if key then listed[key] = true end
    end
  end
  return function(name)
    local key = nameKey(name)
    if not key then return false end
    if listed[key] then return true end
    if type(tracked) ~= 'table' then return false end
    -- a set may be keyed by the plain or the display key
    return tracked[key] == true or tracked[M.keyOf(name)] == true or false
  end
end

-- The named NPC suggestions of a zone that are not tracked yet.
function M.suggestions(data, short, trackedNames)
  local isTracked = trackedMatcher(trackedNames)
  local out = {}
  for _, entry in ipairs(M.namedOfZone(data, short) or {}) do
    if not isTracked(entry.name) then
      out[#out + 1] = { name = entry.name, display = entry.display, level = entry.level }
    end
  end
  return out
end

-- Same distance math as core/findwalk.lua.
local function distance(a, b)
  if not a or not b or not finite(a.x) or not finite(a.y)
    or not finite(b.x) or not finite(b.y) then
    return nil
  end
  local dz = (finite(a.z) and finite(b.z)) and (a.z - b.z) or 0
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + dz ^ 2)
end

-- The living NPC that matches `name`, by cleaned display name or by raw name (the data
-- keeps names with underscores, the client shows spaces). A hand-typed short name
-- ("frenzied" for "a frenzied ghoul") also matches when it is contained in the spawn's
-- name; exact matches win over contained ones. Several matches: the nearest to `me`
-- wins; without a position (me nil, no x/y/z) the first match by id. nil when nothing
-- lives in `spawns` under that name.
function M.matchSpawn(spawns, me, name)
  if type(spawns) ~= 'table' or type(name) ~= 'string' then return nil end
  local target = M.keyOf(name)
  if not target then return nil end
  local spaced = (target:gsub('_', ' '))
  local function bestOf(matches, best, nearest)
    for _, spawn in ipairs(matches) do
      local exact = distance(me, spawn)
      if best == nil or (exact ~= nil and (nearest == nil or exact < nearest)) then
        best, nearest = spawn, exact
      end
    end
    return best, nearest
  end
  local exact, substring = {}, {}
  for _, spawn in ipairs(spawns) do
    if type(spawn) == 'table' and spawn.npc == true and spawn.corpse ~= true then
      local displayKey = M.keyOf(findwalk.displayName(spawn))
      local rawKey = M.keyOf(type(spawn.name) == 'string' and spawn.name or '')
      if displayKey == target or displayKey == spaced or rawKey == target or rawKey == spaced then
        exact[#exact + 1] = spawn
      elseif #spaced >= 3 and ((displayKey and displayKey:find(spaced, 1, true))
          or (rawKey and rawKey:find(spaced, 1, true))) then
        substring[#substring + 1] = spawn
      end
    end
  end
  local best, nearest = bestOf(exact)
  if best == nil then best = bestOf(substring) end
  return best
end

-- The rows of the /named window for one zone: the named NPCs of the data plus the tracked
-- names it does not know (custom=true). Each row: name, display, level, tracked, custom,
-- spawned, id, dist. spawned/id/dist only when the listed zone is the zone the player is
-- in and a living spawn matches; dist is a whole number, nil without a usable position.
function M.rows(data, spawns, me, currentShort, zoneShort, tracked)
  local rows = {}
  local zoneKey = M.keyOf(zoneShort or '')
  if not zoneKey then return { rows = rows } end
  local isTracked = trackedMatcher(tracked)

  local seen = {}
  for _, entry in ipairs(M.namedOfZone(data, zoneKey) or {}) do
    seen[nameKey(entry.name)] = true
    rows[#rows + 1] = {
      name = entry.name,
      display = entry.display,
      level = entry.level,
      tracked = isTracked(entry.name),
      custom = false,
      spawned = false,
      id = nil,
      dist = nil,
    }
  end

  -- Tracked names the data does not know are still listed, marked custom.
  if type(tracked) == 'table' then
    for _, name in ipairs(tracked) do
      if type(name) == 'string' then
        local key = nameKey(name)
        if key and not seen[key] then
          seen[key] = true
          rows[#rows + 1] = {
            name = name,
            display = displayOf(name),
            level = nil,
            tracked = true,
            custom = true,
            spawned = false,
            id = nil,
            dist = nil,
          }
        end
      end
    end
  end

  if M.keyOf(currentShort or '') == zoneKey then
    for _, row in ipairs(rows) do
      local spawn = M.matchSpawn(spawns, me, row.name)
      if spawn then
        row.spawned = true
        row.id = spawn.id
        local exact = distance(me, spawn)
        row.dist = exact and math.floor(exact + 0.5) or nil
      end
    end
  end

  table.sort(rows, function(a, b)
    local al, bl = a.display:lower(), b.display:lower()
    if al ~= bl then return al < bl end
    if a.custom ~= b.custom then return b.custom end
    return a.name < b.name
  end)
  return { rows = rows }
end

-- The tracked names, persisted next to the settings file and modeled on core/settings.lua:
-- the whole store is one table {version = 1, zones = {[short] = {names...}}, hidden = {[short] = {names...}},
-- split = n}, read once here and rewritten on every change. `hidden` holds the names removed from the
-- tracker window's list (the "x" of a row); they show up in the editor's suggestion list again, and adding
-- them there unhides them. `split` is the tracker window's divider between the named list and the drops
-- list (design pixels of list height). Both fields are absent in older files.
function M.newStore(mq, readConfig, onError)
  local load = readConfig or dofile
  local ok, config = pcall(load, FILE)
  local zones = {}
  local hidden = {}
  local split
  if ok and type(config) == 'table' and config.version == VERSION
    and type(config.zones) == 'table' then
    if type(config.split) == 'number' and config.split == config.split
        and config.split > -math.huge and config.split < math.huge then
      split = config.split
    end
    local function readNameList(t, into)
      if type(t) ~= 'table' then return end
      for short, names in pairs(t) do
        if type(short) == 'string' and short:match(SHORT_PATTERN) and #short <= M.MAX_ZONE
          and type(names) == 'table' then
          local kept = {}
          for _, name in ipairs(names) do
            local display = M.normalizeName(name)
            if display then kept[#kept + 1] = display end
          end
          into[short] = kept
        end
      end
    end
    readNameList(config.zones, zones)
    readNameList(config.hidden, hidden)
  end

  local function save()
    local snapshot = { version = VERSION, zones = {}, hidden = {} }
    for short, names in pairs(zones) do
      local copy = {}
      for i, name in ipairs(names) do copy[i] = name end
      snapshot.zones[short] = copy
    end
    for short, names in pairs(hidden) do
      local copy = {}
      for i, name in ipairs(names) do copy[i] = name end
      snapshot.hidden[short] = copy
    end
    if split then snapshot.split = split end
    local saved, err = pcall(mq.pickle, FILE, snapshot)
    if not saved and onError then pcall(onError, err) end
    return saved
  end

  local function copyNames(short)
    local out = {}
    for i, name in ipairs(zones[short] or {}) do out[i] = name end
    return out
  end

  local function zoneKey(short)
    if type(short) ~= 'string' then return nil end
    local trimmed = short:match(TRIM) or ''
    if trimmed == '' then return nil end
    return trimmed:lower()
  end

  return {
    list = function(short)
      local key = zoneKey(short)
      if not key then return {} end
      return copyNames(key)
    end,

    add = function(short, name)
      local key = zoneKey(short)
      if not key or #key > M.MAX_ZONE or not key:match(SHORT_PATTERN) then
        return false, 'Invalid zone.'
      end
      local display = M.normalizeName(name)
      if not display then return false, 'That name cannot be tracked.' end
      local names = zones[key]
      if not names then
        names = {}
        zones[key] = names
      end
      local newKey = nameKey(display)
      for _, existing in ipairs(names) do
        -- a duplicate is refused, not silently ignored, so a click says something
        if nameKey(existing) == newKey then return false, 'Already tracking that name.' end
      end
      names[#names + 1] = display
      if save() then return true end
      return false, 'Could not save the tracked names.'
    end,

    remove = function(short, name)
      local key = zoneKey(short)
      if not key or #key > M.MAX_ZONE then return false, 'Invalid zone.' end
      local nameKey_ = nameKey(name)
      if not nameKey_ then return false, 'Invalid name.' end
      local names = zones[key]
      if not names then return true end
      local kept, changed = {}, false
      for _, existing in ipairs(names) do
        if nameKey(existing) == nameKey_ then
          changed = true
        else
          kept[#kept + 1] = existing
        end
      end
      if not changed then return true end
      zones[key] = kept
      if save() then return true end
      return false, 'Could not save the tracked names.'
    end,

    zones = function()
      local out = {}
      for short in pairs(zones) do out[#out + 1] = short end
      table.sort(out)
      return out
    end,

    -- the tracker window's divider between the named list and the drops list (design pixels of
    -- list height), or nil when never set
    split = function()
      return split
    end,

    setSplit = function(value)
      if type(value) ~= 'number' or value ~= value or value <= -math.huge or value >= math.huge
          or value < 1 or value > 4000 then
        return false
      end
      split = math.floor(value + 0.5)
      return save()
    end,

    -- the names removed from the tracker window's list (the "x" of a row), per zone
    hiddenList = function(short)
      local key = zoneKey(short)
      if not key then return {} end
      local out = {}
      for i, name in ipairs(hidden[key] or {}) do out[i] = name end
      return out
    end,

    hide = function(short, name)
      local key = zoneKey(short)
      if not key or #key > M.MAX_ZONE or not key:match(SHORT_PATTERN) then
        return false, 'Invalid zone.'
      end
      local display = M.normalizeName(name)
      if not display then return false, 'That name cannot be hidden.' end
      local names = hidden[key]
      if not names then
        names = {}
        hidden[key] = names
      end
      local newKey = nameKey(display)
      for _, existing in ipairs(names) do
        if nameKey(existing) == newKey then return true end -- already hidden
      end
      names[#names + 1] = display
      if save() then return true end
      return false, 'Could not save the tracked names.'
    end,

    unhide = function(short, name)
      local key = zoneKey(short)
      if not key or #key > M.MAX_ZONE then return false, 'Invalid zone.' end
      local nameKey_ = nameKey(name)
      if not nameKey_ then return false, 'Invalid name.' end
      local names = hidden[key]
      if not names then return true end
      local kept, changed = {}, false
      for _, existing in ipairs(names) do
        if nameKey(existing) == nameKey_ then
          changed = true
        else
          kept[#kept + 1] = existing
        end
      end
      if not changed then return true end
      hidden[key] = kept
      if save() then return true end
      return false, 'Could not save the tracked names.'
    end,
  }
end

return M
