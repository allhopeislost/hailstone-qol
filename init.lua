local hs = require('hailstone')
local mq = require('mq')
local info = require('core.info')
local function reportSaveError(err)
  hs.chat('QoL: could not save settings: ' .. tostring(err), 15)
end
local settings = require('core.settings').new(mq, nil, reportSaveError)

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function positiveInteger(value)
  return finite(value) and value >= 1 and value % 1 == 0
end

local features = {
  {name = 'target_level', label = 'Show target levels'},
  {name = 'npc_class', label = 'Show target class'},
  {name = 'spell_info', label = 'Additional spell information'},
  {name = 'item_info', label = 'Additional item information'},
  {name = 'item_preview', label = 'Item version windows'},
  {name = 'map_target_line', label = 'Target line on map and minimap'},
  {name = 'map_npcs', label = 'Show all NPCs on the map'},
  {name = 'findwalk', label = 'Find window (/findW)'},
  {name = 'named_tracker', label = 'Named tracker (/named)'},
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
  if not finite(id) or id <= 0 then return nil end
  return info.spell(hs.spell(id))
end)

-- The display gets structured effect rows as well as the existing text API.
hs.ui_function('spell_view', function(id)
  if not settings.get('spell_info') then return nil end
  if not finite(id) or id <= 0 then return nil end
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
  if not positiveInteger(id) or id == player.spawn_id then return nil end
  local target = hs.spawn(id)
  if not target then return nil end
  if not finite(target.x) or not finite(target.y) then return nil end
  -- Hailstone world axes differ from /loc and from map-file axes.
  local point = {x = -target.y, y = -target.x}
  -- The minimap is centred on the player and only knows offsets, so it also needs the player's own point.
  local me = positiveInteger(player.spawn_id) and hs.spawn(player.spawn_id)
  if me and finite(me.x) and finite(me.y) then point.px, point.py = -me.y, -me.x end
  return point
end)

-- FindWalk (ui/modern/findwalk.lua). The window is a separate script: it asks for its state and its rows here, so the
-- spawn list, filtering and sorting stay in core/findwalk.lua and only the visible rows cross over.
local find = require('core.findwalk')
local findWalkState = {open = false, search = '', serial = 0}

local function toggleFindWalk(...)
  if not settings.get('findwalk') then
    findWalkState.open = false
    if type(hs.chat) == 'function' then
      pcall(hs.chat, 'QoL: the Find window is turned off; enable it under Options \xE2\x86\x92 Plugins.', 15)
    end
    return
  end
  local text = table.concat({...}, ' '):match('^%s*(.-)%s*$')
  if text ~= '' then
    findWalkState.open, findWalkState.search = true, text:sub(1, find.MAX_TEXT)
    findWalkState.serial = findWalkState.serial + 1
  else
    findWalkState.open = not findWalkState.open
  end
end

-- The command opens (or closes) the window, `/findW gnoll` opens it with that search. The menu entry is the same.
if type(mq.bind) == 'function' then pcall(mq.bind, '/findW', toggleFindWalk) end
if type(hs.menu) == 'function' then pcall(hs.menu, 'Find', '/findW') end

hs.ui_function('findwalk_state', function()
  -- turning the option off closes the window on its next frame
  if not settings.get('findwalk') then findWalkState.open = false end
  return {open = findWalkState.open, search = findWalkState.search, serial = findWalkState.serial}
end)

hs.ui_function('findwalk_close', function() findWalkState.open = false end)

hs.ui_function('findwalk_rows', function(query)
  if not settings.get('findwalk') then return nil end
  if type(hs.spawns) ~= 'function' or type(hs.player) ~= 'function' then return nil end
  local player = hs.player()
  if type(player) ~= 'table' or player.in_zone == false then return {rows = {}, total = 0, has_role = false} end
  local me = positiveInteger(player.spawn_id) and type(hs.spawn) == 'function' and hs.spawn(player.spawn_id)
  if type(me) == 'table' then me.id = player.spawn_id else me = nil end
  local rows, total = find.rows(hs.spawns(), me, query)
  return {rows = find.plain(rows), total = total, has_role = find.hasRole(rows)}
end)

