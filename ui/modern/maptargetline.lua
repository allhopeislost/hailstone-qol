-- Reuse the installed Modern map, not a frozen copy. dofile falls back to the pack's
-- map.lua and runs it in this add-on's environment (lua_host.cpp). This file must NOT
-- be named map.lua: that would resolve to itself instead of the pack's map.
local function finite(value)
  return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

-- The client's own views and the shadows this script installs, kept in the plugin's globals: the host
-- keeps those across a reload of one file (lua_host.cpp), so a reload replaces the hook in the existing
-- shadow. Wrapping the previous wrapper would draw the line once per reload, and a failed load would put
-- a stale wrapper back instead of passing straight through. The minimap adapter reads the same table.
local shim = qol_map_hooks
if type(shim) ~= 'table' or type(shim.shadowEq) ~= 'table' then
  local uiApi = type(hs) == 'table' and hs.UI
  local mapApi = type(uiApi) == 'table' and uiApi.map
  if type(mapApi) ~= 'table' then mapApi = nil end
  shim = {
    eq = eq, hs = hs, ui = uiApi, map = mapApi,
    shadowEq = setmetatable({}, {__index = eq}),
    DrawZoneMap = eq.DrawZoneMap,
  }
  if mapApi then
    shim.DrawZone = mapApi.DrawZone
    shim.shadowMap = setmetatable({}, {__index = mapApi})
    shim.shadowUi = setmetatable({map = shim.shadowMap}, {__index = uiApi})
    shim.shadowHs = setmetatable({UI = shim.shadowUi}, {__index = hs})
  end
  qol_map_hooks = shim
end

-- The map adapter usually loads first; take the client functions it left out, from the flat name or the
-- pack's facade name. A client that only has the facade names still loads the pack.
shim.DrawZoneMap = shim.DrawZoneMap or shim.eq.DrawZoneMap
shim.DrawZone = shim.DrawZone or (shim.map and shim.map.DrawZone)

local function drawTarget(x0, y0, x1, y1, cx, cy, result)
  local k, midx, midy, px, py = table.unpack(result, 1, 5)
  if not finite(k) or k <= 0 or not finite(px) or not finite(py) then return end
  cx, cy = cx or midx, cy or midy
  if not finite(cx) or not finite(cy) then return end
  if not finite(x0) or not finite(y0) or not finite(x1) or not finite(y1)
      or x1 <= x0 or y1 <= y0 then return end
  local plugin = shim.eq.Plugin and shim.eq.Plugin('script:qol')
  if not plugin or type(plugin.map_target) ~= 'function' then return end
  local target = plugin.map_target()
  if type(target) ~= 'table' or not finite(target.x) or not finite(target.y) then return end
  local sx, sy = (x0 + x1) / 2, (y0 + y1) / 2
  local ax, ay = sx + (px - cx) * k, sy + (py - cy) * k
  local bx, by = sx + (target.x - cx) * k, sy + (target.y - cy) * k
  if not finite(ax) or not finite(ay) or not finite(bx) or not finite(by) then return end
  local width = math.max(1.5, (y1 - y0) / 400)
  -- DrawZone has popped its own clip; restore the map rectangle for our overlay.
  ui.PushClipRect(x0, y0, x1, y1, true)
  ui.DrawLine(ax, ay, bx, by, 1, 0.45, 0.15, 0.9, width)
  ui.DrawCircleFilled(bx, by, width * 2, 1, 0.45, 0.15, 1)
  ui.PopClipRect()
end

-- The Modern pack draws through its hs.UI.map names now; eq keeps the flat names for
-- older files. Both are the same client function, so one wrapper serves both.
local drawZone = shim.DrawZoneMap
if type(drawZone) ~= 'function' then drawZone = shim.DrawZone end
if type(drawZone) ~= 'function' then
  ui.window('Map', function() ui.base_window() end)
  return
end

local function zone(...)
  local result = table.pack(drawZone(...))
  local x0, y0, x1, y1, _, cx, cy = ...
  drawTarget(x0, y0, x1, y1, cx, cy, result)
  return table.unpack(result, 1, result.n)
end

-- Shadow only the add-on's globals, never write into the shared/read-only API. The pack's
-- hs.UI facade captured its function at start-up, so the eq alias alone no longer reaches it.
-- All other functions (including our other windows' APIs) pass through unchanged.
shim.shadowEq.DrawZoneMap = zone
if shim.shadowMap then shim.shadowMap.DrawZone = zone end
eq = shim.shadowEq
if shim.shadowHs then hs = shim.shadowHs end

local loaded = pcall(dofile, 'map.lua')
if not loaded then
  -- The pack is unavailable: drop this script's hook and keep the minimap adapter's, so both names
  -- pass straight through instead of calling a wrapper the failed load left behind.
  shim.shadowEq.DrawZoneMap = nil
  if shim.shadowMap then shim.shadowMap.DrawZone = nil end
  ui.window('Map', function() ui.base_window() end)
end
