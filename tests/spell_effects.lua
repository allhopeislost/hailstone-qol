local fx = require('core.spell_effects')
local info = require('core.info')

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

-- No class level: the level is not guessed, but the row shows the level 1 value and the rate (D058);
-- a fixed slot still formats as before.
rows = fx.rows({effects = {
  {effect = 4, base = 10, base2 = 0, max = 0, formula = 101},
  {effect = 2, base = 5, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Strength' and rows[1].min == '+10' and rows[1].min_level == nil)
assert(rows[1].scale == '+1 per 2 levels' and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Strength +10, +1 per 2 levels')
assert(rows[2].min == '+5' and rows[2].is_raw == false)

-- Steal Strength (spell 944): a proc spell with no class levels. base -15, +1 per 4 levels, cap 27, so the
-- row reads -15 at level 1 up to -27 at level 48 instead of a raw SPA line (D058).
rows = fx.rows({effects = {
  {effect = 4, base = -15, base2 = 0, max = 27, formula = 109},
}})
assert(rows[1].name == 'Strength' and rows[1].min == '-15' and rows[1].min_level == nil)
assert(rows[1].max == '-27' and rows[1].max_level == 48)
assert(rows[1].note == '-1 per 4 levels' and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Strength -15 to Strength -27 (level 48), -1 per 4 levels')

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

-- An SPA without a kind gets a shape from its name; flags show their name only; HP is per tick for a buff.
rows = fx.rows({class_level = {10}, duration_cap = 10, effects = {
  {effect = 31, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 12, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 0, base = 20, base2 = 0, max = 0, formula = 100},
  {effect = 3, base = 30, base2 = 0, max = 0, formula = 100},
  {effect = 4, base = 5, base2 = 0, max = 0, formula = 1005},
}})
assert(rows[1].name == 'Mez' and rows[1].min == '' and not rows[1].is_raw)
assert(rows[2].name == 'Invisibility' and fx.format(rows[2]) == 'Invisibility')
assert(rows[3].name == 'HP per tick' and rows[3].min == '+20')
assert(rows[4].name == 'Movement Speed' and rows[4].min == '+30%')
assert(rows[5].is_raw, 'tick based formulas are not shown')

-- Shape rule (D048): every named SPA gets a normal row. SPA 20 Blind is a flag (name only); SPA 58 Illusion is an
-- id (base is a race id); SPA 120 Heal Rate is a percentage; SPA 24 Stamina is a number.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 20, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 58, base = 130, base2 = 0, max = 0, formula = 100},
  {effect = 120, base = 10, base2 = 0, max = 0, formula = 100},
  {effect = 24, base = 5, base2 = 0, max = 0, formula = 100},
}})
assert(#rows == 4)
assert(rows[1].name == 'Blind' and rows[1].min == '' and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Blind')
assert(rows[2].name == 'Illusion' and rows[2].min == '#130' and not rows[2].is_raw)
assert(fx.format(rows[2]) == 'Illusion #130')
assert(rows[3].name == 'Heal Rate' and rows[3].min == '+10%' and not rows[3].is_raw)
assert(fx.format(rows[3]) == 'Heal Rate +10%')
assert(rows[4].name == 'Stamina' and rows[4].min == '+5' and not rows[4].is_raw)
assert(fx.format(rows[4]) == 'Stamina +5')

-- The rule does not show base2; the base2 guard is only for curated kinds.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 24, base = 10, base2 = 5, max = 0, formula = 100},
}})
assert(rows[1].name == 'Stamina' and rows[1].min == '+10' and not rows[1].is_raw)

-- A scaling rule-derived slot shows its value at the class level; without one it shows the level 1 value and the
-- rate (D058).
rows = fx.rows({class_level = {20}, effects = {
  {effect = 24, base = 10, base2 = 0, max = 0, formula = 101},
}})
assert(rows[1].name == 'Stamina' and rows[1].min == '+20' and rows[1].min_level == 20)
assert(rows[1].max == nil and rows[1].scale == '+1 per 2 levels' and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Stamina +20 (level 20), +1 per 2 levels')
rows = fx.rows({effects = {
  {effect = 24, base = 10, base2 = 0, max = 0, formula = 101},
}})
assert(rows[1].name == 'Stamina' and rows[1].min == '+10' and rows[1].min_level == nil)
assert(rows[1].scale == '+1 per 2 levels' and not rows[1].is_raw)

-- An SPA with no name in the generated table stays raw.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 9999, base = 1, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].is_raw and rows[1].min:find('SPA 9999', 1, true))

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

