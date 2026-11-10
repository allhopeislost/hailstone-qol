-- Readable spell effects, table driven.
--
-- Data: core/spell_spa_names.lua (generated: every SPA id -> name) plus the KIND table below, which says how an SPA's
-- numbers are shown. SPAs without a KIND fall back to a named raw line ("Slot 2: Root (SPA 99, base ...)"), so
-- nothing is lost and nothing is guessed. To support another SPA, add it to KIND (and DISPLAY for a nicer name).
--
-- Kinds:  num   signed number            pct   signed percentage        ac     AC (display = floor(raw*3/10))
--         hp    per-tick when the spell has a duration, else instant     once   instant only
--         flag  name only                haste Haste / Slow (raw - 100)  ds     damage shield (negative base)
--         acc   accuracy, base2 = skill
-- Values follow CalcAffectChangeGeneric (Hailstone-dev src/game/mechanics/effects.cpp): |base| + change(formula,
-- level), capped at |max|, sign of base. Tick based, random and HP based formulas are not shown (raw line).
--
-- Row shape (plain tables, safe across the plugin boundary):
--   slot, spa, name, min (text; '' for flags), min_level, max, max_level, scale ('+1 per 2 levels'), skill,
--   note ('for up to 1m', 'PC 0.5s, up to level 55'), is_raw
-- A scaling effect needs the lowest class level of the spell; without one it stays raw (no level is guessed).
-- Values are spell-effect values, not character-sheet totals; an uncapped effect never shows a made-up cap.
local M = {}
local GENERATED = require('core.spell_spa_names')

local DISPLAY = {
  [0] = 'HP', [15] = 'Mana', [189] = 'Endurance', [79] = 'HP', [198] = 'Endurance', [358] = 'Mana',
  [1] = 'Armor Class', [2] = 'Attack', [3] = 'Movement Speed', [4] = 'Strength', [5] = 'Dexterity',
  [6] = 'Agility', [7] = 'Stamina', [8] = 'Intelligence', [9] = 'Wisdom', [10] = 'Charisma',
  [11] = 'Haste', [98] = 'Haste', [119] = 'Haste',
  [46] = 'Fire Resist', [47] = 'Cold Resist', [48] = 'Poison Resist', [49] = 'Disease Resist',
  [50] = 'Magic Resist', [370] = 'Corruption Resist', [111] = 'All Resists', [159] = 'All Stats',
  [59] = 'Damage Shield', [69] = 'Max HP', [214] = 'Max HP Change', [97] = 'Max Mana', [190] = 'Max Endurance',
  [216] = 'Accuracy', [292] = 'Strikethrough', [185] = 'Damage Modifier', [169] = 'Critical Hit Chance',
  [100] = 'Heal per tick', [21] = 'Stun',
  [337] = 'XP Increase',
  [33] = 'Summon Pet', [71] = 'Summon Pet', [103] = 'Call Pet', [106] = 'Summon Warder',
}

local KIND = {}
local function kinds(kind, list) for _, id in ipairs(list) do KIND[id] = kind end end
kinds('num', { 2, 4, 5, 6, 7, 8, 9, 10, 46, 47, 48, 49, 50, 69, 97, 111, 146, 159, 190, 214, 370 })
kinds('pctneg', { 168 }) -- Melee Mitigation: stored negative for an improvement (MacroQuest shows -value)
kinds('pct', { 3, 127, 170, 171, 172, 173, 174, 175, 176, 177, 180, 181, 186, 188, 195, 196, 200,
  250, 266, 273, 274, 275, 292 })
