-- Pet chain: after you send your pets in (/pet attack, the pet window's Attack button, a hot button), it keeps
-- going down your extended target list for you. When the mob the pets were sent on is gone, it targets the next
-- living NPC on the list and sends the pets on it, so you do not have to select each one yourself.
--
-- Ported from the standalone petchain script into the QoL add-on. Differences: no own main loop (the tick comes
-- from the UI frame loop via the petchain_tick ui_function, throttled to TICK_MS here), the option lives in
-- Options -> Plugins (pet_chain), and the /target wait is a pending state instead of a blocking mq.delay, so the
-- tick never blocks a plugin call. A mob that is the last one on the list is never skipped for a
-- minute, and the chain waits out the skip list instead of stopping while mobs remain.
--
-- /petchain               toggle on / off
-- /petchain on|off        set it
-- /petchain status        what it is doing
-- /petchain go [pet]      start now on your target: "#petcmd attack all" (Triune / NMS), or with "pet" /pet attack
-- /petchain group <g>     which pets #petcmd commands: all (default), a class as the pet window lists it, swarm
--
-- Needs the target, actions, read, commands and packets capabilities (on_packet watches the pet orders).
local M = {}

local OP_PET_COMMANDS = 0x0159
local OP_CHANNEL_MESSAGE = 0x2b2d  -- net/opcodes_rof2.inc; the server's #petcmd goes out as a say
-- net/pet_packets.h: kPetAttack 2, kPetFollow 4, kPetGuard 5, kPetBackOff 28, kPetGetLost 29
local PET_ATTACK, PET_BACK_OFF, PET_FOLLOW, PET_GUARD, PET_GET_LOST = 2, 28, 4, 5, 29

local TICK_MS = 250
local BLACKLIST_MS = 60000
local MAX_TRIES = 3
local STALL_MS = 15000          -- no health lost for this long: the order goes out again
local TARGET_WAIT_MS = 600      -- how long a /target id may take before it counts as failed

function M.attach(mq, hs, opts)
  local enabled = opts.enabled        -- function() -> boolean (the Options -> Plugins switch)
  local say = opts.say                -- function(text, color)

  local PET_GROUP = 'all'             -- which pets #petcmd commands: all, a class (as the pet window lists it) or swarm
  local style = 'petcmd'              -- how the pets are sent: 'petcmd' (Triune / NMS: #petcmd attack all) or 'pet' (/pet attack)
  local chaining = false              -- an attack order started a chain
  local current = nil                 -- the mob the pets were last sent on
  local tries = {}                    -- [id] = {n = orders sent, at = when last}
  local ignore = {}                   -- [id] = until when
  local zone = nil
  local seen = false                  -- the current mob was on the extended target list at least once
  local watch_hp, watch_at = 100, 0   -- the current mob's lowest health seen, and when it last dropped
  local kick = false                  -- /petchain go: send the order on the current mob at the next tick
  local pending = nil                 -- {id, since, count}: a /target id we wait for before the order goes out
  local lastTick = 0

  local function now() return mq.gettime() end

  local function alive(id)
    local sp = mq.TLO.Spawn('id ' .. id)
    if not sp() then return false end
    local t = sp.Type()
    if t ~= 'NPC' then return false end
    return (tonumber(sp.PctHPs()) or 0) > 0
  end

  local function hp_of(id)
    return tonumber(mq.TLO.Spawn('id ' .. id).PctHPs()) or 0
  end

  local function target_id()
    return tonumber(mq.TLO.Target.ID()) or 0
  end

  local function on_list(id)
    local slots = tonumber(hs.player() and hs.player().xtarget_slots) or 0
    for i = 1, slots do
      local x = hs.xtarget(i)
      if x and x.spawn_id == id then return true end
    end
    return false
  end

  local function is_pet(sp)
    if sp.Type() == 'Pet' then return true end
    local surname = (sp.Surname() or ''):lower()
    return surname:find("['`]s pet$") ~= nil
  end

  local function stop(why)
    if chaining and why then say(why) end
    chaining, current, kick, pending = false, nil, false, nil
    tries = {}
  end

  -- The next mob: a living NPC in an extended target slot, not a pet, not mezzed, not on the ignore list. The first
  -- in slot order, but one that is on me comes before one that is not (slot type 1 = auto hater).
  -- every living, non-pet, non-mezzed mob on the extended target list, the ignore list not applied,
  -- optionally except one id (the current one)
  local function list_mobs(except)
    local out = {}
    local slots = tonumber(hs.player() and hs.player().xtarget_slots) or 0
    for i = 1, slots do
      local x = hs.xtarget(i)
      local id = x and x.spawn_id or 0
      if id ~= 0 and id ~= except then
        local sp = mq.TLO.Spawn('id ' .. id)
        if sp() and alive(id) and not is_pet(sp) and sp.Mezzed() == nil then
          out[#out + 1] = id
        end
      end
    end
    return out
  end

  local function next_mob()
    local best, best_hater
    for _, id in ipairs(list_mobs(current)) do
      if (ignore[id] or 0) < now() then
        -- slot type 1 = auto hater: one that is on me comes before one that is not
        local slots = tonumber(hs.player() and hs.player().xtarget_slots) or 0
        local hater = false
        for i = 1, slots do
          local x = hs.xtarget(i)
          if x and x.spawn_id == id then hater = x.type == 1 break end
        end
        if not best or (hater and not best_hater) then
          best, best_hater = id, hater
        end
      end
    end
    return best
  end

  local function try(id)
    local t = tries[id] or { n = 0, at = 0 }
    t.n, t.at = t.n + 1, now()
    tries[id] = t
    return t.n
  end

  -- Starts waiting for the target; the pet order itself goes out in tick() once the target took (or failed).
  local function send_pets(id, count)
    if pending then return end
    mq.cmdf('/target id %d', id)
    pending = { id = id, since = now(), count = count }
  end

  local function send_order()
    if style == 'petcmd' then
      mq.cmd('/say #petcmd attack ' .. PET_GROUP) -- all pets in one order, as the Triune pet window does
    else
      mq.cmd('/pet attack')
    end
  end

  local function tick()
    if not enabled() or not chaining then return end
    local t = now()
    if t - lastTick < TICK_MS then return end
    lastTick = t
    if mq.TLO.Me.Dead() == true then return stop('you died, stopped.') end
    local z = mq.TLO.Zone.ID()
    if zone and z ~= zone then zone = z; return stop('zone changed, stopped.') end
    zone = z

    -- /petchain go: the order on the mob the chain starts with.
    if kick then
      kick = false
      if current and alive(current) then send_pets(current, false); return end
    end

    -- A /target we are waiting for: the order goes out when it took; after TARGET_WAIT_MS it counts as failed.
    if pending then
      local p = pending
      if target_id() == p.id then
        pending = nil
        send_order()
        if p.id ~= current then seen = false end
        current = p.id
        watch_hp, watch_at = hp_of(p.id), now()
        if p.count then try(p.id) end
      elseif now() - p.since > TARGET_WAIT_MS then
        pending = nil
        -- a mob we cannot target is skipped for a minute, but never when it is the last one left
        if try(p.id) >= MAX_TRIES and #list_mobs(p.id) > 0 then
          ignore[p.id] = now() + BLACKLIST_MS
          say('could not target mob ' .. p.id .. ', skipped for a minute.')
        else
          send_pets(p.id, p.count) -- try the target again at the next tick
        end
      end
      return
    end

    -- The client does not tell us what a pet is fighting, so "done" is the mob's death or it leaving the list (once
    -- it was on it). While it is up: wait as long as its health drops, else send the order again.
    if current and alive(current) then
      local listed = on_list(current)
      if listed then seen = true end
      if listed or not seen then
        local hp = hp_of(current)
        if hp < watch_hp then watch_hp, watch_at = hp, now(); return end
        if now() - watch_at < STALL_MS then return end
        local full = hp >= 100
        -- at full health after MAX_TRIES orders the mob is skipped for a minute, but never when it is
        -- the last one on the list: then the order just goes out again
        if full and (tries[current] and tries[current].n or 0) >= MAX_TRIES and #list_mobs(current) > 0 then
          ignore[current] = now() + BLACKLIST_MS
          say('the pets do not reach mob ' .. current .. ', skipped for a minute.')
        else
          send_pets(current, full)  -- a hurt mob is being fought: the order again, but it is never skipped
          watch_at = now()
          return
        end
      end
    end

    local id = next_mob()
    if id then send_pets(id, false); return end
    -- nothing eligible right now: if mobs are still on the list (all skipped for a while), wait for the
    -- ignore list to run out instead of stopping; only when the list is really empty is the chain done
    if #list_mobs(current) > 0 then return end
    return stop()
  end

  -- Starts a chain on the mob the order named, else your target. Already chaining: an order on another living NPC
  -- switches the chain to that mob (the old one stays on the list and gets its turn later), and the chain goes on
  -- the way you last ordered.
  local function begin(how, target)
    local id = target ~= 0 and target or (target_id() ~= 0 and target_id() or nil)
    if chaining then
      if not id or id == current or not alive(id) then return end
      local sp = mq.TLO.Spawn('id ' .. id)
      if is_pet(sp) then return end
      style = how
      current = id
      ignore[id] = nil
      seen = false
      watch_hp, watch_at = hp_of(id), now()
      return
    end
    style = how
    chaining = true
    zone = mq.TLO.Zone.ID()
    current = id
    tries = {}
    seen = false
    watch_hp, watch_at = 100, now()
  end

  -- An attack order from you starts the chain; back off / follow / guard stops it.
  pcall(hs.on_packet, 'zone', 'out', OP_PET_COMMANDS, function(_, data)
    if not enabled() or #data < 8 then return nil end
    local cmd, target = string.unpack('<I4I4', data)
    if cmd == PET_ATTACK then
      begin('pet', target)
    elseif cmd == PET_BACK_OFF or cmd == PET_FOLLOW or cmd == PET_GUARD or cmd == PET_GET_LOST then
      stop()
    end
    return nil
  end)

  -- The server's #petcmd goes out as a say (OP_ChannelMessage). The pet window's "Attack" for All, a class or swarm
  -- sends "#petcmd attack <group>"; a text search is enough, so the packet's layout does not matter.
  pcall(hs.on_packet, 'zone', 'out', OP_CHANNEL_MESSAGE, function(_, data)
    if not enabled() then return nil end
    local text = data:lower()
    local word, group = text:match('#petcmd%s+(%a+)%s*([%w_%-]*)')
    if not word then return nil end
    if word == 'attack' then
      if group ~= '' then PET_GROUP = group end
      begin('petcmd', 0)
    elseif word == 'follow' or word == 'guard' or word:find('^back') or word == 'getlost' or word == 'sit' then
      stop()
    end
    return nil
  end)

  local function command(a)
    a = (a or ''):lower()
    local sub, rest = a:match('^(%S*)%s*(.*)$')
    if sub == 'go' then
      begin(rest == 'pet' and 'pet' or 'petcmd', 0)
      kick = true -- the tick sends the order: a bind cannot wait for the target
      return
    elseif sub == 'group' then
      PET_GROUP = rest ~= '' and rest or 'all'
      say('commands the pets: ' .. PET_GROUP .. '.')
      return
    end
    if a == 'on' then
      -- the Options -> Plugins switch owns the on/off; the command reports and starts nothing
      say('pet chain is ' .. (enabled() and 'on' or 'off') .. ' (Options -> Plugins).')
      return
    elseif a == 'status' then
      say((enabled() and 'on' or 'off') .. (chaining and (', chaining' .. (current and (' (mob ' .. current .. ')') or '')) or ', idle') .. '.')
      return
    elseif a ~= '' then
      say('/petchain [status | go [pet] | group <all|class|swarm>]')
      return
    end
    say('pet chain is ' .. (enabled() and 'on' or 'off') .. ' (Options -> Plugins). It starts with your next pet attack.')
  end

  -- one error in a tick must not stall the chain silently: report it and stop, as the standalone script did
  local function tickSafe()
    local ok, err = pcall(tick)
    if not ok then stop('error: ' .. tostring(err)) end
  end

  return { tick = tickSafe, command = command }
end

return M
