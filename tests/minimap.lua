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
    north = table.pack(0, -1)}
  local api = {
    DrawMinimap = function(...)
      state.calls = state.calls + 1
      state.lastArgs = table.pack(...)
      return table.unpack(state.north, 1, state.north.n)
    end,
    Plugin = function(name)
      assert(name == 'script:qol')
      if state.plugin then return {map_target = functions.map_target} end
    end,
  }
  if mode == 'missing' then api.DrawMinimap = nil end
  local readonly = setmetatable({}, {__index = api, __newindex = function() error('shared API write') end})
  local ui = {
    window = function(name, fn) state.windows[name] = fn end,
    base_window = function() state.base = state.base + 1 end,
    PushClipRect = function() state.clips = state.clips + 1 end,
    PopClipRect = function() assert(state.clips > 0) state.clips = state.clips - 1 end,
    DrawLine = function(...) assert(state.clips > 0) state.lines[#state.lines + 1] = {...} end,
    DrawCircleFilled = function(...) state.circles[#state.circles + 1] = {...} end,
  }
  local env = setmetatable({eq = readonly, ui = ui}, {__index = _G})
  env.dofile = function(path)
    assert(path == 'minimap.lua', 'load stock minimap, never the adapter itself')
    if mode == 'failed' then error('minimap unavailable') end
    return assert(load([[ui.window('Minimap', function()
      results = table.pack(eq.DrawMinimap(100, 100, 50, 100, rotating))
    end)]], 'stock minimap fixture', 't', env))()
  end
  assert(loadfile('ui/modern/minimaptargetline.lua', 't', env))()
  state.env, state.original = env, readonly
  return state
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

-- North up: offset (30, -30) map units at 0.5 px per unit.
local s = adapter()
s.windows.Minimap()
assert(s.calls == 1 and s.clips == 0 and #s.lines == 1 and #s.circles == 1)
local line = s.lines[1]
assert(line[1] == 100 and line[2] == 100 and near(line[3], 115) and near(line[4], 85))
assert(s.original.DrawMinimap ~= s.env.eq.DrawMinimap, 'API intercepted locally only')
assert(s.env.results.n == 2 and s.env.results[2] == -1, 'stock return values pass through')

-- Rotation: heading east of north turns the map; north points along (1, 0), so map offsets turn with it.
s.north = table.pack(1, 0)
s.windows.Minimap()
line = s.lines[2]
assert(near(line[3], 100 + 15) and near(line[4], 100 + 15), 'rotated with the player')

-- A target beyond the range stops at the circle's edge, without the end dot.
s.north = table.pack(0, -1)
target = {x = 400, y = -600} -- far: map offset (570, -370)
local dots = #s.circles
s.windows.Minimap()
line = s.lines[3]
assert(near(math.sqrt((line[3] - 100) ^ 2 + (line[4] - 100) ^ 2), 50) and #s.circles == dots)
target = {x = 40, y = -60}

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

for _, mode in ipairs({'missing', 'failed'}) do
  local fallback = adapter(mode)
  fallback.windows.Minimap()
  assert(fallback.base == 1 and fallback.env.eq == fallback.original)
end
print('minimap target line: ok')
