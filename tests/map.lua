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

local function adapter(mode)
  local state = {lines = {}, circles = {}, clips = 0, base = 0, calls = 0, windows = {},
    result = table.pack(2, 10, 20, 15, 25), args = table.pack(0, 0, 200, 100, 1), plugin = true,
    settings = {['map.sidebar'] = '0', ['map.showMarkers'] = '0'}}
  local api = {
    DrawZoneMap = function(...)
      state.calls = state.calls + 1
      state.lastArgs = table.pack(...)
      return table.unpack(state.result, 1, state.result.n)
    end,
    Plugin = function(name)
      assert(name == 'script:qol')
      if state.plugin then return {map_target = functions.map_target} end
    end,
    InGame = function() return state.inGame ~= false end,
    WindowShown = function() return state.shown ~= false end,
    ZoneName = function() return 'Example', 'example' end,
    MapAutoZ = function() return false end,
  }
  if mode == 'missing' then api.DrawZoneMap = nil end
  -- Model the host's read-only eq view: any accidental write fails the test.
  local readonly = setmetatable({}, {__index = api, __newindex = function() error('shared API write') end})
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
  local env = setmetatable({eq = readonly, ui = ui}, {__index = _G})
  env.dofile = function(path)
    if path == 'lib/hud.lua' then
      local color = {1, 1, 1, 1}
      return {T = {color = {accent = color, ink = color, muted = color, text = color, mapBg = color},
        font = {small = {}}, Text = function() end, TextSize = function() return 10, 10 end,
        Hit = function(id) return state.zoomIn and id == '##zin' end},
        Dialog = function(_, _, _, body) body(0, 0, 400, 300, 1) end}
    end
    assert(path == 'map.lua', 'load stock map, never recursively load the adapter')
    if mode == 'failed' then error('map unavailable') end
    if mode == 'stock' then return assert(loadfile(arg[1], 't', env))() end
    -- Like lua_host.cpp, the pack's file executes with the add-on's _ENV.
    return assert(load([[ui.window('Map', function()
      results = table.pack(eq.DrawZoneMap(table.unpack(args, 1, args.n)))
    end)]], 'stock map fixture', 't', env))()
  end
  env.args = state.args
  assert(loadfile('ui/modern/maptargetline.lua', 't', env))()
  state.env, state.original = env, readonly
  return state
end

local s = adapter()
s.windows.Map()
assert(s.calls == 1 and s.clips == 0 and #s.lines == 1 and #s.circles == 1)
local line = s.lines[1]
assert(line[1] == 110 and line[2] == 60 and line[3] == 200 and line[4] == -70)
assert(s.original.DrawZoneMap ~= s.env.eq.DrawZoneMap, 'API intercepted locally only')
assert(s.env.results.n == 5 and s.env.results[5] == 25)

-- Pan and zoom: use the actual call's centre, not a later Follow update.
s.env.args = table.pack(20, 40, 220, 140, 3, 30, -10, false)
s.result = table.pack(4, 10, 20, 15, 25, nil, 'future return')
s.windows.Map()
line = s.lines[2]
assert(line[1] == 60 and line[2] == 230 and line[3] == 240 and line[4] == -30)
assert(s.lastArgs.n == 8 and s.lastArgs[8] == false)
assert(s.env.results.n == 7 and s.env.results[6] == nil and s.env.results[7] == 'future return')

-- Read the current endpoint each frame: movement and target loss cannot leave a cached line.
target = {x = -10, y = 20}
s.windows.Map()
line = s.lines[3]
assert(line[3] == -80 and line[4] == 170)
target = {x = 40, y = -60}

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
for _, mode in ipairs({'missing', 'failed'}) do
  local fallback = adapter(mode)
  fallback.windows.Map()
  assert(fallback.base == 1 and fallback.env.eq == fallback.original)
end

if arg[1] then
  local stock = adapter('stock')
  stock.zoomIn = true
  stock.windows.Map()
  assert(stock.calls == 1 and #stock.lines == 1 and stock.clips == 0)
  local first = stock.lines[1]
  local call = stock.lastArgs
  local cx, cy = call[6] or 10, call[7] or 20
  assert(first[1] == (call[1] + call[3]) / 2 + (15 - cx) * 2)
  assert(first[2] == (call[2] + call[4]) / 2 + (25 - cy) * 2)
  stock.zoomIn = false
  stock.windows.Map()
  assert(stock.lastArgs[6] == 15 and stock.lastArgs[7] == 25, 'Follow centre takes effect next frame')
  stock.shown = false
  stock.windows.Map()
  assert(stock.calls == 2, 'closed map does not read positions or draw')
  stock.shown, stock.inGame = true, false
  stock.windows.Map()
  assert(stock.calls == 2, 'out of game does not draw')
  print('installed Modern map adapter contract: ok')
end
print('map target data and adapter: ok')
