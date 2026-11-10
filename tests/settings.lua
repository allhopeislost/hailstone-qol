local Settings = require('settings')

local saved
local failSave = false
local mq = {
  pickle = function(path, value)
    assert(path == 'qol.lua')
    if failSave then error('disk unavailable') end
    saved = value
  end,
}
local function readSaved()
  return saved
end

local settings = Settings.new(mq, function() return nil end)
for _, name in ipairs({'nameplate_level', 'target_level', 'npc_class', 'spell_info', 'item_info', 'map_target_line', 'map_npcs'}) do
  assert(settings.get(name) == true)
end
assert(settings.get('item_preview') == false, 'the experimental tier preview defaults to off')

assert(settings.set('target_level', false))
assert(saved.version == 1 and saved.target_level == false)
assert(saved.nameplate_level and saved.npc_class and saved.spell_info and saved.item_info
  and saved.map_target_line and saved.map_npcs)
settings = Settings.new(mq, readSaved)
assert(settings.get('target_level') == false and settings.get('spell_info') == true)
assert(settings.get('map_target_line') == true and settings.get('map_npcs') == true)

settings = Settings.new(mq, function()
  return {version = 1, nameplate_level = false, item_info = false}
end)
assert(settings.get('nameplate_level') == false and settings.get('item_info') == false)
assert(settings.get('map_target_line') == true, 'missing map_target_line key defaults to on')
assert(settings.get('map_npcs') == true, 'missing map_npcs key defaults to on')
assert(settings.get('npc_class') == true, 'missing npc_class key defaults to on')
assert(settings.set('target_level', false))
assert(saved.nameplate_level == false and saved.item_info == false)
assert(saved.map_target_line == true and saved.map_npcs == true)

settings = Settings.new(mq, function()
  return {version = 1, map_target_line = false, map_npcs = false}
end)
assert(settings.get('map_target_line') == false, 'explicit map_target_line=false is honored')
assert(settings.get('map_npcs') == false, 'explicit map_npcs=false is honored')
assert(settings.get('nameplate_level') == true and settings.get('target_level') == true)
assert(settings.get('spell_info') == true and settings.get('item_info') == true)

settings = Settings.new(mq, function() return nil end)
assert(settings.set('map_target_line', false))
assert(saved.map_target_line == false and saved.version == 1)
settings = Settings.new(mq, readSaved)
assert(settings.get('map_target_line') == false, 'map_target_line=false persists')
assert(settings.set('map_target_line', true))
assert(saved.map_target_line == true)
settings = Settings.new(mq, readSaved)
assert(settings.get('map_target_line') == true)

settings = Settings.new(mq, function() return nil end)
assert(settings.set('map_npcs', false))
assert(saved.map_npcs == false and saved.version == 1)
settings = Settings.new(mq, readSaved)
assert(settings.get('map_npcs') == false, 'map_npcs=false persists')
assert(settings.set('map_npcs', true))
assert(saved.map_npcs == true)
settings = Settings.new(mq, readSaved)
assert(settings.get('map_npcs') == true)

settings = Settings.new(mq, function() return nil end)
assert(settings.set('npc_class', false))
assert(saved.npc_class == false and saved.version == 1)
settings = Settings.new(mq, readSaved)
assert(settings.get('npc_class') == false, 'npc_class=false persists')
assert(settings.set('npc_class', true))
assert(saved.npc_class == true)
settings = Settings.new(mq, readSaved)
assert(settings.get('npc_class') == true)

settings = Settings.new(mq, function() return nil end)
assert(settings.set('item_preview', true))
assert(saved.item_preview == true and saved.version == 1)
settings = Settings.new(mq, readSaved)
assert(settings.get('item_preview') == true, 'item_preview=true persists')
assert(settings.set('item_preview', false))
assert(saved.item_preview == false)
settings = Settings.new(mq, readSaved)
assert(settings.get('item_preview') == false)

settings = Settings.new(mq, function() return 'not a settings table' end)
assert(settings.get('target_level') == true)
settings = Settings.new(mq, function() return {version = 99, target_level = false} end)
assert(settings.get('target_level') == true)
settings = Settings.new(mq, function()
  return {version = 1, target_level = false, spell_info = 'false', item_info = 0, map_target_line = 0,
    map_npcs = 'false'}
end)
assert(settings.get('target_level') == false)
assert(settings.get('spell_info') == true and settings.get('item_info') == true)
assert(settings.get('map_target_line') == true and settings.get('map_npcs') == true)
assert(settings.get('item_preview') == false, 'a missing item_preview key defaults to off')
settings = Settings.new(mq, function() error('bad config') end)
assert(settings.get('nameplate_level') == true)

local reported
settings = Settings.new(mq, function() return nil end, function(err) reported = err end)
failSave = true
assert(not settings.set('nameplate_level', false))
assert(settings.get('nameplate_level') == false)
assert(reported:find('disk unavailable', 1, true))
failSave = false

print('settings: ok')
