local T = dofile("lib/theme.lua")
local W = dofile("lib/window.lua")
local C = T.C

-- A HUD window at x, y (design px), w x h; inputs: the mouse may click in it. draw(x0, y0, x1, y1).
local function hud(name, x, y, w, h, inputs, draw)
  T.frame()
  T.resetFonts()
  local px, py, pw, ph = T.px(x), T.px(y), T.px(w), T.px(h)
  if px < 0 then px = T.W + px - pw end -- negative x: from the right edge
  if py < 0 then py = T.H + py - ph end
  ui.SetNextWindowPos(px, py, ui.Cond.Always)
  ui.SetNextWindowSize(pw, ph, ui.Cond.Always)
  ui.PushStyleVar(ui.StyleVar.WindowPadding, 0, 0)
  ui.PushStyleVar(ui.StyleVar.WindowBorderSize, 0)
  local flags = ui.WindowFlags.NoDecoration | ui.WindowFlags.NoBackground | ui.WindowFlags.NoSavedSettings
      | ui.WindowFlags.NoMove | ui.WindowFlags.NoFocusOnAppearing | ui.WindowFlags.NoBringToFrontOnFocus | W.NoNav
  if not inputs then flags = flags | ui.WindowFlags.NoInputs end
  if ui.Begin(name, nil, flags) then
    T.font(T.BASE)
    draw(px, py, px + pw, py + ph)
    T.unfont()
  end
  ui.End()
  ui.PopStyleVar(2)
end
-- ---------------------------------------------------------------- target
local conRgba, conBar = { 0, 0, 0, 1 }, { 0, 0, 0, 1 } -- the target's con colour, and its bar's (darker)
local function conColour()
  if eq.ChildShown("TargetWindow", "A_TargetBoxStaticAnimFill") == false then return nil end
  local r, g, b = eq.ChildColor("TargetWindow", "A_TargetBoxStaticAnimFill", "decal")
  if r then
    conRgba[1], conRgba[2], conRgba[3] = r, g, b
    return conRgba
  end
  return nil
end

local TARGET_BUFFS = {} -- TargetWindow's Buff0..Buff41
for i = 0, 41 do TARGET_BUFFS[i + 1] = "Buff" .. i end
local targetBuffs = {} -- the slots holding a buff this frame, in order

ui.window("HUD Target", function()
  if not W.shown("TargetWindow") then return end
  local frac, name, raw = eq.Gauge(6)
  if raw == -1 or not name or name == "" then return end
  -- a second row only for the target's buffs or its target (eq.Gauge(27))
  local tfrac, tname, traw = eq.Gauge(27)
  local nBuffs = 0
  for i = 1, #TARGET_BUFFS do
    if eq.BuffSlot("TargetWindow", TARGET_BUFFS[i]) then
      nBuffs = nBuffs + 1
      targetBuffs[nBuffs] = TARGET_BUFFS[i]
    end
  end
  local extra = (traw ~= -1 and (tname or "") ~= "") or nBuffs > 0
  hud("HUD Target", 660, 74, 600, extra and 150 or 110, false, function(x0, y0, x1, y1)
    T.panel(x0, y0, x1, y1, 0.9)
    local con = conColour()
    local p = T.px(16)
    if con then -- the con colour as the panel's left edge and the name
      T.rect(x0, y0 + T.px(14), x0 + T.px(6), y1 - T.px(14), con, 1, T.px(3))
    end
    T.font(26)
    local _, nh = ui.CalcTextSize("Ag")
    local plugin = eq.Plugin("script:qol")
    local displayName = plugin and plugin.target_name(name) or name
    T.textIn(x0 + p + T.px(4), y0 + p - T.px(2), x1 - p - T.px(90), y0 + p + nh, displayName, con or C.text, 0)
    T.unfont()
    -- the distance (a client that gives it: eq.TargetDistance)
    if eq.TargetDistance then
      local d = eq.TargetDistance()
      if d then
        T.font(18)
        T.textIn(x1 - p - T.px(140), y0 + p, x1 - p, y0 + p + nh, string.format("%d ft", math.floor(d + 0.5)), C.dim, 1)
        T.unfont()
      end
    end
    local y = y0 + p + nh + T.px(6)
    local bh = T.px(30)
    local pct = eq.Label(29) or ""
    if con then conBar[1], conBar[2], conBar[3] = con[1] * 0.85, con[2] * 0.85, con[3] * 0.85 end
    T.bar(x0 + p + T.px(4), y, x1 - p, y + bh, raw == -3 and 0 or frac, con and conBar or C.hp,
      raw == -3 and "Corpse" or "", pct ~= "" and (pct .. "%") or "")
    y = y + bh + T.px(8)
    -- the target's buffs: small icons
    local s = T.px(28)
    local x = x0 + p + T.px(4)
    for i = 1, nBuffs do
      local tex, u0, v0, u1, v1 = eq.ChildArt("TargetWindow", targetBuffs[i], "decal")
      if type(tex) == "userdata" then
        T.icon(tex, u0, v0, u1, v1, x, y, x + s, y + s)
        x = x + s + T.px(3)
        if x + s > x1 - p - T.px(180) then break end
      end
    end
    -- the target's target
    if traw ~= -1 and tname and tname ~= "" then
      T.font(16)
      local tx0 = x1 - p - T.px(170)
      T.bar(tx0, y + T.px(2), x1 - p, y + s - T.px(2), tfrac, C.hp, T.fit(tname, T.px(150)))
      T.unfont()
    end
  end)
end)
