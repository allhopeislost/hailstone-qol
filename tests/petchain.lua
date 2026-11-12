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

-- a mob on the extended target list, alive, not a pet, not mezzed
spawnDefs[10] = { type = 'NPC', hp = 80, mezzed = nil, surname = '' }
player.xtarget_slots = 1
xtargets[1] = { type = 1, spawn_id = 10, name = 'a gnoll' }
hs.xtarget = function(i) return xtargets[i] end

local function tick()
  now = now + 300 -- past the 250 ms tick rate
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

-- the option off: the tick does nothing, the command says where to enable it
options.pet_chain.set(0)
spawnDefs[13] = { type = 'NPC', hp = 100, mezzed = nil, surname = '' }
xtargets[1] = { type = 1, spawn_id = 13, name = 'a zombie' }
packets[0x0159](0x0159, string.pack('<I4I4', 2, 13)) -- hook ignores it: not enabled
before = #commands
tick(); tick()
assert(#commands == before and #cmdfs == 2, 'nothing while the option is off')
assert(functions.petchain_tick() == nil, 'the tick answers nil while off')
bound['/petchain']('status')
assert(chats[#chats]:find('Options'), 'the command says where to turn it on: ' .. chats[#chats])

print('petchain ok')
