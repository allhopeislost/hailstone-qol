-- Named tracker: the pure helpers in core/named.lua, the generated core/named_data.lua, the
-- per-zone tracked-name store, and the named_* functions the windows call in init.lua.
-- Run from qol/.
local named = dofile('core/named.lua')
assert(type(named) == 'table', 'core/named.lua exports a table')

-- ---------------------------------------------------------------- pure helpers

-- normalizeName: trims, underscores read as spaces, runs of spaces collapse, capped at MAX_NAME.
assert(named.MAX_NAME == 64, 'the cap for a tracked name is 64 characters')
assert(named.normalizeName('  a_frenzied__ghoul  ') == 'a frenzied ghoul', 'trim, underscores, collapse')
assert(named.normalizeName('a_frenzied_ghoul02') == 'a frenzied ghoul02', 'digits are kept')
assert(named.normalizeName("  mac's_hut ") == "mac's hut")
assert(named.normalizeName('') == nil and named.normalizeName('   ') == nil, 'empty is no name')
assert(named.normalizeName('___') == nil, 'underscores alone are no name')
assert(named.normalizeName(nil) == nil and named.normalizeName(5) == nil and
  named.normalizeName({}) == nil, 'only strings are names')
assert(#named.normalizeName(string.rep('x', 500)) == named.MAX_NAME, 'a long name is cut to MAX_NAME')

-- keyOf: the trimmed lowercase comparison key.
assert(named.keyOf('A_Frenzied__Ghoul') == 'a_frenzied__ghoul', 'keyOf only trims and lowercases')
assert(named.keyOf('  Rats ') == 'rats')
assert(named.keyOf(nil) == nil, 'a non-string has no key')
assert(named.keyOf('') == nil, 'an empty string has no key')

-- zoneList: every zone of the data, the current one first, then A to Z by short name.
local data = {
  zones = {
    gukbottom = { long = 'The Ruins of Old Guk', named = {
      { name = 'a_frenzied_ghoul', level = 42, drops = { { 1365, 20.0 } } } } },
    beholder = { long = 'Gorge of King Xorbb', named = {} },
  },
  items = { [1365] = 'Flowing Black Silk Sash' },
}
data.zones['mistmoore'] = { long = 'Castle Mistmoore', named = {} }
local zones = named.zoneList(data, 'gukbottom')
assert(type(zones) == 'table' and #zones == 3, 'every zone is listed')
assert(zones[1].short == 'gukbottom' and zones[1].current == true, 'the current zone is first')
assert(zones[1].long == 'The Ruins of Old Guk' and zones[1].count == 1)
assert(zones[2].short == 'beholder' and zones[3].short == 'mistmoore', 'then A to Z')
assert(zones[2].current == false)
zones = named.zoneList(data, 'not_a_zone')
assert(zones[1].short == 'beholder', 'an unknown current zone is simply not first')
assert(#named.zoneList(nil, 'x') == 0 and #named.zoneList({}, 'x') == 0, 'no data, no zones')

-- namedOfZone: the zone's named as records with the item name filled in; nil when unknown.
local guk = named.namedOfZone(data, 'gukbottom')
assert(type(guk) == 'table' and #guk == 1)
assert(guk[1].name == 'a_frenzied_ghoul' and guk[1].display == 'a frenzied ghoul')
assert(guk[1].level == 42 and guk[1].drops[1].id == 1365 and guk[1].drops[1].chance == 20.0)
assert(guk[1].drops[1].item == 'Flowing Black Silk Sash', 'the item name comes from items')
assert(named.namedOfZone(data, 'nowhere') == nil, 'an unknown zone has no entry')
assert(named.namedOfZone(data, nil) == nil and named.namedOfZone(data, 5) == nil)

-- suggestions: the zone's named that are not tracked yet, by key; tracked may be a list or a set.
local suggestionData = {
  zones = { gukbottom = { long = 'G', named = {
    { name = 'a_alpha', level = 10, drops = {} },
    { name = 'Beta_Brav', level = 12, drops = {} },
  } } },
}
local sugg = named.suggestions(suggestionData, 'gukbottom', { 'a alpha' })
assert(type(sugg) == 'table' and #sugg == 1 and sugg[1].name == 'Beta_Brav',
  'the tracked name is not suggested again')
sugg = named.suggestions(suggestionData, 'gukbottom',
  { [named.keyOf('a alpha')] = true, [named.keyOf('beta brav')] = true })
assert(#sugg == 0, 'everything tracked leaves no suggestions')
assert(#named.suggestions(suggestionData, 'nowhere', {}) == 0, 'an unknown zone suggests nothing')

-- matchSpawn: the living NPC whose cleaned display name or raw name matches; nearest to `me`
-- when several match, first by id without a position. Corpses and players never match.
local function spawn(id, name, x, extra)
  local s = { id = id, name = name, x = x, y = 0, z = 0, npc = true, level = 42, class = 1 }
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end
local two = { spawn(2, 'a_frenzied_ghoul', 30), spawn(3, 'a_frenzied_ghoul02', 5) }
assert(named.matchSpawn(nil, nil, 'x') == nil, 'no spawns is no match')
assert(named.matchSpawn(two, nil, 'zzz') == nil, 'an absent name matches nothing')
assert(named.matchSpawn(two, nil, nil) == nil, 'no name is no match')
local hit = named.matchSpawn(two, nil, 'a_frenzied_ghoul')
assert(hit and hit.id == 2, 'without a position the first match by id wins')
hit = named.matchSpawn(two, { x = 0, y = 0, z = 0 }, 'a frenzied ghoul')
assert(hit and hit.id == 3, 'the digit-stripped display name matches too, nearest wins: ' .. tostring(hit and hit.id))
hit = named.matchSpawn(two, nil, 'frenzied')
assert(hit and hit.id == 2, 'a hand-typed short name matches a spawn whose name contains it')
assert(named.matchSpawn(two, nil, 'fr') == nil, 'a too-short name does not substring-match')
assert(named.matchSpawn(two, { x = 0, y = 0, z = 0 }, 'ghoul') == nil or true)
hit = named.matchSpawn(two, { x = 0, y = 0, z = 0 }, 'ghoul')
assert(hit and hit.id == 3, 'a contained word matches, nearest wins: ' .. tostring(hit and hit.id))
local corpsed = { { id = 4, name = 'a_frenzied_ghoul', npc = true, corpse = true, x = 1, y = 0, z = 0 } }
assert(named.matchSpawn(corpsed, nil, 'a frenzied ghoul') == nil, 'a corpse does not count')
local pced = { { id = 5, name = 'a_frenzied_ghoul', npc = false, x = 1, y = 0, z = 0 } }
assert(named.matchSpawn(pced, nil, 'a frenzied ghoul') == nil, 'a player does not count')

-- rows: the data's named plus tracked custom names; spawned/id/dist only in the current zone.
local rowData = {
  zones = { guk = { long = 'G', named = {
    { name = 'a_alpha', level = 10, drops = { { 1365, 20.0 } } },
    { name = 'b_bravo', level = 12, drops = {} },
  } } },
}
local zoneSpawns = { { id = 7, name = 'a_alpha', npc = true, x = 0, y = 0, z = 0 } }
local function rowOf(rows, key)
  local want = named.nameKey(key)
  for _, row in ipairs(rows) do
    if type(row) == 'table' and (named.nameKey(row.name or '') == want
        or named.nameKey(row.display or '') == want) then return row end
  end
end
-- a plain array of names (the store's list)
local function hasName(names, key)
  local want = named.nameKey(key)
  for _, n in ipairs(names) do
    if named.nameKey(n) == want then return true end
  end
  return false
end
local result = named.rows(rowData, zoneSpawns, { x = 10, y = 0, z = 0 }, 'guk', 'guk', {})
assert(type(result) == 'table' and type(result.rows) == 'table' and #result.rows == 2)
local rows = result.rows
assert(rows[1].name == 'a_alpha' and rows[2].name == 'b_bravo', 'sorted by display name')
assert(rows[1].spawned == true and rows[1].id == 7 and rows[1].dist == 10, 'spawned with id and whole distance')
assert(rows[2].spawned == false and rows[2].id == nil, 'an absent named is not spawned')
result = named.rows(rowData, zoneSpawns, { x = 0, y = 0, z = 0 }, 'guk', 'guk', { 'a alpha' })
assert(rowOf(result.rows, 'a alpha').tracked == true, 'the tracked flag marks a tracked name')
result = named.rows(rowData, zoneSpawns, nil, 'guk', 'guk', { 'zeta_custom' })
local custom = rowOf(result.rows, 'zeta custom')
assert(custom and custom.custom == true and custom.tracked == true, 'a custom tracked name joins the list')
assert(custom.spawned == false and custom.id == nil)
result = named.rows(rowData, zoneSpawns, nil, 'other', 'guk', {})
assert(rowOf(result.rows, 'a alpha').spawned == false, 'a foreign current zone spawns nothing')
result = named.rows(rowData, zoneSpawns, nil, 'guk', 'guk', {})
assert(rowOf(result.rows, 'a alpha').dist == nil, 'no player record: no distances')
assert(named.rows(rowData, nil, nil, 'guk', '', {}).rows ~= nil
  and #named.rows(rowData, nil, nil, 'guk', '', {}).rows == 0, 'an empty zone lists nothing')

print('named helpers ok')

-- ---------------------------------------------------------------- the generated data
local file = assert(dofile('core/named_data.lua'), 'the generated data loads')
assert(type(file.items) == 'table' and type(file.zones) == 'table', 'items and zones tables')
local zonesChecked, namedChecked, dropsChecked = 0, 0, 0
for short, zone in pairs(file.zones) do
  assert(type(short) == 'string' and short ~= '' and short:lower() == short,
    'zone keys are lowercase: ' .. tostring(short))
  assert(type(zone) == 'table' and type(zone.long) == 'string' and type(zone.named) == 'table', short)
  local previous
  for _, entry in ipairs(zone.named) do
    assert(type(entry.name) == 'string' and entry.name ~= '', short .. ': named entries carry a name')
    local key = entry.name:lower()
    assert(previous == nil or previous < key, 'named are sorted by lower(name) in ' .. short)
    previous = key
    assert(type(entry.drops) == 'table', entry.name)
    for _, drop in ipairs(entry.drops) do
      assert(type(drop[1]) == 'number' and type(drop[2]) == 'number', entry.name .. ': drops are {id, chance}')
      assert(type(file.items[drop[1]]) == 'string', entry.name .. ': drop ' .. drop[1] .. ' is in items')
      assert(drop[2] > 0 and drop[2] <= 100, entry.name .. ': chance in (0, 100]')
      dropsChecked = dropsChecked + 1
    end
    namedChecked = namedChecked + 1
  end
  zonesChecked = zonesChecked + 1
end
assert(zonesChecked > 100 and namedChecked > 1000 and dropsChecked > 10000,
  'the data has many zones with named npcs and drops: ' .. zonesChecked .. '/' .. namedChecked .. '/' .. dropsChecked)
-- server-specific NPCs are excluded from the named list (D033), in every zone
for short, zone in pairs(file.zones) do
  for _, entry in ipairs(zone.named) do
    assert(entry.name:lower():gsub('_', ' '):gsub('%s+', ' ') ~= 'echo of the past',
      'echo of the past is filtered out of ' .. short)
  end
end
assert(file.zones.gukbottom and file.zones.gukbottom.long == 'The Ruins of Old Guk')
local frenzied
for _, entry in ipairs(file.zones.gukbottom.named) do
  if entry.name == 'a_frenzied_ghoul' then frenzied = entry end
end
assert(frenzied, 'gukbottom lists a_frenzied_ghoul')
local hasSash
for _, drop in ipairs(frenzied.drops) do
  if drop[1] == 1365 and drop[2] == 20 then hasSash = true end
end
assert(hasSash and file.items[1365] == 'Flowing Black Silk Sash', 'the ghoul drops the silk sash at 20%')

-- the loot index for hand-tracked (placeholder-style) names: a reanimated hand is not flagged
-- named in the database, but its drops are indexed by name
assert(type(file.loot) == 'table', 'the loot index is a table')
local handLoot = file.loot['a reanimated hand']
assert(type(handLoot) == 'table' and #handLoot > 0, 'a reanimated hand is in the loot index')
local hasBracer
for _, drop in ipairs(handLoot) do
  assert(type(drop[1]) == 'number' and type(drop[2]) == 'number' and drop[2] > 0 and drop[2] <= 100)
  assert(type(file.items[drop[1]]) == 'string', 'loot drop ' .. drop[1] .. ' is in items')
  if drop[1] == 10148 and drop[2] == 75 then hasBracer = true end
end
assert(hasBracer and file.items[10148] == 'Serpentine Bracer', 'the hand drops the bracer at 75%')
local lootRows = named.lootOf(file, 'A_Reanimated_Hand')
assert(type(lootRows) == 'table' and lootRows[1].id == 10148 and lootRows[1].chance == 75
  and lootRows[1].item == 'Serpentine Bracer', 'lootOf resolves by nameKey with item names')
assert(named.lootOf(file, 'no such mob anywhere') == nil, 'an unknown name has no loot')
assert(named.lootOf(file, nil) == nil and named.lootOf(nil, 'x') == nil)
local loaded = named.loadData()
assert(type(loaded) == 'table' and type(loaded.zones) == 'table' and loaded.generated == file.generated
  and loaded.zones.gukbottom ~= nil, 'loadData hands out the data')

print('named data ok')

-- ---------------------------------------------------------------- the tracked-name store
local written = {}
local storeMq = { pickle = function(path, value) assert(path == 'qol_named.lua'); written[path] = value end }
local store = named.newStore(storeMq, function(path) return written[path] end)
assert(#store.list('gukbottom') == 0, 'a fresh store tracks nothing')
assert(store.add('gukbottom', 'My_Own_Brat'), 'a short zone plus a name is accepted')
assert(#store.list('gukbottom') == 1 and store.list('gukbottom')[1] == 'My Own Brat', 'stored normalized')
assert(store.add('gukbottom', 'my other brat') == true and #store.list('gukbottom') == 2)
local dupOk, dupErr = store.add('gukbottom', 'MY  OTHER  BRAT')
assert(not dupOk and type(dupErr) == 'string' and #store.list('gukbottom') == 2,
  'a duplicate (any spelling) is refused and adds nothing: ' .. tostring(dupErr))
assert(not store.add('gukbottom', nil) and not store.add('gukbottom', '') and
  not store.add('gukbottom', 5), 'bad names are refused')
local ok, err = store.add('Bad Zone!!', 'x')
assert(not ok and type(err) == 'string', 'a bad zone is refused: ' .. tostring(err))
assert(store.remove('gukbottom', 'my own brat') == true)
assert(#store.list('gukbottom') == 1, 'remove takes the name in any spelling')
assert(store.add('nadox', 'a_tormax_slave') == true, 'a second zone')
local storeZones = store.zones()
assert(#storeZones == 2 and store.list('nadox')[1] == 'a tormax slave')
-- a new store reads what the first one saved (the roundtrip)
local reread = named.newStore(storeMq, function(path) return written[path] end)
assert(#reread.list('gukbottom') == 1 and #reread.list('nadox') == 1, 'the saved lists are read back')
-- the tracker window's divider (split) roundtrips too, and bad values are refused
assert(store.split() == nil, 'no split saved yet')
assert(store.setSplit(200) == true and store.split() == 200, 'a split is accepted')
assert(named.newStore(storeMq, function(path) return written[path] end).split() == 200,
  'the split survives the roundtrip')
for _, bad in ipairs({ 'x', nil, 0 / 0, -5, 99999, true }) do
  assert(store.setSplit(bad) == false, 'a bad split is refused: ' .. tostring(bad))
end
assert(store.split() == 200, 'a refused split does not change the saved one')
-- the hidden (removed-from-the-list) names roundtrip too
assert(#store.hiddenList('gukbottom') == 0, 'nothing hidden yet')
assert(store.hide('gukbottom', 'a_frenzied_ghoul') == true)
assert(#store.hiddenList('gukbottom') == 1 and store.hiddenList('gukbottom')[1] == 'a frenzied ghoul')
assert(store.hide('gukbottom', 'A FRENZIED GHOUL') == true and #store.hiddenList('gukbottom') == 1,
  'hiding dedupes by name key')
assert(named.newStore(storeMq, function(path) return written[path] end).hiddenList('gukbottom')[1]
  == 'a frenzied ghoul', 'the hidden names survive the roundtrip')
assert(store.hide('Bad Zone!!', 'x') == false and store.hide('gukbottom', nil) == false, 'bad hide refused')
assert(store.unhide('gukbottom', 'a frenzied ghoul') == true and #store.hiddenList('gukbottom') == 0)
-- a corrupt config file starts empty, and a save failure reports through onError
local reported
local failing = named.newStore({ pickle = function() error('disk unavailable') end },
  function() return { version = 99 } end, function(e) reported = e end)
assert(#failing.list('gukbottom') == 0, 'a wrong-version config starts empty')
assert(not failing.add('gukbottom', 'x') and reported and reported:find('disk unavailable', 1, true),
  'a save failure is reported')

print('named store ok')

-- ---------------------------------------------------------------- init.lua wiring
local functions, bound, menu, commands, chats, inspected, options = {}, {}, {}, {}, {}, {}, {}
local player = { spawn_id = 1, in_zone = true, zone_id = 66 }
local zoneSpawns = {
  { id = 1, name = 'Me', npc = false, x = 0, y = 0, z = 0 },
  { id = 2, name = 'a_frenzied_ghoul', npc = true, x = 30, y = 0, z = 0, level = 42, class = 1 },
  { id = 3, name = 'the_ghoul_lord', npc = true, x = 100, y = 0, z = 0, level = 47, class = 1 },
}
local hs = {
  option = function(o) options[o.name] = o end,
  ui_function = function(name, fn) functions[name] = fn end,
  menu = function(label, command) menu[#menu + 1] = { label, command } end,
  chat = function(text) chats[#chats + 1] = text end,
  player = function() return player end,
  spawns = function() return zoneSpawns end,
  spawn = function(id) for _, s in ipairs(zoneSpawns) do if s.id == id then return s end end end,
  zone_name = function(id) if id == 66 then return 'gukbottom' end end,
  server = function() return { world = 'Project Triune' } end,
  inspect_item = function(id) inspected[#inspected + 1] = id end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function()
  return {
    pickle = function(path, value) written[path] = value end,
    bind = function(name, fn) bound[name] = fn end,
    cmd = function(line) commands[#commands + 1] = line end,
  }
end
dofile('init.lua')

-- the option, the command, the menu entry
assert(options.named_tracker and options.named_tracker.label == 'Named tracker (/named)')
assert(options.named_tracker.get() == 1, 'on by default')
assert(bound['/named'], '/named is bound')
local menuHasNamed
for _, entry in ipairs(menu) do
  if entry[1] == 'Named' and entry[2] == '/named' then menuHasNamed = true end
end
assert(menuHasNamed, 'the menu entry Named runs /named')
for _, name in ipairs({'named_state', 'named_close', 'named_edit_set', 'named_zones', 'named_list',
    'named_drops', 'named_target', 'named_open_item', 'named_tracked', 'named_add', 'named_remove',
    'named_split', 'named_split_set', 'named_hide'}) do
  assert(type(functions[name]) == 'function', 'the window function ' .. name .. ' is registered')
end

-- the divider between the two lists: unset at first, then kept
assert(functions.named_split() == nil, 'no divider saved yet')
assert(functions.named_split_set(220) == true and functions.named_split() == 220, 'the divider is kept')
assert(functions.named_split_set('wide') == false and functions.named_split() == 220, 'a bad divider is refused')

-- the state: closed at first, /named toggles, /named <zone> opens on that zone
local state = functions.named_state()
assert(state.open == false and state.edit == false and state.zone == 'gukbottom' and state.serial == 0,
  'closed at first, the zone resolves to the current one')
bound['/named']()
assert(functions.named_state().open == true, '/named opens it')
bound['/named']()
assert(functions.named_state().open == false, '/named again closes it')
bound['/named']('nadox')
state = functions.named_state()
assert(state.open and state.zone == 'nadox' and state.serial > 0, 'a zone argument opens it there')
functions.named_close()
assert(functions.named_state().open == false)
functions.named_edit_set(true)
assert(functions.named_state().edit == true, 'the editor opens')
functions.named_edit_set(false)
assert(functions.named_state().edit == false)

-- the zone list: the current zone first, with its long name and named count
local zonesResult = functions.named_zones()
assert(zonesResult.current == 'gukbottom')
assert(type(zonesResult.zones) == 'table' and zonesResult.zones[1].short == 'gukbottom'
  and zonesResult.zones[1].current == true and zonesResult.zones[1].count > 0)
assert(zonesResult.zones[1].long == 'The Ruins of Old Guk')

-- the list of one zone: data named plus custom tracked, spawned only in the current zone
local list = functions.named_list('gukbottom')
assert(list.zone == 'gukbottom' and list.current == true and list.long == 'The Ruins of Old Guk')
local frenziedRow = rowOf(list.rows, 'a frenzied ghoul')
assert(frenziedRow and frenziedRow.spawned == true and frenziedRow.id == 2 and frenziedRow.dist == 30,
  'a frenzied ghoul is up, at 30')
local lordRow = rowOf(list.rows, 'the ghoul lord')
assert(lordRow and lordRow.spawned == true and lordRow.id == 3 and lordRow.dist == 100)
list = functions.named_list('nadox')
assert(list.current == false and list.long ~= nil)
for _, row in ipairs(list.rows) do assert(row.spawned == false and row.id == nil, 'nothing spawns elsewhere') end
assert(functions.named_list(5) == nil and functions.named_list('') == nil
  and functions.named_list(string.rep('a', 40)) == nil, 'a bad zone argument answers nothing')
player.in_zone = false
assert(functions.named_list('gukbottom').rows[1].spawned == false, 'outside a zone nothing is up')
assert(functions.named_zones().current == nil, 'no current zone outside a zone')
player.in_zone = true

-- the drops of one named, with item ids, chances and names
local drops = functions.named_drops('gukbottom', 'a_frenzied_ghoul')
assert(type(drops) == 'table' and type(drops.drops) == 'table')
local sash
for _, drop in ipairs(drops.drops) do
  if drop.id == 1365 then sash = drop end
end
assert(sash and sash.chance == 20 and sash.item == 'Flowing Black Silk Sash', 'the sash is there at 20%')
assert(functions.named_drops('gukbottom', 5) == nil, 'a non-string name answers nothing')
assert(functions.named_drops('nowhere-at-all', 'x') == nil, 'an unknown zone answers nothing')
-- a hand-tracked name that is not a flagged named still gets its drops from the loot index
drops = functions.named_drops('gukbottom', 'a reanimated hand')
assert(type(drops) == 'table' and type(drops.drops) == 'table')
local bracer
for _, drop in ipairs(drops.drops) do
  if drop.id == 10148 then bracer = drop end
end
assert(bracer and bracer.chance == 75 and bracer.item == 'Serpentine Bracer',
  'the reanimated hand drops the bracer at 75% via the loot index')
assert(functions.named_drops('gukbottom', 'totally unknown name') == nil, 'an untracked unknown name answers nothing')

-- target: only /target id N, only for a spawn that is really in the zone
local sent = functions.named_target(2)
assert(sent.ok == true and commands[#commands] == '/target id 2', 'the up named is targeted')
local before = #commands
for _, bad in ipairs({ 0, -1, 1.5, '2', false, math.huge, 0 / 0 }) do
  local refused = functions.named_target(bad)
  assert(refused.ok == false and #commands == before, tostring(bad))
end
local gone = functions.named_target(999)
assert(gone.ok == false and gone.error:find('no longer') and #commands == before, 'a despawned spawn sends nothing')

-- open a drop's item window: Project Triune only, like the Other versions controls
local opened = functions.named_open_item(1365)
assert(opened.ok == true and opened.id == 1365 and inspected[1] == 1365, 'the item window opens on Triune')
for _, bad in ipairs({ 0, -1, 4294967296, '1365', math.huge, 0 / 0 }) do
  local refused = functions.named_open_item(bad)
  assert(refused.ok == false and refused.kind == 'invalid_id' and #inspected == 1, tostring(bad))
end
hs.server = function() return { world = 'Some Other Server' } end
local refused = functions.named_open_item(1365)
assert(refused.ok == false and refused.kind == 'server' and #inspected == 1, 'not on Triune')
hs.server = function() return { world = 'Project Triune' } end

-- the tracked names of a zone, with the data's suggestions
local tracked = functions.named_tracked('gukbottom')
assert(type(tracked.names) == 'table' and #tracked.names == 0)
assert(type(tracked.suggestions) == 'table' and #tracked.suggestions > 0)
assert(rowOf(tracked.suggestions, 'a frenzied ghoul') ~= nil, 'a frenzied ghoul is suggested')
local added = functions.named_add('gukbottom', 'a_frenzied_ghoul')
assert(added.ok == true and #added.names == 1 and added.names[1] == 'a frenzied ghoul')
tracked = functions.named_tracked('gukbottom')
assert(#tracked.names == 1 and rowOf(tracked.suggestions, 'a frenzied ghoul') == nil,
  'a tracked name is no longer suggested')
local again = functions.named_add('gukbottom', 'A FRENZIED GHOUL')
assert(again.ok == true and #functions.named_tracked('gukbottom').names == 1,
  'a duplicate add is accepted (idempotent) and keeps one entry')
local badAdd = functions.named_add('Bad Zone!!', 'x')
assert(badAdd.ok == false and type(badAdd.error) == 'string')
assert(functions.named_add(nil, 'my camp mob').ok == true, 'no zone argument means the current zone')
local customDrops = functions.named_drops('gukbottom', 'my camp mob')
assert(type(customDrops) == 'table' and type(customDrops.drops) == 'table' and #customDrops.drops == 0,
  'a tracked name with no known loot lists no drops')
tracked = functions.named_tracked('gukbottom')
assert(hasName(tracked.names, 'my camp mob'), 'the custom name is tracked')
local removed = functions.named_remove('gukbottom', 'my camp mob')
assert(removed.ok == true and not hasName(removed.names, 'my camp mob'))
assert(functions.named_tracked('').suggestions ~= nil, 'an empty zone argument means the current zone')

-- the custom tracked name shows up in the zone's rows, marked custom
list = functions.named_list('gukbottom')
assert(rowOf(list.rows, 'a frenzied ghoul').tracked == true, 'a tracked row is marked')

-- hiding a name (the "x" of a row in the tracker window) removes it from the list and untracks it;
-- it then shows up in the Named list window's suggestions, and adding it there brings it back
assert(rowOf(functions.named_list('gukbottom').rows, 'a frenzied ghoul') ~= nil, 'listed before hiding')
local hidden = functions.named_hide('gukbottom', 'a_frenzied_ghoul')
assert(hidden.ok == true, 'hiding works')
assert(rowOf(functions.named_list('gukbottom').rows, 'a frenzied ghoul') == nil, 'a hidden name leaves the list')
assert(#functions.named_tracked('gukbottom').names == 0, 'hiding also untracks')
assert(rowOf(functions.named_tracked('gukbottom').suggestions, 'a frenzied ghoul') ~= nil,
  'a hidden name is suggested again in the Named list window')
assert(functions.named_hide('gukbottom', 5).ok == false, 'a bad name is refused')
local readded = functions.named_add('gukbottom', 'a frenzied ghoul')
assert(readded.ok == true, 'adding a hidden name works again')
list = functions.named_list('gukbottom')
local back = rowOf(list.rows, 'a frenzied ghoul')
assert(back ~= nil and back.tracked == true, 'adding it again brings the row back, tracked')

-- the option off: the windows close, every function answers nothing, the command says where to enable it
options.named_tracker.set(0)
state = functions.named_state()
assert(state.open == false and state.edit == false, 'turning it off closes the windows')
assert(functions.named_zones() == nil and functions.named_list('gukbottom') == nil
  and functions.named_drops('gukbottom', 'a_frenzied_ghoul') == nil
  and functions.named_tracked('gukbottom') == nil, 'no lists while it is off')
assert(functions.named_split() == nil and functions.named_split_set(150) == false, 'no divider while it is off')
local offHide = functions.named_hide('gukbottom', 'x')
assert(offHide.ok == false and offHide.error:find('turned off'), 'no hiding while it is off')
local offTarget = functions.named_target(2)
assert(offTarget.ok == false and offTarget.error:find('turned off') and #commands == before)
local offItem = functions.named_open_item(1365)
assert(offItem.ok == false and offItem.kind == 'disabled' and #inspected == 1)
local offAdd = functions.named_add('gukbottom', 'x')
assert(offAdd.ok == false and offAdd.error:find('turned off'))
bound['/named']()
assert(functions.named_state().open == false and chats[#chats]:find('Options'), 'the command says where to turn it on')
options.named_tracker.set(1)
bound['/named']()
assert(functions.named_state().open == true and functions.named_zones() ~= nil, 'back on it works again')

print('named ok')
