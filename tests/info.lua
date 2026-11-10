local info = require('info')
assert(info.spell(nil) == nil and info.item(nil) == nil)
assert(info.spell_details(nil) == nil)

-- Partial records remain useful when optional custom-client data is absent.
local spell = {id = 7, name = 'Example', class_level = {255, 3}, timer_id = 4, cast_time = 1000,
  recovery_time = 1000, recast_time = 5000, mana = 80, target_type = 0, skill = 1, is_skill = false,
  gem_icon = 12}
local text = info.spell(spell)
assert(text:find('Spell ID: 7', 1, true))
assert(not text:find('Gem icon', 1, true))
assert(text:find('Recovery: 1.00s', 1, true))
assert(text:find('Recast: 5.00s', 1, true))
assert(text:find('CLR 3', 1, true))
assert(not text:find('SPA', 1, true))

-- Formatter aliases remain supported; these are not a spell-title lookup fallback.
local bookSpell = {id = 9, name = 'Book spell', icon = 42, level = 12, mana = 150, endurance = 0,
  castTime = 2000, recoveryTime = 500, recastTime = 4000, range = 100, aeRange = 25,
  duration = 3, beneficial = true, targetType = 1, skill = 2, skillName = 'Evocation'}
text = info.spell(bookSpell)
assert(text:find('Spell ID: 9', 1, true))
assert(not text:find('Icon: 42', 1, true))
assert(text:find('Level: 12', 1, true))
assert(text:find('Cast: 2.00s', 1, true))
assert(text:find('AE range: 25', 1, true))
assert(text:find('Skill: Evocation', 1, true))

-- eq.Item / hailstone.item fields actually available to Lua; optional fields can be absent.
local item = {id = 5, icon = 6, count = 2, charges = 4, stackSize = 20, stackable = true, bagSlots = 0,
  weight = 1.5, magic = true, lore = false, type = 10, size = 1, ac = 3, hp = 12, mana = 0}
text = info.item(item)
assert(text:find('Item ID: 5', 1, true))
assert(not text:find('Icon:', 1, true), 'the item window header already shows the icon')
assert(not text:find('Type:', 1, true), 'item type is not repeated in additional information')
assert(text:find('Stack: 2', 1, true))
assert(text:find('AC: 3', 1, true))
assert(text:find('Magic', 1, true))

local hailstoneItem = {id = 11, icon = 4, item_class = 3, req_level = 20, stack = 1, click_spell = 99}
text = info.item(hailstoneItem)
assert(text:find('Required level: 20', 1, true))
assert(text:find('Click spell ID: 99', 1, true))
assert(not text:find('Icon:', 1, true) and not text:find('Type:', 1, true))
assert(info.item({}) == nil)
assert(info.item({icon = 4, item_class = 3}) == nil, 'icon and type alone are not additional information')

-- Full supported custom-client spell record. Unsupported effects keep raw
-- SPA text; supported ones render readably. Cast messages are not shown.
text = info.spell({id = 321, spell_icon = 88, recovery_time = 250, recast_time = 6000,
  range = 200, ae_range = 35, push_back = -1.5, spell_type = 0, resist = 2, resist_adj = -25,
  class_level = {255, 12}, effects = {
    {effect = 0, base = -50, base2 = 0, max = 100, formula = 102}, {effect = 254},
  }, cast_on_you = 'You glow.', cast_on_other = 'glows.', wear_off = 'Your glow fades.'})
for _, fragment in ipairs({'Recovery: 0.25s', 'Recast: 6.00s', 'Range: 200',
    'AE range: 35', 'Pushback: -1.5', 'Resist type: 2', 'Modifier: -25', 'CLR 12',
    'HP -62 (level 12) to HP -100 (level 50)'}) do
  assert(text:find(fragment, 1, true), fragment)
end
assert(not text:find('Slot 2', 1, true))
assert(text:find('You glow', 1, true))
assert(text:find('Wears off', 1, true))
assert(not info.spell({spell_type = 1, resist = 2, resist_adj = 25}))

-- Supported buff stats render as readable scaling lines.
text = info.spell({id = 100, class_level = {255, 11}, effects = {
  {effect = 4, base = 15, base2 = 0, max = 45, formula = 101},
  {effect = 2, base = 5, base2 = 0, max = 0, formula = 100},
}})
assert(text:find('Strength +20 (level 11) to Strength +45 (level 60)', 1, true))
assert(text:find('Attack +5', 1, true))
assert(not text:find('SPA 4', 1, true))

-- Malformed effect slots fall back to raw rows instead of being dropped.
text = info.spell({id = 1, effects = {false, {effect = 1}}})
assert(text:find('Slot 1: SPA ?, base ?, base2 ?, max ?, formula ?', 1, true))
assert(text:find('Slot 2: Armor Class (SPA 1, base ?, base2 ?, max ?, formula ?)', 1, true))

-- Structured rows share the same data; details split rows from header.
local rows = info.spell_effects({class_level = {11}, effects = {
  {effect = 4, base = 15, base2 = 0, max = 45, formula = 101},
}})
assert(#rows == 1 and rows[1].name == 'Strength' and rows[1].max_level == 60)
local details = info.spell_details({id = 7, class_level = {3},
  effects = {{effect = 2, base = 5, base2 = 0, max = 0, formula = 100}}})
assert(details.metadata[1] == 'Spell ID: 7')
assert(#details.effects == 1 and details.effects[1].name == 'Attack')
assert(info.spell_effects(nil) ~= nil and #info.spell_effects(nil) == 0)

text = info.item({id = 123, icon = 44, value = 250, favor = 10, damage = 8, delay = 24,
  name = 'Sword', lore = 'An ancient blade'})
for _, fragment in ipairs({'Item ID: 123', 'Base value: 250 copper',
    'Tribute value: 10', 'Delay / damage: 3.000', 'Lore: An ancient blade'}) do
  assert(text:find(fragment, 1, true), fragment)
end
assert(not text:find('Icon:', 1, true) and not text:find('Type:', 1, true))
assert(info.item({name = 'Sword', lore = 'Sword', damage = 0, delay = 24}) == nil)
assert(info.item({lore = '', damage = 8, delay = 0}) == nil)
for _, bad in ipairs({false, 'bad', 42}) do
  assert(info.spell(bad) == nil and info.item(bad) == nil)
end
assert(info.spell({}) == nil)
assert(info.spell({id = math.huge, mana = 0/0, range = 'bad', resist_adj = math.huge}) == nil)
assert(info.item({value = math.huge, favor = 'bad', damage = false, lore = {}}) == nil)

print('info: ok')