-- Target the spawn, then walk to it. `/target` needs the target capability and `/nav` the move capability.
hs.ui_function('findwalk_travel', function(id)
  if not settings.get('findwalk') then return {ok = false, error = 'The Find window is turned off.'} end
  if not positiveInteger(id) then return {ok = false, error = 'Invalid spawn.'} end
  if type(hs.spawn) ~= 'function' or not hs.spawn(id) then
    return {ok = false, error = 'That spawn is no longer in the zone.'}
  end
  for _, line in ipairs({'/target id ' .. id, '/nav id ' .. id}) do
    local sent, err = pcall(mq.cmd, line)
    if not sent then return {ok = false, error = 'Command refused: ' .. tostring(err)} end
  end
  return {ok = true}
end)

-- Named tracker (ui/modern/named.lua). Same split as FindWalk: the window is a separate
-- script; it asks for its state, the zone list and its rows here, so everything over the
-- generated database (core/named_data.lua) and the tracked-name store stays in core/named.lua.
-- The data may be missing (a stale install without the generated file): the window then has
-- no zones to list and tracks nothing. projectTriune is declared here and defined with the
-- Other versions controls below; the loot windows check the server the same way.
local projectTriune
local named = require('core.named')
local namedData = named.loadData()
local namedStore = named.newStore(mq, nil, reportSaveError)
local namedState = {open = false, edit = false, zone = nil, serial = 0}

-- The short name of the zone the player is in, lowercase to match the data's keys, or nil
-- when the client does not tell (not in a zone, or no zone_name in this client).
local function currentZoneShort()
  if type(hs.player) ~= 'function' then return nil end
  local ok, player = pcall(hs.player)
  if not ok or type(player) ~= 'table' or player.in_zone == false then return nil end
  if not positiveInteger(player.zone_id) then return nil end
  local read, name = pcall(hs.zone_name, player.zone_id)
  if not read or type(name) ~= 'string' then return nil end
  local short = name:match('^%s*(.-)%s*$'):lower()
  if short == '' then return nil end
  return short
end

-- The zone to work on: an argument wins, otherwise the player's current zone.
local function namedZone(zoneShort)
  if type(zoneShort) == 'string' then
    zoneShort = zoneShort:match('^%s*(.-)%s*$'):lower():sub(1, named.MAX_ZONE)
    if zoneShort ~= '' then return zoneShort end
  end
  return currentZoneShort()
end

local function toggleNamed(...)
  if not settings.get('named_tracker') then
    namedState.open, namedState.edit = false, false
    if type(hs.chat) == 'function' then
      pcall(hs.chat, 'QoL: the named tracker is turned off; enable it under Options \xE2\x86\x92 Plugins.', 15)
    end
    return
  end
  local text = table.concat({...}, ' '):match('^%s*(.-)%s*$')
  if text ~= '' then
    -- `/named gukbottom` opens the window on that zone
    namedState.zone = text:sub(1, named.MAX_ZONE)
    namedState.open = true
  else
    namedState.open = not namedState.open
  end
  namedState.serial = namedState.serial + 1
end

pcall(mq.bind, '/named', toggleNamed)
pcall(hs.menu, 'Named', '/named')

hs.ui_function('named_state', function()
  -- turning the option off closes the window on its next frame
  if not settings.get('named_tracker') then
    namedState.open, namedState.edit = false, false
  end
  return {
    open = namedState.open,
    edit = namedState.edit,
    zone = namedState.zone or currentZoneShort(),
    serial = namedState.serial,
  }
end)

hs.ui_function('named_close', function() namedState.open = false end)

