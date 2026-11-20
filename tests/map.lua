-- Run from qol/. Optional argument exercises the installed/reference Modern map too:
-- lua tests/map.lua /path/to/Hailstone-dev/ui/modern/map.lua
local options, functions = {}, {}
local player = {spawn_id = 1, target_id = 2, in_zone = true}
local target = {x = 40, y = -60}
local playerReads, spawnReads = 0, 0
local hs = {
  option = function(option) options[option.name] = option end,
  ui_function = function(name, fn) functions[name] = fn end,
  player = function() playerReads = playerReads + 1 return player end,
  spawn = function(id)
    if id == 1 then return {x = 10, y = -30} end -- the player
    assert(id == 2)
    spawnReads = spawnReads + 1
    return target
  end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function() return {pickle = function() end} end
dofile('init.lua')
assert(options.map_target_line.get() == 1)
local point = functions.map_target()
assert(point.x == 60 and point.y == -40, 'world-to-map swaps and negates the axes')
assert(point.px == 30 and point.py == -10, 'the player point uses the same axes')
options.map_target_line.set(0)
local reads = playerReads
assert(functions.map_target() == nil and playerReads == reads)
options.map_target_line.set(1)
for _, id in ipairs({0, -1, 1, 1.5, '2', false, math.huge, 0/0}) do
  player.target_id = id
  reads = spawnReads
  assert(functions.map_target() == nil and spawnReads == reads)
end
player.target_id = nil
assert(functions.map_target() == nil)
player.target_id, player.in_zone = 2, false
assert(functions.map_target() == nil)
player.in_zone = true
for _, bad in ipairs({false, '40', math.huge, -math.huge, 0/0}) do
  target.x = bad
  assert(functions.map_target() == nil)
end
target = nil
assert(functions.map_target() == nil)
target = {x = 40}
assert(functions.map_target() == nil)
target = {x = 40, y = -60}
local savedPlayer = hs.player
hs.player = nil
assert(functions.map_target() == nil)
hs.player = savedPlayer
player = nil
assert(functions.map_target() == nil)
player = {spawn_id = 1, target_id = 2, in_zone = true}

local function adapter(mode, first)
  local state = {lines = {}, circles = {}, clips = 0, base = 0, calls = 0, windows = {},
    result = table.pack(2, 10, 20, 15, 25), args = table.pack(0, 0, 200, 100, 1), plugin = true,
    settings = {['map.sidebar'] = '0', ['map.showMarkers'] = '0'}}
  local function drawZone(...)
    state.calls = state.calls + 1
    state.lastArgs = table.pack(...)
    return table.unpack(state.result, 1, state.result.n)
  end
  -- The client has both; the minimap adapter is loaded in the same environment in the combined check.
  local function drawMinimap(...)
    state.minimapCalls = (state.minimapCalls or 0) + 1
    state.minimapArgs = table.pack(...)
    return 0, -1, 15, 25, 0.5
  end
  local api = {
    DrawZoneMap = drawZone,
    DrawMinimap = drawMinimap,
    Plugin = function(name)
      assert(name == 'script:qol')
      if state.plugin then return {map_target = functions.map_target} end
    end,
    InGame = function() return state.inGame ~= false end,
    WindowShown = function() return state.shown ~= false end,
    ZoneName = function() return 'Example', 'example' end,
    MapAutoZ = function() return false end,
  }
  local mapApi = {DrawZone = drawZone, DrawMinimap = drawMinimap}
  if mode == 'missing' then
    api.DrawZoneMap, api.DrawMinimap, mapApi.DrawZone, mapApi.DrawMinimap = nil, nil, nil, nil
  elseif mode == 'facade' then
    api.DrawZoneMap, api.DrawMinimap = nil, nil -- only the pack's hs.UI names exist
  end
  -- Model the host's read-only views: any accidental write into a shared table fails the test, and the
  -- fixture keeps the client functions so the test can prove they were not replaced.
  local function view(tbl)
    return setmetatable({}, {__index = tbl, __newindex = function() error('shared API write') end})
  end
  local readonly = view(api)
  local hsApi = view({UI = view({map = view(mapApi)})})
  local ui = {
    window = function(name, fn) state.windows[name] = fn end,
    base_window = function() state.base = state.base + 1 end,
    PushClipRect = function(x0, y0, x1, y1, intersect)
      assert(intersect and x0 < x1 and y0 < y1)
      state.clips = state.clips + 1
    end,
    PopClipRect = function() assert(state.clips > 0) state.clips = state.clips - 1 end,
    DrawLine = function(...) assert(state.clips > 0) state.lines[#state.lines + 1] = {...} end,
    DrawCircleFilled = function(...) state.circles[#state.circles + 1] = {...} end,
    GetSetting = function(key) return state.settings[key] end,
    SetSetting = function(key, value) state.settings[key] = value end,
    GetWindowPos = function() return 0, 0 end,
    IsItemHovered = function() return false end,
    IsItemActive = function() return false end,
    GetMousePos = function() return 0, 0 end,
    GetIO = function() return {} end,
    BeginPopup = function() return false end,
  }
  for _, name in ipairs({'DrawRectFilled', 'DrawRect', 'SetCursorPos', 'InvisibleButton', 'PushFont', 'PopFont'}) do
    ui[name] = function() end
  end
  local env = setmetatable({eq = readonly, hs = hsApi, ui = ui}, {__index = _G})
  env.dofile = function(path)
    if path == 'lib/hud.lua' then
      local color = {1, 1, 1, 1}
      return {T = {color = {accent = color, ink = color, muted = color, text = color, mapBg = color},
        font = {small = {}}, Text = function() end, TextSize = function() return 10, 10 end,
        Hit = function(id) return state.zoomIn and id == '##zin' end},
        Dialog = function(_, _, _, body) body(0, 0, 400, 300, 1) end}
    end
    if mode == 'failed' or state.dofileFails then error(path .. ' unavailable') end
    if path == 'map.lua' then
      -- Like lua_host.cpp, the pack's file executes with the add-on's _ENV and captures its API once, as
      -- the installed Modern pack does; the legacy mode keeps the older flat eq call covered.
      local call = mode == 'legacy' and 'eq.DrawZoneMap' or 'API.map.DrawZone'
      return assert(load(([[local API = hs.UI
      ui.window('Map', function()
        results = table.pack(%s(table.unpack(args, 1, args.n)))
      end)]]):format(call), 'stock map fixture', 't', env))()
    end
    assert(path == 'minimap.lua', 'load stock map or minimap, never an adapter')
    local call = mode == 'legacy' and 'eq.DrawMinimap' or 'API.map.DrawMinimap'
    return assert(load(([[local API = hs.UI
    ui.window('Minimap', function()
      minimapResults = table.pack(%s(100, 100, 50, 100, true))
    end)]]):format(call), 'stock minimap fixture', 't', env))()
  end
  env.args = state.args
  if first == 'minimap' then assert(loadfile('ui/modern/minimaptargetline.lua', 't', env))() end
  assert(loadfile('ui/modern/maptargetline.lua', 't', env))()
  state.env, state.original, state.hsApi = env, readonly, hsApi
  state.draw, state.minimapDraw = drawZone, drawMinimap
  return state
end

local function sameTuple(a, b)
  if a.n ~= b.n then return false end
  for i = 1, a.n do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local s = adapter()
s.windows.Map()
assert(s.calls == 1 and s.clips == 0 and #s.lines == 1 and #s.circles == 1)
local line = s.lines[1]
assert(line[1] == 110 and line[2] == 60 and line[3] == 200 and line[4] == -70)
assert(s.original.DrawZoneMap ~= s.env.eq.DrawZoneMap, 'API intercepted locally only')
assert(s.hsApi.UI.map.DrawZone ~= s.env.hs.UI.map.DrawZone, 'pack facade intercepted locally only')
assert(s.original.DrawZoneMap == s.draw and s.hsApi.UI.map.DrawZone == s.draw,
  'the shared views keep the client functions')
assert(s.env.results.n == 5 and s.env.results[5] == 25)

-- Older files call the flat eq name; the same wrapper answers it.
local legacy = adapter('legacy')
legacy.windows.Map()
assert(legacy.calls == 1 and #legacy.lines == 1 and #legacy.circles == 1)

-- Pan and zoom: use the actual call's centre, not a later Follow update.
s.env.args = table.pack(20, 40, 220, 140, 3, 30, -10, false)
s.result = table.pack(4, 10, 20, 15, 25, nil, 'future return')
s.windows.Map()
line = s.lines[2]
assert(line[1] == 60 and line[2] == 230 and line[3] == 240 and line[4] == -30)
assert(sameTuple(s.lastArgs, table.pack(20, 40, 220, 140, 3, 30, -10, false)), 'all arguments pass through')
assert(sameTuple(s.env.results, table.pack(4, 10, 20, 15, 25, nil, 'future return')),
  'all return values pass through, a nil included')

-- Read the current endpoint each frame: movement and target loss cannot leave a cached line.
target = {x = -10, y = 20}
s.windows.Map()
line = s.lines[3]
assert(line[3] == -80 and line[4] == 170)
target = {x = 40, y = -60}

-- A reload runs in the same plugin globals (lua_host.cpp keeps a folder's environment), so it must
-- replace its hook there: one client call and one overlay line per frame, not one more of each.
local calls, drawn = s.calls, #s.lines
assert(loadfile('ui/modern/maptargetline.lua', 't', s.env))()
assert(s.env.eq ~= s.original and s.env.hs ~= s.hsApi, 'a reload keeps the shadow instead of restoring the client view')
assert(s.env.eq.DrawZoneMap ~= s.original.DrawZoneMap, 'a reload keeps the hook')
s.windows.Map()
assert(s.calls == calls + 1 and #s.lines == drawn + 1, 'a reload replaces the wrapper instead of stacking it')
assert(s.original.DrawZoneMap == s.draw and s.hsApi.UI.map.DrawZone == s.draw,
  'a reload still leaves the shared views alone')

-- A failed pack load drops this script's hook; the names then pass straight through.
s.dofileFails = true
assert(loadfile('ui/modern/maptargetline.lua', 't', s.env))()
s.dofileFails = false
s.windows.Map()
assert(s.base == 1, 'a failed load keeps the bare map window')
assert(s.env.eq.DrawZoneMap == s.draw and s.env.hs.UI.map.DrawZone == s.draw,
  'a failed load clears the hook instead of restoring a stale wrapper')

-- The next reload installs the hook again and draws once.
assert(loadfile('ui/modern/maptargetline.lua', 't', s.env))()
s.windows.Map()
assert(s.calls == calls + 2 and #s.lines == drawn + 2)

local function hidden()
  local count = #s.lines
  s.windows.Map()
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
player.target_id = 1
hidden()
player.target_id = 2
target = {x = 40, y = -60}
for _, result in ipairs({table.pack(), table.pack(2, 10, 20), table.pack(0, 10, 20, 15, 25),
    table.pack(0/0, 10, 20, 15, 25)}) do
  s.result = result
  hidden()
end
local missing = adapter('missing')
missing.windows.Map()
assert(missing.base == 1 and missing.env.eq == missing.original and missing.env.hs == missing.hsApi,
  'with no client function nothing is shadowed and the bare map window opens')
local failed = adapter('failed')
failed.windows.Map()
assert(failed.base == 1 and failed.env.eq.DrawZoneMap == failed.draw
  and failed.env.hs.UI.map.DrawZone == failed.draw, 'a failed pack load leaves both names passing straight through')

-- The add-on loads both adapters in one environment: the first makes the shim and the second hooks only
-- its own function, so each frame calls each client function once.
local both = adapter()
assert(loadfile('ui/modern/minimaptargetline.lua', 't', both.env))()
assert(both.env.eq.DrawMinimap ~= both.original.DrawMinimap, 'the second adapter finds the shim and hooks its function')
assert(both.env.eq.DrawZoneMap ~= both.original.DrawZoneMap, 'the first adapter keeps its hook')
assert(both.original.DrawMinimap == both.minimapDraw and both.original.DrawZoneMap == both.draw)
both.windows.Map()
both.windows.Minimap()
assert(both.calls == 1 and both.minimapCalls == 1 and #both.lines == 2, 'one client call and one overlay per window')

-- A failed reload of one adapter clears only its own hook; the other window still draws exactly once.
both.dofileFails = true
assert(loadfile('ui/modern/maptargetline.lua', 't', both.env))()
both.dofileFails = false
assert(both.env.eq.DrawZoneMap == both.draw, 'the failed map hook is cleared')
assert(both.env.eq.DrawMinimap ~= both.original.DrawMinimap, 'the minimap hook survives')
local before = #both.lines
both.windows.Minimap()
assert(both.minimapCalls == 2 and #both.lines == before + 1, 'the minimap still draws after a failed map reload')
assert(loadfile('ui/modern/maptargetline.lua', 't', both.env))()

both.dofileFails = true
assert(loadfile('ui/modern/minimaptargetline.lua', 't', both.env))()
both.dofileFails = false
assert(both.env.eq.DrawMinimap == both.minimapDraw, 'the failed minimap hook is cleared')
assert(both.env.eq.DrawZoneMap ~= both.original.DrawZoneMap, 'the map hook survives')
before = #both.lines
both.windows.Map()
assert(both.calls == 2 and #both.lines == before + 1)

-- The other order: the minimap adapter makes the shim and the map adapter finds it.
local miniFirst = adapter(nil, 'minimap')
assert(miniFirst.env.eq.DrawZoneMap ~= miniFirst.original.DrawZoneMap,
  'the map adapter finds the shim made by the minimap adapter')
assert(miniFirst.env.eq.DrawMinimap ~= miniFirst.original.DrawMinimap)
miniFirst.windows.Minimap()
miniFirst.windows.Map()
assert(miniFirst.minimapCalls == 1 and miniFirst.calls == 1 and #miniFirst.lines == 2)

-- A client that only has the pack's facade names still loads the pack and draws.
local facade = adapter('facade')
facade.windows.Map()
assert(facade.calls == 1 and #facade.lines == 1)
assert(facade.env.hs.UI.map.DrawZone ~= facade.hsApi.UI.map.DrawZone, 'the facade name is hooked')

if arg[1] then
  -- A drift check, not proof: it only notices a renamed call early. Comments are stripped first, so
  -- a commented-out call cannot keep it green.
  local function source(path)
    local file = assert(io.open(path, 'rb'))
    local text = file:read('*a')
    file:close()
    return text
  end
  local function code(path)
    local text = source(path)
    text = text:gsub('%-%-%[(=*)%[.-%]%1%]', '') -- long comments, any level of '='
    return (text:gsub('%-%-[^\n]*', '')) -- line comments
  end
  local map = code(arg[1])
  assert(map:find('local API%s*=%s*hs%.UI'), 'map.lua still takes its API from hs.UI')
  assert(map:find('API%.map%.DrawZone%s*%('), 'map.lua still draws through hs.UI.map.DrawZone')
  local minimap = code(arg[2] or arg[1]:gsub('map%.lua$', 'minimap.lua'))
  assert(minimap:find('local API%s*=%s*hs%.UI'), 'minimap.lua still takes its API from hs.UI')
  assert(minimap:find('API%.map%.DrawMinimap%s*%('), 'minimap.lua still draws through hs.UI.map.DrawMinimap')
  print('installed Modern map call contract: ok')
end
print('map target data and adapter: ok')
