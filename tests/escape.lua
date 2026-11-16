-- Esc-to-close for the add-on's own dialogs. The client's lib/escape.lua reads hud.esc.<screen> in the pack's
-- settings (a plugin can only write its own namespace) and consumes one press in the first pack window that
-- draws, so each QoL window reads Escape from ImGui itself and honours the right-click menu's on/off choice.
-- Run from qol/.
local settings = {}
local frame, now, escapeDown, hovered, clicked = 0, 0, false, false, false
local ui = {
  GetSetting = function(key) return settings[key] end,
  SetSetting = function(key, value) settings[key] = value end,
  window = function() end,
  GetTime = function() return now end,
  GetFrameCount = function() return frame end,
  IsKeyPressed = function(key) return escapeDown and key == 'Escape' end,
  Key = {Escape = 'Escape'},
  IsWindowHovered = function() return hovered end,
  HoveredFlags = {ChildWindows = 1},
  IsMouseClicked = function() return clicked end,
  Mouse = {Left = 0},
}
local function loadWindow(path, preset)
  settings = {}
  for k, v in pairs(preset or {}) do settings[k] = v end
  local hud = {T = {color = {}}}
  local env = setmetatable({ui = ui}, {__index = _G})
  env.dofile = function(p)
    if p == 'lib/hud.lua' then return hud end
    return dofile(p)
  end
  local chunk = assert(loadfile(path, 't', env))
  chunk()
  return settings
end

local s = loadWindow('ui/modern/findwalk.lua')
assert(s['hud.esc.FindWalkWnd'] == '1', 'FindWalk closes with Esc by default')

s = loadWindow('ui/modern/findwalk.lua', {['hud.esc.FindWalkWnd'] = '0'})
assert(s['hud.esc.FindWalkWnd'] == '0', 'an explicit off survives a reload')

s = loadWindow('ui/modern/named.lua')
assert(s['hud.esc.NamedWnd'] == '1' and s['hud.esc.NamedEditWnd'] == '1',
  'both named windows close with Esc by default')

s = loadWindow('ui/modern/named.lua', {['hud.esc.NamedWnd'] = '0'})
assert(s['hud.esc.NamedWnd'] == '0' and s['hud.esc.NamedEditWnd'] == '1',
  'each named window keeps its own Esc choice')

-- the key handling: one press closes the last opened or clicked window, and the menu item switches it off
local esc = rawget(_G, 'qolEscClose')
assert(esc and esc.note and esc.shouldClose, 'the window scripts publish the shared Esc state')

frame, now, escapeDown = 1, 10, false
esc.note('FindWalkWnd')
assert(esc.shouldClose('FindWalkWnd') == false, 'no key press: nothing closes')

escapeDown = true
assert(esc.shouldClose('FindWalkWnd') == true, 'Escape closes the shown FindWalk window')

settings['hud.esc.FindWalkWnd'] = '0'
assert(esc.shouldClose('FindWalkWnd') == false, 'unticked in the menu: Escape does nothing')
settings['hud.esc.FindWalkWnd'] = '1'
settings['hud.esc.NamedWnd'] = '1'

frame, now = 2, 20
esc.note('NamedWnd')
assert(esc.shouldClose('FindWalkWnd') == false and esc.shouldClose('NamedWnd') == true,
  'one press closes the window opened last')

frame, now = 3, 30
hovered, clicked = true, true
esc.note('FindWalkWnd')
hovered, clicked = false, false
assert(esc.shouldClose('FindWalkWnd') == true, 'a click makes it the front window again')
