-- Esc-to-close for the add-on's own dialogs. The client's lib/escape.lua reads hud.esc.<screen> and only
-- defaults it on for the game's windows, so each QoL window-script turns it on while the setting is empty.
-- An explicit "Close with Esc" choice in a window's right-click menu must survive. Run from qol/.
local function loadWindow(path, preset)
  local settings = {}
  for k, v in pairs(preset or {}) do settings[k] = v end
  local hud = {T = {color = {}}}
  local ui = {
    GetSetting = function(key) return settings[key] end,
    SetSetting = function(key, value) settings[key] = value end,
    window = function() end,
  }
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
