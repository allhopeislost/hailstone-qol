-- The FindWalk window's layout, drawn against a fake ui that records every call. It checks the structure the design
-- calls for (columns, alignment, the Role column coming and going with the window's width, the sort arrow) with no
-- client. Run from qol/. `lua tests/findwalk_layout.lua --svg DIR` also writes DIR/findwalk-*.svg to look at.
local find = dofile('core/findwalk.lua')
local svgDir = arg and arg[1] == '--svg' and arg[2] or nil

-- ---------------------------------------------------------------- a fake ui that records what is drawn
local ops, clicks, hover = {}, {}, nil
local cursor, lastItem, nextWidth, scroll = {x = 0, y = 0}, nil, nil, 0
local child, scrollbar = nil, false
local fontPx = {[2] = 12, [3] = 13, [5] = 16, [6] = 20}
local function textWidth(text, font) return #text * (fontPx[font] or 13) * 0.55 end
local function textHeight(font) return (fontPx[font] or 13) * 1.2 end
local color = {0.9, 0.9, 0.9, 1}
local palette = {}
for _, name in ipairs({'text', 'muted', 'faint', 'accent', 'ink', 'pet', 'gold', 'bad', 'inset', 'window'}) do
  palette[name] = {1, 1, 1, 1}
end
palette.inset = {0.02, 0.024, 0.034, 0.75}
palette.window = {0.05, 0.06, 0.082, 1}
palette.accent = {0.48, 0.78, 1.0, 1}
palette.faint = {0.5, 0.55, 0.63, 1}
palette.muted = {0.66, 0.72, 0.8, 1}
palette.text = {0.93, 0.95, 0.98, 1}
palette.pet = {0.36, 0.84, 0.54, 1}
palette.gold = {1.0, 0.8, 0.36, 1}
palette.bad = {1.0, 0.36, 0.36, 1}

local function record(op) ops[#ops + 1] = op return op end
local function item(x0, y0, x1, y1) lastItem = {x0 = x0, y0 = y0, x1 = x1, y1 = y1} cursor = {x = x0, y = y1} end

local T = {
  color = palette,
  font = {tiny = 2, small = 3, normal = 5, large = 6},
  TextSize = function(text, font) return textWidth(text, font), textHeight(font) end,
  Fit = function(text, width, font)
    if textWidth(text, font) <= width then return text end
    local n = #text
    while n > 1 and textWidth(text:sub(1, n) .. '...', font) > width do n = n - 1 end
    return text:sub(1, n) .. '...'
  end,
  Text = function(x, y, text, col, font, align)
    local w = textWidth(text, font)
    record({kind = 'text', x = x, y = y, text = text, color = col, font = font, align = align or 'left', w = w})
    return w, textHeight(font)
  end,
  Hit = function(id, x0, y0, x1, y1)
    item(x0, y0, x1, y1)
    record({kind = 'hit', id = id, x0 = x0, y0 = y0, x1 = x1, y1 = y1})
    lastItem.id = id
    return clicks[id] == true
  end,
  Button = function(id, x0, y0, x1, y1, s, label, opts)
    item(x0, y0, x1, y1)
    lastItem.id = id
    record({kind = 'button', id = id, x0 = x0, y0 = y0, x1 = x1, y1 = y1, label = label, opts = opts})
    return clicks[id] == true and (opts == nil or opts.enabled ~= false)
  end,
}

local tooltip, doubleClick
local ui = {
  Mouse = {Left = 0},
  GetTime = function() return 0 end,
  GetCursorScreenPos = function() return cursor.x, cursor.y - (child and scroll or 0) end,
  SetCursorScreenPos = function(x, y) cursor = {x = x, y = y} end,
  SetNextItemWidth = function(w) nextWidth = w end,
  InputTextWithHint = function(id, hint, text)
    local w = nextWidth or 200
    nextWidth = nil
    record({kind = 'input', id = id, hint = hint, text = text, x0 = cursor.x, y0 = cursor.y, x1 = cursor.x + w,
      y1 = cursor.y + 24})
    item(cursor.x, cursor.y, cursor.x + w, cursor.y + 24)
    return text, false
  end,
  Checkbox = function(label, value)
    local name = label:match('^(.-)##')
    local w = 17 + 4 + textWidth(name, 3)
    record({kind = 'check', label = name, checked = value, x0 = cursor.x, y0 = cursor.y, x1 = cursor.x + w,
      y1 = cursor.y + 17})
    item(cursor.x, cursor.y, cursor.x + w, cursor.y + 17)
    return clicks[label] and not value or value, clicks[label] == true
  end,
  SameLine = function(offset, spacing) cursor = {x = lastItem.x1 + (spacing or 8), y = lastItem.y0} end,
  BeginChild = function(id, w, h)
    child = {id = id, x0 = cursor.x, y0 = cursor.y, x1 = cursor.x + w, y1 = cursor.y + h}
    record({kind = 'child', id = id, x0 = child.x0, y0 = child.y0, x1 = child.x1, y1 = child.y1})
    return true
  end,
  EndChild = function() child = nil record({kind = 'endchild'}) end,
  GetScrollY = function() return scroll end,
  SetScrollY = function(y) scroll = y end,
  GetContentRegionAvail = function() return (child.x1 - child.x0) - (scrollbar and 14 or 0), child.y1 - child.y0 end,
  Dummy = function(w, h)
    if child then scrollbar = h > (child.y1 - child.y0) end
  end,
  IsItemHovered = function() return hover ~= nil and lastItem ~= nil and lastItem.id == hover end,
  SetTooltip = function(text) tooltip = text end,
  IsMouseDoubleClicked = function() return doubleClick == true end,
  DrawRectFilled = function(x0, y0, x1, y1, r, g, b, a, rad)
    record({kind = 'fill', x0 = x0, y0 = y0, x1 = x1, y1 = y1, color = {r, g, b, a}, rad = rad})
  end,
  DrawRect = function(x0, y0, x1, y1, r, g, b, a, rad)
    record({kind = 'rect', x0 = x0, y0 = y0, x1 = x1, y1 = y1, color = {r, g, b, a}, rad = rad})
  end,
  DrawLine = function(x0, y0, x1, y1, r, g, b, a)
    record({kind = 'line', x0 = x0, y0 = y0, x1 = x1, y1 = y1, color = {r, g, b, a}})
  end,
  DrawTriangleFilled = function(x1, y1, x2, y2, x3, y3, r, g, b, a)
    record({kind = 'triangle', pts = {x1, y1, x2, y2, x3, y3}, color = {r, g, b, a}})
  end,
}

-- A dialog as the client draws it: title bar above, 10 px of padding each side, the contents' size from opts.size.
local TITLE_H, PAD_X, PAD_Y = 28, 10, 8
local dialog
local hud = {
  T = T,
  Dialog = function(screen, title, opts, body)
    if opts.shown == false then return end
    local w, h = opts.size(1)
    dialog = {x = 100, y = 100, w = w + 2 * PAD_X, h = h + TITLE_H + PAD_Y * 2 - 8, contentW = w, contentH = h,
      title = title, screen = screen, onClose = opts.onClose}
    ops, tooltip = {}, nil
    body(dialog.x + PAD_X, dialog.y + TITLE_H + PAD_Y, w, h, 1)
  end,
}

-- ---------------------------------------------------------------- the zone and the plugin the window talks to
local me = {id = 1, x = 0, y = 0, z = 0}
local function spawn(id, name, x, class, extra)
  local s = {id = id, name = name, x = x, y = 0, z = 0, npc = true, level = 10, class = class or 1}
  for k, v in pairs(extra or {}) do s[k] = v end
  return s
end
local zone = {
  {id = 1, name = 'Me', npc = false, x = 0, y = 0, z = 0, level = 50},
  spawn(2, 'Banker_Vorn', 24, 40), spawn(3, 'Guildmaster_Aldric', 31, 21), spawn(4, 'Guildmaster_Selene', 58, 31),
  spawn(5, 'Barkeep_Tomas', 66, 41), spawn(6, 'Elara_the_Smith', 91, 41),
  spawn(7, 'Mirabel_the_Scribe_of_the_Northern_Reaches', 102, 41), spawn(8, 'Guard_Hanson', 88, 1, {level = 50}),
  spawn(9, 'a_city_rat', 120, 1, {level = 1}),
  spawn(10, 'a_gnoll_pup00', 42, 1, {level = 3}), spawn(11, 'a_gnoll_scout', 61, 1, {level = 6}),
  spawn(12, 'a_gnoll_pup01', 73, 1, {level = 3}), spawn(13, 'Gnasher', 1301, 1, {level = 8}),
  spawn(14, 'Dalamar', 23, 1, {npc = false, level = 51}), spawn(15, "Aedan's_corpse", 12, 1, {npc = false, corpse = true}),
}
local open = {open = true, search = '', serial = 0}
local travelled
local qol = {
  findwalk_state = function() return open end,
  findwalk_close = function() open.open = false end,
  findwalk_rows = function(query)
    local rows, total = find.rows(zone, me, query)
    return {rows = find.plain(rows), total = total, has_role = find.hasRole(rows)}
  end,
  findwalk_travel = function(id) travelled = id return {ok = true} end,
}
local drawWindow
eq = {
  Plugin = function() return qol end,
  InGame = function() return true end,
}
_G.ui = {window = function(name, fn) drawWindow = fn end}
for k, v in pairs(ui) do _G.ui[k] = v end
local realDofile = dofile
dofile = function(path)
  if path == 'lib/hud.lua' then return hud end
  return realDofile(path)
end
realDofile('ui/modern/findwalk.lua')
dofile = realDofile
assert(drawWindow, 'the window registers itself')

local function frame(opts)
  clicks, hover = opts and opts.clicks or {}, opts and opts.hover
  scroll = 0
  cursor, lastItem = {x = 0, y = 0}, nil
  drawWindow()
end
-- three frames: the list says in the first whether it scrolls, the columns move for its scroll bar in the next
local function settle(opts) frame(opts) frame(opts) frame(opts) end

local function find_op(kind, pred)
  for _, op in ipairs(ops) do
    if op.kind == kind and (not pred or pred(op)) then return op end
  end
end
local function all(kind, pred)
  local out = {}
  for _, op in ipairs(ops) do
    if op.kind == kind and (not pred or pred(op)) then out[#out + 1] = op end
  end
  return out
end
local function near(a, b, msg) assert(math.abs(a - b) < 0.01, (msg or '') .. ': ' .. tostring(a) .. ' vs ' .. tostring(b)) end

-- ---------------------------------------------------------------- the window with roles in the list
local function dump(name)
  if not svgDir then return end
  local f = assert(io.open(svgDir .. '/' .. name .. '.svg', 'w'))
  local function rgba(c) return string.format('rgba(%.0f,%.0f,%.0f,%.2f)', c[1] * 255, c[2] * 255, c[3] * 255, c[4] or 1) end
  local W, H = dialog.x * 2 + dialog.w, dialog.y + dialog.h + 40
  f:write(string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" font-family="sans-serif">\n', W, H))
  f:write(string.format('<rect width="100%%" height="100%%" fill="#06070a"/>\n'))
  f:write(string.format('<rect x="%d" y="%d" width="%d" height="%d" rx="8" fill="#0d0f15" stroke="#303644"/>\n', dialog.x, dialog.y, dialog.w, dialog.h))
  f:write(string.format('<rect x="%d" y="%d" width="%d" height="%d" rx="8" fill="#15192a"/>\n', dialog.x, dialog.y, dialog.w, TITLE_H))
  f:write(string.format('<text x="%d" y="%d" fill="#edf2fa" font-size="14" font-weight="600">%s</text>\n', dialog.x + 10, dialog.y + 19, dialog.title))
  f:write(string.format('<text x="%d" y="%d" fill="#a8b8cc" font-size="14" text-anchor="end">x</text>\n', dialog.x + dialog.w - 10, dialog.y + 19))
  local clip = find_op('child')
  f:write(string.format('<clipPath id="c"><rect x="%f" y="%f" width="%f" height="%f"/></clipPath>\n', clip.x0, clip.y0, clip.x1 - clip.x0, clip.y1 - clip.y0))
  for _, op in ipairs(ops) do
    if op.kind == 'child' then f:write('<g clip-path="url(#c)">\n') elseif op.kind == 'endchild' then f:write('</g>\n') end
    if op.kind == 'fill' then
      f:write(string.format('<rect x="%f" y="%f" width="%f" height="%f" rx="%f" fill="%s"/>\n', op.x0, op.y0, op.x1 - op.x0, op.y1 - op.y0, op.rad or 0, rgba(op.color)))
    elseif op.kind == 'rect' then
      f:write(string.format('<rect x="%f" y="%f" width="%f" height="%f" rx="%f" fill="none" stroke="%s"/>\n', op.x0, op.y0, op.x1 - op.x0, op.y1 - op.y0, op.rad or 0, rgba(op.color)))
    elseif op.kind == 'line' then
      f:write(string.format('<line x1="%f" y1="%f" x2="%f" y2="%f" stroke="%s"/>\n', op.x0, op.y0, op.x1, op.y1, rgba(op.color)))
    elseif op.kind == 'triangle' then
      f:write(string.format('<polygon points="%f,%f %f,%f %f,%f" fill="%s"/>\n', op.pts[1], op.pts[2], op.pts[3], op.pts[4], op.pts[5], op.pts[6], rgba(op.color)))
    elseif op.kind == 'text' then
      local anchor = op.align == 'right' and 'end' or 'start'
      f:write(string.format('<text x="%f" y="%f" font-size="%d" text-anchor="%s" fill="%s">%s</text>\n', op.x, op.y + (fontPx[op.font] or 13) * 0.95, fontPx[op.font] or 13, anchor, rgba(op.color), op.text))
    elseif op.kind == 'input' then
      f:write(string.format('<rect x="%f" y="%f" width="%f" height="%f" rx="4" fill="#1b202a" stroke="#6b7a94"/>\n', op.x0, op.y0, op.x1 - op.x0, op.y1 - op.y0))
      f:write(string.format('<text x="%f" y="%f" font-size="13" fill="%s">%s</text>\n', op.x0 + 8, op.y0 + 16, op.text == '' and '#808ea1' or '#edf2fa', op.text == '' and op.hint or op.text))
    elseif op.kind == 'check' then
      f:write(string.format('<rect x="%f" y="%f" width="15" height="15" rx="3" fill="%s" stroke="#6b7a94"/>\n', op.x0, op.y0 + 1, op.checked and '#7ac7ff' or '#1b202a'))
      f:write(string.format('<text x="%f" y="%f" font-size="13" fill="#edf2fa">%s</text>\n', op.x0 + 21, op.y0 + 13, op.label))
    elseif op.kind == 'button' then
      local on = not op.opts or op.opts.enabled ~= false
      f:write(string.format('<rect x="%f" y="%f" width="%f" height="%f" rx="5" fill="%s" stroke="%s"/>\n', op.x0, op.y0, op.x1 - op.x0, op.y1 - op.y0, on and 'rgba(122,199,255,.22)' or 'rgba(255,255,255,.03)', on and 'rgba(122,199,255,.5)' or 'rgba(255,255,255,.08)'))
      f:write(string.format('<text x="%f" y="%f" font-size="13" text-anchor="middle" fill="%s">%s</text>\n', (op.x0 + op.x1) / 2, (op.y0 + op.y1) / 2 + 5, on and '#edf2fa' or '#808ea1', op.label))
    end
  end
  f:write('</svg>\n')
  f:close()
end

-- the sorted column is marked: one arrow, up for ascending
settle()
assert(dialog.title == 'Find' and dialog.screen == 'FindWalkWnd')
assert(find_op('check', function(o) return o.label == 'NPC' end).checked == true, 'NPC is on by default')
assert(find_op('check', function(o) return o.label == 'PC' end).checked == false)
assert(find_op('check', function(o) return o.label == 'Corpse' end).checked == false)
local arrows = all('triangle')
assert(#arrows == 1, 'one arrow, on the sorted column')
assert(arrows[1].pts[2] > arrows[1].pts[6], 'ascending points up (the tip is above the base)')

-- roles in the list: Name, Role, Lvl and Dist, and the window is 410 wide (390 + the 10 px each side)
local function headText(label) return find_op('text', function(o) return o.text == label end) end
assert(dialog.contentW == 390 and dialog.w == 410, 'wide with the Role column: ' .. dialog.w)
local nameH, roleH, lvlH, distH = headText('NAME'), headText('ROLE'), headText('LVL'), headText('DIST')
assert(nameH and roleH and lvlH and distH, 'all four column heads')
assert(nameH.x < roleH.x and roleH.x < lvlH.x - lvlH.w and lvlH.x < distH.x - distH.w, 'Name, Role, Lvl, Dist left to right')
assert(lvlH.align == 'right' and distH.align == 'right' and nameH.align == 'left' and roleH.align == 'left')

-- every row lines up with its head: names and roles on the left edge, numbers on the right edge
local panel = find_op('fill', function(o) return o.rad == 6 end)
local function rowsOf(pred) return all('text', pred) end
local nameCells = rowsOf(function(o) return o.font == 3 and o.align == 'left' and o.y > nameH.y and o.y < find_op('child').y1 end)
local lvlCells = rowsOf(function(o) return o.font == 3 and o.align == 'right' and o.x == lvlH.x and o.y < find_op('child').y1 end)
local distCells = rowsOf(function(o) return o.font == 3 and o.align == 'right' and o.x == distH.x and o.y < find_op('child').y1 end)
assert(#nameCells >= 6 and #lvlCells == #nameCells and #distCells == #nameCells, 'every row has all its cells')
for _, c in ipairs(nameCells) do near(c.x, nameH.x, 'names start under NAME') end
local listBottom = find_op('child').y1
local roleCells = rowsOf(function(o) return o.font == 2 and o.align == 'left' and o.y > nameH.y and o.y < listBottom end)
assert(#roleCells >= 3, 'the roles are listed')
for _, c in ipairs(roleCells) do near(c.x, roleH.x, 'roles start under ROLE') end
-- rows are one height apart and the first sits right under the head
local ys = {}
for _, c in ipairs(nameCells) do ys[#ys + 1] = c.y end
for i = 2, #ys do near(ys[i] - ys[i - 1], ys[2] - ys[1], 'even rows') end
-- a name too long for its column is cut with dots and never reaches the Role column
for _, c in ipairs(nameCells) do assert(c.x + c.w <= roleH.x - 10 + 0.01, c.text .. ' stays out of the Role column') end
-- roles and service NPCs: no level, a dash
local dashes = all('text', function(o) return o.text == '\xE2\x80\x93' and o.x == lvlH.x end)
assert(#dashes >= 3, 'banker, trainers and merchants have no level')
assert(find_op('text', function(o) return o.text == 'Banker' end) and find_op('text', function(o) return o.text == 'Trainer' end)
  and find_op('text', function(o) return o.text == 'Merchant' end))
assert(find_op('text', function(o) return o.text == 'Banker Vorn' end), 'names are shown cleaned up')
-- A to Z by name at first: the arrow stands after NAME, pointing up; the first row is 'a city rat', 120 away
assert(nameCells[1].text == 'a city rat' and distCells[1].text == '120', 'whole numbers, no unit')
assert(find_op('triangle').pts[1] > nameH.x + nameH.w, 'the arrow stands after NAME')
for i = 2, #nameCells do assert(nameCells[i - 1].text:lower() <= nameCells[i].text:lower(), 'A to Z') end
-- the panel, its head and the list sit inside each other
local child = find_op('child')
assert(child.x0 > panel.x0 and child.x1 < panel.x1 and child.y1 < panel.y1 and child.y0 > nameH.y)
-- the Travel to button is as wide as the contents, disabled until a row is chosen
local button = find_op('button')
assert(button.label == 'Travel to' and button.opts.enabled == false and button.opts.tooltip:find('Select'))
near(button.x1 - button.x0, 390, 'the button fills the width')
local search = find_op('input')
near(search.x1 - search.x0, 390, 'the search fills the width')
assert(find_op('text', function(o) return o.text == 'Nothing selected' end))
assert(find_op('text', function(o) return o.text:find('^%d+ of %d+ spawns$') end))
dump('findwalk-roles')

-- a name too long for its column is cut with dots, short of the Role column
open.search, open.serial = 'mirabel', 10
settle()
local longName = find_op('text', function(o) return o.font == 3 and o.align == 'left' and o.text:find('%.%.%.$') end)
assert(longName, 'the long name is cut')
assert(longName.x + longName.w <= headText('ROLE').x - 10 + 0.01, 'and stops short of the Role column')
open.search, open.serial = '', 11
settle()

-- another head sorts by it, ascending; the same head again turns it round
frame({clicks = {['##fwhdist'] = true}})
settle()
assert(find_op('triangle').pts[2] > find_op('triangle').pts[6], 'ascending points up')
assert(all('text', function(o) return o.font == 3 and o.align == 'left' and o.y > headText('NAME').y end)[1].text == 'Banker Vorn',
  'nearest first')
frame({clicks = {['##fwhdist'] = true}})
settle()
assert(find_op('triangle').pts[2] < find_op('triangle').pts[6], 'descending points down')
assert(all('text', function(o) return o.font == 3 and o.align == 'left' and o.y > headText('NAME').y end)[1].text == 'Gnasher',
  'farthest first')
-- ...and by another head: that column becomes the sorted one, ascending
frame({clicks = {['##fwhrole'] = true}})
settle()
local roleArrow = find_op('triangle')
assert(roleArrow.pts[2] > roleArrow.pts[6], 'a new column starts ascending')
assert(roleArrow.pts[5] < headText('ROLE').x, 'the arrow stands before ROLE')
local firstName = all('text', function(o) return o.font == 3 and o.align == 'left' and o.y > headText('NAME').y end)[1]
assert(firstName.text == 'Banker Vorn', 'Banker is the first role A-Z')
dump('findwalk-role-sorted')

-- selecting a row enables Travel to and shows who is selected
local rowHit = find_op('hit', function(o) return o.id == '##fwr2' end)
assert(rowHit, 'a row is a hit box')
near(rowHit.x1 - rowHit.x0, child.x1 - child.x0 - (scrollbar and 14 or 0), 'a row spans the list')
frame({clicks = {['##fwr2'] = true}})
frame()
assert(find_op('button').opts.enabled == true)
assert(find_op('text', function(o) return o.text == 'Selected: Banker Vorn' end))
assert(find_op('fill', function(o) return o.color[4] == 0.22 and o.rad == 0 end), 'the selected row is highlighted')
dump('findwalk-selected')
frame({clicks = {['##fwtravel'] = true}})
assert(travelled == 2, 'Travel to asks for the selected spawn')

-- a double click on a row travels at once, a single click only selects. The hit box reports a click on mouse up;
-- the double click is true on the frame the mouse goes down, so the two never share a frame (as in the client).
travelled = nil
frame({clicks = {['##fwr3']= true}})
assert(travelled == nil, 'one click only selects')
doubleClick = true
frame({hover = '##fwr3'})
doubleClick = false
assert(travelled == 3, 'a double click on a row is Travel to, without the hit box reporting it')
frame()
assert(find_op('text', function(o) return o.text == 'Selected: Guildmaster Aldric' end), 'and it selects the row')
-- a double click on one row does not travel to another: only the hovered row counts
travelled = nil
doubleClick = true
frame({hover = '##fwr2'})
doubleClick = false
assert(travelled == 2, 'the hovered row is the one travelled to')

-- a search with no roles in it: the Role column is gone and the window is 360 wide
open.search, open.serial = 'gnoll', 1
settle()
assert(dialog.contentW == 340 and dialog.w == 360, 'narrow without the Role column: ' .. dialog.w)
assert(not headText('ROLE'), 'no Role head')
assert(find_op('text', function(o) return o.text == 'a gnoll pup' end))
assert(find_op('input').text == 'gnoll', '/findW gnoll fills the search box')
local plainName, plainLvl, plainDist = headText('NAME'), headText('LVL'), headText('DIST')
assert(plainName.x < plainLvl.x and plainLvl.x < plainDist.x)
local plainCells = all('text', function(o) return o.font == 3 and o.align == 'left' and o.y > plainName.y end)
for _, c in ipairs(plainCells) do assert(c.x + c.w <= plainLvl.x - plainLvl.w - 10 + 0.01) end
assert(find_op('triangle') and #all('triangle') == 1)
assert(find_op('triangle').pts[1] > plainName.x + plainName.w, 'the arrow stands after NAME')
dump('findwalk-plain')

-- while the sorted column is Role and its roles go away, the sort falls back to name A to Z
open.search, open.serial = '', 2
frame({clicks = {}})
settle()
frame({clicks = {['##fwhrole'] = true}})
settle()
open.search, open.serial = 'gnoll', 3
settle()
settle()
assert(not headText('ROLE') and find_op('triangle') and #all('triangle') == 1)
local arrowAtName = find_op('triangle')
assert(arrowAtName.pts[1] > headText('NAME').x + headText('NAME').w and arrowAtName.pts[2] > arrowAtName.pts[6],
  'the arrow is back on NAME, pointing up')

-- closing the dialog closes it for good
dialog.onClose()
assert(open.open == false)
ops = {}
frame()
assert(#ops == 0, 'nothing is drawn while it is closed')
print('findwalk ok')
