-- Named tracker: two windows of its own (/named). The tracker lists a zone's named spawns; a gold * marks a tracked
-- one (tracking is managed in the editor window), the x at a row's right edge removes the name from the list (it
-- appears in the editor's suggestion list again, where + brings it back), a green dot means
-- the spawn is up here now, and the up ones show how far away they are. A row is clicked to select it (an up one is
-- targeted too) and the selected row's known drops are listed under the list; a drop is clicked to open the item in
-- game. The editor window adds a name by hand and offers the names the zone's data knows. All state and data come from the
-- named_* functions in init.lua (which read the generated core/named_data.lua); this file only draws what it gets.
local hud = dofile("lib/hud.lua")
local T = hud.T
local C = T.color

local WINDOW = "NamedWnd" -- the tracker dialog
local EDIT_WINDOW = "NamedEditWnd" -- the list editor dialog
local REFRESH = 0.5 -- seconds between two reads of the zone
local BLINK_S = 3 -- a row blinks this long when its named comes up (not seen -> seen)

-- Design pixels. The dialog adds 10 each side, so the tracker window is 410 wide and the editor 360. Both windows
-- are resizable: these sizes are the defaults, and the named list (the editor's two lists) takes whatever height the
-- window is dragged to; the text keeps its size.
local WIDTH, EDIT_WIDTH = 390, 340
local MIN_W, MIN_H = 360, 280 -- the tracker's smallest size
local EDIT_MIN_W, EDIT_MIN_H = 320, 220 -- the editor's smallest size
local TOP_H, GAP, STATUS_H = 24, 8, 14
local HEAD_H, LIST_H, ROW_PAD, COL_GAP = 22, 160, 8, 10
local STAR_W, UP_W, X_W, COL_DIST, EDIT_W, ADD_W = 16, 16, 16, 48, 88, 56
local HEAD_TEXT_H, DROPS_H = 16, 76
local EDIT_LABEL_H, EDIT_INPUT_H, EDIT_ROW_H, EDIT_ROWS = 12, 24, 20, 8
local PANEL_CHROME = 1 + 4 + HEAD_H + 1 -- the named panel without its list: borders, padding, column head
local PANEL_H = PANEL_CHROME + LIST_H -- the panel at the default height
local DROPS_PANEL_H = 1 + DROPS_H + 1
local CONTENT_H = TOP_H + GAP + PANEL_H + GAP + HEAD_TEXT_H + GAP + DROPS_PANEL_H + GAP + STATUS_H
-- The tracker's fixed parts, in design pixels: everything except the two flexible list heights (the named list and
-- the drops list share what is left; the divider between them is draggable and kept in the plugin's store).
local FIXED_H = TOP_H + GAP + PANEL_CHROME + GAP + HEAD_TEXT_H + GAP + 2 + GAP + STATUS_H
local MIN_LIST_H = 3 * EDIT_ROW_H -- the named list keeps room for a few rows however short the window is
local MIN_DROPS_H = 2 * EDIT_ROW_H -- the drops list keeps room for a couple of rows
local MIN_EDIT_LIST_H = 2 * EDIT_ROW_H -- the editor's lists keep room for a couple of rows each

local STAR = "*" -- a tracked name, drawn only (no button; plain ASCII: the game fonts lack star glyphs)
local DASH = "-"
local DROPS_HINT = "click an item to open it in game"

-- ---------------------------------------------------------------- the tracker window

local state = {
  zone = nil, -- the zone the combo shows: a short name, resolved from the one the plugin asked for
  zones = nil, -- named_zones(): where the combo's entries come from
  list = nil, -- named_list(zone): the rows and whether this is the current zone
  selected = nil, selectedName = nil, -- the selected row's name and what it shows
  drops = nil, dropsFor = nil, -- named_drops for the selected name (only while it is still the same one)
  error = nil,
  barW = 0,
  fetchedAt = nil, dropsAt = nil, dirty = true, dropsDirty = true, serial = nil, scrollTop = false, wasOpen = false,
  split = nil, -- the divider between the named list and the drops list (design px), from named_split() once
  blink = {}, -- row name -> time its named first showed up (not seen -> seen), for the blink highlight
  wasSpawned = {}, -- row name -> whether it was up at the last read
}

-- The zone's entries, the tracked list and the rows, at most every REFRESH seconds.
local function fetchList(qol)
  local zones = qol.named_zones()
  if type(zones) == "table" then state.zones = zones end
  if state.split == nil then -- the saved divider, fetched once (our own drags keep the local value)
    local sp = qol.named_split()
    if type(sp) == "number" then state.split = sp end
  end
  local result = qol.named_list(state.zone)
  state.fetchedAt, state.dirty = ui.GetTime(), false
  if type(result) ~= "table" then return end
  state.list = result
  if state.zone == nil then state.zone = result.zone end -- the zone asked for, here the current one, resolved once
  -- a named that just came up (not up at the last read, spawned now) gets a blink mark for BLINK_S seconds
  local now = ui.GetTime()
  local seen = {}
  for _, row in ipairs(result.rows or {}) do
    if row.name then
      if row.spawned and not state.wasSpawned[row.name] then state.blink[row.name] = now end
      seen[row.name] = row.spawned == true
    end
  end
  for name in pairs(state.blink) do
    if not seen[name] then state.blink[name] = nil end -- row no longer listed
  end
  state.wasSpawned = seen
  -- the selection survives a refresh only while its row is still listed
  if state.selected then
    local found = false
    for _, row in ipairs(result.rows or {}) do
      if row.name == state.selected then found = true break end
    end
    if not found then state.selected, state.selectedName, state.drops, state.dropsFor = nil, nil, nil, nil end
  end
end

local function fetchDrops(qol)
  state.dropsAt = ui.GetTime()
  local name = state.selected
  if not name or not state.zone then state.drops, state.dropsFor = nil, nil return end
  local result = qol.named_drops(state.zone, name)
  state.dropsFor = name
  if type(result) ~= "table" then state.drops = nil return end
  state.drops = result.drops or {}
end

-- Target an up named; a refusal is shown in the status line.
local function target(qol, id)
  local result = qol.named_target(id)
  if type(result) == "table" and result.ok then
    state.error = nil
  else
    state.error = (type(result) == "table" and result.error) or "Could not target it."
  end
end

-- Remove a row's name from the tracker window (the "x" at its right edge): the name then appears in the
-- Named list window's suggestion list, where adding it brings it back. A refusal is shown in the status line.
local function hideRow(qol, row)
  local result = qol.named_hide(state.zone, row.name)
  if type(result) == "table" and not result.ok then
    state.error = result.error or "Could not remove it."
  else
    state.error = nil
  end
  fetchList(qol)
  state.dropsDirty = true
end

-- Open a drop's item in game; a refusal is shown in the status line.
local function openItem(qol, id)
  local result = qol.named_open_item(id)
  if type(result) == "table" and result.ok then
    state.error = nil
  else
    state.error = (type(result) == "table" and (result.error or "Could not open the item.")) or "Could not open the item."
  end
end

-- The entry the combo shows: the chosen zone, else the current one (named_zones() puts it first).
local function chosenZone()
  local zones = state.zones and state.zones.zones or {}
  for _, zone in ipairs(zones) do
    if zone.short == state.zone then return zone end
  end
  return zones[1]
end

local function zoneLabel(zone)
  if not zone then return "Zone..." end
  return zone.long .. " (" .. zone.short .. ")"
end

-- A chance as a short percentage: %g keeps whole numbers whole and repeats no useless digits.
local function chanceText(chance)
  if type(chance) ~= "number" then return DASH end
  return string.format("%g%%", chance)
end

-- An inset panel like findwalk's list: the inset rectangle with its faint outline.
local function panel(x0, y0, x1, y1, s)
  ui.DrawRectFilled(x0, y0, x1, y1, C.inset[1], C.inset[2], C.inset[3], C.inset[4], 6 * s)
  ui.DrawRect(x0, y0, x1, y1, C.ink[1], C.ink[2], C.ink[3], 0.12, 6 * s, 1)
end

-- A column head over a list; here it only labels (the lists keep the order their data gives).
local function head(label, x, y0, y1, s, align)
  local _, th = T.TextSize(label, T.font.tiny)
  T.Text(x, y0 + (y1 - y0 - th) / 2, label, C.faint, T.font.tiny, align or "left")
end

local function body(cx, cy, w, h, s, qol)
  local textH = select(2, T.TextSize("Ag", T.font.small))
  local rowH = math.floor(textH + 8 * s + 0.5)
  local list = state.list or { rows = {} }
  local rows = list.rows or {}
  local pad, gap = ROW_PAD * s, COL_GAP * s

  -- the zone picker and the Edit list button
  ui.SetCursorScreenPos(cx, cy)
  ui.SetNextItemWidth(w - (EDIT_W + GAP) * s)
  if ui.BeginCombo("##namedzone", zoneLabel(chosenZone())) then
    for _, zone in ipairs((state.zones and state.zones.zones) or {}) do
      local chosen = zone.short == state.zone
      if ui.Selectable(zoneLabel(zone) .. "##namedz" .. tostring(zone.short), chosen) then
        state.zone, state.dirty = zone.short, true
        state.selected, state.selectedName, state.drops, state.dropsFor, state.error = nil, nil, nil, nil, nil
        state.dropsDirty, state.scrollTop = true, true
      end
      if chosen then ui.SetItemDefaultFocus() end
    end
    ui.EndCombo()
  end
  if T.Button("##namededit", cx + w - EDIT_W * s, cy, cx + w, cy + TOP_H * s, s, "Edit list",
      { tooltip = "Edit the names tracked in the zones" }) then
    qol.named_edit_set(true)
  end

  -- the named list and the drops list share the height beyond the fixed parts; the divider between them is
  -- draggable and its position (design px of list height) is kept by the plugin. h arrives in screen pixels.
  local availH = h / s - FIXED_H
  local maxListH = math.max(MIN_LIST_H, availH - MIN_DROPS_H)
  local listH = math.min(math.max(state.split or LIST_H, MIN_LIST_H), maxListH)
  local dropsH = math.max(MIN_DROPS_H, availH - listH)

  -- the panel: column heads over the list
  local px0, py0 = cx, cy + (TOP_H + GAP) * s
  local px1, py1 = cx + w, py0 + (PANEL_CHROME + listH) * s
  panel(px0, py0, px1, py1, s)

  -- columns from the right edge: the remove "x", then Dist, then the up dot's column; the star and the name take the rest
  local xR = px1 - state.barW - pad
  local distR = xR - X_W * s - gap
  local upR = distR - COL_DIST * s - gap
  local upDotX = upR - (UP_W * s) / 2
  local starX = px0 + pad
  local nameX = starX + STAR_W * s + gap
  local nameR = upR - gap

  local hy0 = py0 + 5 * s
  local hy1 = hy0 + (HEAD_H - 1) * s
  head("NAME", nameX, hy0, hy1, s)
  head("UP?", upR, hy0, hy1, s, "right")
  head("DIST", distR, hy0, hy1, s, "right")
  ui.DrawLine(px0 + 1, hy1, px1 - 1, hy1, C.ink[1], C.ink[2], C.ink[3], 0.12, 1)

  -- the rows, drawn only where the list shows them
  local lx, ly = px0 + 1, hy1 + 1
  local lw, lh = w - 2, listH * s
  ui.SetCursorScreenPos(lx, ly)
  ui.BeginChild("##namedlist", lw, lh, false)
  if state.scrollTop then
    ui.SetScrollY(0)
    state.scrollTop = false
  end
  local n = #rows
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
    local selected = row.name ~= nil and row.name == state.selected
    if T.Hit("##nmr" .. i, ox, ry, right, ry + rowH) then
      state.selected, state.selectedName = row.name, row.display or row.name
      state.drops, state.dropsDirty, state.error = nil, true, nil
      if row.spawned then target(qol, row.id) end
    end
    local hovered = ui.IsItemHovered()
    if selected then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.accent[1], C.accent[2], C.accent[3], 0.22, 0)
      ui.DrawRect(ox, ry, right, ry + rowH, C.accent[1], C.accent[2], C.accent[3], 1, 0, 1)
    elseif hovered then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.10, 0)
    elseif i % 2 == 0 then
      ui.DrawRectFilled(ox, ry, right, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.06, 0)
    end
    -- blink for BLINK_S seconds when the named just came up (not seen -> seen)
    local blinkAt = state.blink[row.name]
    if blinkAt then
      local t = ui.GetTime() - blinkAt
      if t < BLINK_S and math.floor(t / 0.25) % 2 == 0 then
        ui.DrawRectFilled(ox, ry, right, ry + rowH, C.accent[1], C.accent[2], C.accent[3], 0.38, 0)
      end
    end
    -- the remove "x" at the row's right edge (its own hit box, submitted after the row's so it wins
    -- where they overlap; the row click still selects/targets)
    if T.Hit("##nmx" .. i, xR - X_W * s, ry, xR, ry + rowH) then
      hideRow(qol, row)
    end
    local xHovered = ui.IsItemHovered()
    if xHovered then ui.SetTooltip("Remove from this list - it appears in the Named list window") end
    local ty = ry + (rowH - textH) / 2
    if row.tracked then T.Text(starX, ty, STAR, C.gold, T.font.small) end -- passive marker only
    T.Text(xR - X_W * s / 2, ty, "x", xHovered and C.bad or C.faint, T.font.small, "center")
    T.Text(nameX, ty, T.Fit(row.display or row.name or DASH, nameR - nameX, T.font.small), C.text, T.font.small)
    if list.current then -- only here is "up here now" and a distance meaningful
      if row.spawned then
        ui.DrawCircleFilled(upDotX, ry + rowH / 2, 3 * s, C.pet[1], C.pet[2], C.pet[3], 1)
      else
        ui.DrawCircle(upDotX, ry + rowH / 2, 3 * s, C.faint[1], C.faint[2], C.faint[3], 0.9, 1)
      end
      T.Text(distR, ty, row.dist and tostring(math.floor(row.dist + 0.5)) or DASH, C.muted, T.font.small, "right")
    end
    if hovered and row.custom then ui.SetTooltip("A named you added yourself") end
  end
  if n == 0 then
    T.Text(starX, oy + (rowH - textH) / 2, "No named listed for this zone.", C.faint, T.font.small)
  end
  ui.EndChild()

  -- the divider between the named list and the drops: drag it to give one of the two lists more room;
  -- the position is kept by the plugin when the drag ends
  local sy0, sy1 = py1 - 2 * s, py1 + (GAP + 2) * s
  local splitClicked = T.Hit("##nmsplit", px0, sy0, px1, sy1)
  local splitActive, splitHovered = ui.IsItemActive(), ui.IsItemHovered()
  if splitActive and ui.IsMouseDragging(ui.Mouse.Left) then
    state.split = math.min(math.max((state.split or LIST_H) + ui.GetIO().mouseDY / s, MIN_LIST_H), maxListH)
  end
  if splitClicked then qol.named_split_set(math.floor((state.split or LIST_H) + 0.5)) end
  if splitActive or splitHovered then
    local my = (sy0 + sy1) / 2
    ui.DrawLine(px0 + 2 * s, my, px1 - 2 * s, my, C.accent[1], C.accent[2], C.accent[3],
      splitActive and 1 or 0.6, 2 * s)
    if splitHovered and not splitActive then ui.SetTooltip("Drag to give the lists more or less room") end
  end

  -- the selected row's drops: the name, the hint, then one row an item
  local ody = py1 + GAP * s
  local _, dh = T.TextSize("Ag", T.font.small)
  local dty = ody + (HEAD_TEXT_H * s - dh) / 2
  local hintW, hintH = T.TextSize(DROPS_HINT, T.font.tiny)
  T.Text(cx + w, ody + (HEAD_TEXT_H * s - hintH) / 2, DROPS_HINT, C.faint, T.font.tiny, "right")
  local dropsHead = state.selectedName and ("Drops - " .. state.selectedName) or "Drops"
  T.Text(cx, dty, T.Fit(dropsHead, w - hintW - 12 * s, T.font.small), C.text, T.font.small)

  local q0 = ody + (HEAD_TEXT_H + GAP) * s
  local q1 = q0 + (1 + dropsH + 1) * s
  panel(cx, q0, cx + w, q1, s)
  local drops = (state.selected and state.dropsFor == state.selected and state.drops) or nil
  local dn = drops and #drops or 0
  local dlx, dly = cx + 1, q0 + 1
  local dlw, dlh = w - 2, dropsH * s
  ui.SetCursorScreenPos(dlx, dly)
  ui.BeginChild("##nameddrops", dlw, dlh, false)
  local dox, doy = ui.GetCursorScreenPos()
  local davail = ui.GetContentRegionAvail()
  local bright = dox + davail
  local itemR = bright - pad -- the chance's right edge
  local itemR2 = itemR - 40 * s - gap -- the item name's right edge
  for i = 1, dn do
    local drop = drops[i]
    local ry = doy + (i - 1) * rowH
    if T.Hit("##nmd" .. i, dox, ry, bright, ry + rowH) then openItem(qol, drop.id) end
    local hovered = ui.IsItemHovered()
    if hovered then
      ui.DrawRectFilled(dox, ry, bright, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.10, 0)
      ui.SetTooltip("Open it in game")
    end
    local ty = ry + (rowH - textH) / 2
    local label = drop.item or ("#" .. tostring(drop.id))
    T.Text(dox + pad, ty, T.Fit(label, itemR2 - (dox + pad), T.font.small), C.link, T.font.small)
    T.Text(itemR, ty, chanceText(drop.chance), C.muted, T.font.small, "right")
  end
  if dn == 0 then
    local empty = state.selected and "No known drops for this name." or "Select a named to see its drops."
    T.Text(dox + pad, doy + (rowH - textH) / 2, empty, C.faint, T.font.small)
  end
  ui.EndChild()

  -- the count and the selection
  local sy = q1 + GAP * s
  local _, stH = T.TextSize("Ag", T.font.tiny)
  local ty = sy + (STATUS_H * s - stH) / 2
  local up = 0
  for i = 1, n do
    if rows[i].spawned then up = up + 1 end
  end
  local left = list.current and string.format("%d of %d up in %s", up, n, state.zone) or (list.long or state.zone)
  T.Text(cx, ty, left, C.faint, T.font.tiny)
  local rightText, rightColor = "Nothing selected", C.faint
  if state.error then
    rightText, rightColor = state.error, C.bad
  elseif state.selectedName then
    rightText = "Selected: " .. state.selectedName
  end
  local leftW = T.TextSize(left, T.font.tiny)
  T.Text(cx + w, ty, T.Fit(rightText, w - leftW - 12 * s, T.font.tiny), rightColor, T.font.tiny, "right")
