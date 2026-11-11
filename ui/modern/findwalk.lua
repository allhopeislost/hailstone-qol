-- FindWalk: a window of its own (opened with /findW) that lists the spawns in the zone. A search box, NPC / PC /
-- Corpse filters, columns that sort when their head is clicked (again to reverse, an arrow marks the sorted one) and a
-- Travel to button that targets the selected spawn and walks to it. The Role column (Merchant, Banker, Trainer) is
-- there only while the listed spawns have a role, and the window narrows when it goes. The spawn list, filtering and
-- sorting are in init.lua / core/findwalk.lua; this file only draws the rows it gets.
local hud = dofile("lib/hud.lua")
local T = hud.T
local C = T.color

local WINDOW = "FindWalkWnd"
local REFRESH = 0.5 -- seconds between two reads of the zone

-- Design pixels. The dialog adds 10 each side, so the window is 410 wide with the Role column and 360 without.
local WIDTH_ROLE, WIDTH_PLAIN = 390, 340
local SEARCH_H, CHECK_H, HEAD_H, LIST_H, STATUS_H, BUTTON_H, GAP = 28, 16, 22, 224, 14, 32, 8
local PANEL_H = 1 + 4 + HEAD_H + LIST_H + 1
local CONTENT_H = SEARCH_H + GAP + CHECK_H + GAP + PANEL_H + GAP + STATUS_H + GAP + BUTTON_H
local COL_ROLE, COL_LVL, COL_DIST, COL_GAP, ROW_PAD = 70, 40, 54, 10, 8

local state = {
  types = { npc = true, pc = false, corpse = false },
  search = "", sort = "name", desc = false, -- A to Z at first
  rows = {}, total = 0, hasRole = false,
  selected = nil, selectedName = nil, error = nil, barW = 0,
  fetchedAt = nil, dirty = true, serial = nil, scrollTop = false, wasOpen = false,
}

local function fetch(qol)
  local result = qol.findwalk_rows({ types = state.types, text = state.search, sort = state.sort, desc = state.desc })
  state.fetchedAt, state.dirty = ui.GetTime(), false
  if type(result) ~= "table" then return end
  state.rows, state.total, state.hasRole = result.rows or {}, result.total or 0, result.has_role == true
  -- the sorted column went away with the last role: back to the default order
  if state.sort == "role" and not state.hasRole then
    state.sort, state.desc, state.dirty, state.scrollTop = "name", false, true, true
  end
  if state.selected then
    local found = false
    for _, row in ipairs(state.rows) do
      if row.id == state.selected then found = true break end
    end
    if not found then state.selected, state.selectedName = nil, nil end
  end
end

-- Target the spawn and walk to it; a refusal is shown in the status line.
local function travel(qol, id)
  local result = qol.findwalk_travel(id)
  state.error = type(result) == "table" and not result.ok and (result.error or "Could not travel.") or nil
end

local function sortBy(key)
  if state.sort == key then state.desc = not state.desc else state.sort, state.desc = key, false end
  state.dirty, state.scrollTop = true, true
end

-- The sort arrow: up for ascending, down for descending, h tall and 1.4 h wide, centred on (cx, cy).
local function arrow(cx, cy, h, up, color)
  local half = h * 0.7
  if up then
    ui.DrawTriangleFilled(cx - half, cy + h / 2, cx + half, cy + h / 2, cx, cy - h / 2, color[1], color[2], color[3], 1)
  else
    ui.DrawTriangleFilled(cx - half, cy - h / 2, cx + half, cy - h / 2, cx, cy + h / 2, color[1], color[2], color[3], 1)
  end
end

