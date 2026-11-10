local realDofile = dofile
local displayed, extras, ids, children = {}, {}, {}, {}
local lines, rects = 0, 0
local enabled, pluginAvailable, currentId = true, true, 701
local colors = {text = {1, 1, 1, 1}, muted = {.5, .5, .5, 1}, ink = {0, 0, 0, 1}}
local drawn, inline = {}, {}
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
    return {spell_view = function(id)
      assert(id == currentId)
      if enabled then return {metadata = 'Spell ID: ' .. id .. '\nMana: 40\nClasses: BST 11\nCast: 6.50s\nRecovery: 1.50s\nRecast: 1.50s',
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
assert(table.concat(drawn, '|'):find('+20 (L11)', 1, true))
assert(table.concat(drawn, '|'):find('+45 (L60)', 1, true))
assert(table.concat(drawn, '|'):find('1H Blunt', 1, true))
assert(table.concat(drawn, '|'):find('PC 2s, up to level 55', 1, true))
assert(table.concat(drawn, '|'):find('+1% per 2 levels', 1, true))
assert(table.concat(inline, '|'):find('Duration: 1h    Mana: 40    Classes: BST 11', 1, true))
assert(table.concat(inline, '|'):find('Cast: 6.50s    Recovery: 1.50s    Recast: 1.50s', 1, true))
assert(not table.concat(drawn, '|'):find('→', 1, true))
assert(rects == 6 and lines >= 24) -- each panel and each geometric arrow
local function unchanged()
  windows['Spell Display']()
  assert(#extras == 6)
  assert(children[#children][3] == 246)
end
enabled = false
unchanged()
enabled, currentId = true, nil
unchanged()
eq.DisplaySpellId = nil
unchanged()
pluginAvailable = false
unchanged()
print('spell display custom client contract: ok')
