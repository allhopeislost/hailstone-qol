local fx = require('spell_effects')
local info = require('info')

-- Missing input yields no rows, never a guessed level.
assert(#fx.rows(nil) == 0 and #fx.rows(false) == 0 and #fx.rows(42) == 0)
assert(#fx.rows({}) == 0)
assert(fx.min_level(nil) == nil and fx.min_level({}) == nil)
assert(fx.min_level({class_level = {255, 11, 0, 300}}) == 11)
assert(info.spell_details(nil) == nil)

-- Screenshot values at caster level 11.
local spell = {
  id = 100,
  class_level = {255, 11},
  effects = {
    {effect = 216, base = 5, base2 = 0, max = 0, formula = 101},
    {effect = 4, base = 15, base2 = 0, max = 45, formula = 101},
    {effect = 11, base = 110, base2 = 0, max = 160, formula = 102},
    {effect = 2, base = 5, base2 = 0, max = 0, formula = 100},
    {effect = 1, base = 25, base2 = 0, max = 40, formula = 101},
    {effect = 292, base = 50, base2 = 0, max = 0, formula = 100},
  },
}
local rows = fx.rows(spell)
assert(#rows == 6)

assert(rows[1].name == 'Accuracy' and rows[1].skill == '1H Blunt' and rows[1].spa == 216)
assert(rows[1].min == '+10%' and rows[1].min_level == 11 and not rows[1].is_raw)
assert(rows[1].max == nil and rows[1].scale == '+1% per 2 levels')

assert(rows[2].name == 'Strength' and not rows[2].is_raw)
assert(rows[2].min == '+20' and rows[2].min_level == 11)
assert(rows[2].max == '+45' and rows[2].max_level == 60)

assert(rows[3].name == 'Haste' and not rows[3].is_raw)
assert(rows[3].min == '+21%' and rows[3].min_level == 11)
assert(rows[3].max == '+60%' and rows[3].max_level == 50)

assert(rows[4].name == 'Attack' and rows[4].min == '+5')
assert(rows[4].max == nil and rows[4].min_level == nil and rows[4].scale == nil)

assert(rows[5].name == 'Armor Class' and not rows[5].is_raw)
assert(rows[5].min == '+9' and rows[5].min_level == 11)
assert(rows[5].max == '+12' and rows[5].max_level == 30)

assert(rows[6].name == 'Strikethrough' and rows[6].min == '+50%')

assert(fx.format(rows[2]) == 'Strength +20 (level 11) to Strength +45 (level 60)')
assert(fx.format(rows[4]) == 'Attack +5')

-- info.spell uses the readable lines and drops cast messages.
local text = info.spell(spell)
assert(text:find('Strength +20 (level 11) to Strength +45 (level 60)', 1, true))
assert(text:find('Haste +21% (level 11) to Haste +60% (level 50)', 1, true))
assert(text:find('Attack +5', 1, true))
assert(not text:find('SPA 216, base', 1, true))

local with_messages = {id = 1, class_level = {5},
  effects = {{effect = 2, base = 5, base2 = 0, max = 0, formula = 100}},
  cast_on_you = 'You glow.', cast_on_other = 'glows.', wear_off = 'fades.'}
text = info.spell(with_messages)
assert(text:find('Attack +5', 1, true))
assert(text:find('You glow', 1, true))
assert(not text:find('glows', 1, true))
assert(text:find('fades', 1, true))

local via_info = info.spell_effects(spell)
assert(#via_info == 6 and via_info[2].name == 'Strength' and via_info[2].max_level == 60)

local details = info.spell_details({id = 7, class_level = {255, 3},
  effects = {{effect = 2, base = 5, base2 = 0, max = 0, formula = 100}}})
assert(details.metadata[1] == 'Spell ID: 7')
assert(#details.effects == 1 and details.effects[1].name == 'Attack')
assert(type(details.effects[1].slot) == 'number' and type(details.effects[1].spa) == 'number')
assert(details.effects[1].is_raw == false)

-- Uncapped scaling carries a rate and no fabricated max.
rows = fx.rows({class_level = {20}, effects = {
  {effect = 4, base = 10, base2 = 0, max = 0, formula = 101},
}})
assert(rows[1].min == '+20' and rows[1].max == nil and rows[1].scale == '+1 per 2 levels')

-- No guessed level when class levels are missing: scaling falls back to
-- raw, fixed still formats.
rows = fx.rows({effects = {
  {effect = 4, base = 10, base2 = 0, max = 0, formula = 101},
  {effect = 2, base = 5, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].is_raw == true)
assert(rows[2].min == '+5' and rows[2].is_raw == false)

-- Debuff, unsupported SPA/formula/skill and malformed fields stay raw.
rows = fx.rows({class_level = {11}, effects = {
  {effect = 4, base = -20, base2 = 0, max = 0, formula = 101},
  {effect = 0, base = -50, base2 = 0, max = 100, formula = 102},
  {effect = 4, base = 10, base2 = 0, max = 30, formula = 109},
  {effect = 216, base = 5, base2 = 99, max = 0, formula = 101},
  {effect = 254, base = 0, base2 = 0, max = 0, formula = 100},
  {effect = 1},
  false,
}})
assert(#rows == 6, 'empty SPA 254 ignored, malformed kept')
-- A debuff keeps its sign and grows in magnitude; HP is named; formula 109 is supported.
assert(rows[1].name == 'Strength' and rows[1].min == '-25' and not rows[1].is_raw)
assert(rows[2].name == 'HP' and rows[2].min == '-61' and rows[2].max == '-100' and rows[2].max_level == 50)
assert(rows[3].min == '+12' and rows[3].max == '+30' and rows[3].max_level == 80)
-- Unknown skill and malformed records stay raw, named when the SPA is known.
assert(rows[4].is_raw and rows[4].min:find('Accuracy (SPA 216', 1, true))
assert(rows[5].is_raw and rows[5].min:find('SPA 1', 1, true))
assert(rows[6].is_raw and rows[6].min:find('SPA ?', 1, true))
for i = 4, 6 do assert(fx.format(rows[i]) == rows[i].min) end

-- An SPA without a kind is a named raw line; flags show their name only; HP is per tick for a buff.
rows = fx.rows({class_level = {10}, duration_cap = 10, effects = {
  {effect = 31, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 12, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 0, base = 20, base2 = 0, max = 0, formula = 100},
  {effect = 3, base = 30, base2 = 0, max = 0, formula = 100},
  {effect = 4, base = 5, base2 = 0, max = 0, formula = 1005},
}})
assert(rows[1].is_raw and rows[1].min:find('Mez (SPA 31', 1, true))
assert(rows[2].name == 'Invisibility' and fx.format(rows[2]) == 'Invisibility')
assert(rows[3].name == 'HP per tick' and rows[3].min == '+20')
assert(rows[4].name == 'Movement Speed' and rows[4].min == '+30%')
assert(rows[5].is_raw, 'tick based formulas are not shown')

-- Slow below the 100 baseline subtracts the change.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 11, base = 70, base2 = 0, max = 0, formula = 101},
}})
assert(rows[1].name == 'Slow' and rows[1].min == '35%')

-- Capped slow would mislead (the client snaps to the floor), so raw.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 11, base = 70, base2 = 0, max = 40, formula = 101},
}})
assert(rows[1].is_raw and rows[1].min:find('SPA 11', 1, true))