hs.ui_function('named_edit_set', function(value)
  if not settings.get('named_tracker') then
    namedState.edit = false
    return
  end
  namedState.edit = value == true
end)

-- The tracker window's divider between the named list and the drops list (design pixels of list
-- height), persisted in qol_named.lua; nil when never dragged.
hs.ui_function('named_split', function()
  if not settings.get('named_tracker') then return nil end
  return namedStore.split()
end)

hs.ui_function('named_split_set', function(value)
  if not settings.get('named_tracker') then return false end
  return namedStore.setSplit(value)
end)

hs.ui_function('named_zones', function()
  if not settings.get('named_tracker') then return nil end
  local current = currentZoneShort()
  return {current = current, zones = named.zoneList(namedData, current)}
end)

hs.ui_function('named_list', function(zoneShort)
  if not settings.get('named_tracker') then return nil end
  if type(zoneShort) ~= 'string' then return nil end
  zoneShort = zoneShort:lower()
  if zoneShort == '' or #zoneShort > named.MAX_ZONE then return nil end
  local currentShort = currentZoneShort()
  -- rows exist outside a zone too; only there does anything spawn
  local spawns = type(hs.spawns) == 'function' and hs.spawns() or nil
  local me
  if currentShort and type(hs.spawn) == 'function' then
    local player = hs.player()
    if type(player) == 'table' and positiveInteger(player.spawn_id) then
      me = hs.spawn(player.spawn_id)
      if type(me) == 'table' then me.id = player.spawn_id else me = nil end
    end
  end
  local result = named.rows(namedData, spawns, me, currentShort, zoneShort,
    namedStore.list(zoneShort))
  -- names removed from the tracker window (the "x" of a row) stay out of its list; the editor's
  -- suggestion list shows them again, and adding them there unhides them
  local hiddenSet = {}
  for _, existing in ipairs(namedStore.hiddenList(zoneShort)) do
    hiddenSet[named.nameKey(existing)] = true
  end
  local visible = {}
  for _, row in ipairs(result.rows) do
    if not hiddenSet[named.nameKey(row.name)] then visible[#visible + 1] = row end
  end
  result.rows = visible
  local long
  if type(namedData) == 'table' and type(namedData.zones) == 'table' then
    local zone = namedData.zones[zoneShort]
    if type(zone) == 'table' and type(zone.long) == 'string' then long = zone.long end
  end
  return {
    zone = zoneShort,
    long = long,
    current = currentShort ~= nil and zoneShort == currentShort,
    rows = result.rows,
  }
end)

-- The loot of one named entry from the data, for the drop list in the window. A tracked
-- custom name has no data entry, so it lists no drops; anything else unknown is nil.
hs.ui_function('named_drops', function(zoneShort, name)
  if not settings.get('named_tracker') then return nil end
  if type(zoneShort) ~= 'string' or type(name) ~= 'string' then return nil end
  if #zoneShort > named.MAX_ZONE then return nil end
  zoneShort = zoneShort:match('^%s*(.-)%s*$')
  if zoneShort == '' then zoneShort = currentZoneShort() or '' end
  zoneShort = zoneShort:lower()
  if zoneShort == '' then return nil end
  local key = named.nameKey(name)
  if not key then return nil end
  for _, entry in ipairs(named.namedOfZone(namedData, zoneShort) or {}) do
    if named.nameKey(entry.name) == key then
      return { drops = entry.drops }
    end
  end
  -- not a flagged named of the zone: a hand-tracked name still gets its drops from the loot index
  local loot = named.lootOf(namedData, name)
  if loot then return { drops = loot } end
  for _, existing in ipairs(namedStore.list(zoneShort)) do
    if named.nameKey(existing) == key then return { drops = {} } end
  end
  return nil
end)

-- Target a spawned named. Only `/target` here, no movement: walking is FindWalk's job.
hs.ui_function('named_target', function(id)
  if not settings.get('named_tracker') then
    return {ok = false, error = 'The named tracker is turned off.'}
  end
  if not positiveInteger(id) then return {ok = false, error = 'Invalid spawn.'} end
  if type(hs.spawn) ~= 'function' or not hs.spawn(id) then
    return {ok = false, error = 'That spawn is no longer in the zone.'}
  end
  local sent, err = pcall(mq.cmd, '/target id ' .. id)
  if not sent then return {ok = false, error = 'Command refused: ' .. tostring(err)} end
  return {ok = true}
end)

-- A named's loot opens in its own item window, on the same servers as the Other versions
-- controls; hs.inspect_item is mirrored from request_item_preview.
hs.ui_function('named_open_item', function(itemId)
  if not settings.get('named_tracker') then
    return {ok = false, kind = 'disabled',
      error = 'The named tracker is turned off; enable it under Options → Plugins.'}
  end
  if not positiveInteger(itemId) or itemId > 4294967295 then
    return {ok = false, kind = 'invalid_id', error = 'Invalid item id for a loot window.'}
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
      error = "Loot windows are for Project Triune; current server '" .. tostring(name)
        .. "' is not recognized."}
  end
  if type(hs.inspect_item) ~= 'function' then
    return {ok = false, kind = 'missing_api',
      error = 'hs.inspect_item is unavailable in this client, so no item window can be opened.'}
  end
  local sent, err = pcall(hs.inspect_item, itemId)
  if not sent then
    return {ok = false, kind = 'refused', error = 'The item window request was refused: ' .. tostring(err)}
  end
  return {ok = true, id = itemId}
end)

