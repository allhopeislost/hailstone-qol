local options, hooks = {}, nil

package.preload.hailstone = function()
  return {
    option = function(option) options[option.name] = option end,
    ui_function = function() end,
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

assert(hooks and hooks.map_spawn, 'map_spawn hook is registered')
assert(options.map_npcs and options.map_npcs.min == 0 and options.map_npcs.max == 1)
assert(options.map_npcs.get() == 1, 'NPCs on the map are enabled by default')

local map = hooks.map_spawn
assert(map({npc = true, name = 'a rat'}) == true)
assert(map({npc = true, level = 12}) == true)
for _, spawn in ipairs({{}, {npc = false, name = 'A_player'}, {npc = true, corpse = true, name = 'a rat'},
    {npc = true, name = "a rat's corpse"}, {npc = true, name = "a rat's corpse", corpse = true}}) do
  assert(map(spawn) == nil)
end
assert(map(nil) == nil)

options.map_npcs.set(0)
assert(map({npc = true, name = 'a rat'}) == nil)
options.map_npcs.set(1)
assert(map({npc = true, name = 'a rat'}) == true)

print('map npcs: ok')
