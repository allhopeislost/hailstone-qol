local options, functions, hooks = {}, {}, nil

package.preload.hailstone = function()
  return {
    option = function(option) options[option.name] = option end,
    ui_function = function(name, fn) functions[name] = fn end,
    hooks = function(value) hooks = value end,
    chat = function() end,
    spell = function() end,
    spawn = function() end,
  }
end
package.preload.mq = function()
  return {TLO = {Target = {ID = function() return nil end}}, pickle = function() end}
end
dofile('init.lua')

assert(hooks and hooks.nameplate)
assert(options.nameplate_level.get() == 1)
assert(functions.target_name and functions.spell_info and functions.item_info)
assert(options.target_level and options.spell_info)
assert(options.item_info.get() == 1)

local nameplate = hooks.nameplate
assert(nameplate({npc = true, level = 12}, 'a rat') == 'a rat [12]')
for _, spawn in ipairs({{}, {npc = false, level = 12}, {npc = true, corpse = true, level = 12},
    {npc = true, level = 0}, {npc = true, level = -1}, {npc = true}}) do
  assert(nameplate(spawn, 'unchanged') == nil)
end
assert(nameplate(nil, 'unchanged') == nil)
options.nameplate_level.set(0)
assert(nameplate({npc = true, level = 12}, 'a rat') == nil)
assert(options.target_level.get() == 1)
options.nameplate_level.set(1)
assert(nameplate({npc = true, level = 12}, 'a rat') == 'a rat [12]')

-- The class rides along with the level; each switch also works alone.
local rat = {npc = true, level = 12, class = 9}
assert(options.npc_class.get() == 1)
assert(nameplate(rat, 'a rat') == 'a rat [12 ROG]')
options.nameplate_level.set(0)
assert(nameplate(rat, 'a rat') == 'a rat [ROG]')
options.npc_class.set(0)
assert(nameplate(rat, 'a rat') == nil)
options.nameplate_level.set(1)
assert(nameplate(rat, 'a rat') == 'a rat [12]')
options.npc_class.set(1)

-- No class tag for non-player class ids, malformed ids or a missing field.
for _, case in ipairs({
    {{npc = true, level = 12, class = 41}, 'a rat [12]'},
    {{npc = true, level = 12, class = 'wizard'}, 'a rat [12]'},
    {{npc = true, level = 12, class = 1.5}, 'a rat [12]'},
    {{npc = true, level = 12, class = 0}, 'a rat [12]'},
    {{npc = true, class = 2}, 'a rat [CLR]'},
  }) do
  assert(nameplate(case[1], 'a rat') == case[2], case[2])
end

local Settings = require('settings')
local stored = Settings.new({pickle = function() end}, function() return nil end)
assert(stored.get('nameplate_level') == true and stored.get('item_info') == true,
  'all supported features default to enabled')
assert(stored.get('npc_class') == true)

-- Missing optional APIs on other clients must not prevent remaining helpers loading.
package.loaded.hailstone.hooks = nil
package.loaded.hailstone.option = nil
dofile('init.lua')
assert(functions.target_name('unchanged') == 'unchanged')

print('nameplate custom client contract: ok')