-- An uncapped AC shows its value at the spell's level; its converted/rounded growth cannot be described using
-- the raw growth rate, so the scale note stays generic.
rows = fx.rows({class_level = {10}, effects = {
  {effect = 1, base = 25, base2 = 0, max = 0, formula = 101},
  {effect = 4, base = 1, base2 = 0, max = 1000, formula = 101},
}})
assert(rows[1].name == 'Armor Class' and not rows[1].is_raw)
assert(rows[1].min == '+9' and rows[1].min_level == 10)
assert(rows[1].max == nil and rows[1].scale == 'scales with level')
assert(fx.format(rows[1]) == 'Armor Class +9 (level 10), scales with level')
-- A cap the highest level never reaches is shown without a level.
assert(rows[2].max == '+1000' and rows[2].max_level == nil and rows[2].min == '+6')
-- The charisma spacer (base 0/1) is not a row.
assert(#fx.rows({class_level = {10}, effects = {{effect = 10, base = 1, base2 = 0, max = 0, formula = 100}}}) == 0)

-- Feral Spirit (spell 139) slot 6: an uncapped AC at class level 18 is a normal row, not a raw line.
rows = fx.rows({id = 139, class_level = {18}, effects = {
  {effect = 1, base = 15, base2 = 0, max = 0, formula = 101},
}})
assert(#rows == 1 and rows[1].name == 'Armor Class' and not rows[1].is_raw)
assert(rows[1].min == '+7' and rows[1].min_level == 18)
assert(rows[1].max == nil and rows[1].scale == 'scales with level')
assert(fx.format(rows[1]) == 'Armor Class +7 (level 18), scales with level')

-- Inferno Shield: damage shield (SPA 59, formula 109) and fire resist (SPA 46).
rows = fx.rows({class_level = {255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 28}, effects = {
  {effect = 59, base = -6, base2 = 0, max = 15, formula = 109},
  {effect = 46, base = 20, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Damage Shield' and rows[1].min == '13' and rows[1].min_level == 28)
assert(rows[1].max == '15' and rows[1].max_level == 36 and not rows[1].is_raw)
assert(rows[2].name == 'Fire Resist' and rows[2].min == '+20' and not rows[2].is_raw)

-- A damage shield is stored negative but shown as a positive amount, so its rate is positive too (D058).
rows = fx.rows({effects = {
  {effect = 59, base = -6, base2 = 0, max = 0, formula = 109},
}})
assert(rows[1].name == 'Damage Shield' and rows[1].min == '6' and rows[1].min_level == nil)
assert(rows[1].scale == '+1 per 4 levels' and not rows[1].is_raw)
rows = fx.rows({class_level = {28}, effects = {
  {effect = 59, base = -6, base2 = 0, max = 0, formula = 109},
}})
assert(rows[1].min == '13' and rows[1].min_level == 28 and rows[1].scale == '+1 per 4 levels')
rows = fx.rows({effects = {
  {effect = 59, base = -6, base2 = 0, max = 15, formula = 109},
}})
assert(rows[1].min == '6' and rows[1].max == '15' and rows[1].max_level == 36)
assert(rows[1].note == '+1 per 4 levels' and not rows[1].is_raw)

-- Rune I: base is the amount absorbed, max the cap, formula 111 (+6 per level above 16).
rows = fx.rows({class_level = {13}, effects = {
  {effect = 55, base = 35, base2 = 0, max = 65, formula = 111},
}})
assert(rows[1].name == 'Rune' and not rows[1].is_raw)
assert(rows[1].min == '35' and rows[1].min_level == 13)
assert(rows[1].max == '65' and rows[1].max_level == 21)
assert(fx.format(rows[1]) == 'Rune 35 (level 13) to Rune 65 (level 21)')
-- An uncapped rune scales without a made-up cap.
rows = fx.rows({class_level = {13}, effects = {
  {effect = 55, base = 35, base2 = 0, max = 0, formula = 111},
}})
assert(rows[1].min == '35' and rows[1].max == nil and rows[1].scale == 'scales with level')

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

-- Allure of Death (NEC 18) slot 3: Casting Level (SPA 112) is a signed number. The client names it but never
-- applies it, so the name and base are all there is; SPA 272 has the same name and gets the same number row.
rows = fx.rows({class_level = {255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 18},
  effects = {{effect = 112, base = 2, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].name == 'Casting Level' and not rows[1].is_raw)
assert(rows[1].min == '+2')
assert(fx.format(rows[1]) == 'Casting Level +2')
-- SPA 272 carries the same client name; the shape rule shows it as a number too (the name is all the client gives).
rows = fx.rows({class_level = {18}, effects = {{effect = 272, base = 2, base2 = 0, max = 0, formula = 100}}})
assert(rows[1].name == 'Casting Level2' and rows[1].min == '+2' and not rows[1].is_raw)

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

-- A proc row also says what the fired spell does when the lookup gives a summary.
rows = fx.rows(procSpell, function(id)
  return id == 2722 and {name = 'Inferno Strike', summary = '45 fire damage'} or nil
end)
assert(rows[1].min == 'Inferno Strike: 45 fire damage')
assert(fx.format(rows[1]) == 'Weapon Proc Inferno Strike: 45 fire damage, proc rate +150%')

-- A one-line summary: direct damage with the resist type, otherwise the first one or two effect rows.
local strike = {name = 'Prismatic Strike II', resist = 2, class_level = {20}, effects = {
  {effect = 0, base = -45, base2 = 0, max = 0, formula = 100},
}}
assert(fx.summary(strike) == '45 fire damage')
assert(fx.summary({class_level = {20}, resist = 0, effects = {
  {effect = 0, base = -45, base2 = 0, max = 0, formula = 100},
}}) == '45 damage', 'an unresistable spell has no resist name')
assert(fx.summary({class_level = {20}, resist = 42, effects = {
  {effect = 0, base = -45, base2 = 0, max = 0, formula = 100},
}}) == '45 damage', 'an unknown resist has no name')
assert(fx.summary({class_level = {20}, effects = {
  {effect = 4, base = 15, base2 = 0, max = 0, formula = 100},
  {effect = 2, base = 5, base2 = 0, max = 0, formula = 100},
  {effect = 1, base = 25, base2 = 0, max = 0, formula = 100},
}}) == 'Strength +15, Attack +5', 'no damage: the first two effect rows')
assert(fx.summary({class_level = {20}, effects = {
  {effect = 4, base = 15, base2 = 0, max = 0, formula = 100},
}}) == 'Strength +15')
assert(fx.summary(nil) == nil and fx.summary({}) == nil)
assert(fx.summary({class_level = {20}, effects = {
  {effect = 254, base = 0, base2 = 0, max = 0, formula = 100},
}}) == nil, 'nothing to say')

-- The trigger row shows the name and the summary; a plain string lookup keeps the old contract.
local trigger = {class_level = {1}, effects = {
  {effect = 339, base = 100, base2 = 25543, max = 0, formula = 100},
}}
rows = fx.rows(trigger, function(id)
  return id == 25543 and {name = 'Prismatic Strike II', summary = fx.summary(strike)} or nil
end)
assert(rows[1].name == 'Trigger on Cast' and rows[1].min == '100%')
assert(rows[1].note == 'Prismatic Strike II: 45 fire damage')
assert(fx.format(rows[1]) == 'Trigger on Cast 100%, Prismatic Strike II: 45 fire damage')
rows = fx.rows(trigger, function(id)
  return id == 25543 and {name = 'Prismatic Strike II', summary = fx.summary({class_level = {20}, effects = {
    {effect = 4, base = 15, base2 = 0, max = 0, formula = 100},
  }})} or nil
end)
assert(rows[1].note == 'Prismatic Strike II: Strength +15', 'no damage: the first effect row')
rows = fx.rows(trigger, function(id) return id == 25543 and 'Prismatic Strike II' or nil end)
assert(rows[1].note == 'Prismatic Strike II', 'a plain string lookup keeps the old contract')
rows = fx.rows(trigger, function() return nil end)
assert(rows[1].note == '#25543', 'nothing found: the id')

-- The Limit: Spell phrase uses the name only, never the summary.
rows = fx.rows({class_level = {1}, effects = {
  {effect = 139, base = 25543, base2 = 0, max = 0, formula = 100},
}}, function(id)
  return id == 25543 and {name = 'Prismatic Strike II', summary = '45 fire damage'} or nil
end)
assert(rows[1].is_limit and rows[1].min == 'spell Prismatic Strike II')

-- Melee Mitigation is stored negative for an improvement and shown with the sign turned round.
rows = fx.rows({class_level = {28}, effects = {
  {effect = 168, base = -10, base2 = 0, max = 0, formula = 100},
  {effect = 168, base = 10, base2 = 0, max = 0, formula = 100},
}})
assert(rows[1].name == 'Melee Mitigation' and rows[1].min == '+10%' and rows[2].min == '-10%')

-- Focus spells: one row for the modifier, one muted row that joins every limit.
local focus = {id = 1, class_level = {255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255},
  effects = {
    {effect = 141, base = 1, base2 = 0, max = 0, formula = 100},   -- Limit Instant
    {effect = 138, base = 0, base2 = 0, max = 0, formula = 100},   -- Limit Spell Type
    {effect = 348, base = 1, base2 = 0, max = 0, formula = 100},   -- Limit Mana Min
    {effect = 142, base = 1, base2 = 0, max = 0, formula = 100},   -- Limit Min Level
    {effect = 311, base = 0, base2 = 0, max = 0, formula = 100},   -- Limit Combat Skills
    {effect = 137, base = 0, base2 = 0, max = 0, formula = 100},   -- Limit Effect
    {effect = 339, base = 100, base2 = 25543, max = 0, formula = 100}, -- Trigger On Cast
  }}
rows = fx.rows(focus, function(id) return id == 25543 and 'Arcane Echo' or nil end)
assert(#rows == 2, 'one focus row and one limits row')
assert(rows[1].name == 'Trigger on Cast' and rows[1].min == '100%' and rows[1].note == 'Arcane Echo')
assert(rows[1].is_focus and not rows[1].is_raw)
assert(rows[2].name == 'Limits' and rows[2].is_limit and not rows[2].is_raw)
assert(rows[2].min == 'instant, detrimental, mana >= 1, level >= 1, no combat skills, HP effect')
assert(fx.format(rows[2]) == 'Limits: instant, detrimental, mana >= 1, level >= 1, no combat skills, HP effect')
for _, row in ipairs(rows) do assert(not row.is_raw) end

-- A focus modifier without limits has no Limits row.
rows = fx.rows({class_level = {1}, effects = {{effect = 124, base = 25, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].name == 'Spell Damage' and rows[1].min == '+25%')
assert(rows[1].is_focus and not rows[1].is_limit and not rows[1].is_raw)
assert(fx.format(rows[1]) == 'Spell Damage +25%')

-- A limit SPA with a curated phrase joins the Limits row; its base is a condition value (a class id, a spell id, a
-- bitmask), never an amount, so it must not appear as a +N effect row.
rows = fx.rows({class_level = {1}, effects = {{effect = 403, base = 1, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].name == 'Limits' and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'spell class 1')

-- 403/404 mirror the client's match_or_exclude (0x193/0x194): a negative base is the exclusion.
rows = fx.rows({class_level = {1}, effects = {{effect = 403, base = -3, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'not spell class 3')
rows = fx.rows({class_level = {1}, effects = {{effect = 404, base = -3, base2 = 0, max = 0, formula = 100}}})
assert(rows[1].min == 'not spell subclass 3')

-- 411/412 are bitmasks in the client (0x19b/0x19c), so they are shown as a mask, not as a class or race id.
rows = fx.rows({class_level = {1}, effects = {{effect = 411, base = 2, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and rows[1].min == 'class mask 0x2')
rows = fx.rows({class_level = {1}, effects = {{effect = 412, base = 4, base2 = 0, max = 0, formula = 100}}})
assert(rows[1].min == 'race mask 0x4')
-- The mask is unsigned: bit 31 is a real bit, not a sign to strip.
rows = fx.rows({class_level = {1}, effects = {{effect = 412, base = -2147483645, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'race mask 0x80000003')

-- 137 with an unknown effect id keeps its condition: no name, but still "no effect N" (0x89: base >= 0 includes).
rows = fx.rows({class_level = {1}, effects = {{effect = 137, base = -12345, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'no effect 12345')

-- A named limit SPA outside the client switch (408 Limit HP Percent) joins the Limits row in short form.
rows = fx.rows({class_level = {1}, effects = {{effect = 408, base = 50, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'hp percent 50')

-- 415: -1 in base or base2 is "any" (0x19f), so it must not read as an item class id.
rows = fx.rows({class_level = {1}, effects = {{effect = 415, base = -1, base2 = -1, max = 0, formula = 100}}})
assert(rows[1].min == 'any item class')
rows = fx.rows({class_level = {1}, effects = {{effect = 415, base = 2, base2 = 5, max = 0, formula = 100}}})
assert(rows[1].min == 'item class 2, subclass 5')

-- The screenshot case (Improved Damage I): every limit joins one Limits row, including target types the client does
-- not name, so no slot falls back to a raw line.
rows = fx.rows({id = 2336, class_level = {1}, effects = {
  {effect = 124, base = 50, base2 = 0, max = 0, formula = 100},
  {effect = 134, base = 20, base2 = 5, max = 0, formula = 100},
  {effect = 141, base = 1, base2 = 0, max = 0, formula = 100},
  {effect = 138, base = 0, base2 = 0, max = 0, formula = 100},
  {effect = 311, base = 0, base2 = 0, max = 0, formula = 100},
  {effect = 136, base = -17, base2 = 0, max = 0, formula = 100},
  {effect = 136, base = -18, base2 = 0, max = 0, formula = 100},
}})
assert(#rows == 2, 'one focus row and one limits row')
assert(rows[1].name == 'Spell Damage' and rows[1].min == '+50%')
assert(rows[2].name == 'Limits' and rows[2].is_limit)
assert(rows[2].min == 'level <= 20 (-5% per level over), instant, detrimental, no combat skills, '
  .. 'target not giant, target not dragon')
for _, row in ipairs(rows) do assert(not row.is_raw) end

-- An unknown target type is still a condition: shown by number, with the sign kept, not as a raw SPA dump.
rows = fx.rows({class_level = {1}, effects = {{effect = 136, base = -20, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_limit and not rows[1].is_raw)
assert(rows[1].min == 'target not type 20')

-- A limit SPA with no generated name keeps the raw line (D048).
rows = fx.rows({class_level = {1}, effects = {{effect = 9999, base = 1, base2 = 0, max = 0, formula = 100}}})
assert(#rows == 1 and rows[1].is_raw and rows[1].min:find('SPA 9999', 1, true))

-- Damage per mana uses the spell's own direct damage: SPA 0 (HP) and SPA 79 (Instant HP) with a negative base.
assert(fx.damage(nil) == nil and fx.damage({}) == nil)
-- Direct damage: |base| + change(formula, level), capped at |max|.
assert(fx.damage({class_level = {20}, effects = {
  {effect = 0, base = -50, base2 = 0, max = 100, formula = 102},
}}) == 70)
-- A DoT's SPA 0 is per tick: per-tick x duration_cap ticks.
assert(fx.damage({class_level = {20}, duration_cap = 5, effects = {
  {effect = 0, base = -10, base2 = 0, max = 0, formula = 100},
}}) == 50)
-- SPA 79 is always instant, even with a duration.
assert(fx.damage({class_level = {20}, duration_cap = 5, effects = {
  {effect = 79, base = -30, base2 = 0, max = 0, formula = 100},
}}) == 30)
-- Every damage slot is summed.
assert(fx.damage({class_level = {20}, effects = {
  {effect = 0, base = -50, base2 = 0, max = 100, formula = 102},
  {effect = 79, base = -30, base2 = 0, max = 0, formula = 100},
}}) == 100)
-- A heal is not damage; a scaling damage slot without a class level is not guessed.
assert(fx.damage({class_level = {20}, effects = {
  {effect = 100, base = 10, base2 = 0, max = 0, formula = 100},
}}) == nil)
assert(fx.damage({effects = {
  {effect = 0, base = -50, base2 = 0, max = 100, formula = 102},
}}) == nil)

print('spell effects: ok')
