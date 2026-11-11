-- FindWalk: roles, filtering, sorting and the functions the window calls in init.lua.
-- Run from qol/.
local find = dofile('core/findwalk.lua')

-- roles from class ids
local role, trains = find.role(20)
assert(role == 'Trainer' and trains == 'Warriors', 'class id 20 is the warrior guildmaster')
role, trains = find.role(35)
assert(role == 'Trainer' and trains == 'Berserkers')
assert(select(2, find.role(31)) == 'Wizards' and select(2, find.role(30)) == 'Necromancers', 'a guildmaster trains its class')
assert(find.role(40) == 'Banker' and find.role(66) == 'Banker')
for _, id in ipairs({41, 59, 61, 67, 68, 70}) do assert(find.role(id) == 'Merchant', id) end
for _, id in ipairs({0, 1, 16, 19, 36, 39, 42, 60, 62, 63, 71, 1.5, -1, '41', false, math.huge}) do
  assert(find.role(id) == nil, tostring(id))
end
assert(find.role(nil) == nil)

-- kinds and names
assert(find.kind({npc = true}) == 'npc' and find.kind({npc = false}) == 'pc' and find.kind({}) == 'pc')
assert(find.kind({npc = true, corpse = true}) == 'corpse' and find.kind({corpse = true}) == 'corpse')
assert(find.displayName({npc = true, name = 'a_gnoll_pup00'}) == 'a gnoll pup', 'digits and underscores go')
assert(find.displayName({npc = true, name = 'Guard_Hanson'}) == 'Guard Hanson')
assert(find.displayName({npc = false, name = 'Bob2'}) == 'Bob2', 'player names keep their digits')
assert(find.displayName({npc = true, corpse = true, name = "a_rat's_corpse"}) == "a rat's corpse")
assert(find.displayName({}) == '')

local me = {id = 1, x = 0, y = 0, z = 0}
local function spawn(id, name, x, class, extra)
  local s = {id = id, name = name, x = x, y = 0, z = 0, npc = true, level = 10, class = class or 1}
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end
local zone = {
  {id = 1, name = 'Me', npc = false, x = 0, y = 0, z = 0, level = 50},
  spawn(2, 'a_gnoll_pup01', 42, 1, {level = 3}),
  spawn(3, 'a_gnoll_scout', 61, 1, {level = 6}),
  spawn(4, 'Banker_Vorn', 24, 40, {level = 1}),
  spawn(5, 'Guildmaster_Selene', 58, 31),
  spawn(6, 'Elara_the_Smith', 91, 41),
  spawn(7, 'a_gnoll_pup02', 73, 1, {level = 3}),
  spawn(8, 'Bobkin', 9, 1, {npc = false, level = 34}),
  spawn(9, 'Aedan\'s_corpse', 12, 1, {npc = false, corpse = true, level = 20}),
}
local function ids(rows)
  local out = {}
  for i, row in ipairs(rows) do out[i] = row.id end
  return table.concat(out, ',')
end

-- default order: A to Z by name; the player themselves is never listed
local rows, total = find.rows(zone, me, {types = {npc = true}})
assert(total == 8, 'total counts everything but the player: ' .. total)
assert(ids(rows) == '2,7,3,4,6,5', 'the default order is by name: ' .. ids(rows))
rows = find.rows(zone, me, {types = {npc = true}, sort = 'dist'})
assert(ids(rows) == '4,2,5,3,7,6', ids(rows))
assert(find.rows(zone, me, nil)[1] == nil, 'no types selected lists nothing')
-- levels: roles have none, others keep theirs; distance is a whole number
assert(rows[1].level == nil and rows[1].role == 'Banker' and rows[1].dist == 24)
assert(rows[2].level == 3 and rows[2].role == nil and rows[2].name == 'a gnoll pup')
assert(rows[3].role == 'Trainer' and rows[3].trains == 'Wizards')
assert(find.hasRole(rows) and not find.hasRole({rows[2]}), 'the role column needs a role in the list')

-- kinds are filters
assert(ids(find.rows(zone, me, {types = {pc = true}})) == '8')
assert(ids(find.rows(zone, me, {types = {corpse = true}})) == '9')
assert(ids(find.rows(zone, me, {types = {pc = true, corpse = true}})) == '9,8', 'by name: Aedan before Bobkin')
assert(find.rows(zone, me, {types = {npc = true}})[1].kind == 'npc')
-- a corpse has no role even with a merchant class id
local lone = {spawn(10, 'a_corpse', 5, 41, {corpse = true})}
assert(find.rows(lone, me, {types = {corpse = true}})[1].role == nil)

