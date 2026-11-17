-- Readable spell effects, table driven.
--
-- Data: core/spell_spa_names.lua (generated: every SPA id -> name) plus the KIND table below, which says how an SPA's
-- numbers are shown. An SPA without a KIND gets a row from the shape rule (D048): the client's name decides whether
-- it is a flag (name only), an id (#N), a percentage (+N%) or a number (+N). An SPA with no name, or one whose
-- value cannot be shown, falls back to a raw line ("Slot 2: SPA 9999, base ..."), so nothing is lost and nothing is
-- guessed. To support another SPA exactly, add it to KIND (and DISPLAY for a nicer name).
--
-- Shape rule (D048): KIND/DISPLAY, FOCUS and LIMIT win. Otherwise the name decides: a pure state is a flag (name
-- only), a record id is shown as #N, a name with Percent/Chance/Rate/Modifier/Multiplier/Mitigate/Reduction/Haste/
-- Slow/Accuracy/Strikethrough is a percentage (+N%), and everything else is a number (+N). The value uses the same
-- arithmetic as numeric(); a scaling slot without a class level stays raw, and base2 is not shown.
--
-- Kinds:  num   signed number            pct   signed percentage        ac     AC (display = floor(raw*3/10))
--         hp    per-tick when the spell has a duration, else instant     once   instant only
--         flag  name only                haste Haste / Slow (raw - 100)  ds     damage shield (negative base)
--         acc   accuracy, base2 = skill  rune  absorb amount, shown unsigned (no '+' prefix)
-- Values follow CalcAffectChangeGeneric (Hailstone-dev src/game/mechanics/effects.cpp): |base| + change(formula,
-- level), capped at |max|, sign of base. Tick based, random and HP based formulas are not shown (raw line).
--
-- Row shape (plain tables, safe across the plugin boundary):
--   slot, spa, name, min (text; '' for flags), min_level, max, max_level, scale ('+1 per 2 levels'), skill,
--   note ('for up to 1m', 'PC 0.5s, up to level 55'), is_raw, is_focus, is_limit
-- A focus spell has one is_focus row per modifier and one is_limit row that joins every limit phrase.
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
kinds('num', { 2, 4, 5, 6, 7, 8, 9, 10, 46, 47, 48, 49, 50, 69, 97, 111, 112, 146, 159, 190, 214, 370 })
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
-- Rune: base is the amount absorbed, max the cap; a pool, so it is shown unsigned (35, not +35).
kinds('rune', { 55 })
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

-- Focus spells (Character::check_focus_limit / spell_focus_pct, spell_math.cpp): one effect is the modifier and
-- the others are limits. Only SPAs whose meaning and sign the client source confirms are listed; anything else
-- stays a raw line (D005). 127 and 310 are the two the client applies: a positive base shortens the cast/reuse.
local FOCUS = {
  [124] = { name = 'Spell Damage', percent = true },
  [125] = { name = 'Healing', percent = true },
  [127] = { name = 'Spell Cast Time', percent = true, invert = true },
  [128] = { name = 'Spell Duration', percent = true },
  [129] = { name = 'Spell Range', percent = true },
  [132] = { name = 'Mana Cost', percent = true }, -- stored negative for a reduction
  [133] = { name = 'Spell Stun Duration', percent = true },
  [310] = { name = 'Reuse Timer', percent = true, invert = true },
  [339] = { name = 'Trigger on Cast', trigger = true }, -- base is the chance, base2 the spell
}

-- Limit phrases (check_focus_limit's cases). A nil phrase leaves that slot raw.
local RESIST = { [0] = 'unresistable', 'magic', 'fire', 'cold', 'poison', 'disease', 'chromatic', 'prismatic',
  'physical', 'corruption' }
local TARGET = { [1] = 'line of sight', [3] = 'group teleport', [4] = 'area around caster', [5] = 'single',
  [6] = 'self', [8] = 'area around target', [9] = 'animal', [10] = 'undead', [11] = 'summoned',
  [13] = 'lifetap', [14] = 'pet', [15] = 'corpse', [41] = 'group' }
local SPELL_TYPE = { [0] = 'detrimental', [1] = 'beneficial', [2] = 'beneficial group-only' }

-- lookup(id) may return a name string (the old contract) or {name = <string>, summary = <string|nil>}.
local function lookup_name(found)
  if type(found) == 'string' then return found ~= '' and found or nil end
  if type(found) == 'table' and type(found.name) == 'string' and found.name ~= '' then return found.name end
end

local function lookup_summary(found)
  if type(found) == 'table' and type(found.summary) == 'string' and found.summary ~= '' then
    return found.summary
  end
end

local LIMIT = {}
local function limit(spa, fn) LIMIT[spa] = fn end

-- 134/433/434/435: the spell's level for the caster's class must be at most base; base2 is the falloff per level over.
local function levelLimit(effect)
  local text = 'level <= ' .. effect.base
  if effect.base2 ~= 0 then text = text .. (' (%+d%% per level over)'):format(-effect.base2) end
  return text
end
limit(134, levelLimit)
limit(433, levelLimit)
limit(434, levelLimit)
limit(435, levelLimit)
limit(135, function(effect)
  local name = RESIST[effect.base]
  return name and 'resist ' .. name or nil
end)
limit(136, function(effect)
  local name = TARGET[math.abs(effect.base)]
  if not name then return nil end
  return (effect.base < 0 and 'target not ' or 'target ') .. name
end)
limit(137, function(effect)
  if effect.base == 0 then return 'HP effect' end
  local name = GENERATED[math.abs(effect.base)]
  if not name then return nil end
  return (effect.base < 0 and 'no ' or 'has ') .. name
end)
limit(138, function(effect) return SPELL_TYPE[effect.base] end)
limit(139, function(effect, lookup)
  local id = math.abs(effect.base)
  local found = type(lookup) == 'function' and lookup(id)
  local name = lookup_name(found) or ('#' .. id)
  return (effect.base < 0 and 'not spell ' or 'spell ') .. name
end)
limit(140, function(effect) return 'duration >= ' .. duration(effect.base * 6) end)
limit(141, function() return 'instant' end)
limit(142, function(effect) return 'level >= ' .. effect.base end)
limit(143, function(effect) return 'cast >= ' .. millis(effect.base) end)
limit(144, function(effect) return 'cast <= ' .. millis(effect.base) end)
limit(311, function(effect) return effect.base ~= 0 and 'combat skills only' or 'no combat skills' end)
limit(348, function(effect) return 'mana >= ' .. effect.base end)
limit(391, function(effect) return 'mana <= ' .. effect.base end)
limit(414, function(effect)
  -- -1 is "all skills" for the accuracy SPAs, not for this limit: the client compares the spell's skill exactly.
  if effect.base < 0 then return nil end
  local name = SKILLS[effect.base]
  return name and 'skill ' .. name or nil
end)

local function focusRow(slot, effect, lookup)
  local f = FOCUS[effect.effect]
  -- A focus modifier's formula is unused (0 or 100); a scaling formula is a normal effect of the same SPA, but
  -- FOCUS wins over the shape rule, so it stays raw.
  if not f or effect.formula ~= 0 and effect.formula ~= 100 then return nil end
  local row = { slot = slot, spa = effect.effect, name = f.name, is_raw = false, is_focus = true }
  if f.trigger then
    row.min = ('%d%%'):format(effect.base)
    if effect.base2 > 0 then
      local found = type(lookup) == 'function' and lookup(effect.base2)
      local spellName = lookup_name(found) or ('#' .. effect.base2)
      local summary = lookup_summary(found)
      row.note = summary and (spellName .. ': ' .. summary) or spellName
    end
  elseif f.percent then
    row.min = ('%+d%%'):format(f.invert and -effect.base or effect.base)
  else
    row.min = ('%+d'):format(effect.base)
  end
  return row
end

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

-- The spell's own direct damage: SPA 0 (HP) and SPA 79 (Instant HP) with a negative base, the two the client uses
-- for direct damage (spell_projectiles.cpp). SPA 0 with a duration is damage per tick, so its total is per-tick x
-- ticks; SPA 79 is always instant. nil when there is no damage slot, a scaling slot has no class level, or the
-- total is 0. Raw spell values only: no focus, resist, partials or crits.
function M.damage(spell)
  if type(spell) ~= 'table' or type(spell.effects) ~= 'table' then return nil end
  local level = M.min_level(spell)
  local ticks = isInteger(spell.duration_cap) and spell.duration_cap > 0 and spell.duration_cap or 0
  local total, found = 0, false
  for _, effect in ipairs(spell.effects) do
    if type(effect) == 'table' and isInteger(effect.effect) and isInteger(effect.base)
        and isInteger(effect.max) and isInteger(effect.formula)
        and (effect.effect == 0 or effect.effect == 79) and effect.base < 0 then
      local formula = effect.formula
      local fixed = formula == 0 or formula == 100
      if not fixed and change(formula, 1) == nil then return nil end
      if not fixed and not level then return nil end
      local mag = math.abs(effect.base) + (fixed and 0 or change(formula, level))
      local cap = effect.max ~= 0 and math.abs(effect.max) or nil
      if cap and mag > cap then mag = cap end
      if effect.effect == 0 and ticks > 0 then mag = mag * ticks end
      total, found = total + mag, true
    end
  end
  if not found or total == 0 then return nil end
  return total
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
    if o.unsigned then return tostring(v) end
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
    -- AC is shown as floor(raw * 3 / 10), so its raw growth rate would be wrong; the value still scales.
    row.scale = o.ac and 'scales with level' or scaleText(formula, o.percent, sign)
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

-- Shape rule (D048). The lists are word lists, not per-SPA entries: a name that matches nothing is a number.
-- The alternate spellings from the client's spa_ids.h are included so a regenerated name table keeps working.
local FLAG = {}
for _, text in ipairs({
  'invisibility', 'see invis', 'see invisible', 'water breathing', 'lull', 'blind', 'blindness',
  'charm', 'fear', 'bind affinity', 'gate', 'invis vs undead', 'invisibility vs undead',
  'invis vs animals', 'invisibility vs animals', 'confuse', 'divine aura', 'shadow step',
  'lycanthropy', 'vampirism', 'true north', 'levitate', 'levitation', 'identify', 'wipe hate list',
  'memblur', 'spin target', 'spin stun', 'infra vision', 'infravision', 'ultra vision', 'ultravision',
  'eye of zomm', 'reclaim pet', 'reclaim energy', 'preserve corpse', 'bind sight', 'feign death',
  'voice graft', 'sentinel', 'locate corpse', 'revive', 'succor', 'cloak', 'stop rain',
  'negate if combat', 'sacrifice', 'silence', 'fearless', 'anti gate', 'summon horse', 'summon mount',
  'magic weapon', 'screech', 'immunity', 'sanctuary', 'mez', 'mesmerize', 'root', 'feign', 'bind',
  'destroy', 'banish', 'berserk', 'cancel magic', 'dispel magic', 'transfer item', 'item id',
  'corpse bomb', 'enchant light', 'toss up', 'magnify vision', 'balance mana', 'taunt',
  'gravity effect', 'pacify', 'twin cast blocker', 'stacking: block', 'stacking: overwrite',
  'stacking: no twincast', 'no fizzle', 'nomove check sneak', 'noproc', 'invulnerability',
  'skill attack', 'stun and fear',
  'amnesia', 'fading memories', 'mass group buff', 'group fear immunity', 'rampage', 'ae taunt',
  'flesh to bone', 'purge poison', 'dispel beneficial', 'ae melee', 'frenzied devastation',
  'block behind', 'two hand bash', 'persistant casting', 'extended shielding', 'divine save',
  'free pet', 'give pet group target', 'illusion persistence', 'permanent illusion', 'string unbreakable',
  'secondary forte', 'consume projectile', 'shroudof stealth', 'pet discipline', 'trade skill mastery',
  'masteryof past', 'add pet command', 'ambidexterity', 'unfailing divinity', 'feigned minion',
  'double special attack', 'nimble evasion', 'purify', 'wake the dead', 'doppelganger', 'appraisal',
  'zone suspend minion', 'invisibility2', 'invis vs undead2', 'improved invis animals',
  'no break ae sneak', 'bard ae dot', 'block next spell focus', 'summon and res all corpses',
  'summon all corpses', 'summon a pet swarm', 'immune fleeing', 'interrupt casting',
  'double ranged attack', 'persistent effect', 'deactivate all traps', 'learn trap', 'fc mute',
  'passive sense trap', 'group shielding', 'fling', 'shadow step directional', 'knockdown',
  'knock toward caster', 'negate spell effect', 'leap', 'two hand blunt block',
  'beneficial count down hold', 'distance removal', 'a stacker', 'b stacker', 'c stacker', 'd stacker',
  'ff override not focusable', 'shield target', 'pc pet rampage', 'pc pet ae rampage',
  'double melee round', 'double backstab front', 'ff same caster', 'ff focus cast proc no bypass',
}) do FLAG[text] = true end
local FLAG_PREFIX = { 'detect ', 'sense ' }

local ID = {}
for _, text in ipairs({
  'nec pet', 'create undead pet', 'call pet', 'familiar', 'gate casters bindpoint', 'summon',
  'weapon proc', 'ranged proc', 'defensive proc', 'add melee proc', 'add proc',
  'proc on kill shot', 'proc on spell kill shot', 'sympathetic proc', 'skill attack proc',
  'spell trigger', 'post effect', 'apply effect', 'spell on death', 'fc cast spell on land',
}) do ID[text] = true end
local ID_PREFIX = { 'summon ', 'teleport', 'translocate', 'gate to', 'cast on', 'caston ', 'trigger ',
  'illusion' }

local PERCENT = { 'percent', 'percentage', 'percental', 'pct', 'chance', 'rate', 'modifier', 'mod',
  'multiplier', 'mitigate', 'reduction', 'haste', 'slow', 'accuracy', 'strikethrough', 'strike through' }

-- A whole-word match that treats a digit as a boundary ("Mod2" matches, "Model" does not).
local function hasWord(text, word)
  local init = 1
  while true do
    local s, e = text:find(word, init, true)
    if not s then return false end
    local before = s == 1 or not text:sub(s - 1, s - 1):match('%a')
    local after = e == #text or not text:sub(e + 1, e + 1):match('%a')
    if before and after then return true end
    init = e + 1
  end
end

local function hasPrefix(text, list)
  for _, prefix in ipairs(list) do
    if text:sub(1, #prefix) == prefix then return true end
  end
  return false
end

local function shapeOf(label)
  local text = label:lower()
  -- A limit's base is a condition value (a class id, a spell id, a bitmask), not an amount: keep it raw.
  if text == 'limit' or text:sub(1, 6) == 'limit ' then return 'limit' end
  if FLAG[text] or hasPrefix(text, FLAG_PREFIX) then return 'flag' end
  if ID[text] or hasPrefix(text, ID_PREFIX) then return 'id' end
  if text:find('%%') then return 'percent' end
  for _, word in ipairs(PERCENT) do
    if hasWord(text, word) then return 'percent' end
  end
  return 'number'
end

local function ruleRow(slot, effect, level)
  local label = GENERATED[effect.effect]
  if not label then return nil end
  local shape = shapeOf(label)
  if shape == 'flag' then
    return { slot = slot, spa = effect.effect, name = label, min = '', is_raw = false }
  end
  if shape == 'id' then
    return { slot = slot, spa = effect.effect, name = label, min = '#' .. math.abs(effect.base), is_raw = false }
  end
  if shape == 'limit' then return nil end
  return numeric({ slot = slot, spa = effect.effect, name = label, base = effect.base, max = effect.max,
    formula = effect.formula, level = level, percent = shape == 'percent' })
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
  if not kind then
    -- FOCUS and LIMIT win over the shape rule; a focus/limit SPA that cannot be shown stays raw.
    if FOCUS[spa] or LIMIT[spa] then return nil end
    return ruleRow(slot, effect, level)
  end
  local label = name(spa)
  if kind == 'proc' then
    if base <= 0 or formula ~= 100 and formula ~= 0 then return nil end
    local found = type(lookup) == 'function' and lookup(base)
    local spellName = lookup_name(found) or ('#' .. base)
    local summary = lookup_summary(found)
    return { slot = slot, spa = spa, name = label, min = summary and (spellName .. ': ' .. summary) or spellName,
      is_raw = false,
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
  if kind == 'rune' then o.unsigned = true end
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
  local limits = {}
  for i, effect in ipairs(spell.effects) do
    if type(effect) ~= 'table' then
      out[#out + 1] = rawRow(i, effect)
    elseif isInteger(effect.effect) and effect.effect == 254 then
      -- empty slot
    elseif isInteger(effect.effect) and isInteger(effect.base) and isInteger(effect.base2)
        and isInteger(effect.max) and isInteger(effect.formula) then
      local phrase = LIMIT[effect.effect] and LIMIT[effect.effect](effect, lookup)
      if phrase then
        limits[#limits + 1] = phrase
      else
        local row = focusRow(i, effect, lookup) or readableRow(i, effect, level, ticks, lookup)
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
      end
    else
      out[#out + 1] = rawRow(i, effect)
    end
  end
  if #limits > 0 then
    out[#out + 1] = { name = 'Limits', min = table.concat(limits, ', '), is_limit = true }
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
  if row.is_limit then
    return 'Limits: ' .. (type(row.min) == 'string' and row.min or '')
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

-- A one-line description of a spell for a proc or trigger row: its direct damage with the resist type when the
-- client names one, otherwise its first one or two effect rows. Built without a lookup, so it cannot recurse.
function M.summary(spell)
  local damage = M.damage(spell)
  if damage then
    local resist = type(spell) == 'table' and isInteger(spell.resist) and spell.resist ~= 0
      and RESIST[spell.resist] or nil
    if resist then return ('%d %s damage'):format(damage, resist) end
    return ('%d damage'):format(damage)
  end
  local parts = {}
  for _, row in ipairs(M.rows(spell)) do
    local text = M.format(row)
    if text then
      parts[#parts + 1] = text
      if #parts == 2 then break end
    end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, ', ')
end

return M
