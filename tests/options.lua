local options, functions = {}, {}
local spawn, nameplate
local spellReads = 0
local failSave = false
local saved, warning
local spellData = {id = 7, name = 'Example', spell_icon = 90, class_level = {255, 12}, cast_time = 1000,
  recovery_time = 500, recast_time = 5000, mana = 80, gem_icon = 12, range = 200, ae_range = 35,
  push_back = 1.5, spell_type = 0, resist = 2, resist_adj = -25,
  effects = {{effect = 0, base = -50, base2 = 0, max = 100, formula = 102}},
  cast_on_you = 'You glow.', cast_on_other = 'glows.', wear_off = 'Your glow fades.'}

package.preload.hailstone = function()
  return {
    option = function(option) options[option.name] = option end,
    ui_function = function(name, fn) functions[name] = fn end,
    hooks = function(hooks) nameplate = assert(hooks.nameplate) end,
    chat = function(text, color) warning = {text, color} end,
    spawn = function() return spawn end,
    spell = function(id)
      spellReads = spellReads + 1
      assert(id == 7)
      return spellData
    end,
  }
end
package.preload.mq = function()
  return {
    TLO = {Target = {ID = function() return spawn and 10 end}},
    pickle = function(path, value)
      assert(path == 'qol.lua')
      if failSave then error('disk unavailable') end
      saved = value
    end,
  }
end
dofile('init.lua')

assert(options.target_level and options.spell_info)
assert(options.target_level.min == 0 and options.target_level.max == 1)
assert(options.spell_info.min == 0 and options.spell_info.max == 1)
assert(not options.nameplate_level and options.item_info and options.item_preview)
assert(options.target_level.label == 'Show target Levels')
assert(options.npc_class.label == 'Show target class')
assert(options.map_npcs.label == 'Show all NPCs on the map')
for _, option in pairs(options) do
  assert(option.min == 0 and option.max == 1)
  assert(option.get() == (option.name == 'item_preview' and 0 or 1))
end
assert(options.target_level.get() == 1 and options.spell_info.get() == 1)
assert(functions.target_name and functions.spell_info and functions.item_info)
assert(functions.spell_view)

options.target_level.set(0)
spawn = {npc = true, level = 12}
assert(functions.target_name('a rat') == 'a rat')
assert(nameplate(spawn, 'a rat') == nil)
options.target_level.set(1)
assert(functions.target_name('a rat') == 'a rat [12]')
assert(nameplate(spawn, 'a rat') == 'a rat [12]')

-- The target window adds the class with the same single switch as the nameplates.
spawn = {npc = true, level = 12, class = 2}
assert(functions.target_name('a rat') == 'a rat [12 CLR]')
options.target_level.set(0)
assert(functions.target_name('a rat') == 'a rat [CLR]')
options.npc_class.set(0)
assert(functions.target_name('a rat') == 'a rat')
options.target_level.set(1)
assert(functions.target_name('a rat') == 'a rat [12]')
options.npc_class.set(1)
spawn = {npc = true, level = 12}
assert(functions.target_name('a rat') == 'a rat [12]')
spawn = {npc = true, corpse = true, level = 12, class = 2}
assert(functions.target_name('a corpse') == 'a corpse')

options.spell_info.set(0)
assert(functions.spell_info(7) == nil and spellReads == 0)
assert(functions.spell_view(7) == nil and spellReads == 0)
options.spell_info.set(1)
local text = functions.spell_info(7)
assert(text:find('Spell ID: 7', 1, true) and spellReads == 1)
assert(not text:find('Icon', 1, true))
for _, fragment in ipairs({'Pushback: 1.5', 'Modifier: -25', 'CLR 12',
    'HP -62 (level 12)'}) do
  assert(text:find(fragment, 1, true), fragment)
end
assert(text:find('Cast on you', 1, true))
assert(text:find('Wears off', 1, true))

for _, invalid in ipairs({false, 0, -1, '7', {}, math.huge, 0/0}) do
  assert(functions.spell_info(invalid) == nil)
end
assert(functions.spell_info(nil) == nil and spellReads == 1)
local view = functions.spell_view(7)
assert(view and type(view.effects) == 'table' and view.metadata:find('Spell ID: 7', 1, true))
assert(not view.metadata:find('Cast on another:', 1, true))
assert(not view.metadata:find('Slot 1: SPA', 1, true))
spellReads = spellReads - 1
spellData = nil
assert(functions.spell_info(7) == nil and spellReads == 2)

local item = {id = 5, icon = 6, count = 2, charges = 0, weight = 1, magic = true, lore = false,
  type = 10, size = 1, ac = 3, hp = 12, mana = 0}
assert(functions.item_info(item):find('HP: 12', 1, true))
options.item_info.set(0)
assert(functions.item_info(item) == nil)
options.item_info.set(1)
assert(functions.item_info(item):find('HP: 12', 1, true))
assert(functions.item_info(nil) == nil)
assert(saved.nameplate_level and saved.item_info)

-- The experimental tier preview is opt-in: off by default, refused while
-- off, available once enabled.
assert(functions.preview_enabled and functions.preview_enabled() == false)
local denied = functions.request_item_preview(51907)
assert(denied.ok == false and denied.kind == 'disabled')
options.item_preview.set(1)
assert(options.item_preview.get() == 1 and functions.preview_enabled() == true)
options.item_preview.set(0)
assert(options.item_preview.get() == 0 and functions.preview_enabled() == false)

failSave = true
options.target_level.set(0)
assert(options.target_level.get() == 0)
assert(warning and warning[1]:find('disk unavailable', 1, true) and warning[2] == 15)

print('options: ok')