-- search: name, raw name and role, any case, one substring
assert(ids(find.rows(zone, me, {types = {npc = true}, text = 'GNOLL'})) == '2,7,3')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = 'gnoll pup'})) == '2,7', 'underscores read as spaces')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = 'gnoll_pup'})) == '2,7', 'the raw name matches too')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = 'banker'})) == '4', 'the role matches')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = '  trainer '})) == '5', 'trimmed')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = 'zzz'})) == '')
assert(ids(find.rows(zone, me, {types = {npc = true}, text = '%'})) == '', 'text is plain, not a pattern')

-- sorting: both ways on every column
local npc = {npc = true}
assert(ids(find.rows(zone, me, {types = npc, sort = 'dist', desc = true})) == '6,7,3,5,2,4')
-- name: A-Z, the two pups tie and keep distance order
assert(ids(find.rows(zone, me, {types = npc, sort = 'name'})) == '2,7,3,4,6,5')
assert(ids(find.rows(zone, me, {types = npc, sort = 'name', desc = true})) == '5,6,4,3,2,7')
-- level: roles have none and stay last in both directions; ties fall back to distance
assert(ids(find.rows(zone, me, {types = npc, sort = 'level'})) == '2,7,3,4,5,6')
assert(ids(find.rows(zone, me, {types = npc, sort = 'level', desc = true})) == '3,2,7,4,5,6')
-- role: A-Z, rows without one last in both directions
assert(ids(find.rows(zone, me, {types = npc, sort = 'role'})) == '4,6,5,2,3,7')
assert(ids(find.rows(zone, me, {types = npc, sort = 'role', desc = true})) == '5,6,4,2,3,7')
-- equal values order by distance, whichever way the column goes
local rats = {spawn(2, 'a_rat', 30), spawn(3, 'a_rat', 10), spawn(4, 'a_rat', 20)}
assert(ids(find.rows(rats, me, {types = npc, sort = 'name'})) == '3,4,2')
assert(ids(find.rows(rats, me, {types = npc, sort = 'name', desc = true})) == '3,4,2', 'descending reverses the column, not the ties')

-- unknown position: distance is blank and those rows go last
local nowhere = find.rows({spawn(2, 'a_rat', 30), {id = 3, name = 'a_bat', npc = true}}, me, {types = npc, sort = 'dist'})
assert(ids(nowhere) == '2,3' and nowhere[2].dist == nil)
nowhere = find.rows({spawn(2, 'a_rat', 30)}, nil, {types = npc})
assert(nowhere[1].dist == nil, 'no player record: no distances')
nowhere = find.rows({spawn(2, 'a_rat', 30, 1, {x = 0 / 0})}, me, {types = npc})
assert(nowhere[1].dist == nil, 'a NaN position gives no distance')

-- a click on a column head
local key, reverse = find.nextSort('dist', false, 'dist')
assert(key == 'dist' and reverse == true, 'the same column reverses')
key, reverse = find.nextSort('dist', true, 'dist')
assert(key == 'dist' and reverse == false)
key, reverse = find.nextSort('dist', true, 'name')
assert(key == 'name' and reverse == false, 'another column starts ascending')

