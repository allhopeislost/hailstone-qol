local hs = require('hailstone')
local mq = require('mq')
local info = require('info')
local function reportSaveError(err)
  hs.chat('QoL: could not save settings: ' .. tostring(err), 15)
end
local settings = require('settings').new(mq, nil, reportSaveError)

local features = {
  {name = 'nameplate_level', label = 'NPC nameplate levels'},
  {name = 'target_level', label = 'Target levels'},
  {name = 'npc_class', label = 'NPC classes'},
  {name = 'spell_info', label = 'Additional spell information'},
  {name = 'item_info', label = 'Additional item information'},
  {name = 'map_target_line', label = 'Map target line'},
  {name = 'map_npcs', label = 'NPCs on the map'},
}

if hs.option then
  for _, feature in ipairs(features) do
    local name = feature.name
    hs.option{
      name = name,
      label = feature.label,
      min = 0,
      max = 1,
      get = function() return settings.get(name) and 1 or 0 end,
      set = function(value) settings.set(name, value == 1) end,
    }
  end
end

hs.ui_function('spell_info', function(id)
  if not settings.get('spell_info') then return nil end
  if type(id) ~= 'number' or id <= 0 or id ~= id or id == math.huge then return nil end
  return info.spell(hs.spell(id))
end)

-- The display gets structured effect rows as well as the existing text API.
hs.ui_function('spell_view', function(id)
  if not settings.get('spell_info') then return nil end
  if type(id) ~= 'number' or id <= 0 or id ~= id or id == math.huge then return nil end
  local spell = hs.spell(id)
  if type(spell) ~= 'table' then return nil end
  local details = info.spell_details(spell, function(spellId)
    local other = hs.spell(spellId)
    return type(other) == 'table' and other.name or nil
  end)
  return {effects = details.effects, metadata = table.concat(details.metadata, '\n')}
end)

-- Plain map coordinates only: no spawn scan, movement command or persistent target cache.
hs.ui_function('map_target', function()
  if not settings.get('map_target_line') then return nil end
  if type(hs.player) ~= 'function' or type(hs.spawn) ~= 'function' then return nil end
  local player = hs.player()
  if not player or player.in_zone == false then return nil end
  local id = player.target_id
  if type(id) ~= 'number' or id <= 0 or id ~= id or id == math.huge
      or id % 1 ~= 0 or id == player.spawn_id then return nil end
  local target = hs.spawn(id)
  if not target then return nil end
  local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
  end
  if not finite(target.x) or not finite(target.y) then return nil end
  -- Hailstone world axes differ from /loc and from map-file axes.
  return {x = -target.y, y = -target.x}
end)

-- A living NPC's class short name, or nil when the client sends no playable class id.
local function className(spawn)
  local id = spawn and spawn.class
  if type(id) == 'number' and id % 1 == 0 then return info.classes[id] end
end

-- The nameplate/target suffix: "[12]", "[WAR]" or "[12 WAR]", and "" when neither shows.
local function detail(spawn, level, class)
  local parts = {}
  if level and type(spawn.level) == 'number' and spawn.level > 0 then
    parts[#parts + 1] = tostring(spawn.level)
  end
  local name = class and className(spawn)
  if name then parts[#parts + 1] = name end
  if #parts == 0 then return '' end
  return ' [' .. table.concat(parts, ' ') .. ']'
end

-- Supported custom clients supply nameplate text and map spawn data to these hooks.
if hs.hooks then
  hs.hooks{
    nameplate = function(spawn, text)
      if not spawn or not spawn.npc or spawn.corpse or type(text) ~= 'string' then return nil end
      local suffix = detail(spawn, settings.get('nameplate_level'), settings.get('npc_class'))
      if suffix == '' then return nil end
      return text .. suffix
    end,
    -- The client asks about every spawn it does not draw itself; only living NPCs get a mark.
    map_spawn = function(spawn)
      if not settings.get('map_npcs') then return nil end
      if not spawn or not spawn.npc or spawn.corpse then return nil end
      local name = spawn.name
      if type(name) == 'string' and name:lower():find("'s corpse$") then return nil end
      return true
    end,
  }
end
hs.ui_function('item_info', function(item)
  if not settings.get('item_info') then return nil end
  return info.item(item)
end)

-- Experimental read-only tier preview. The UI asks for exactly one item id per click; this function only
-- checks that the request is well formed and that this really is Project Triune, then asks the client for
-- that item's native display. It does not wait for, find, or alter the response window.
local function projectTriune(server)
  if type(server) ~= 'table' then return false end
  for _, key in ipairs({'world', 'name'}) do
    local value = server[key]
    if type(value) == 'string' then
      local id = value:match('^%s*(.-)%s*$'):lower()
      -- The saved profile folder is project-triune; the server's display name is Project Triune.
      if id == 'project triune' or id == 'project-triune' then return true end
    end
  end
  return false
end

hs.ui_function('request_item_preview', function(itemId)
  if type(itemId) ~= 'number' or itemId ~= itemId or itemId == math.huge or itemId == -math.huge
      or itemId % 1 ~= 0 or itemId < 1 or itemId > 4294967295 then
    return {ok = false, kind = 'invalid_id', error = 'Invalid item id for a preview request.'}
  end
  if type(hs.server) ~= 'function' then
    return {ok = false, kind = 'server',
      error = 'Cannot confirm Project Triune: hs.server is unavailable in this client.'}
  end
  local read, server = pcall(hs.server)
  if not read then
    return {ok = false, kind = 'server',
      error = 'Cannot confirm Project Triune: hs.server failed: ' .. tostring(server)}
  end
  if type(server) ~= 'table' then
    return {ok = false, kind = 'server',
      error = 'Cannot confirm Project Triune: no server identity (not logged into a world?).'}
  end
  if not projectTriune(server) then
    local name = server.world or server.name or server.host or 'unknown'
    return {ok = false, kind = 'server',
      error = "This tier preview is a Project Triune experiment; current server '" .. tostring(name)
        .. "' is not recognized."}
  end
  if type(hs.inspect_item) ~= 'function' then
    return {ok = false, kind = 'missing_api',
      error = 'hs.inspect_item is unavailable in this client, so no preview can be requested.'}
  end
  local sent, err = pcall(hs.inspect_item, itemId)
  if not sent then
    return {ok = false, kind = 'refused', error = 'The preview request was refused: ' .. tostring(err)}
  end
  return {ok = true, id = itemId}
end)

hs.ui_function('target_name', function(name)
  local showLevel, showClass = settings.get('target_level'), settings.get('npc_class')
  if (not showLevel and not showClass) or type(name) ~= 'string' then return name end
  local id = mq.TLO.Target.ID()
  local spawn = id and hs.spawn(id)
  if not spawn or not spawn.npc or spawn.corpse then return name end
  return name .. detail(spawn, showLevel, showClass)
end)
