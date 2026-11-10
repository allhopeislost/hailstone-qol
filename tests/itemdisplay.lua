-- Item display custom-client contract and the experimental tier preview.
local realDofile = dofile
local windows, displays, windowText, windowShown, titles = {}, {}, {}, {}, {}
local buttons, texts, wrapped, colored, headings, clicks = {}, {}, {}, {}, {}, {}
local stmlLinks, drawLinks, stmlRaws, infoRecords = {}, {}, {}, {}
local requested, requestCalls = {}, 0
local now, width, invisibleClick, hovered, checkboxClick, tierClick = 10, 380, false, false, false, nil
local pluginAvailable, requestImpl = true, nil
local previewEnabled = true

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
    buttons[#buttons + 1] = {id = id, label = label, primary = opts and opts.primary,
      enabled = opts and opts.enabled}
    if tierClick == label and not (opts and opts.enabled == false) then
      tierClick = nil
      return true
    end
    return false
  end,
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
  DisplayItemData = function(instance) return displays[instance] end,
  Plugin = function(name)
    assert(name == 'script:qol')
    if not pluginAvailable then return nil end
    return {
      item_info = function(record)
        infoRecords[#infoRecords + 1] = record
        return require('info').item(record)
      end,
      preview_enabled = function() return previewEnabled end,
      request_item_preview = requestImpl,
    }
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
  PushFont = function() end,
  PopFont = function() end,
  PushTextWrapPos = function() end,
  PopTextWrapPos = function() end,
  TextColored = function(_, _, _, _, text) colored[#colored + 1] = text end,
  BeginChild = function() end,
  EndChild = function() end,
  GetContentRegionAvail = function() return width end,
  Dummy = function() end,
  SameLine = function() end,
  DrawLine = function() end,
  DrawRect = function() end,
  DrawRectFilled = function() end,
  SetTooltip = function(text) headings[#headings + 1] = text end,
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
  buttons, texts, wrapped, colored, headings, clicks = {}, {}, {}, {}, {}, {}
  stmlLinks, drawLinks, stmlRaws, infoRecords = {}, {}, {}, {}
  requested, requestCalls = {}, 0
  now, width, invisibleClick, hovered, checkboxClick, tierClick = 10, 380, false, false, false, nil
  pluginAvailable = true
  previewEnabled = true
  requestImpl = function(id)
    requestCalls = requestCalls + 1
    requested[#requested + 1] = id
    return {ok = true, id = id}
  end
  realDofile('ui/modern/itemdisplay.lua')
end

local function frame(name)
  buttons, texts, wrapped, colored, headings, clicks = {}, {}, {}, {}, {}, {}
  stmlLinks, drawLinks, stmlRaws, infoRecords = {}, {}, {}, {}
  windows[name or 'Item Display']()
end

local function button(label)
  for _, b in ipairs(buttons) do if b.label == label then return b end end
end

local function has(list, needle)
  return table.concat(list, '\n'):find(needle, 1, true) ~= nil
end

local function statuses() return table.concat(wrapped, '\n') end
local function labels() return table.concat(texts, '\n') end

-- Rendering alone must never ask the server, and the source tier starts highlighted.
load()
item(1, 51907, 'Original Base', 'Live base description', {mod = 'Modified'})
frame()
assert(requestCalls == 0, 'rendering must not request a preview')
assert(#buttons == 3 and button('Base').primary and not button('Enchanted').primary)
assert(has(texts, 'Stats'), 'the tier buttons sit by the Stats heading')
assert(has(wrapped, 'extra item window'), 'the experimental status names the extra window')
assert(infoRecords[1] and infoRecords[1].id == 51907, 'the original item keeps its own additional information')

-- A click asks for exactly the requested tier's id; nothing switches until a matching native window is read.
tierClick = 'Enchanted'
frame()
assert(requestCalls == 1 and requested[1] == 1051907)
assert(not has(texts, 'Enchanted preview'), 'the annotation waits for the response')
assert(button('Base').primary, 'the source choice stays highlighted while loading')
assert(has(wrapped, 'Requesting Enchanted'))
item(5, 1051907, 'Target Enchanted',
  '<a WndNotify="27,0^5">Enchanted effect</a> text',
  {lines = {'Class: WAR'}, ac = '25', sockets = true})
now = now + 0.1
frame()
assert(not has(texts, 'Enchanted preview'), 'the poll respects its modest cadence')
now = now + 0.3
invisibleClick = true
frame()
invisibleClick = false
assert(has(texts, 'Enchanted preview'), 'the original header names the preview tier')
assert(button('Enchanted').primary and not button('Base').primary)
assert(requestCalls == 1, 'a matching response must not be requested again')
assert(has(colored, 'Original Base'), 'the original name stays in the header')
assert(infoRecords[1] and infoRecords[1].id == 1051907, 'metadata comes from the selected version')
assert(has(wrapped, 'Preview without augments'), 'augment sockets are not interactive in a preview')
assert(#clicks == 0, 'a preview dispatches no icon, socket or Modified clicks')
assert(#stmlLinks == 0, 'a preview description never follows a link into a native window')
assert(drawLinks[#drawLinks] == nil, 'the preview description is drawn without a link handler')

-- Repeating the same choice does not request the same window again.
tierClick = 'Enchanted'
frame()
assert(requestCalls == 1 and has(texts, 'Enchanted preview'))

-- The snapshot is a copy: closing the native response window does not damage what is shown.
displays[5], windowText[winName(5)], windowShown[winName(5)] = nil, nil, nil
frame()
assert(has(texts, 'Enchanted preview') and infoRecords[1].id == 1051907)

-- Another item display is its own state; it is not previewed by the first window.
item(2, 777, 'Unrelated Item', 'Its own description', {ac = '3'})
frame('Item Display 2')
assert(button('Base') and button('Base').primary)
assert(infoRecords[1].id == 777)
assert(requestCalls == 1, 'an unrelated display must not request the preview')
frame()
assert(has(texts, 'Enchanted preview'), 'the first display keeps its own preview')

-- Returning to the source tier clears the snapshot and restores the live controls.
tierClick = 'Base'
frame()
assert(requestCalls == 1, 'returning to the source is local, not another request')
frame()
assert(button('Base').primary and not has(texts, 'Enchanted preview'))
assert(type(drawLinks[#drawLinks]) == 'function', 'the live description links to its own window again')
invisibleClick = true
clicks = {}
frame()
invisibleClick = false
assert(#clicks == 1 and clicks[1][2] == 'IconButton', 'the live icon links in chat again')
checkboxClick = true
clicks = {}
frame()
assert(#clicks == 1 and clicks[1][2] == 'IDW_ModButton', 'the live Modified control is usable again')

-- A different original item clears the state; an Enchanted source starts on Enchanted.
item(1, 1051907, 'Now Enchanted', 'Enchanted live description', {ac = '20'})
frame()
assert(not has(texts, 'Enchanted preview'))
assert(button('Enchanted').primary and not button('Base').primary)
assert(infoRecords[1].id == 1051907)
assert(requestCalls == 1, 'changing the original item must not request anything')

-- Exact target ids from every source tier.
local function targetFor(sourceId, label, expected)
  load()
  item(1, sourceId, 'Source', 'Source description')
  frame()
  assert(requestCalls == 0)
  tierClick = label
  frame()
  assert(requestCalls == 1 and requested[1] == expected,
    ('%s from %d should request %s'):format(label, sourceId, tostring(expected)))
end
targetFor(51907, 'Enchanted', 1051907)
targetFor(51907, 'Legendary', 2051907)
targetFor(1051907, 'Base', 51907)
targetFor(1051907, 'Legendary', 2051907)
targetFor(2051907, 'Base', 51907)
targetFor(2051907, 'Enchanted', 1051907)

-- Choosing the source tier never asks the server.
load()
item(1, 2051907, 'Legendary Source', 'Live legendary')
frame()
assert(button('Legendary').primary)
tierClick = 'Legendary'
frame()
assert(requestCalls == 0)
assert(type(drawLinks[#drawLinks]) == 'function')

-- An unrelated id in the display list is not the requested item, so the preview times out unchanged.
load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
tierClick = 'Enchanted'
frame()
assert(requested[1] == 1051907)
item(2, 999, 'Other Item', 'Other description')
now = now + 0.3
frame()
assert(not has(texts, 'Enchanted preview'), 'a different id must not be read as the response')
assert(button('Base').primary)
now = now + 6
frame()
assert(has(wrapped, 'No matching item window'), 'the timeout is named')
assert(button('Base').primary and not has(texts, 'Enchanted preview'))
assert(infoRecords[1].id == 51907, 'the original content stays coherent after a timeout')

-- A later failure leaves an earlier successful preview and its selection in place.
load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
tierClick = 'Enchanted'
frame()
item(5, 1051907, 'Target Enchanted', 'Enchanted effect', {lines = {'Class: WAR'}})
now = now + 0.3
frame()
assert(button('Enchanted').primary and infoRecords[1].id == 1051907)
requestImpl = function(id)
  requestCalls = requestCalls + 1
  requested[#requested + 1] = id
  error('later request failed')
end
tierClick = 'Legendary'
frame()
assert(has(wrapped, 'later request failed'))
assert(button('Enchanted').primary and not button('Legendary').primary)
assert(has(texts, 'Enchanted preview') and infoRecords[1].id == 1051907,
  'a failed request must not replace coherent current content')

-- Paths that cannot start the experiment fail visibly, not silently.
load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
requestImpl = nil
tierClick = 'Enchanted'
frame()
assert(has(wrapped, 'request_item_preview'), 'a missing API is named')
assert(button('Base').primary and infoRecords[1].id == 51907)

load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
pluginAvailable = false
tierClick = 'Enchanted'
frame()
assert(has(wrapped, 'Experimental preview unavailable'))
assert(#buttons == 3 and button('Base').primary)

load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
requestImpl = function(id)
  requestCalls = requestCalls + 1
  requested[#requested + 1] = id
  error('preview denied')
end
tierClick = 'Enchanted'
frame()
assert(has(wrapped, 'preview denied'))
assert(button('Base').primary and not has(texts, 'Enchanted preview'))

load()
item(1, 51907, 'Original Base', 'Live base description')
frame()
requestImpl = function(id)
  requestCalls = requestCalls + 1
  requested[#requested + 1] = id
  return {ok = false, error = 'permission refused'}
end
tierClick = 'Enchanted'
frame()
assert(has(wrapped, 'Preview refused') and has(wrapped, 'permission refused'))
assert(button('Base').primary)

-- Ids outside the three known tiers get no tier buttons and no request.
for _, id in ipairs({4000000, 1000000, 2000000, 0}) do
  load()
  item(1, id, 'Not tiered', 'No tiers', {stats = false})
  frame()
  assert(#buttons == 0, 'an id outside the tier ranges has no buttons')
  assert(requestCalls == 0)
end

-- While the item_preview option is off, no tier buttons are drawn and the
-- plain Stats heading stays; re-enabling restores the buttons.
load()
previewEnabled = false
item(1, 51907, 'Original Base', 'Live base description')
frame()
assert(#buttons == 0, 'a disabled preview has no tier buttons')
assert(has(headings, 'Stats'), 'the plain Stats heading stays without a preview')
assert(requestCalls == 0)
tierClick = 'Enchanted'
frame()
assert(requestCalls == 0, 'no buttons means no click can request a preview')
previewEnabled = true
tierClick = nil
frame()
assert(#buttons == 3 and button('Base').primary, 're-enabling restores the tier buttons')

-- Disabling mid-preview clears the state and its buttons.
tierClick = 'Enchanted'
frame()
assert(requestCalls == 1 and requested[1] == 1051907)
previewEnabled = false
frame()
assert(#buttons == 0 and not has(texts, 'Enchanted preview'), 'disabling clears a running preview')
assert(has(headings, 'Stats'))

print('item display custom client contract: ok')