-- Raise Stat Cap: base2 is the stat (0 STR, 1 STA, 2 AGI, 3 DEX, 4 WIS, 5 INT, 6 CHA)
kinds('statcap', { 262 })
-- Percent XP Increase: base is the percentage (the game's own description text may show 0 for it)
kinds('pct', { 337 })
local STAT = { 'STR', 'STA', 'AGI', 'DEX', 'WIS', 'INT', 'CHA' }
kinds('hp', { 0, 15, 189 })
kinds('once', { 79, 198, 358 })
kinds('flag', { 12, 13, 14, 28, 29, 40, 51, 52, 53, 54, 56, 57, 65, 66, 102,
  33, 71, 103, 106, -- 33/71/103/106: pet summons (the pet's name is not in the spell record)
  25, 26, 63, 64, 68, 74, 83, 88, 91, 99, 101, 104, 105, 113 }) -- bind, gate, root, feign, teleport ...: no value
-- Summoned items: base is the item id (the client has no item name by id, so the id is shown)
KIND[32], KIND[109] = 'item', 'item'
-- Procs: base is the spell that fires (looked up by name when the caller gives a lookup), base2 the rate modifier
kinds('proc', { 85, 201, 323, 419 })
kinds('haste', { 11, 98, 119 })
KIND[1], KIND[59] = 'ac', 'ds'
kinds('acc', { 216, 185, 169 }) -- a percentage limited to a skill (base2; -1 = all)
KIND[100], KIND[21] = 'hot', 'stun'
-- Counters: a negative base removes counters (a cure), a positive one adds them (a debuff).
local COUNTER = { [35] = 'Disease', [36] = 'Poison', [116] = 'Curse', [369] = 'Corruption' }
for id in pairs(COUNTER) do KIND[id] = 'counter' end

-- skill id -> name (generated); -1 means every skill
local SKILLS = setmetatable({ [-1] = 'all skills' }, { __index = GENERATED.skills })

-- 90 -> '1m 30s'
local function duration(seconds)
  seconds = math.floor(seconds)
  local parts = {}
  if seconds >= 3600 then parts[#parts + 1] = (seconds // 3600) .. 'h' end
  if seconds % 3600 >= 60 then parts[#parts + 1] = (seconds % 3600 // 60) .. 'm' end
  if seconds % 60 > 0 or #parts == 0 then parts[#parts + 1] = (seconds % 60) .. 's' end
  return table.concat(parts, ' ')
end
local function millis(ms) return ('%g'):format(ms / 1000) .. 's' end

local function isInteger(value)
  return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
    and value % 1 == 0 and value >= -2147483648 and value <= 2147483647
end

-- The level based part of a formula (effects.cpp); nil for formulas that need ticks, a roll or the target's HP.
local OVER = { [111] = { 16, 6 }, [112] = { 24, 8 }, [113] = { 34, 10 }, [114] = { 44, 15 }, [115] = { 15, 7 },
  [116] = { 24, 10 }, [117] = { 34, 13 }, [118] = { 44, 20 }, [124] = { 50, 1 }, [125] = { 50, 2 },
  [126] = { 50, 3 }, [127] = { 50, 4 }, [128] = { 50, 5 }, [129] = { 50, 10 }, [130] = { 50, 15 },
  [131] = { 50, 20 }, [132] = { 50, 25 } }
local function change(formula, level)
  if formula == 0 or formula == 100 then return 0 end
  if formula >= 1 and formula <= 99 then return level * formula end
  if formula == 101 then return level // 2 end
  if formula == 102 then return level end
  if formula == 103 then return level * 2 end
  if formula == 104 then return level * 3 end
  if formula == 105 then return level * 4 end
  if formula == 109 then return level // 4 end
  if formula == 110 then return level // 6 end
  if formula == 119 then return level // 8 end
  if formula == 121 then return level // 3 end
  if formula == 143 then return (level * 3) // 4 end
  local o = OVER[formula]
  if o then return level > o[1] and (level - o[1]) * o[2] or 0 end
  if formula > 2000 and formula < 3000 then return (formula - 2000) * level end
  return nil
end
local PERIOD = { [101] = { 1, '2 levels' }, [102] = { 1, 'level' }, [103] = { 2, 'level' }, [104] = { 3, 'level' },
  [105] = { 4, 'level' }, [109] = { 1, '4 levels' }, [110] = { 1, '6 levels' }, [119] = { 1, '8 levels' },
  [121] = { 1, '3 levels' } }

local function scaleText(formula, percent, sign)
  local p = PERIOD[formula] or (formula >= 1 and formula <= 99 and { formula, 'level' })
  if not p then return 'scales with level' end
  return ('%s%d%s per %s'):format(sign < 0 and '-' or '+', p[1], percent and '%' or '', p[2])
end

function M.min_level(spell)
  if type(spell) ~= 'table' or type(spell.class_level) ~= 'table' then return nil end
  local best
  for _, level in ipairs(spell.class_level) do
    if isInteger(level) and level > 0 and level < 255 and (best == nil or level < best) then best = level end
  end
  return best
end

-- The first level from `from` whose value reaches `target` (values only grow with level).
local function firstLevel(from, valueAt, target)
  for level = from, 255 do
    if valueAt(level) >= target then return level end
  end
end

-- num / pct / ac / hp / ds / acc rows.
local function numeric(o)
  local formula, base = o.formula, o.base
  local fixed = formula == 0 or formula == 100
  if not fixed and change(formula, 1) == nil then return nil end
  local sign = base < 0 and -1 or 1
  if o.invert then sign = -sign end
  local cap = o.max ~= 0 and math.abs(o.max) or nil
  local function mag(level)
    local m = math.abs(base) + (fixed and 0 or change(formula, level))
    if cap and m > cap then m = cap end
    return m
  end
  local function show(m)
    if o.ac then m = math.floor(m * 3 / 10) end
    local v = sign * m
    if o.plain then return tostring(-v) end
    return (o.percent and '%+d%%' or '%+d'):format(v)
  end
  local row = { slot = o.slot, spa = o.spa, name = o.name, is_raw = false, skill = o.skill, note = o.note }
  if fixed then
    row.min = show(mag(1))
    return row
  end
  if not o.level then return nil end
  local minM = mag(o.level)
  row.min, row.min_level = show(minM), o.level
  if not cap then
    if o.ac then return nil end
    row.scale = scaleText(formula, o.percent, sign)
    return row
  end
  if minM >= cap then
    row.min = show(cap)
    return row
  end
  -- the level where the cap is reached; nil when it never is (the maximum is then shown without a level)
  local reach = firstLevel(o.level, function(l) return math.abs(base) + change(formula, l) end, cap)
  row.max, row.max_level = show(cap), reach
  return row
end

-- Haste above 100, slow below it (the stored value includes the 100 baseline).
local function haste(slot, spa, base, max, formula, level)
  local fixed = formula == 0 or formula == 100
  if not fixed and change(formula, 1) == nil then return nil end
  local function build(minRaw, minLevel, maxRaw, maxLevel, scale)
    if minRaw > 100 and (maxRaw == nil or maxRaw > 100) then
      local row = { slot = slot, spa = spa, name = 'Haste', is_raw = false, min = ('%+d%%'):format(minRaw - 100),
        min_level = minLevel, max_level = maxLevel, scale = scale }
      if maxRaw then row.max = ('%+d%%'):format(maxRaw - 100) end
      return row
    end
    if minRaw < 100 and minRaw > 0 and (maxRaw == nil or (maxRaw < 100 and maxRaw > 0)) then
      local row = { slot = slot, spa = spa, name = 'Slow', is_raw = false, min = (100 - minRaw) .. '%',
        min_level = minLevel, max_level = maxLevel, scale = scale }
      if maxRaw then row.max = (100 - maxRaw) .. '%' end
      return row
    end
  end
  local slow = base < 100
  if fixed then
    local value = base
    if max ~= 0 then
      if slow then
        if base < max then value = max end
      elseif base > max then
        value = max
      end
    end
    if value == 100 or value <= 0 then return nil end
    -- a nonzero cap on a slow snaps it to the cap, so a ramp would mislead
    if value < 100 and max ~= 0 then return nil end
    return build(value, nil, nil, nil, nil)
  end
  if not level then return nil end
  if slow then
    if base <= 0 or max ~= 0 then return nil end
    return build(base - change(formula, level), level, nil, nil, scaleText(formula, true, 1))
  end
  local minRaw = base + change(formula, level)
  if max == 0 then return build(minRaw, level, nil, nil, scaleText(formula, true, 1)) end
  if max <= 100 then return nil end
  if minRaw >= max then return build(max, level, nil, nil, nil) end
  local reach = firstLevel(level, function(l) return base + change(formula, l) end, max)
  if not reach then return nil end
  return build(minRaw, level, max, reach, nil)
end

local function name(spa)
  return DISPLAY[spa] or GENERATED[spa]
end

local function fieldText(value)
  if type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge then
    if value % 1 == 0 then return ('%d'):format(value) end
    return tostring(value)
  end
  return '?'
end

local function rawText(slot, effect)
  if type(effect) ~= 'table' then
    return ('Slot %d: SPA ?, base ?, base2 ?, max ?, formula ?'):format(slot)
  end
  local label = isInteger(effect.effect) and GENERATED[effect.effect]
  return ('Slot %d: %sSPA %s, base %s, base2 %s, max %s, formula %s%s'):format(slot,
    label and (label .. ' (') or '', fieldText(effect.effect), fieldText(effect.base),
    fieldText(effect.base2), fieldText(effect.max), fieldText(effect.formula), label and ')' or '')
end

local function rawRow(slot, effect)
  local spa = 0
  if type(effect) == 'table' and isInteger(effect.effect) then spa = effect.effect end
  return { slot = slot, spa = spa, name = 'Slot ' .. slot, min = rawText(slot, effect), is_raw = true }
end

local function readableRow(slot, effect, level, ticks, lookup)
  local spa, base, base2, max, formula = effect.effect, effect.base, effect.base2, effect.max, effect.formula
  local kind = KIND[spa]
  if not kind then return nil end
  local label = name(spa)
  if kind == 'proc' then
    if base <= 0 or formula ~= 100 and formula ~= 0 then return nil end
    local found = type(lookup) == 'function' and lookup(base)
    return { slot = slot, spa = spa, name = label, min = type(found) == 'string' and found ~= '' and found
      or ('#' .. base), is_raw = false,
      note = base2 ~= 0 and ('proc rate %+d%%'):format(base2) or nil }
  end
  if kind == 'item' then
    if base <= 0 or formula ~= 1 and formula ~= 100 and formula ~= 0 then return nil end
    local row = { slot = slot, spa = spa, name = spa == 109 and 'Summon Item Into Bag' or 'Summon Item',
      min = '#' .. base, is_raw = false }
    if spa == 109 then row.bag = { lo = base, hi = base, n = 1 } end
    return row
  end
  if kind == 'flag' then
    return { slot = slot, spa = spa, name = label, min = '', is_raw = false }
  end
  if kind == 'haste' then
    if base2 ~= 0 then return nil end
    return haste(slot, spa, base, max, formula, level)
  end
  -- charisma is also a non-display spacer in the spell data (MacroQuest hides it too)
  if spa == 10 and (base <= 1 or base > 255) then return 'skip' end
  if kind == 'stun' then
    -- base: stun time in ms, base2: the same against a player, max: the highest target level (0 = any)
    if formula ~= 100 and formula ~= 0 or base <= 0 or base2 < 0 or max < 0 then return nil end
    local notes = {}
    if base2 > 0 and base2 ~= base then notes[#notes + 1] = 'PC ' .. millis(base2) end
    if max > 0 then notes[#notes + 1] = 'up to level ' .. max end
    return { slot = slot, spa = spa, name = label, min = millis(base), is_raw = false,
      note = #notes > 0 and table.concat(notes, ', ') or nil }
  end
  local o = { slot = slot, spa = spa, name = label, base = base, max = max, formula = formula, level = level }
  if kind == 'statcap' then
    if base2 < 0 or base2 > 6 or base < 0 then return nil end
    o.name = STAT[base2 + 1] .. ' Cap'
  end
  if kind == 'counter' then
    if base < 0 then
      o.name, o.plain = 'Cure ' .. COUNTER[spa], true -- shown as the number of counters removed
    else
      o.name = COUNTER[spa] .. ' Counter'
    end
  end
  if kind == 'hot' then
    if base < 0 then return nil end
    if ticks > 0 then o.note = 'for up to ' .. duration(ticks * 6) end
  end
  if kind == 'acc' then
    o.skill = SKILLS[base2]
    if not o.skill then return nil end
    o.percent = true
  elseif base2 ~= 0 and kind ~= 'hp' and kind ~= 'once' and kind ~= 'statcap' then
    return nil
  end
  if kind == 'pct' then o.percent = true end
  if kind == 'pctneg' then o.percent, o.invert = true, true end
  if kind == 'ac' then o.ac = true end
  if kind == 'ds' then
    if base >= 0 then return nil end
    o.plain = true
  end
  if kind == 'hp' and ticks > 0 then o.name = label .. ' per tick' end
  return numeric(o)
end

-- lookup(id) -> spell name (optional): names the spells that procs and the like point at
function M.rows(spell, lookup)
  if type(spell) ~= 'table' or type(spell.effects) ~= 'table' then return {} end
  local level = M.min_level(spell)
  local ticks = isInteger(spell.duration_cap) and spell.duration_cap > 0 and spell.duration_cap or 0
  local out = {}
  local bagRow
  for i, effect in ipairs(spell.effects) do
    if type(effect) ~= 'table' then
      out[#out + 1] = rawRow(i, effect)
    elseif isInteger(effect.effect) and effect.effect == 254 then
      -- empty slot
    elseif isInteger(effect.effect) and isInteger(effect.base) and isInteger(effect.base2)
        and isInteger(effect.max) and isInteger(effect.formula) then
      local row = readableRow(i, effect, level, ticks, lookup)
      if row == 'skip' then
        -- nothing to show
      elseif type(row) == 'table' and row.bag then
        -- every bag content is its own slot: one row for the lot
        if bagRow then
          bagRow.bag.lo, bagRow.bag.hi = math.min(bagRow.bag.lo, row.bag.lo), math.max(bagRow.bag.hi, row.bag.hi)
          bagRow.bag.n = bagRow.bag.n + 1
        else
          bagRow = row
          out[#out + 1] = row
        end
      else
        out[#out + 1] = row or rawRow(i, effect)
      end
    else
      out[#out + 1] = rawRow(i, effect)
    end
  end
  if bagRow then
    local b = bagRow.bag
    bagRow.bag = nil
    if b.n > 1 then
      bagRow.min = b.n .. ' items'
      bagRow.note = b.lo == b.hi and ('#' .. b.lo) or ('IDs #' .. b.lo .. '-#' .. b.hi)
    end
  end
  return out
end

function M.format(row)
  if type(row) ~= 'table' then return nil end
  if row.is_raw then
    return type(row.min) == 'string' and row.min or nil
  end
  if type(row.name) ~= 'string' or type(row.min) ~= 'string' then return nil end
  if row.min == '' then
    if row.note ~= nil then return row.name .. ', ' .. row.note end
    return row.name
  end
  local label = row.name .. ' ' .. row.min
  if row.skill then label = label .. ' (' .. row.skill end
  if row.min_level ~= nil and (row.max ~= nil or row.scale ~= nil) then
    if row.skill then label = label .. ', level ' .. tostring(row.min_level) .. ')'
    else label = label .. ' (level ' .. tostring(row.min_level) .. ')' end
  elseif row.skill then
    label = label .. ')'
  end
  if row.max ~= nil then
    local tail = row.name .. ' ' .. row.max
    if row.max_level == nil then
      -- cap never reached by the highest level: no level to name
    elseif row.skill then tail = tail .. ' (' .. row.skill .. ', level ' .. tostring(row.max_level) .. ')'
    else tail = tail .. ' (level ' .. tostring(row.max_level) .. ')' end
    label = label .. ' to ' .. tail
  elseif row.scale ~= nil then
    label = label .. ', ' .. row.scale
  end
  if row.note ~= nil then label = label .. ', ' .. row.note end
  return label
end

return M
