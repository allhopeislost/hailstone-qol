-- Spell displays: replace the game's SpellDisplayWindow. The game shows one for a spell gem held with the right
-- button (gone again when it comes up), the book's "Spell window", a link, ...; several can be open at once, as
-- SpellDisplayWindow, SpellDisplayWindow#2, ... (eq.ReplaceWindow numbers windows that share a screen name). Each is
-- a small resizable dialog: the spell's icon and name over the game's own description (SDW_SpellDescription: level,
-- mana, cast and recast times, duration, the effects), which scrolls when the window is short. Opening and closing
-- stay the game's: the close box closes that display.
local hud = dofile("lib/hud.lua")
local W = dofile("lib/widgets.lua")
local stml = dofile("lib/stml.lua")
local P = dofile("lib/progress.lua")
local T = hud.T
local C = T.color
local INSTANCES = 6
local ICON_OPTS = { radius = 6 }
local SI = dofile("spellinfo.lua")
local descriptions = {}
-- Spell data never changes for an id, so all preparation (spell_view, metadata parsing, effect
-- sorting) is done once per id and shared by every window/frame showing that spell.
local spellCache = {}
local META_SUMMARY, META_REMAINING = SI.META_SUMMARY, SI.META_REMAINING
local shallowCopy, metadata, metadataLine = SI.shallowCopy, SI.metadata, SI.metadataLine
local prepareEffects, drawEffects, drawMetadata = SI.prepareEffects, SI.drawEffects, SI.drawMetadata

-- The summary line; the damage-per-mana line belongs to the metadata block below the effects.
local function summaryLine(fields, labels)
  metadataLine(fields, labels, C.text)
end

-- Build the immutable preparation for one spell id. Failures (no plugin / no spell_view result)
-- are not cached, so they keep the old per-frame no-details fallback behaviour.
local function prepareSpell(id, plugin)
  local details = plugin and plugin.spell_view(id)
  if not details then return nil end
  local pristine, other = metadata(details.metadata)
  local known = {}
  for label in pairs(pristine) do known[label] = true end
  return {
    details = details,
    ordered = prepareEffects(details.effects),
    fields = pristine,
    other = other,
    known = known,
  }
end

-- testing (test.open.SpellDisplayWindow=1): the first gem's spell, else Complete Heal
local function testOpen()
  local st = eq.SpellBookState()
  local id = st and st.gems and st.gems[1] or -1
  eq.ShowSpell(id ~= -1 and id or 13)
end
local function size() return 360, 300 end

for i = 1, INSTANCES do
  local window = i == 1 and "SpellDisplayWindow" or ("SpellDisplayWindow#" .. i)
  -- made once per window, not every frame
  local opts = {
    key = window,
    keepTitle = true,
    size = size,
    resizable = { 240, 140 },
    place = function(W_, H, w, h, s, x, y) return x + (i - 1) * 24, y + (i - 1) * 24 end,
  }
  local function body(x, y, w, h, s)
    local name = eq.WindowTitle(window) or ""
    name = name:gsub('^Spell:%s*', '')
    local tex, u0, v0, u1, v1 = eq.ChildArt(window, "SDW_IconButton", "decal")
    if type(tex) ~= "userdata" then tex = nil end
    local size = 40 * s
    T.Icon(x, y, size, s, tex, u0, v0, u1, v1, nil, ICON_OPTS)
    local _, nh = T.TextSize("Ag", T.font.normal)
    T.Text(x + size + 10 * s, y + (size - nh) / 2, T.Fit(name ~= "" and name or "Spell", w - size - 10 * s,
      T.font.normal), C.text, T.font.normal)
    local ly = y + size + 8 * s
    ui.DrawLine(x, ly, x + w, ly, C.ink[1], C.ink[2], C.ink[3], 0.06, 1)
    ui.SetCursorScreenPos(x, ly + 6 * s)
    ui.PushFont(T.font.small)
    local plugin = eq.Plugin("script:qol")
    local id = eq.DisplaySpellId and eq.DisplaySpellId(i)
    local entry = id and spellCache[id]
    if id and not entry then
      entry = prepareSpell(id, plugin)
      if entry then spellCache[id] = entry end
    end
    local details = entry and entry.details
    ui.BeginChild("##qolspell", 0, math.max(1, y + h - ly - 6 * s), false)
    local width = ui.GetContentRegionAvail()
    local raw = W.Text(window, "SDW_SpellDescription") or ""
    -- metadataLine / drawMetadata delete and mutate fields, so consume a fresh copy each frame.
    local fields = entry and shallowCopy(entry.fields) or {}
    local other = entry and entry.other or {}
    local desc = descriptions[window]
    if not desc or desc.raw ~= raw then
      desc = { raw = raw, lines = stml.Lines(raw, C.text) }
      descriptions[window] = desc
    end
    -- labels this window already shows from the addon's own data: the game's copy of them is dropped
    local known = entry and entry.known or {}
    local summaryShown = false
    for _, line in ipairs(desc.lines) do
      local plain = ''
      for _, segment in ipairs(line) do plain = plain .. (segment[1] or '') end
      local label = plain:match('^%s*([%a ]+):')
      if not summaryShown and details and #line == 1 and not line[1][3] and plain:match('^%s*Duration:') then
        -- "Duration: 1h 42m   Mana: 99999   Classes: ..." on one line: keep the parts as separate fields
        local dur = plain:match('Duration:%s*(.-)%s+Mana:') or plain:match('Duration:%s*(.-)%s+Classes:')
          or plain:match('Duration:%s*(.-)%s*$')
        if dur and dur ~= '' then fields.Duration = dur end
        if not fields.Mana then fields.Mana = plain:match('Mana:%s*(%S+)') end
        if not fields.Classes then fields.Classes = plain:match('Classes:%s*(.-)%s*$') end
        summaryLine(fields, META_SUMMARY)
        summaryShown = true
      elseif label and known[label] then
        if not summaryShown then
          summaryLine(fields, META_REMAINING)
          summaryShown = true
        end
      else
        if not summaryShown then
          summaryLine(fields, META_REMAINING)
          summaryShown = true
        end
        stml.DrawLine(line, width, function(link) eq.StmlLink(window, "SDW_SpellDescription", link[1], link[2]) end)
      end
    end
    if not summaryShown then summaryLine(fields, META_REMAINING) end
    if entry then
      drawEffects(entry.ordered, width, s)
      ui.Dummy(0, 6 * s)
      drawMetadata(fields, other, false)
      ui.Dummy(0, 6 * s)
      drawMetadata(fields, other, true)
    end
    ui.EndChild()
    ui.PopFont()
  end
  ui.window("Spell Display" .. (i == 1 and "" or (" " .. i)), function()
    if not eq.InGame() then return end
    if i == 1 then P.TestOpen(window, testOpen) end
    hud.Dialog(window, "Spell", opts, body)
  end)
end
