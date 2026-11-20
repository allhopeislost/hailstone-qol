-- Same adapter as maptargetline.lua, for the minimap: reuse the installed Modern minimap and draw the
-- target line over what DrawMinimap draws. This file must NOT be named minimap.lua (it would load itself).
local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- The client's own views and the shadows this script installs, kept in the plugin's globals (the same
-- table maptargetline.lua uses): the host keeps those across a reload of one file (lua_host.cpp), so a
-- reload replaces its own hook instead of wrapping the previous wrapper.
local shim = qol_map_hooks
if type(shim) ~= 'table' or type(shim.shadowEq) ~= 'table' then
  local uiApi = type(hs) == 'table' and hs.UI
  local mapApi = type(uiApi) == 'table' and uiApi.map
  if type(mapApi) ~= 'table' then mapApi = nil end
  shim = {
    eq = eq, hs = hs, ui = uiApi, map = mapApi,
    shadowEq = setmetatable({}, {__index = eq}),
    DrawZoneMap = eq.DrawZoneMap,
    DrawMinimap = eq.DrawMinimap,
  }
  if mapApi then
    shim.DrawZone = mapApi.DrawZone
    shim.shadowMap = setmetatable({}, {__index = mapApi})
    shim.shadowUi = setmetatable({map = shim.shadowMap}, {__index = uiApi})
    shim.shadowHs = setmetatable({UI = shim.shadowUi}, {__index = hs})
  end
  qol_map_hooks = shim
end

-- The map adapter usually loads first and captures only the map function; take the minimap one from the
-- client's own views, flat name first, then the pack's facade name. A facade-only client still loads.
shim.DrawMinimap = shim.DrawMinimap or shim.eq.DrawMinimap or (shim.map and shim.map.DrawMinimap)

-- The minimap is centred on the player; k = r / range screen pixels per map unit. With rotation on, the
-- map is turned so that north points along (nx, ny) = (sin, -cos) of the heading.
local function drawTarget(cx, cy, r, range, nx, ny)
  if not (finite(cx) and finite(cy) and finite(r) and r > 0 and finite(range) and range > 0) then return end
  if not (finite(nx) and finite(ny)) then return end
  local plugin = shim.eq.Plugin and shim.eq.Plugin('script:qol')
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

-- The Modern pack draws through its hs.UI.map names now; eq keeps the flat names for
-- older files. Both are the same client function, so one wrapper serves both.
local drawMinimap = shim.DrawMinimap
if type(drawMinimap) ~= 'function' then
  ui.window('Minimap', function() ui.base_window() end)
  return
end

local function minimap(...)
  local result = table.pack(drawMinimap(...))
  local cx, cy, r, range = ...
  drawTarget(cx, cy, r, range, result[1], result[2])
  return table.unpack(result, 1, result.n)
end

-- Shadow only the add-on's globals, never write into the shared/read-only API. The pack's
-- hs.UI facade captured its function at start-up, so the eq alias alone no longer reaches it.
-- All other functions (including our other windows' APIs) pass through unchanged.
shim.shadowEq.DrawMinimap = minimap
if shim.shadowMap then shim.shadowMap.DrawMinimap = minimap end
eq = shim.shadowEq
if shim.shadowHs then hs = shim.shadowHs end

local loaded = pcall(dofile, 'minimap.lua')
if not loaded then
  -- The pack is unavailable: drop this script's hook and keep the map adapter's, so both names pass
  -- straight through instead of calling a wrapper the failed load left behind.
  shim.shadowEq.DrawMinimap = nil
  if shim.shadowMap then shim.shadowMap.DrawMinimap = nil end
  ui.window('Minimap', function() ui.base_window() end)
end