-- Tracked names of a zone and what the data suggests instead; '' as the zone is the current one.
hs.ui_function('named_tracked', function(zoneShort)
  if not settings.get('named_tracker') then return nil end
  local zone = namedZone(zoneShort)
  if not zone then return {names = {}, suggestions = {}} end
  local names = namedStore.list(zone)
  return {names = names, suggestions = named.suggestions(namedData, zone, names)}
end)

hs.ui_function('named_add', function(zoneShort, name)
  if not settings.get('named_tracker') then
    return {ok = false, error = 'The named tracker is turned off.'}
  end
  local zone = namedZone(zoneShort)
  if not zone then return {ok = false, error = 'Not in a zone.'} end
  namedStore.unhide(zone, name) -- adding a name also shows it in the tracker window again
  local ok, err = namedStore.add(zone, name)
  if not ok then
    -- already tracked: fine, it is now unhidden and tracked
    if err == 'Already tracking that name.' then
      return {ok = true, names = namedStore.list(zone)}
    end
    return {ok = false, error = err or 'Could not track that name.'}
  end
  return {ok = true, names = namedStore.list(zone)}
end)

-- Remove a name from the tracker window's list (the "x" of a row). Hiding also stops tracking it;
-- the name then shows up in the editor's suggestion list, where adding it brings it back.
hs.ui_function('named_hide', function(zoneShort, name)
  if not settings.get('named_tracker') then
    return {ok = false, error = 'The named tracker is turned off.'}
  end
  local zone = namedZone(zoneShort)
  if not zone then return {ok = false, error = 'Not in a zone.'} end
  if type(name) ~= 'string' or not named.nameKey(name) then
    return {ok = false, error = 'Invalid name.'}
  end
  namedStore.remove(zone, name)
  local ok, err = namedStore.hide(zone, name)
  if not ok then return {ok = false, error = err or 'Could not remove that name.'} end
  return {ok = true}
end)

hs.ui_function('named_remove', function(zoneShort, name)
  if not settings.get('named_tracker') then
    return {ok = false, error = 'The named tracker is turned off.'}
  end
  local zone = namedZone(zoneShort)
  if not zone then return {ok = false, error = 'Not in a zone.'} end
  local ok, err = namedStore.remove(zone, name)
  if not ok then return {ok = false, error = err or 'Could not remove that name.'} end
  return {ok = true, names = namedStore.list(zone)}
end)

