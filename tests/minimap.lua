-- Run from qol/. Checks the minimap adapter against a fake eq/ui; the client's own minimap is not loaded.
local options, functions = {}, {}
local player = {spawn_id = 1, target_id = 2, in_zone = true}
local me = {x = 10, y = -30}       -- map point (30, -10)
local target = {x = 40, y = -60}   -- map point (60, -40)
local hs = {
  option = function(option) options[option.name] = option end,
  ui_function = function(name, fn) functions[name] = fn end,
  player = function() return player end,
  spawn = function(id) if id == 1 then return me end assert(id == 2) return target end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function() return {pickle = function() end} end
dofile('init.lua')

local function adapter(mode)
  local state = {lines = {}, circles = {}, clips = 0, windows = {}, base = 0, calls = 0, plugin = true,
    north = table.pack(0, -1, 15, 25, 0.5)}
  local function drawMinimap(...)
    state.calls = state.calls + 1
    state.lastArgs = table.pack(...)
    return table.unpack(state.north, 1, state.north.n)
  end
  local api = {
    DrawMinimap = drawMinimap,
    Plugin = function(name)
      assert(name == 'script:qol')
      if state.plugin then return {map_target = functions.map_target} end
    end,
  }
  local mapApi = {DrawMinimap = drawMinimap}
  if mode == 'missing' then
    api.DrawMinimap, mapApi.DrawMinimap = nil, nil
  elseif mode == 'facade' then
    api.DrawMinimap = nil -- only the pack's hs.UI name exists
  end
  -- Model the host's read-only views: a write into either shared table fails the test, and the fixture
  -- keeps the client functions so the test can prove they were not replaced.
  local function view(tbl)
    return setmetatable({}, {__index = tbl, __newindex = function() error('shared API write') end})
  end
  local readonly = view(api)
  local hsApi = view({UI = view({map = view(mapApi)})})
  local ui = {
    window = function(name, fn) state.windows[name] = fn end,
    base_window = function() state.base = state.base + 1 end,
    PushClipRect = function() state.clips = state.clips + 1 end,
    PopClipRect = function() assert(state.clips > 0) state.clips = state.clips - 1 end,
    DrawLine = function(...) assert(state.clips > 0) state.lines[#state.lines + 1] = {...} end,
    DrawCircleFilled = function(...) state.circles[#state.circles + 1] = {...} end,
  }
  local env = setmetatable({eq = readonly, hs = hsApi, ui = ui, rotating = true},
    {__index = _G})
  env.dofile = function(path)
    assert(path == 'minimap.lua', 'load stock minimap, never the adapter itself')
    if mode == 'failed' or state.dofileFails then error('minimap unavailable') end
    -- The installed Modern pack calls hs.UI.map.DrawMinimap and captures its API once, as map.lua does.
    local call = mode == 'legacy' and 'eq.DrawMinimap' or 'API.map.DrawMinimap'
    return assert(load(([[local API = hs.UI
    ui.window('Minimap', function()
      results = table.pack(%s(100, 100, 50, 100, rotating))
    end)]]):format(call), 'stock minimap fixture', 't', env))()
  end
  assert(loadfile('ui/modern/minimaptargetline.lua', 't', env))()
  state.env, state.original, state.hsApi, state.draw = env, readonly, hsApi, drawMinimap
  return state
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local function sameTuple(a, b)
  if a.n ~= b.n then return false end
  for i = 1, a.n do
    if a[i] ~= b[i] then return false end
  end
  return true
end

-- North up: offset (30, -30) map units at 0.5 px per unit.
local s = adapter()
s.windows.Minimap()
assert(s.calls == 1 and s.clips == 0 and #s.lines == 1 and #s.circles == 1)
local line = s.lines[1]
assert(line[1] == 100 and line[2] == 100 and near(line[3], 115) and near(line[4], 85))
assert(s.original.DrawMinimap ~= s.env.eq.DrawMinimap, 'API intercepted locally only')
assert(s.hsApi.UI.map.DrawMinimap ~= s.env.hs.UI.map.DrawMinimap, 'pack facade intercepted locally only')
assert(s.original.DrawMinimap == s.draw and s.hsApi.UI.map.DrawMinimap == s.draw,
  'the shared views keep the client functions')
assert(sameTuple(s.lastArgs, table.pack(100, 100, 50, 100, true)), 'all arguments pass through, the rotation flag included')
assert(sameTuple(s.env.results, table.pack(0, -1, 15, 25, 0.5)), 'all return values pass through')

-- A nil in the client's returns still passes through; the line still draws from the first two.
s.north = table.pack(0, -1, nil, 25, 0.5)
local drawn = #s.lines
s.windows.Minimap()
assert(sameTuple(s.env.results, table.pack(0, -1, nil, 25, 0.5)), 'a nil return value passes through')
assert(#s.lines == drawn + 1)
s.north = table.pack(0, -1)

-- Older files call the flat eq name; the same wrapper answers it.
local legacy = adapter('legacy')
legacy.windows.Minimap()
assert(legacy.calls == 1 and #legacy.lines == 1 and #legacy.circles == 1)

-- Rotation: heading east of north turns the map; north points along (1, 0), so map offsets turn with it.
s.north = table.pack(1, 0)
s.windows.Minimap()
line = s.lines[#s.lines]
assert(near(line[3], 100 + 15) and near(line[4], 100 + 15), 'rotated with the player')

-- A target beyond the range stops at the circle's edge, without the end dot.
s.north = table.pack(0, -1)
target = {x = 400, y = -600} -- far: map offset (570, -370)
local dots = #s.circles
s.windows.Minimap()
line = s.lines[#s.lines]
assert(near(math.sqrt((line[3] - 100) ^ 2 + (line[4] - 100) ^ 2), 50) and #s.circles == dots)
target = {x = 40, y = -60}

-- A reload runs in the same plugin globals (lua_host.cpp keeps a folder's environment), so it must
-- replace its hook there: one client call and one overlay line per frame, not one more of each.
local calls, lines = s.calls, #s.lines
assert(loadfile('ui/modern/minimaptargetline.lua', 't', s.env))()
assert(s.env.eq ~= s.original and s.env.hs ~= s.hsApi, 'a reload keeps the shadow instead of restoring the client view')
assert(s.env.eq.DrawMinimap ~= s.original.DrawMinimap, 'a reload keeps the hook')
s.windows.Minimap()
assert(s.calls == calls + 1 and #s.lines == lines + 1, 'a reload replaces the wrapper instead of stacking it')
assert(s.original.DrawMinimap == s.draw and s.hsApi.UI.map.DrawMinimap == s.draw,
  'a reload still leaves the shared views alone')

-- A failed pack load drops this script's hook; the names then pass straight through.
s.dofileFails = true
assert(loadfile('ui/modern/minimaptargetline.lua', 't', s.env))()
s.dofileFails = false
s.windows.Minimap()
assert(s.base == 1, 'a failed load keeps the bare minimap window')
assert(s.env.eq.DrawMinimap == s.draw and s.env.hs.UI.map.DrawMinimap == s.draw,
  'a failed load clears the hook instead of restoring a stale wrapper')

-- The next reload installs the hook again and draws once.
assert(loadfile('ui/modern/minimaptargetline.lua', 't', s.env))()
s.windows.Minimap()
assert(s.calls == calls + 2 and #s.lines == lines + 2)

local function hidden()
  local count = #s.lines
  s.windows.Minimap()
  assert(#s.lines == count and s.clips == 0)
end
options.map_target_line.set(0)
hidden()
options.map_target_line.set(1)
s.plugin = false
hidden()
s.plugin = true
target = nil
hidden()
target = {x = 40, y = -60}
player.target_id = 1
hidden()
player.target_id = 2
me = nil -- no player point: nothing to draw from
hidden()
me = {x = 10, y = -30}
s.north = table.pack(0/0, 0)
hidden()
s.north = table.pack(0, -1)

local missing = adapter('missing')
missing.windows.Minimap()
assert(missing.base == 1 and missing.env.eq == missing.original and missing.env.hs == missing.hsApi,
  'with no client function nothing is shadowed and the bare minimap window opens')
local failed = adapter('failed')
failed.windows.Minimap()
assert(failed.base == 1 and failed.env.eq.DrawMinimap == failed.draw
  and failed.env.hs.UI.map.DrawMinimap == failed.draw, 'a failed pack load leaves both names passing straight through')

-- A client that only has the pack's facade name still loads the pack and draws.
local facade = adapter('facade')
facade.windows.Minimap()
assert(facade.calls == 1 and #facade.lines == 1, 'a facade-only client still loads the pack and draws')
assert(facade.env.hs.UI.map.DrawMinimap ~= facade.hsApi.UI.map.DrawMinimap, 'the facade name is hooked')
print('minimap target line: ok')
