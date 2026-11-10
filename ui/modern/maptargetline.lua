-- Reuse the installed Modern map, not a frozen copy. dofile falls back to the pack's
-- map.lua and runs it in this add-on's environment (lua_host.cpp). This file must NOT
-- be named map.lua: that would resolve to itself instead of the pack's map.
local original = eq

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function drawTarget(x0, y0, x1, y1, cx, cy, result)
  local k, midx, midy, px, py = table.unpack(result, 1, 5)
  if not finite(k) or k <= 0 or not finite(px) or not finite(py) then return end
  cx, cy = cx or midx, cy or midy
  if not finite(cx) or not finite(cy) then return end
  if not finite(x0) or not finite(y0) or not finite(x1) or not finite(y1)
      or x1 <= x0 or y1 <= y0 then return end
  local plugin = original.Plugin and original.Plugin('script:qol')
  if not plugin or type(plugin.map_target) ~= 'function' then return end
  local target = plugin.map_target()
  if type(target) ~= 'table' or not finite(target.x) or not finite(target.y) then return end
  local sx, sy = (x0 + x1) / 2, (y0 + y1) / 2
  local ax, ay = sx + (px - cx) * k, sy + (py - cy) * k
  local bx, by = sx + (target.x - cx) * k, sy + (target.y - cy) * k
  if not finite(ax) or not finite(ay) or not finite(bx) or not finite(by) then return end
  local width = math.max(1.5, (y1 - y0) / 400)
  -- DrawZoneMap has popped its own clip; restore the map rectangle for our overlay.
  ui.PushClipRect(x0, y0, x1, y1, true)
  ui.DrawLine(ax, ay, bx, by, 1, 0.45, 0.15, 0.9, width)
  ui.DrawCircleFilled(bx, by, width * 2, 1, 0.45, 0.15, 1)
  ui.PopClipRect()
end

if type(original.DrawZoneMap) ~= 'function' then
  ui.window('Map', function() ui.base_window() end)
  return
end

-- Shadow only the add-on's eq global, never write into the shared/read-only API.
-- All other functions (including our other windows' APIs) pass through unchanged.
eq = setmetatable({
  DrawZoneMap = function(...)
    local result = table.pack(original.DrawZoneMap(...))
    local x0, y0, x1, y1, _, cx, cy = ...
    drawTarget(x0, y0, x1, y1, cx, cy, result)
    return table.unpack(result, 1, result.n)
  end,
}, {__index = original})

local loaded = pcall(dofile, 'map.lua')
if not loaded then
  eq = original
  ui.window('Map', function() ui.base_window() end)
end