end

-- ---------------------------------------------------------------- the list editor window

local edit = {
  zone = nil, -- the zone short name being edited (the tracker window resolves it first)
  names = {}, suggestions = {}, -- named_tracked(): the names tracked here and those the zone's data knows
  text = "", error = nil,
  fetchedAt = nil, wasOpen = false,
}

local function fetchEdit(qol)
  local result = qol.named_tracked(edit.zone)
  edit.fetchedAt = ui.GetTime()
  if type(result) ~= "table" then return end
  edit.names, edit.suggestions = result.names or {}, result.suggestions or {}
end

-- Track one name in the zone; a refusal is shown in the status line. The list is read again afterwards.
local function addNamed(qol, name)
  if not name or name == "" then return end
  local result = qol.named_add(edit.zone, name)
  fetchEdit(qol)
  if type(result) == "table" and not result.ok then
    edit.error = result.error or "Could not add it."
  else
    edit.error = nil
    if name == edit.text then edit.text = "" end -- a typed name is handed over: the input starts empty again
  end
end

-- The design pixels of the editor's inner list: a row for each entry, at least one (two rows added around it).
local function listInner(n)
  return (n > 0 and math.min(n, EDIT_ROWS) or 1) * EDIT_ROW_H
end

-- The editor's fixed parts, in design pixels: the input row, the one section label with its gap, the panel's
-- borders and the status line. The known-names list gets the rest of the height.
local EDIT_FIXED_H = EDIT_INPUT_H + GAP + (EDIT_LABEL_H + GAP) + 2 + GAP + STATUS_H