-- A clickable column head. align: "left" or "right" (x is then the column's right edge). The sort arrow stands before
-- the label, except on the name, which keeps its label at the left edge of the names and takes the arrow after it.
local function head(key, label, x, y0, y1, colW, align, s)
  local font = T.font.tiny
  local active = state.sort == key
  local x0 = align == "right" and x - colW or x
  if T.Hit("##fwh" .. key, x0, y0, x0 + colW, y1) then sortBy(key) end
  local hovered = ui.IsItemHovered()
  local color = active and C.accent or (hovered and C.text or C.faint)
  local tw, th = T.TextSize(label, font)
  local ty = y0 + (y1 - y0 - th) / 2
  local ah = 6 * s
  local half, gap = ah * 0.7, 4 * s
  local up = not state.desc
  if align == "right" then
    T.Text(x, ty, label, color, font, "right")
    if active then arrow(x - tw - gap - half, ty + th / 2, ah, up, color) end
  elseif key == "name" then
    T.Text(x, ty, label, color, font)
    if active then arrow(x + tw + gap + half, ty + th / 2, ah, up, color) end
  else
    local lx = active and x + 2 * half + gap or x
    T.Text(lx, ty, label, color, font)
    if active then arrow(x + half, ty + th / 2, ah, up, color) end
  end
  if hovered then ui.SetTooltip("Click to sort, click again to reverse") end
end

local function checkbox(id, label, key, tip)
  local value, changed = ui.Checkbox(label .. "##fw" .. id, state.types[key])
  if ui.IsItemHovered() then ui.SetTooltip(tip) end
  if changed then
    state.types[key] = value
    state.dirty, state.scrollTop = true, true
  end
end

local function body(cx, cy, w, h, s, qol)
  local textH = select(2, T.TextSize("Ag", T.font.small))
  local rowH = math.floor(textH + 8 * s + 0.5)

  -- search
  ui.SetCursorScreenPos(cx, cy)
  ui.SetNextItemWidth(w)
  local text = ui.InputTextWithHint("##fwsearch", "Search...", state.search, 64)
  if text ~= state.search then
    state.search = text
    state.dirty, state.scrollTop = true, true
  end

  -- what to list
  local y = cy + (SEARCH_H + GAP) * s
  ui.SetCursorScreenPos(cx, y)
  checkbox("npc", "NPC", "npc", "Show NPCs")
  ui.SameLine(0, 14 * s)
  checkbox("pc", "PC", "pc", "Show players")
  ui.SameLine(0, 14 * s)
  checkbox("corpse", "Corpse", "corpse", "Show corpses")

  -- the panel: column heads over the list
  local px0, py0 = cx, y + (CHECK_H + GAP) * s
  local px1, py1 = cx + w, py0 + PANEL_H * s
  ui.DrawRectFilled(px0, py0, px1, py1, C.inset[1], C.inset[2], C.inset[3], C.inset[4], 6 * s)
  ui.DrawRect(px0, py0, px1, py1, C.ink[1], C.ink[2], C.ink[3], 0.12, 6 * s, 1)

  -- columns from the right edge: Dist, Lvl, Role (while shown), the name takes the rest. The head and the rows share
  -- them; while the list scrolls, its scroll bar (measured last frame) takes the right edge.
  local pad, gap = ROW_PAD * s, COL_GAP * s
  local distR = px1 - state.barW - pad
  local lvlR = distR - COL_DIST * s - gap
  local roleX = lvlR - COL_LVL * s - gap - COL_ROLE * s
  local nameX = px0 + pad
  local nameR = (state.hasRole and roleX or (lvlR - COL_LVL * s)) - gap

  local hy0 = py0 + 5 * s
  local hy1 = hy0 + (HEAD_H - 1) * s
  head("name", "NAME", nameX, hy0, hy1, nameR - nameX, "left", s)
  if state.hasRole then head("role", "ROLE", roleX, hy0, hy1, COL_ROLE * s, "left", s) end
  head("level", "LVL", lvlR, hy0, hy1, COL_LVL * s, "right", s)
  head("dist", "DIST", distR, hy0, hy1, COL_DIST * s, "right", s)
  ui.DrawLine(px0 + 1, hy1, px1 - 1, hy1, C.ink[1], C.ink[2], C.ink[3], 0.12, 1)

  -- the rows, drawn only where the list shows them
  local lx, ly = px0 + 1, hy1 + 1
  local lw, lh = w - 2, LIST_H * s
  ui.SetCursorScreenPos(lx, ly)
  ui.BeginChild("##fwlist", lw, lh, false)
  if state.scrollTop then
    ui.SetScrollY(0)
    state.scrollTop = false
  end
  local rows, n = state.rows, #state.rows
  local ox, oy = ui.GetCursorScreenPos()
  local avail = ui.GetContentRegionAvail()
  state.barW = lw - avail
  local right = ox + avail
  ui.Dummy(1, n * rowH)
  local scroll = ui.GetScrollY()
  local first = math.max(1, math.floor(scroll / rowH) + 1)
  local last = math.min(n, math.ceil((scroll + lh) / rowH) + 1)
  for i = first, last do
    local row = rows[i]
    local ry = oy + (i - 1) * rowH
    local selected = row.id == state.selected
    if T.Hit("##fwr" .. row.id, ox, ry, right, ry + rowH) then
      state.selected, state.selectedName, state.error = row.id, row.name, nil
    end
    local hovered = ui.IsItemHovered()
    -- a double click on a row is Travel to. It is asked apart from the hit box: that one reports a click on mouse up,
    -- while IsMouseDoubleClicked is true on the frame the mouse goes down (as the client's own list windows do).
    if hovered and ui.IsMouseDoubleClicked(ui.Mouse.Left) then
      state.selected, state.selectedName, state.error = row.id, row.name, nil
      travel(qol, row.id)
    end
    if selected then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.accent[1], C.accent[2], C.accent[3], 0.22, 0)
      ui.DrawRect(ox, ry, right, ry + rowH, C.accent[1], C.accent[2], C.accent[3], 1, 0, 1)
    elseif hovered then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.10, 0)
    elseif i % 2 == 0 then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.06, 0)
    end
    local ty = ry + (rowH - textH) / 2
    local nameColor = row.kind == "pc" and C.pet or (row.kind == "corpse" and C.gold or C.text)
    T.Text(nameX, ty, T.Fit(row.name, nameR - nameX, T.font.small), nameColor, T.font.small)
    if state.hasRole and row.role then
      local _, rh = T.TextSize(row.role, T.font.tiny)
      T.Text(roleX, ry + (rowH - rh) / 2, row.role, C.muted, T.font.tiny)
    end
    T.Text(lvlR, ty, row.level and tostring(row.level) or "\xE2\x80\x93", C.muted, T.font.small, "right")
    T.Text(distR, ty, row.dist and tostring(row.dist) or "\xE2\x80\x93", C.muted, T.font.small, "right")
    if hovered and row.trains then ui.SetTooltip("Trains " .. row.trains) end
  end
  ui.EndChild()

  -- the count and the selection
  local sy = py1 + GAP * s
  local _, stH = T.TextSize("Ag", T.font.tiny)
  local ty = sy + (STATUS_H * s - stH) / 2
  T.Text(cx, ty, string.format("%d of %d spawns", n, state.total), C.faint, T.font.tiny)
  local right_text, right_color = "Nothing selected", C.faint
  if state.error then right_text, right_color = state.error, C.bad
  elseif state.selected then right_text = "Selected: " .. (state.selectedName or "") end
  local countW = T.TextSize(string.format("%d of %d spawns", n, state.total), T.font.tiny)
  T.Text(cx + w, ty, T.Fit(right_text, w - countW - 12 * s, T.font.tiny), right_color, T.font.tiny, "right")

  -- Travel to
  local by = sy + (STATUS_H + GAP) * s
  local enabled = state.selected ~= nil
  if T.Button("##fwtravel", cx, by, cx + w, by + BUTTON_H * s, s, "Travel to", {
    primary = true, enabled = enabled,
    tooltip = enabled and "Target it and walk there (or double click a row)" or "Select something in the list first",
  }) then
    travel(qol, state.selected)
  end
end

ui.window("FindWalk", function()
  local qol = eq.Plugin("script:qol")
  local open = qol and eq.InGame() and qol.findwalk_state()
  if type(open) ~= "table" or not open.open then
    state.wasOpen = false
    return
  end
  if not state.wasOpen then state.wasOpen, state.dirty, state.scrollTop = true, true, true end
  if open.serial ~= state.serial then -- /findW <text>
    state.serial, state.dirty, state.scrollTop = open.serial, true, true
    if open.serial ~= 0 then state.search = open.search end
  end
  if state.dirty or not state.fetchedAt or ui.GetTime() - state.fetchedAt >= REFRESH then fetch(qol) end
  hud.Dialog(WINDOW, "Find", {
    shown = true,
    keepTitle = true,
    size = function() return state.hasRole and WIDTH_ROLE or WIDTH_PLAIN, CONTENT_H end,
    onClose = function() qol.findwalk_close() end,
  }, function(x, y, w, h, s) body(x, y, w, h, s, qol) end)
end)
