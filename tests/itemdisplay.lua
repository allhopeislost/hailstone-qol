-- Item display custom-client contract and the Other versions item windows.
local realDofile = dofile
local windows, displays, windowText, windowShown, titles = {}, {}, {}, {}, {}
local buttons, texts, wrapped, colored, headings, tooltips, clicks = {}, {}, {}, {}, {}, {}, {}
local stmlLinks, drawLinks, stmlRaws, infoRecords, dataReads = {}, {}, {}, {}, {}
local requested, requestCalls = {}, 0
local now, width, invisibleClick, hovered, checkboxClick, tierClick = 10, 380, false, false, false, nil
local pluginAvailable, requestImpl = true, nil
local versionsAvailable = true

local color = {1, 1, 1, 1}
local T = {
  color = {text = color, gold = color, muted = color, accent = color, danger = color, xp = color,
    pet = color, ink = color},
  font = {tiny = {}, small = {}, normal = {}, large = {}},
  TextSize = function(text) return #tostring(text or '') * 5, 10 end,
  Text = function(x, y, text) texts[#texts + 1] = text end,
  Icon = function() end,
  HoverFx = function() end,
  Button = function(id, x0, y0, x1, y1, s, label, opts)
    buttons[#buttons + 1] = {id = id, x0 = x0, y0 = y0, label = label,
      enabled = opts and opts.enabled}
    if tierClick == label and not (opts and opts.enabled == false) then
      tierClick = nil
      return true
    end
    return false
  end,
  RightPressStart = function() end,
  RightPressFrame = function() end,
}
local function winName(instance)
  return instance == 1 and 'ItemDisplayWindow' or ('ItemDisplayWindow#' .. instance)
end
local hud = {T = T, Dialog = function(_, _, _, body) body(0, 0, 380, 440, 1) end}
local W = {
  Text = function(win, id)
    local t = windowText[win]
    return t and t[id] or ''
  end,
  Shown = function(win, id)
    local t = windowShown[win]
    return t and t[id] == true
  end,
  Heading = function(text) headings[#headings + 1] = text end,
  Button = function() return false end,
}
local stml = {
  Lines = function(raw, c)
    stmlRaws[#stmlRaws + 1] = raw
    return {{{raw, c, false}}}
  end,
  DrawLine = function(_, _, onLink) drawLinks[#drawLinks + 1] = onLink end,
}

eq = {
  InGame = function() return true end,
  ChildArt = function() return nil end,
  ChildShown = function(win, id)
    local t = windowShown[win]
    if t and t[id] ~= nil then return t[id] end
    return false
  end,
  ChildRect = function() return nil end,
  ChildColor = function() return nil end,
  ChildTooltip = function() return '' end,
  WindowText = function(win, id)
    local t = windowText[win]
    return t and t[id]
  end,
  WindowTitle = function(win) return titles[win] or 'Item Display' end,
  DisplayItemData = function(instance)
    dataReads[instance] = (dataReads[instance] or 0) + 1
    return displays[instance]
  end,
  Plugin = function(name)
    assert(name == 'script:qol')
    if not pluginAvailable then return nil end
    local plugin = {
      item_info = function(record)
        infoRecords[#infoRecords + 1] = record
        return require('core.info').item(record)
      end,
      request_item_preview = requestImpl,
    }
    plugin.item_versions_available = function() return versionsAvailable end
    return plugin
  end,
  ClickChild = function(win, id, phase) clicks[#clicks + 1] = {win, id, phase} end,
  StmlLink = function(win, id, message, data)
    stmlLinks[#stmlLinks + 1] = {win, id, message, data}
  end,
}
ui = {
  window = function(name, fn) windows[name] = fn end,
  GetTime = function() return now end,
  GetCursorScreenPos = function() return 0, 0 end,
  SetCursorScreenPos = function() end,
  InvisibleButton = function(id) return invisibleClick and id == '##linkicon' end,
  IsItemHovered = function() return hovered end,
  GetItemID = function() return 0 end,
  IsItemClicked = function() return false end,
  Mouse = {Left = 1, Right = 2},
  GetIO = function() return {} end,
  PushFont = function() end,
  PopFont = function() end,
  PushTextWrapPos = function() end,
  PopTextWrapPos = function() end,
  TextColored = function(_, _, _, _, text) colored[#colored + 1] = text end,
  BeginChild = function() end,
  EndChild = function() end,
  BeginGroup = function() end,
  EndGroup = function() end,
  GetContentRegionAvail = function() return width end,
  Dummy = function() end,
  SameLine = function() end,
  DrawLine = function() end,
  DrawRect = function() end,
  DrawRectFilled = function() end,
  SetTooltip = function(text) tooltips[#tooltips + 1] = text end,
  TextWrapped = function(text) wrapped[#wrapped + 1] = text end,
  Checkbox = function()
    if checkboxClick then
      checkboxClick = false
      return false, true
    end
    return false, false
  end,
  Button = function() return false end,
}
dofile = function(path)
  if path == 'lib/hud.lua' then return hud end
  if path == 'lib/widgets.lua' then return W end
  if path == 'lib/stml.lua' then return stml end
  return realDofile(path)
end

local function item(instance, id, name, desc, extra)
  extra = extra or {}
  local win = winName(instance)
  displays[instance] = {id = id, icon = extra.icon or 44, name = name, lore = extra.lore or 'Lore',
    value = extra.value or 250, favor = extra.favor or 10, damage = extra.damage or 8,
    delay = extra.delay or 24, item_type = extra.item_type or 0}
  local text = {
    IDW_ItemInfo1 = name,
    IDW_ItemInfo2 = extra.flags or 'Magic',
    ItemDescription = desc or '',
    IDW_ModButtonLabel = extra.mod or '',
  }
  local shown = {IDW_ItemInfo1 = true, IDW_ItemInfo2 = true, IDW_ItemInfo3 = false}
  for i, line in ipairs(extra.lines or {}) do
    text['IDW_ItemInfo' .. (i + 2)] = line
    shown['IDW_ItemInfo' .. (i + 2)] = true
  end
  if extra.stats ~= false then
    text.IDW_Row1Col1Stat = 'AC'
    text.IDW_Row1Col1Value = extra.ac or '10'
    shown.IDW_Row1Col1Stat = true
  end
  if extra.mod then shown.IDW_ModButton = true end
  if extra.sockets then shown.IDW_Socket_Slot_1_Screen = true end
  windowText[win], windowShown[win], titles[win] = text, shown, name
end

local function load()
  windows, displays, windowText, windowShown, titles = {}, {}, {}, {}, {}
  buttons, texts, wrapped, colored, headings, tooltips, clicks = {}, {}, {}, {}, {}, {}, {}
  stmlLinks, drawLinks, stmlRaws, infoRecords, dataReads = {}, {}, {}, {}, {}
  requested, requestCalls = {}, 0
  now, width, invisibleClick, hovered, checkboxClick, tierClick = 10, 380, false, false, false, nil
  pluginAvailable, versionsAvailable = true, true
  requestImpl = function(id)
    requestCalls = requestCalls + 1
    requested[#requested + 1] = id
    return {ok = true, id = id}
  end
  realDofile('ui/modern/itemdisplay.lua')
end

local function frame(name)
  buttons, texts, wrapped, colored, headings, tooltips, clicks = {}, {}, {}, {}, {}, {}, {}
  stmlLinks, drawLinks, stmlRaws, infoRecords, dataReads = {}, {}, {}, {}, {}
  windows[name or 'Item Display']()
end

local function button(label)
  for _, b in ipairs(buttons) do if b.label == label then return b end end
end

local function buttonLabels()
  local names = {}
  for _, b in ipairs(buttons) do names[#names + 1] = b.label end
  return names
end

local function assertButtons(expected)
  local names = buttonLabels()
  assert(#names == #expected, 'expected ' .. #expected .. ' version buttons, got ' .. table.concat(names, ', '))
  for _, label in ipairs(expected) do
    assert(button(label), 'missing version button: ' .. label)
  end
  return names
end

local function has(list, needle)
  return table.concat(list, '\n'):find(needle, 1, true) ~= nil
end

local function indexOf(list, needle)
  for i, value in ipairs(list) do
    if value == needle then return i end
  end
end

local function wrappedText() return table.concat(wrapped, '\n') end

-- Rendering alone never requests anything; a Base item offers exactly its two other tiers.
load()
item(1, 51907, 'Original Base', 'Live base description',
  {mod = 'Modified', lines = {'Class: WAR'}, sockets = true})
local baseData = displays[1]
hovered = true
frame()
hovered = false
assert(requestCalls == 0, 'rendering must not request an item version')
assertButtons({'Enchanted', 'Legendary'})
assert(not button('Base'), 'the current tier is not offered')
assert(indexOf(headings, 'Additional information') < indexOf(headings, 'Other versions'),
  'Other versions follows Additional information')
assert(has(wrapped, 'Opens a separate item window.'))
assert(not has(wrapped, 'Asked the client'), 'rendering makes no success claim')
assert(not has(texts, 'Enchanted preview') and not has(wrapped, 'preview'))
assert(infoRecords[1] == baseData and infoRecords[1].id == 51907)
assert(has(colored, 'Original Base'))
assert(has(headings, 'Stats') and has(texts, 'AC'))
assert(has(tooltips, 'Click to link this item in chat'), 'the live icon tooltip stays')
assert(dataReads[1] == 1 and not dataReads[5], 'only this display is read')
assert(#clicks == 0, 'rendering clicks nothing')

-- A click asks for exactly the selected real item id, once.
tierClick = 'Enchanted'
frame()
assert(requestCalls == 1 and requested[1] == 1051907)
assert(has(wrapped, 'Asked the client to open the Enchanted item window.'))
assert(not has(wrapped, 'opened'), 'inspect_item has no acknowledgement, so no window is claimed')
assert(requestCalls == 1 and #requested == 1)

-- The original window, its data and its live controls are unchanged by requesting a version.
assert(displays[1] == baseData and infoRecords[1] == baseData and infoRecords[1].id == 51907)
assert(has(colored, 'Original Base') and not has(colored, 'Enchanted'))
assert(has(texts, 'AC') and has(texts, '10'))
assertButtons({'Enchanted', 'Legendary'})
assert(#clicks == 0, 'requesting a version dispatches no icon, socket or Modified clicks')
invisibleClick = true
frame()
invisibleClick = false
assert(#clicks == 1 and clicks[1][2] == 'IconButton', 'the live icon still links in chat')
checkboxClick = true
clicks = {}
frame()
assert(#clicks == 1 and clicks[1][2] == 'IDW_ModButton', 'the live Modified control still works')
assert(type(drawLinks[#drawLinks]) == 'function', 'the live description still follows its links')
assert(#stmlLinks == 0)
assert(has(colored, 'Original Base'))

-- A separate native window is independent: it shows its own item and its own other tiers.
item(5, 1051907, 'Enchanted Item', 'Enchanted live description',
  {lines = {'Class: WAR'}, ac = '25'})
local enchantedData = displays[5]
frame('Item Display 5')
assertButtons({'Base', 'Legendary'})
assert(not button('Enchanted'), 'an Enchanted window does not offer Enchanted')
assert(infoRecords[1] == enchantedData and infoRecords[1].id == 1051907)
assert(has(colored, 'Enchanted Item'))
assert(has(wrapped, 'Opens a separate item window.'))
assert(requestCalls == 1, 'opening a separate window requests nothing by itself')
frame()
assert(displays[1] == baseData and infoRecords[1] == baseData)
assert(has(colored, 'Original Base'), 'the first window keeps its own live content')
assertButtons({'Enchanted', 'Legendary'})
assert(requestCalls == 1, 'the windows do not share or replay requests')

-- Every source tier offers the two other tiers and requests their exact ids.
local function targetFor(sourceId, sourceLabel, label, expected)
  load()
  item(1, sourceId, 'Source ' .. sourceLabel, 'Source description')
  frame()
  assert(requestCalls == 0)
  local expectedLabels = {}
  for _, name in ipairs({'Base', 'Enchanted', 'Legendary'}) do
    if name ~= sourceLabel then expectedLabels[#expectedLabels + 1] = name end
  end
  assertButtons(expectedLabels)
  assert(not button(sourceLabel), 'the source tier is never offered')
  tierClick = label
  frame()
  assert(requestCalls == 1 and requested[1] == expected,
    ('%s from %s should request %s'):format(label, sourceLabel, tostring(expected)))
end
targetFor(51907, 'Base', 'Enchanted', 1051907)
targetFor(51907, 'Base', 'Legendary', 2051907)
targetFor(1051907, 'Enchanted', 'Base', 51907)
targetFor(1051907, 'Enchanted', 'Legendary', 2051907)
targetFor(2051907, 'Legendary', 'Base', 51907)
targetFor(2051907, 'Legendary', 'Enchanted', 1051907)

-- Ids outside the known tier ranges get no controls and never a request.
for _, id in ipairs({4000000, 1000000, 2000000, 3000000, 0, 1.5}) do
  load()
  item(1, id, 'Not tiered', 'No tiers', {stats = false})
  frame()
  assert(#buttons == 0, 'an id outside the tier ranges has no buttons')
  assert(not has(headings, 'Other versions'))
  assert(requestCalls == 0)
end

-- The existing item_preview option disables the controls; re-enabling restores them.
load()
versionsAvailable = false
item(1, 51907, 'Original Base', 'Live base description')
frame()
assert(#buttons == 0, 'a disabled option has no version buttons')
assert(not has(headings, 'Other versions'))
assert(has(headings, 'Stats'), 'the plain Stats heading stays')
assert(requestCalls == 0)
tierClick = 'Enchanted'
frame()
assert(requestCalls == 0, 'no buttons means no click can request a version')
versionsAvailable = true
tierClick = nil
frame()
assertButtons({'Enchanted', 'Legendary'})
assert(has(headings, 'Other versions'))

-- A missing plugin fails gracefully.
load()
pluginAvailable = false
item(1, 51907, 'Original Base', 'Live base description')
frame()
assert(#buttons == 0, 'without a QoL plugin nothing is offered')
assert(not has(headings, 'Additional information') and not has(headings, 'Other versions'))
assert(requestCalls == 0)

-- Failures after a click are shown in a small status and never change this window.
local function failedClick(setup, fragment)
  load()
  item(1, 51907, 'Original Base', 'Live base description', {ac = '7'})
  frame()
  requestImpl = setup
  tierClick = 'Legendary'
  frame()
  assert(has(wrapped, fragment), 'expected a status containing: ' .. fragment)
  assert(infoRecords[1].id == 51907 and has(colored, 'Original Base'))
  assert(has(texts, '7'), 'the original stats stay live')
  assertButtons({'Enchanted', 'Legendary'})
  assert(requestCalls == 0 or requested[1] == 2051907)
end
failedClick(nil, 'no request_item_preview API')
failedClick(function() error('client denied the request') end, 'client denied the request')
failedClick(function() return {ok = false, error = 'permission refused'} end, 'permission refused')
failedClick(function() return nil end, 'no result from QoL')

-- A status belongs to its item: changing what this window shows clears it.
load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
tierClick = 'Enchanted'
frame()
assert(has(wrapped, 'Asked the client to open the Enchanted item window.'))
item(1, 51908, 'Different Base', 'Another description')
frame()
assert(not has(wrapped, 'Asked the client'), 'a different item clears the old status')
assertButtons({'Enchanted', 'Legendary'})

-- Narrow windows put each button on its own row instead of clipping it.
load()
width = 100
item(1, 51907, 'Original Base', 'Live base description')
frame()
assertButtons({'Enchanted', 'Legendary'})
assert(button('Legendary').y0 > button('Enchanted').y0,
  'narrow layouts wrap the two buttons onto separate rows')
assert(has(wrapped, 'Opens a separate item window.'))

-- Wide windows keep the two buttons on one row.
load()
width = 380
item(1, 51907, 'Original Base', 'Live base description')
frame()
assert(button('Legendary').y0 == button('Enchanted').y0)

print('item display custom client contract: ok')