local function editContentH()
  return EDIT_FIXED_H + listInner(#edit.suggestions)
end

local function editBody(cx, cy, w, h, s, qol)
  local textH = select(2, T.TextSize("Ag", T.font.small))
  local rowH = EDIT_ROW_H * s
  local pad, gap = ROW_PAD * s, COL_GAP * s
  local bs = 16 * s
  -- the known-names list takes the height the window has beyond the fixed parts
  local knownH = math.max(MIN_EDIT_LIST_H, h / s - EDIT_FIXED_H)

  -- add a name by hand
  ui.SetCursorScreenPos(cx, cy)
  ui.SetNextItemWidth(w - (ADD_W + GAP) * s)
  local text = ui.InputTextWithHint("##nmadd", "Add a name...", edit.text, 64)
  if text ~= edit.text then edit.text = text end
  if ui.IsItemHovered() then ui.SetTooltip("Add this name to the zone's watch list") end
  if T.Button("##nmaddbtn", cx + w - ADD_W * s, cy, cx + w, cy + EDIT_INPUT_H * s, s, "Add",
      { enabled = edit.text ~= "", tooltip = "Add this name to the zone's watch list" }) then
    addNamed(qol, edit.text)
  end

  -- the names the zone's data knows (removed ones included), one row each with a small +
  local ky = cy + (EDIT_INPUT_H + GAP) * s
  T.Text(cx, ky, "KNOWN NAMED IN THIS ZONE (from data)", C.faint, T.font.tiny)
  local kpy = ky + (EDIT_LABEL_H + GAP) * s
  local sugg = edit.suggestions
  local kInner = knownH * s
  local k1 = kpy + kInner + 2
  panel(cx, kpy, cx + w, k1, s)
  ui.SetCursorScreenPos(cx + 1, kpy + 1)
  ui.BeginChild("##nmknown", w - 2, kInner, false)
  local kox, koy = ui.GetCursorScreenPos()
  local kavail = ui.GetContentRegionAvail()
  local kright = kox + kavail
  for i = 1, #sugg do
    local row = sugg[i]
    local ry = koy + (i - 1) * rowH
    if i % 2 == 0 then
      ui.DrawRectFilled(kox, ry, kright, ry + rowH, C.ink[1], C.ink[2], C.ink[3], 0.06, 0)
    end
    local ty = ry + (rowH - textH) / 2
    local lvlR = kright - pad - bs - gap
    local mainR = lvlR - 40 * s - gap -- the level takes the rest of the row before the + button
    local main = row.display or row.name or DASH
    local fitted = T.Fit(main, mainR - (kox + pad), T.font.small)
    T.Text(kox + pad, ty, fitted, C.text, T.font.small)
    -- a sole display name can hide its key: the raw name follows it faintly when the two differ
    if row.name and row.name ~= main then
      local mx = math.min(kox + pad + T.TextSize(fitted, T.font.small) + gap / 2, mainR)
      T.Text(mx, ty, T.Fit(row.name, mainR - mx, T.font.tiny), C.faint, T.font.tiny)
    end
    T.Text(lvlR, ty, row.level and tostring(row.level) or DASH, C.muted, T.font.small, "right")
    if T.Button("##nmad" .. i, kright - pad - bs, ry + (rowH - bs) / 2, kright - pad, ry + (rowH + bs) / 2, s,
        "+", { tooltip = "Add " .. (row.name or main) .. " to the list" }) then
      addNamed(qol, row.name)
    end
  end
  if #sugg == 0 then
    T.Text(kox + pad, koy + (rowH - textH) / 2, "Nothing known about this zone.", C.faint, T.font.small)
  end
  ui.EndChild()

  -- the count and any refusal of the last change
  local sy = k1 + GAP * s
  local _, tinyH = T.TextSize("Ag", T.font.tiny)
  local ty = sy + (STATUS_H * s - tinyH) / 2
  local count = #sugg .. " known in this zone"
  T.Text(cx, ty, count, C.faint, T.font.tiny)
  if edit.error then
    local countW = T.TextSize(count, T.font.tiny)
    T.Text(cx + w, ty, T.Fit(edit.error, w - countW - 12 * s, T.font.tiny), C.bad, T.font.tiny, "right")
  end
end

-- ---------------------------------------------------------------- the windows

ui.window("NamedTracker", function()
  local qol = eq.Plugin("script:qol")
  local open = qol and eq.InGame() and qol.named_state()
  if type(open) ~= "table" or not open.open then
    state.wasOpen = false
    return
  end
  if not state.wasOpen then state.wasOpen, state.dirty, state.scrollTop, state.dropsDirty = true, true, true, true end
  if open.serial ~= state.serial then -- /named [zone]
    state.serial, state.zone = open.serial, open.zone
    state.dirty, state.scrollTop, state.dropsDirty = true, true, true
    state.selected, state.selectedName, state.drops, state.dropsFor, state.error = nil, nil, nil, nil, nil
    state.fetchedAt, state.dropsAt = nil, nil
    state.blink, state.wasSpawned = {}, {} -- no blinking for a zone we just switched to
  end
  if state.dirty or not state.fetchedAt or ui.GetTime() - state.fetchedAt >= REFRESH then
    fetchList(qol)
    state.dropsDirty = true
  end
  if state.dropsDirty or not state.dropsAt or ui.GetTime() - state.dropsAt >= REFRESH then fetchDrops(qol) end
  hud.Dialog(WINDOW, "Named", {
    shown = true,
    keepTitle = true,
    size = function() return WIDTH, CONTENT_H end,
    resizable = { MIN_W, MIN_H },
    onClose = function() qol.named_close() end,
  }, function(x, y, w, h, s) body(x, y, w, h, s, qol) end)
end)

ui.window("NamedEdit", function()
  local qol = eq.Plugin("script:qol")
  local open = qol and eq.InGame() and qol.named_state()
  if type(open) ~= "table" or open.edit ~= true then
    edit.wasOpen = false
    return
  end
  -- the zone comes from the plugin; before its tracker resolve has run, the tracker window's resolution will do
  local zone = open.zone or state.zone
  if not zone then
    edit.wasOpen = false
    return
  end
  if not edit.wasOpen or edit.zone ~= zone then
    edit.wasOpen, edit.zone = true, zone
    edit.fetchedAt, edit.error = nil, nil
  end
  if not edit.fetchedAt or ui.GetTime() - edit.fetchedAt >= REFRESH then fetchEdit(qol) end
  hud.Dialog(EDIT_WINDOW, "Named list - " .. edit.zone, {
    shown = true,
    keepTitle = true,
    size = function() return EDIT_WIDTH, editContentH() end,
    resizable = { EDIT_MIN_W, EDIT_MIN_H },
    onClose = function() qol.named_edit_set(false) end,
  }, function(x, y, w, h, s) editBody(x, y, w, h, s, qol) end)
end)