-- bad queries are repaired, not trusted
local q = find.query({types = 'x', text = 5, sort = 'bogus', desc = 'yes'})
assert(q.sort == 'name' and q.desc == false and q.text == '' and not q.types.npc)
q = find.query({text = string.rep('a', 500)})
assert(#q.text == find.MAX_TEXT)
assert(find.query(nil).sort == 'name' and find.query(nil).desc == false, 'name A to Z is the default')
local none, count = find.rows('nope', me, {})
assert(#none == 0 and count == 0)
assert(#find.rows({false, 5, {}, {id = 0}, {id = 1.5}}, me, {types = npc}) == 0)

-- plain rows carry no sort helpers
local plain = find.plain(find.rows(zone, me, {types = npc, sort = 'dist'}))
assert(plain[1].sortKey == nil and plain[1].exact == nil and plain[1].id == 4)

-- init.lua: the command, the menu entry and the window's functions
local functions, bound, menu, commands, refuseCommands = {}, {}, {}, {}, false
local player = {spawn_id = 1, in_zone = true}
local hs = {
  option = function() end,
  ui_function = function(name, fn) functions[name] = fn end,
  menu = function(label, command) menu[#menu + 1] = {label, command} end,
  player = function() return player end,
  spawns = function() return zone end,
  spawn = function(id)
    for _, s in ipairs(zone) do if s.id == id then return s end end
  end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function()
  return {
    pickle = function() end,
    bind = function(name, fn) bound[name] = fn end,
    cmd = function(line)
      if refuseCommands then error('/target needs the server\'s target permission') end
      commands[#commands + 1] = line
    end,
  }
end
dofile('init.lua')
assert(bound['/findW'], '/findW is bound')
assert(menu[1] and menu[1][1] == 'Find' and menu[1][2] == '/findW', 'the menu entry runs the command')
local state = functions.findwalk_state()
assert(state.open == false and state.search == '' and state.serial == 0)
bound['/findW']()
assert(functions.findwalk_state().open == true, '/findW opens it')
bound['/findW']()
assert(functions.findwalk_state().open == false, '/findW again closes it')
bound['/findW']('gnoll', 'pup')
state = functions.findwalk_state()
assert(state.open and state.search == 'gnoll pup' and state.serial == 1, 'a search opens it with that text')
bound['/findW']('gnoll')
assert(functions.findwalk_state().open and functions.findwalk_state().serial == 2, 'a search never closes it')
functions.findwalk_close()
assert(functions.findwalk_state().open == false)

local result = functions.findwalk_rows({types = {npc = true}, sort = 'dist'})
assert(result.total == 8 and #result.rows == 6 and result.has_role == true and result.rows[1].id == 4)
assert(result.rows[1].sortKey == nil, 'plain rows cross to the window')
result = functions.findwalk_rows({types = {npc = true}, text = 'gnoll'})
assert(#result.rows == 3 and result.has_role == false)
player.in_zone = false
result = functions.findwalk_rows({types = {npc = true}})
assert(#result.rows == 0 and result.total == 0 and result.has_role == false, 'nothing while not in a zone')
player.in_zone = true
player.spawn_id = nil
result = functions.findwalk_rows({types = {npc = true}})
assert(#result.rows == 6 and result.rows[1].dist == nil, 'without the player no distances')
player.spawn_id = 1

-- Travel to: the spawn is targeted, then walked to; nothing is sent for anything else
local sent = functions.findwalk_travel(4)
assert(sent.ok == true and commands[1] == '/target id 4' and commands[2] == '/nav id 4', table.concat(commands, ' | '))
local before = #commands
for _, bad in ipairs({0, -1, 1.5, '4', false, math.huge, 0 / 0}) do
  local refused = functions.findwalk_travel(bad)
  assert(refused.ok == false and #commands == before, tostring(bad))
end
local gone = functions.findwalk_travel(999)
assert(gone.ok == false and gone.error:find('no longer') and #commands == before, 'a despawned spawn sends nothing')
-- a command the client refuses is reported, and the second one is not sent after it
refuseCommands = true
local refused = functions.findwalk_travel(4)
assert(refused.ok == false and refused.error:find('refused') and refused.error:find('permission') and #commands == before)

-- the option: on at first, in Options -> Plugins; off, nothing opens, lists or travels
local options, chats = {}, {}
hs.option = function(o) options[o.name] = o end
hs.chat = function(text) chats[#chats + 1] = text end
functions, bound, menu = {}, {}, {}
dofile('init.lua')
assert(options.findwalk and options.findwalk.label == 'Find window (/findW)' and options.findwalk.get() == 1)
refuseCommands = false
bound['/findW']()
assert(functions.findwalk_state().open == true)
options.findwalk.set(0)
assert(options.findwalk.get() == 0)
assert(functions.findwalk_state().open == false, 'turning it off closes the window')
assert(functions.findwalk_rows({types = {npc = true}}) == nil, 'no rows while it is off')
local before2 = #commands
local off = functions.findwalk_travel(4)
assert(off.ok == false and off.error:find('turned off') and #commands == before2, 'nothing is sent while it is off')
bound['/findW']()
assert(functions.findwalk_state().open == false and chats[1]:find('Options'), 'the command says where to turn it on')
options.findwalk.set(1)
bound['/findW']()
assert(functions.findwalk_state().open == true and functions.findwalk_rows({types = {npc = true}}) ~= nil)
print('find ok')
