-- FindWalk: which spawns the find window lists, in what order, and what its role column says.
-- Pure functions over the spawn records `hs.spawns()` returns; init.lua wires them to the client and the window
-- (ui/modern/findwalk.lua) only draws the rows.
local M = {}

-- Class ids of the NPCs that serve players (client: game/eq_names.cpp, game/clicks.h). Other NPC-only ids
-- (recruiters, tribute masters, mercenary liaisons, ...) stay plain NPCs. A merchant is one class for all of them,
-- so what a merchant sells is not known from the spawn.
local TRAINER_FIRST, TRAINER_LAST = 20, 35 -- guildmasters of the 16 player classes, in class order
local BANKERS = {[40] = true, [66] = true}
local MERCHANTS = {[41] = true, [59] = true, [61] = true, [67] = true, [68] = true, [70] = true}

local TRAINS = {
  'Warriors', 'Clerics', 'Paladins', 'Rangers', 'Shadow Knights', 'Druids', 'Monks', 'Bards',
  'Rogues', 'Shamans', 'Necromancers', 'Wizards', 'Magicians', 'Enchanters', 'Beastlords', 'Berserkers',
}

M.SORT_KEYS = {name = true, role = true, level = true, dist = true}
M.MAX_TEXT = 64
M.DEFAULT_SORT = 'name' -- A to Z, ascending

local function integer(value)
  return type(value) == 'number' and value == value and value % 1 == 0
end

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- The role of a living NPC with this class id ('Trainer', 'Banker' or 'Merchant') and, for a trainer, who it trains.
function M.role(classId)
  if not integer(classId) then return nil end
  if classId >= TRAINER_FIRST and classId <= TRAINER_LAST then
    return 'Trainer', TRAINS[classId - TRAINER_FIRST + 1]
  end
  if BANKERS[classId] then return 'Banker' end
  if MERCHANTS[classId] then return 'Merchant' end
  return nil
end

-- 'npc', 'pc' or 'corpse'.
function M.kind(spawn)
  if spawn.corpse then return 'corpse' end
  if spawn.npc then return 'npc' end
  return 'pc'
end

-- The name as the game shows it: NPC names carry digits the server appends ("a_rat01") and underscores for spaces.
function M.displayName(spawn)
  local name = type(spawn.name) == 'string' and spawn.name or ''
  if spawn.npc and not spawn.corpse then name = name:gsub('%d+$', '') end
  return (name:gsub('_', ' '))
end

local function distance(a, b)
  if not a or not b or not (finite(a.x) and finite(a.y) and finite(b.x) and finite(b.y)) then return nil end
  local dz = (finite(a.z) and finite(b.z)) and (a.z - b.z) or 0
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + dz ^ 2)
end

-- Every query field checked: the window is a different script and its table is not trusted.
function M.query(raw)
  raw = type(raw) == 'table' and raw or {}
  local types = type(raw.types) == 'table' and raw.types or {}
  local text = type(raw.text) == 'string' and raw.text:sub(1, M.MAX_TEXT) or ''
  return {
    types = {npc = types.npc == true, pc = types.pc == true, corpse = types.corpse == true},
    text = text:match('^%s*(.-)%s*$'):lower(),
    sort = M.SORT_KEYS[raw.sort] and raw.sort or M.DEFAULT_SORT,
    desc = raw.desc == true,
  }
end

-- A click on a column head: the same column reverses, another one starts ascending.
function M.nextSort(sort, desc, clicked)
  if clicked == sort then return sort, not desc end
  return clicked, false
end

-- Whether `a` comes before `b`. Rows without the sorted value (no role, no level, no distance) always come last;
-- ties fall back to distance, then name, then id, so the order never jumps between refreshes.
local function before(a, b, key, desc)
  local x, y = a.sortKey[key], b.sortKey[key]
  if x ~= y then
    if x == nil then return false end
    if y == nil then return true end
    if desc then return x > y end
    return x < y
  end
  local da, db = a.exact, b.exact
  if da ~= db then
    if da == nil then return false end
    if db == nil then return true end
    return da < db
  end
  if a.sortKey.name ~= b.sortKey.name then return a.sortKey.name < b.sortKey.name end
  return a.id < b.id
end

-- The rows to list, sorted, and how many spawns there were before filtering. `me` is the player's spawn record.
-- Each row: id, name, kind, role, trains, level (nil for roles and unknown levels), dist (whole number or nil).
function M.rows(spawns, me, rawQuery)
  local query = M.query(rawQuery)
  local rows, total = {}, 0
  if type(spawns) ~= 'table' then return rows, total end
  for _, spawn in ipairs(spawns) do
    if type(spawn) == 'table' and integer(spawn.id) and spawn.id > 0 and not (me and spawn.id == me.id) then
      total = total + 1
      local kind = M.kind(spawn)
      if query.types[kind] then
        local role, trains
        if kind == 'npc' then role, trains = M.role(spawn.class) end
        local name = M.displayName(spawn)
        local haystack = (name .. '\n' .. (type(spawn.name) == 'string' and spawn.name or '')
          .. '\n' .. (role or '')):lower()
        if query.text == '' or haystack:find(query.text, 1, true) then
          local exact = distance(me, spawn)
          local level = (not role and finite(spawn.level) and spawn.level > 0) and spawn.level or nil
          rows[#rows + 1] = {
            id = spawn.id, name = name, kind = kind, role = role, trains = trains, level = level,
            dist = exact and math.floor(exact + 0.5) or nil, exact = exact,
            sortKey = {name = name:lower(), role = role, level = level, dist = exact},
          }
        end
      end
    end
  end
  table.sort(rows, function(a, b) return before(a, b, query.sort, query.desc) end)
  return rows, total
end

-- Whether any row has a role: only then does the window show its Role column.
function M.hasRole(rows)
  for _, row in ipairs(rows) do
    if row.role then return true end
  end
  return false
end

-- The rows as plain records for the window (no sort helpers).
function M.plain(rows)
  local out = {}
  for i, row in ipairs(rows) do
    out[i] = {id = row.id, name = row.name, kind = row.kind, role = row.role, trains = row.trains,
      level = row.level, dist = row.dist}
  end
  return out
end

return M
