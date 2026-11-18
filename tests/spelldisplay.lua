local realDofile = dofile
local displayed, extras, ids, children = {}, {}, {}, {}
local lines, rects, spellViewCalls = 0, 0, 0
local enabled, pluginAvailable, currentId = true, true, 701
local frame, optionReads = 0, 0
local colors = {text = {1, 1, 1, 1}, muted = {.5, .5, .5, 1}, ink = {0, 0, 0, 1}}
local drawn, inline, cyan = {}, {}, {}
local T = {
  color = colors, font = {normal = {}, small = {}},
  Icon = function() end, TextSize = function() return 10, 10 end,
  Text = function(_, _, text) drawn[#drawn + 1] = text end, Fit = function(text) return text end,
}
local hud = {T = T, Dialog = function(_, _, _, body) body(0, 0, 360, 300, 1) end}
local W = {Text = function(...) displayed[#displayed + 1] = {...} return 'description' end}
local stml = {
  Lines = function(raw) return {{{'Duration: 1h'}}, {{raw}}} end,
  DrawLine = function(line, width)
    assert((line[1][1] == 'description' or line[1][1] == 'Duration: 1h') and width == 350)
  end,
}
local windows = {}
ui = {
  GetFrameCount = function() return frame end,
  window = function(name, fn) windows[name] = fn end,
  DrawLine = function() lines = lines + 1 end, DrawRectFilled = function() rects = rects + 1 end,
  SetCursorScreenPos = function() end,
  PushFont = function() end, PopFont = function() end,
  BeginChild = function(...) children[#children + 1] = {...} end,
  GetContentRegionAvail = function() return 350 end,
  GetCursorScreenPos = function() return 0, 0 end,
  Dummy = function() end, PushTextWrapPos = function() end, PopTextWrapPos = function() end,
  TextColored = function(r, g, b, a, text)
    inline[#inline + 1] = text
    if r == 0 and g == 1 and b == 1 and a == 1 then cyan[#cyan + 1] = text end
    if text:find('Spell ID:', 1, true) then extras[#extras + 1] = text end
  end,
  EndChild = function() end,
}
eq = {
  InGame = function() return true end,
  WindowTitle = function() return 'Not in the spellbook' end,
  ChildArt = function() return nil end,
  SpellBook = function() error('never match a spell display by title') end,
  DisplaySpellId = function(instance) ids[#ids + 1] = instance return currentId end,
  Plugin = function(name)
    assert(name == 'script:qol')
    if not pluginAvailable then return nil end
    return {display_options = function()
      optionReads = optionReads + 1
      return {spell_info = enabled, item_info = true}
    end, spell_view = function(id)
      spellViewCalls = spellViewCalls + 1
      assert(id == currentId)
      if enabled then return {metadata = 'Spell ID: ' .. id .. '\nMana: 40\nClasses: BST 11\nDamage per mana: 1.17\nCast: 6.50s\nRecovery: 1.50s\nRecast: 1.50s',
        effects = {{name = 'Accuracy', min = '+10%', min_level = 11, skill = '1H Blunt', scale = '+1% per 2 levels'},
          {name = 'Strength', min = '+20', min_level = 11, max = '+45', max_level = 60},
          {name = 'Stun', min = '4s', note = 'PC 2s, up to level 55'}}} end
    end}
  end,
}
dofile = function(path)
  if path == 'lib/hud.lua' then return hud end
  if path == 'lib/widgets.lua' then return W end
  if path == 'lib/stml.lua' then return stml end
  if path == 'spellinfo.lua' then return realDofile('ui/modern/spellinfo.lua') end
  if path == 'lib/progress.lua' then return {TestOpen = function() end} end
  return realDofile(path)
end
realDofile('ui/modern/spelldisplay.lua')
for i = 1, 6 do
  currentId = 700 + i
  windows['Spell Display' .. (i == 1 and '' or ' ' .. i)]()
  assert(ids[i] == i)
  assert(displayed[i][1] == 'SpellDisplayWindow' .. (i == 1 and '' or '#' .. i))
  assert(displayed[i][2] == 'SDW_SpellDescription')
  assert(extras[i] == 'Spell ID: ' .. currentId)
  assert(children[i][1] == '##qolspell' and children[i][3] == 246)
end
assert(optionReads == 1, 'all six spell windows share one option read in a frame')
assert(table.concat(drawn, '|'):find('+20 (L11)', 1, true))
assert(table.concat(drawn, '|'):find('+45 (L60)', 1, true))
assert(table.concat(drawn, '|'):find('1H Blunt', 1, true))
assert(table.concat(drawn, '|'):find('PC 2s, up to level 55', 1, true))
assert(table.concat(drawn, '|'):find('+1% per 2 levels', 1, true))
assert(table.concat(inline, '|'):find('Duration: 1h    Mana: 40    Classes: BST 11', 1, true))
assert(table.concat(inline, '|'):find('Cast: 6.50s    Recovery: 1.50s    Recast: 1.50s', 1, true))
-- Damage per mana is its own line, the first line of the blue metadata block: drawn in the cyan
-- EXTRA_COLOR (0,1,1,1) like Cast/Recovery/Recast, above them, and no longer part of the summary line.
local ownLine, ownIndex, castIndex = false, nil, nil
for i, entry in ipairs(inline) do
  if entry == 'Damage per mana: 1.17' then ownLine = true; ownIndex = i end
  if entry == 'Cast: 6.50s    Recovery: 1.50s    Recast: 1.50s' then castIndex = i end
end
assert(ownLine, 'damage per mana is drawn as its own line')
assert(table.concat(cyan, '|'):find('Damage per mana: 1.17', 1, true),
  'damage per mana is drawn in the blue metadata block')
assert(ownIndex and castIndex and ownIndex < castIndex, 'damage per mana opens the metadata block')
assert(not table.concat(inline, '|'):find('Classes: BST 11    Damage per mana', 1, true),
  'damage per mana is not part of the summary line')
assert(not table.concat(drawn, '|'):find('→', 1, true))
assert(rects == 6 and lines >= 24) -- each panel and each geometric arrow
local function unchanged()
  frame = frame + 1
  windows['Spell Display']()
  assert(#extras == 6)
  assert(children[#children][3] == 246)
end
enabled = false
currentId = 999 -- a fresh id: its nil spell_view result must still take the no-details fallback
unchanged()
enabled, currentId = true, nil
unchanged()
eq.DisplaySpellId = nil
unchanged()
pluginAvailable = false
unchanged()

-- Cached preparation keyed by spell id: a spell switch must immediately show the new spell, and
-- repeated frames for one id must reuse the cache while still drawing the spell-specific extra text.
pluginAvailable = true
eq.DisplaySpellId = function(instance) ids[#ids + 1] = instance return currentId end
currentId, enabled = 801, true
local function spellText()
  frame = frame + 1
  local from = #extras
  windows['Spell Display']()
  return table.concat(extras, '|', from + 1)
end
local calls = spellViewCalls
assert(spellText():find('Spell ID: 801', 1, true))
assert(spellViewCalls == calls + 1) -- prepared once for the new id
calls = spellViewCalls
assert(spellText():find('Spell ID: 801', 1, true))
assert(spellViewCalls == calls) -- reused next frame, still drawn
currentId = 802
assert(spellText():find('Spell ID: 802', 1, true))
assert(spellViewCalls == calls + 1) -- the new id is prepared once
calls = spellViewCalls
assert(spellText():find('Spell ID: 802', 1, true))
assert(spellViewCalls == calls) -- reused again
-- Live switches gate both warm and cold caches; switching on restores the same id.
enabled = false
assert(spellText() == '' and spellViewCalls == calls)
enabled = true
assert(spellText():find('Spell ID: 802', 1, true) and spellViewCalls == calls)
enabled, currentId = false, 803
assert(spellText() == '' and spellViewCalls == calls)
enabled = true
assert(spellText():find('Spell ID: 803', 1, true) and spellViewCalls == calls + 1)
print('spell display custom client contract: ok')
