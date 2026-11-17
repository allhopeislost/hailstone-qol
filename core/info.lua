local M = {}
local spell_effects = require('core.spell_effects')
-- The playable class short names, indexed by the client's class id (1 WAR .. 16 BER); other ids (merchants,
-- bankers, GM trainers) are not classes a player reads off a nameplate.
M.classes = {'WAR', 'CLR', 'PAL', 'RNG', 'SHD', 'DRU', 'MNK', 'BRD',
  'ROG', 'SHM', 'NEC', 'WIZ', 'MAG', 'ENC', 'BST', 'BER'}


local function number(value)
  if type(value) ~= 'number' or value ~= value or value == math.huge or value == -math.huge then return nil end
  return value
end

local function integer(value)
  value = number(value)
  if value and value % 1 == 0 and value >= -2147483648 and value <= 2147483647 then return value end
end

local function append(lines, label, value)
  if value ~= nil then lines[#lines + 1] = label .. value end
end

-- Target types whose damage slot applies to each target in the area rather than once per cast. The client's
-- TargetType enum names 2 (AE PC v1), 4 (AE around caster) and 8 (AE around target); its cast check lists
-- 21, 22, 23 and 28 as targeted AE types; target_type_name in tlo_game.cpp names 20, 24, 25, 36, 37 and 40.
local area_target_types = {[2] = true, [4] = true, [8] = true, [20] = true, [21] = true, [22] = true,
  [23] = true, [24] = true, [25] = true, [28] = true, [36] = true, [37] = true, [40] = true}

local function is_area_spell(s)
  local ae_range = number(s.ae_range)
  if ae_range and ae_range > 0 then return true end
  return area_target_types[integer(s.target_type)] == true
end

local function spell_header_lines(s)
  local lines = {}
  append(lines, 'Spell ID: ', number(s.id))
  append(lines, 'Level: ', number(s.level))
  append(lines, 'Mana: ', number(s.mana))
  local damage, mana = spell_effects.damage(s), number(s.mana)
  if damage and mana and mana > 0 then
    local suffix = is_area_spell(s) and ' (per target)' or ''
    lines[#lines + 1] = ('Damage per mana: %.2f%s'):format(damage / mana, suffix)
  end
  append(lines, 'Endurance: ', number(s.endurance))

  local cast = number(s.cast_time)
  local recovery = number(s.recovery_time)
  local recast = number(s.recast_time)
  if cast and cast >= 0 then lines[#lines + 1] = ('Cast: %.2fs'):format(cast / 1000) end
  if recovery and recovery >= 0 then lines[#lines + 1] = ('Recovery: %.2fs'):format(recovery / 1000) end
  if recast and recast >= 0 then lines[#lines + 1] = ('Recast: %.2fs'):format(recast / 1000) end
  append(lines, 'Range: ', number(s.range))
  append(lines, 'AE range: ', number(s.ae_range))
  local pushback = number(s.push_back)
  if pushback and pushback ~= 0 then lines[#lines + 1] = ('Pushback: %.1f'):format(pushback) end
  if s.spell_type == 0 then
    append(lines, 'Resist type: ', number(s.resist))
    local modifier = integer(s.resist_adj)
    if modifier then lines[#lines + 1] = ('Modifier: %+d'):format(modifier) end
  end
  if type(s.skillName) == 'string' and s.skillName ~= '' then append(lines, 'Skill: ', s.skillName) end

  local levels = {}
  if type(s.class_level) == 'table' then
    for i, level in ipairs(s.class_level) do
      level = number(level)
      if M.classes[i] and level and level > 0 and level < 255 then
        levels[#levels + 1] = M.classes[i] .. ' ' .. level
      end
    end
  end
  if #levels > 0 then lines[#lines + 1] = 'Classes: ' .. table.concat(levels, ', ') end
  return lines
end

function M.spell(s, lookup)
  if type(s) ~= 'table' then return nil end
  local lines = spell_header_lines(s)
  for _, row in ipairs(spell_effects.rows(s, lookup)) do
    local line = spell_effects.format(row)
    if line then lines[#lines + 1] = line end
  end
  for _, pair in ipairs({{'Cast on you: ', s.cast_on_you}, {'Wears off: ', s.wear_off}}) do
    if type(pair[2]) == 'string' and pair[2] ~= '' then append(lines, pair[1], pair[2]) end
  end
  if #lines == 0 then return nil end
  return table.concat(lines, '\n')
end

-- Readable effect rows for a spell record. Returns an (possibly empty)
-- array of spell_effects rows. See spell_effects.lua for the row shape.
function M.spell_effects(s, lookup)
  return spell_effects.rows(s, lookup)
end

-- Split view for UI rendering: {effects = rows, metadata = header}.
-- effects is the M.spell_effects(s) array (possibly empty); metadata
-- is the spell header without effect lines and without cast messages
-- (array of strings, possibly empty). Returns nil for non-table input.
-- All values are plain tables, strings and numbers, safe to cross the
-- plugin boundary.
function M.spell_details(s, lookup)
  if type(s) ~= 'table' then return nil end
  local rows = spell_effects.rows(s, lookup) or {}
  local header = spell_header_lines(s)
  return {effects = rows, metadata = header}
end

-- The spell an item record carries, in the order a player most wants explained: focus, proc, worn,
-- click, scroll. Returns (id, kind) for the first positive, finite integer id, or nil. Only the
-- record's own id fields are read; nothing is looked up by name.
M.item_spell_fields = {
  {'focus_spell', 'Focus'}, {'proc_spell', 'Proc'}, {'worn_spell', 'Worn'},
  {'click_spell', 'Click'}, {'scroll_spell', 'Scroll'},
}

function M.item_spell(item)
  if type(item) ~= 'table' then return nil end
  for _, field in ipairs(M.item_spell_fields) do
    local id = number(item[field[1]])
    if id and id >= 1 and id % 1 == 0 then return id, field[2] end
  end
  return nil
end

function M.item(item)
  if type(item) ~= 'table' then return nil end
  local lines = {}
  append(lines, 'Item ID: ', number(item.id))
  append(lines, 'Required level: ', number(item.req_level))
  append(lines, 'Stack: ', number(item.stack))
  append(lines, 'Charges: ', number(item.charges))
  append(lines, 'Bag slots: ', number(item.bag_slots))
  append(lines, 'Weight: ', number(item.weight))
  append(lines, 'AC: ', number(item.ac))
  append(lines, 'HP: ', number(item.hp))
  append(lines, 'Mana: ', number(item.mana))
  append(lines, 'Click spell ID: ', number(item.click_spell))
  append(lines, 'Scroll spell ID: ', number(item.scroll_spell))
  local value, favor = number(item.value), number(item.favor)
  if value and value > 0 then append(lines, 'Base value: ', value .. ' copper') end
  if favor and favor > 0 then append(lines, 'Tribute value: ', favor) end
  local damage, delay = number(item.damage), number(item.delay)
  if damage and delay and damage > 0 and delay > 0 then
    local ratio = number(delay / damage)
    if ratio then lines[#lines + 1] = ('Delay / damage: %.3f'):format(ratio) end
  end
  if type(item.lore) == 'string' and item.lore ~= '' and item.lore ~= item.name then
    append(lines, 'Lore: ', item.lore)
  end
  if item.magic == true then lines[#lines + 1] = 'Magic' end
  if item.lore == true then lines[#lines + 1] = 'Lore item' end
  if #lines == 0 then return nil end
  return table.concat(lines, '\n')
end

return M
