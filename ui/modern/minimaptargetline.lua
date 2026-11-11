-- Same adapter as maptargetline.lua, for the minimap: reuse the installed Modern minimap and draw the
-- target line over what eq.DrawMinimap draws. This file must NOT be named minimap.lua (it would load itself).
local original = eq

local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- The minimap is centred on the player; k = r / range screen pixels per map unit. With rotation on, the
-- map is turned so that north points along (nx, ny) = (sin, -cos) of the heading.
local function drawTarget(cx, cy, r, range, nx, ny)
  if not (finite(cx) and finite(cy) and finite(r) and r > 0 and finite(range) and range > 0) then return end
  if not (finite(nx) and finite(ny)) then return end
  local plugin = original.Plugin and original.Plugin('script:qol')
  if not plugin or type(plugin.map_target) ~= 'function' then return end
  local target = plugin.map_target()
  if type(target) ~= 'table' or not (finite(target.x) and finite(target.y)
      and finite(target.px) and finite(target.py)) then return end
  local k, sn, cs = r / range, nx, -ny
  local dx, dy = (target.x - target.px) * k, (target.y - target.py) * k
  local bx, by = dx * cs - dy * sn, dx * sn + dy * cs
  if not finite(bx) or not finite(by) then return end
  local width = math.max(1.5, r / 90)
  local length = math.sqrt(bx * bx + by * by)
  local inside = length <= r
  if not inside then bx, by = bx * r / length, by * r / length end
  -- Clip to the circle's square; the endpoint is already on or inside the circle.
  ui.PushClipRect(cx - r, cy - r, cx + r, cy + r, true)
  ui.DrawLine(cx, cy, cx + bx, cy + by, 1, 0.45, 0.15, 0.9, width)
  if inside then ui.DrawCircleFilled(cx + bx, cy + by, width * 2, 1, 0.45, 0.15, 1) end
  ui.PopClipRect()
end

if type(original.DrawMinimap) ~= 'function' then
  ui.window('Minimap', function() ui.base_window() end)
  return
end

-- Shadow only the add-on's eq global, never write into the shared/read-only API.
eq = setmetatable({
  DrawMinimap = function(...)
    local result = table.pack(original.DrawMinimap(...))
    local cx, cy, r, range = ...
    drawTarget(cx, cy, r, range, result[1], result[2])
    return table.unpack(result, 1, result.n)
  end,
}, {__index = original})

local loaded = pcall(dofile, 'minimap.lua')
if not loaded then
  eq = original
  ui.window('Minimap', function() ui.base_window() end)
end