-- A living NPC's class short name, or nil when the client sends no playable class id.
local function className(spawn)
  local id = spawn and spawn.class
  if type(id) == 'number' and id % 1 == 0 then return info.classes[id] end
end

-- Merchants, bankers and trainers carry a class id past the playable ones: they get no level either.
local function isServiceNpc(spawn)
  local id = spawn.class
  return type(id) == 'number' and id % 1 == 0 and id > #info.classes
end

-- The nameplate/target suffix: "[12]", "[WAR]" or "[12 WAR]", and "" when neither shows.
local function detail(spawn, level, class)
  local parts = {}
  if level and type(spawn.level) == 'number' and spawn.level > 0 and not isServiceNpc(spawn) then
    parts[#parts + 1] = tostring(spawn.level)
  end
  local name = class and className(spawn)
  if name then parts[#parts + 1] = name end
  if #parts == 0 then return '' end
  return ' [' .. table.concat(parts, ' ') .. ']'
end

hs.ui_function('item_info', function(item)
  if not settings.get('item_info') then return nil end
  return info.item(item)
end)

hs.ui_function('target_name', function(name)
  local showLevel, showClass = settings.get('target_level'), settings.get('npc_class')
  if (not showLevel and not showClass) or type(name) ~= 'string' then return name end
  local id = mq.TLO.Target.ID()
  local spawn = id and hs.spawn(id)
  if not spawn or not spawn.npc or spawn.corpse then return name end
  return name .. detail(spawn, showLevel, showClass)
end)

-- Supported custom clients supply nameplate text and map spawn data to these hooks.
if hs.hooks then
  hs.hooks{
    nameplate = function(spawn, text)
      if not spawn or not spawn.npc or spawn.corpse or type(text) ~= 'string' then return nil end
      local suffix = detail(spawn, settings.get('target_level'), settings.get('npc_class'))
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

function projectTriune(server)
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

-- Lightweight eligibility for the Other versions controls. The option is checked every time; the
-- shared server read is cached for a second so six item windows do not repeat it every frame, while
-- a zone change or logout is still reflected promptly. A missing or failing hs.server hides the
-- controls instead of guessing the server.
local versionsCache = {}
hs.ui_function('item_versions_available', function()
  if not settings.get('item_preview') or type(hs.server) ~= 'function' then
    versionsCache.at = nil
    return false
  end
  local now = os.time()
  if versionsCache.at == now then return versionsCache.ok end
  local read, server = pcall(hs.server)
  versionsCache.at, versionsCache.ok = now, read and projectTriune(server) or false
  return versionsCache.ok
end)

-- One item version request per click. The UI asks for exactly one item id; this function only checks
-- that the request is well formed and that this really is Project Triune, then asks the client to
-- open that item's own native window. It does not wait for, find, or alter any item window.
hs.ui_function('request_item_preview', function(itemId)
  if not settings.get('item_preview') then
    return {ok = false, kind = 'disabled',
      error = 'Item version windows are turned off; enable them under Options → Plugins.'}
  end
  if not positiveInteger(itemId) or itemId > 4294967295 then
    return {ok = false, kind = 'invalid_id', error = 'Invalid item id for an item version request.'}
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
      error = "Item version windows are for Project Triune; current server '" .. tostring(name)
        .. "' is not recognized."}
  end
  if type(hs.inspect_item) ~= 'function' then
    return {ok = false, kind = 'missing_api',
      error = 'hs.inspect_item is unavailable in this client, so no item window can be requested.'}
  end
  local sent, err = pcall(hs.inspect_item, itemId)
  if not sent then
    return {ok = false, kind = 'refused', error = 'The item window request was refused: ' .. tostring(err)}
  end
  return {ok = true, id = itemId}
end)