-- AC's converted/rounded growth cannot be described using its raw growth rate.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 1, base = 25, base2 = 0, max = 0, formula = 101},
  {effect = 4, base = 1, base2 = 0, max = 1000, formula = 101},
}})
assert(rows[1].is_raw)
-- A cap the highest level never reaches is shown without a level.
assert(rows[2].max == '+1000' and rows[2].max_level == nil and rows[2].min == '+6')
-- The charisma spacer (base 0/1) is not a row.
assert(#fx.rows({class_level = {10}, effects = {{effect = 10, base = 1, base2 = 0, max = 0, formula = 100}}}) == 0)

-- Inferno Shield: damage shield (SPA 59, formula 109) and fire resist (SPA 46).
rows = fx.rows({class_level = {255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 28}, effects = {
  {effect = 59, base = -6, base2 = 0, max = 15, formula = 109},
  {effect = 46, base = 20, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Damage Shield' and rows[1].min == '13' and rows[1].min_level == 28)
assert(rows[1].max == '15' and rows[1].max_level == 36 and not rows[1].is_raw)
assert(rows[2].name == 'Fire Resist' and rows[2].min == '+20' and not rows[2].is_raw)

-- Stun: base ms, base2 ms against a player, max = highest target level.
rows = fx.rows({class_level = {20}, effects = {
  {effect = 21, base = 4000, base2 = 2000, max = 55, formula = 100},
  {effect = 21, base = 1000, base2 = 0, max = 0, formula = 100},
  {effect = 21, base = 500, base2 = 500, max = 0, formula = 100},
  {effect = 21, base = 4000, base2 = 2000, max = 0, formula = 102},
}})
assert(rows[1].name == 'Stun' and rows[1].min == '4s' and rows[1].note == 'PC 2s, up to level 55')
assert(fx.format(rows[1]) == 'Stun 4s, PC 2s, up to level 55')
assert(rows[2].min == '1s' and rows[2].note == nil)
assert(rows[3].min == '0.5s' and rows[3].note == nil)
assert(rows[4].is_raw, 'a stun with a level formula stays raw')

-- Heal over time: an amount per tick, with the longest duration.
rows = fx.rows({class_level = {20}, duration_cap = 12, effects = {
  {effect = 100, base = 10, base2 = 0, max = 195, formula = 105},
  {effect = 100, base = 5000, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Heal per tick' and rows[1].min == '+90' and rows[1].max == '+195')
assert(rows[1].note == 'for up to 1m 12s' and rows[1].max_level == 47)
assert(rows[2].min == '+5000' and rows[2].note == 'for up to 1m 12s')
assert(fx.format(fx.rows({class_level = {20}, effects = {{effect = 100, base = 5, base2 = 0, max = 0, formula = 100}}})[1])
  == 'Heal per tick +5', 'no duration: no note')

-- Damage modifier and critical hit chance are percentages limited to a skill.
rows = fx.rows({class_level = {20}, effects = {
  {effect = 185, base = 30, base2 = -1, max = 0, formula = 100},
  {effect = 185, base = -55, base2 = -1, max = 0, formula = 100},
  {effect = 169, base = 40, base2 = 8, max = 0, formula = 100},
  {effect = 169, base = 40, base2 = 0, max = 0, formula = 100},
  {effect = 169, base = 40, base2 = 9999, max = 0, formula = 100},
}})
assert(rows[1].name == 'Damage Modifier' and rows[1].min == '+30%' and rows[1].skill == 'all skills')
assert(rows[2].min == '-55%')
assert(rows[3].name == 'Critical Hit Chance' and rows[3].min == '+40%' and rows[3].skill == 'Backstab')
assert(rows[4].skill == '1H Blunt')
assert(rows[5].is_raw and rows[5].min:find('Critical Hit Chance (SPA 169', 1, true), 'unknown skill stays raw')

-- Counters: negative base = a cure (counters removed), positive = counters added.
rows = fx.rows({class_level = {27}, effects = {
  {effect = 35, base = -10, base2 = 0, max = 10, formula = 100},
  {effect = 36, base = -10, base2 = 0, max = 10, formula = 100},
  {effect = 116, base = -10, base2 = 0, max = 10, formula = 100},
  {effect = 35, base = 15, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Cure Disease' and rows[1].min == '10' and not rows[1].is_raw)
assert(rows[2].name == 'Cure Poison' and rows[3].name == 'Cure Curse')
assert(rows[4].name == 'Disease Counter' and rows[4].min == '+15')

-- Pet summons show their name only.
rows = fx.rows({class_level = {30}, effects = {{effect = 106, base = 1, base2 = 0, max = 0, formula = 100}}})
assert(rows[1].name == 'Summon Warder' and rows[1].min == '' and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Summon Warder')

-- Raise Stat Cap: base2 names the stat; the cap grows with level up to max.
rows = fx.rows({class_level = {1}, effects = {
  {effect = 262, base = 0, base2 = 3, max = 70, formula = 102},
  {effect = 262, base = 5, base2 = 0, max = 70, formula = 102},
  {effect = 262, base = 0, base2 = 9, max = 70, formula = 102},
}})
assert(rows[1].name == 'DEX Cap' and rows[1].min == '+1' and rows[1].max == '+70' and rows[1].max_level == 70)
assert(rows[2].name == 'STR Cap' and not rows[2].is_raw)
assert(rows[3].is_raw, 'unknown stat stays raw')

-- Increase Spell Haste is a percentage.
rows = fx.rows({class_level = {1}, effects = {{effect = 127, base = 10, base2 = 0, max = 0, formula = 102}}})
assert(rows[1].name == 'Increase Spell Haste' and rows[1].min == '+11%' and rows[1].scale == '+1% per level')

-- XP Increase is a percentage.
rows = fx.rows({class_level = {1}, effects = {{effect = 337, base = 50, base2 = 0, max = 0, formula = 100}}})
assert(rows[1].name == 'XP Increase' and rows[1].min == '+50%' and not rows[1].is_raw and rows[1].note == nil)

-- Summoned items show their ids; the bag contents are one row.
rows = fx.rows({class_level = {17}, effects = {
  {effect = 32, base = 17310, base2 = 0, max = 0, formula = 1},
  {effect = 109, base = 3405, base2 = 0, max = 0, formula = 1},
  {effect = 109, base = 3411, base2 = 0, max = 0, formula = 1},
  {effect = 109, base = 3408, base2 = 0, max = 0, formula = 1},
  {effect = 26, base = 1, base2 = 0, max = 0, formula = 100},
}})
assert(#rows == 3, 'bag slots are merged')
assert(rows[1].name == 'Summon Item' and rows[1].min == '#17310' and not rows[1].is_raw)
assert(rows[2].name == 'Summon Item Into Bag' and rows[2].min == '3 items' and rows[2].note == 'IDs #3405-#3411')
assert(rows[2].bag == nil, 'no helper field leaks into the row')
assert(rows[3].name == 'Gate' and rows[3].min == '')
rows = fx.rows({class_level = {17}, effects = {{effect = 109, base = 3405, base2 = 0, max = 0, formula = 1}}})
assert(rows[1].min == '#3405' and rows[1].note == nil)

-- Procs name the spell that fires and note the rate modifier.
local procSpell = {class_level = {28}, effects = {{effect = 85, base = 2722, base2 = 150, max = 0, formula = 100}}}
rows = fx.rows(procSpell, function(id) return id == 2722 and 'Inferno Strike' or nil end)
assert(rows[1].name == 'Weapon Proc' and rows[1].min == 'Inferno Strike' and rows[1].note == 'proc rate +150%')
assert(fx.rows(procSpell)[1].min == '#2722', 'without a lookup the spell id is shown')
assert(fx.rows(procSpell, function() return nil end)[1].min == '#2722')
assert(fx.format(rows[1]) == 'Weapon Proc Inferno Strike, proc rate +150%')

-- Melee Mitigation is stored negative for an improvement and shown with the sign turned round.
rows = fx.rows({class_level = {28}, effects = {
  {effect = 168, base = -10, base2 = 0, max = 0, formula = 100},
  {effect = 168, base = 10, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Melee Mitigation' and rows[1].min == '+10%' and rows[2].min == '-10%')

print('spell effects: ok')
