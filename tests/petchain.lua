-- Pet chain: the option, the /petchain command, the packet hooks, the tick state machine and the option-off
-- behavior. Run from qol/.
local functions, bound, menu, commands, cmdfs, chats, options = {}, {}, {}, {}, {}, {}, {}
local packets = {} -- [opcode] = fn
local now = 1000000
local target = 0
local zoneId = 66
local dead = false
-- spawn proxies by id: {type=, hp=, mezzed=, surname=}
local spawnDefs = {}
local xtargets = {} -- 1-based {type=, spawn_id=, name=}
local player = { spawn_id = 1, in_zone = true, zone_id = 66, xtarget_slots = 0 }

local hs = {
  option = function(o) options[o.name] = o end,
  ui_function = function(name, fn) functions[name] = fn end,
  menu = function(label, command) menu[#menu + 1] = { label, command } end,
  hooks = function() end,
  chat = function(text) chats[#chats + 1] = text end,
  on_packet = function(stream, dir, opcode, fn) packets[opcode] = fn end,
  player = function() return player end,
  spawns = function() return {} end,
  spawn = function() end,
  zone_name = function(id) if id == 66 then return 'gukbottom' end end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function()
  return {
    pickle = function() end,
    bind = function(name, fn) bound[name] = fn end,
    cmd = function(line) commands[#commands + 1] = line end,
    cmdf = function(fmt, ...) cmdfs[#cmdfs + 1] = string.format(fmt, ...) end,
    gettime = function() return now end,
    TLO = {
      Target = { ID = function() return target end },
      Me = { Dead = function() return dead end },
      Zone = { ID = function() return zoneId end },
      Spawn = function(sel)
        local id = tonumber(sel:match('id (%d+)'))
        local def = id and spawnDefs[id]
        local function proxy()
          if not def then return nil end
          return def
        end
        local sp = setmetatable({}, { __index = function(_, k)
          if k == 'Type' then return function() return def and def.type or nil end end
          if k == 'PctHPs' then return function() return def and def.hp or nil end end
          if k == 'Mezzed' then return function() return def and def.mezzed or nil end end
          if k == 'Surname' then return function() return def and def.surname or '' end end
          if k == 'ID' then return function() return id end end
          return function() return def and def[k] or nil end
        end })
        -- the proxy itself is callable: sp() returns the def (nil when the spawn is gone)
        return setmetatable({ call = function() return def end }, {
          __call = function() return def end,
          __index = function(_, k) return sp[k] end,
        })
      end,
    },
  }
end
dofile('init.lua')

-- the option, the command, the menu entry, the tick function, the packet hooks
assert(options.pet_chain and options.pet_chain.label == 'Pet chain (/petchain)' and options.pet_chain.get() == 1,
  'pet chain is an option in Options -> Plugins, on by default')
assert(bound['/petchain'], '/petchain is bound')
local menuHasPet
for _, e in ipairs(menu) do if e[1] == 'Pet chain' and e[2] == '/petchain' then menuHasPet = true end end
assert(menuHasPet, 'the Plugins menu entry Pet chain runs /petchain')
assert(type(functions.petchain_tick) == 'function', 'petchain_tick is registered')
assert(type(packets[0x0159]) == 'function' and type(packets[0x2b2d]) == 'function',
  'the outgoing pet-order and say packets are hooked')
assert(type(packets[0x6517]) == 'function', 'the incoming death packet is hooked')

-- a mob on the extended target list, alive, not a pet, not mezzed
spawnDefs[10] = { type = 'NPC', hp = 80, mezzed = nil, surname = '' }
player.xtarget_slots = 1
xtargets[1] = { type = 1, spawn_id = 10, name = 'a gnoll' }
hs.xtarget = function(i) return xtargets[i] end

local function tick(dt)
  now = now + (dt or 300) -- default one 250 ms+ tick
  functions.petchain_tick()
end

-- an outgoing /pet attack (OP_PetCommands, cmd 2) starts the chain on your target
target = 10
packets[0x0159](0x0159, string.pack('<I4I4', 2, 10))
tick() -- the current mob is alive and watched, nothing to send yet
assert(#cmdfs == 0, 'no target change while the sent-on mob is alive')

-- the mob dies: the chain targets the next one on the list
spawnDefs[11] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[1] = { type = 1, spawn_id = 11, name = 'a ghoul' }
spawnDefs[10] = nil
tick()
assert(cmdfs[1] == '/target id 11', 'the chain targets the next mob on the list: ' .. tostring(cmdfs[1]))
target = 11
tick() -- the target took: the pet order goes out (style follows the starting order: /pet attack)
assert(commands[1] == '/pet attack', 'the pets are sent with /pet attack: ' .. tostring(commands[1]))

-- the list runs empty: the chain stops quietly
spawnDefs[11] = nil
xtargets[1] = { type = 1, spawn_id = 0, name = '' }
local before = #commands
tick(); tick()
assert(#commands == before, 'no order when the list has no suitable mob left')

-- a #petcmd attack say starts a petcmd chain on the next mob
spawnDefs[12] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[1] = { type = 1, spawn_id = 12, name = 'a skeleton' }
packets[0x2b2d](0x2b2d, 'some text #petcmd attack all trailing')
tick() -- target 12
assert(cmdfs[#cmdfs] == '/target id 12')
target = 12
tick() -- order out
assert(commands[#commands] == '/say #petcmd attack all')

-- back off stops the chain
packets[0x0159](0x0159, string.pack('<I4I4', 28, 0))
before = #commands
tick(); tick()
assert(#commands == before, 'back off stops the chain')

-- /petchain status reports through chat
bound['/petchain']('status')
assert(chats[#chats]:find('off, idle') or chats[#chats]:find('on, idle'), 'status says idle after back off: ' .. chats[#chats])

-- the last mob at full health is never skipped: the order keeps going out
spawnDefs[20] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[1] = { type = 1, spawn_id = 20, name = 'a zombie' }
target = 20
packets[0x0159](0x0159, string.pack('<I4I4', 2, 20)) -- chain starts on 20
before = #commands
for cycle = 1, 4 do
  tick(16000) -- past the 15 s stall: the order is sent again
  tick(300)   -- the target took: the pet order goes out
end
assert(#commands - before >= 4, 'the last mob keeps getting the order, never skipped: ' .. (#commands - before))

-- with a second mob on the list, the stalling one is skipped after MAX_TRIES and the chain moves on
spawnDefs[21] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[2] = { type = 0, spawn_id = 21, name = 'a skeleton' }
player.xtarget_slots = 2
tick(16000)
assert(cmdfs[#cmdfs] == '/target id 21', 'a skipped mob with another left: the chain moves on: ' .. tostring(cmdfs[#cmdfs]))
target = 21
tick(300)
assert(#commands > before, 'the order goes out for the next mob')

-- when only the skipped mob is left, the chain waits for the minute instead of stopping, then takes it again
spawnDefs[21] = nil
xtargets[2] = { type = 0, spawn_id = 0, name = '' }
before = #commands
tick(300)
assert(#commands == before, 'no order while the only mob left is skipped for a while')
tick(61000) -- the skip minute runs out
assert(cmdfs[#cmdfs] == '/target id 20', 'after the minute the last mob is targeted again: ' .. tostring(cmdfs[#cmdfs]))

-- the option off: the tick does nothing, the command says where to enable it
options.pet_chain.set(0)
spawnDefs[13] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[1] = { type = 1, spawn_id = 13, name = 'a zombie' }
packets[0x0159](0x0159, string.pack('<I4I4', 2, 13)) -- hook ignores it: not enabled
before = #commands
local cmdfsBefore = #cmdfs
tick(); tick()
assert(#commands == before and #cmdfs == cmdfsBefore, 'nothing while the option is off')
assert(functions.petchain_tick() == nil, 'the tick answers nil while off')
bound['/petchain']('status')
assert(chats[#chats]:find('Options'), 'the command says where to turn it on: ' .. chats[#chats])

-- A death packet for the current mob wakes the chain on the next frame even if the normal tick just ran.
options.pet_chain.set(1)
spawnDefs[30] = { type = 'NPC', hp = 100, surname = '' }
spawnDefs[31] = { type = 'NPC', hp = 100, surname = '' }
xtargets[1] = { type = 1, spawn_id = 30 }
xtargets[2] = { type = 1, spawn_id = 31 }
player.xtarget_slots = 2
target = 30
packets[0x0159](0x0159, string.pack('<I4I4', 2, 30))
tick(300)
local targetsBefore = #cmdfs
local function deathPacket(id) return string.pack('<I4I4I4I4I4I4I4I4', id, 0, 0, 0, 0, 0, 0, 0) end
packets[0x6517](0x6517, deathPacket(31)) -- unrelated death
packets[0x6517](0x6517, string.pack('<I4', 30)) -- truncated packet
tick(1)
assert(#cmdfs == targetsBefore, 'unrelated and truncated death packets do not wake the chain')
packets[0x6517](0x6517, deathPacket(30))
assert(#cmdfs == targetsBefore, 'do not change target inside the packet hook')
-- The client can still report the old mob alive until it finishes processing the packet.
tick(1)
assert(cmdfs[#cmdfs] == '/target id 31', 'current death immediately selects the next mob')
target = 31
local ordersBefore = #commands
tick(1)
assert(#commands == ordersBefore + 1 and commands[#commands] == '/pet attack',
  'the confirmed target gets the order on the next frame')
packets[0x0159](0x0159, string.pack('<I4I4', 28, 0))
packets[0x6517](0x6517, deathPacket(31))
targetsBefore = #cmdfs
tick(1)
assert(#cmdfs == targetsBefore, 'death after back off does not restart the chain')

print('petchain ok')
