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
-- MQ2ItemDisplay's default spell information colour.
local EXTRA_COLOR = { 0, 1, 1, 1 }
local descriptions = {}
-- Spell data never changes for an id, so all preparation (spell_view, metadata parsing, effect
-- sorting) is done once per id and shared by every window/frame showing that spell.
local spellCache = {}
-- Sort order for the known effect names; unknown effects and raw lines sort after these.
local PRIORITY = { Haste = 1, Strength = 2, ['Armor Class'] = 3, Attack = 4, Accuracy = 5, Strikethrough = 6 }
-- Constant metadata label groups (kept at module scope instead of rebuilt every frame).
local META_TECHNICAL = { 'Spell ID' }
local META_TIMING = { 'Cast', 'Recovery', 'Recast' }
local META_RANGE = { 'Range', 'AE range', 'Pushback' }
local META_COMMON = { 'Level', 'Endurance', 'Resist type', 'Modifier', 'Skill' }
local META_SUMMARY = { 'Duration', 'Mana', 'Classes' }
local META_REMAINING = { 'Mana', 'Classes' }

local function shallowCopy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function colored(text, color)
  ui.PushTextWrapPos(0)
  ui.TextColored(color[1], color[2], color[3], color[4], text)
  ui.PopTextWrapPos()
end

-- Prepare the effect rows once per spell: copy them (never mutate plugin-owned tables), keep a
-- stable original order for ties, and sort known effects first / raw lines last.
local function prepareEffects(rows)
  if type(rows) ~= 'table' or #rows == 0 then return end
  local ordered = {}
  for _, row in ipairs(rows) do
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    ordered[#ordered + 1] = copy
  end
  -- Keep unknown effects in their original relative order; cache the value strings too.
  for i, row in ipairs(ordered) do
    row._order = i
    row._minText = (row.min or '') .. (row.min_level and (' (L' .. row.min_level .. ')') or '')
    row._maxText = (row.max or '') .. (row.max_level and (' (L' .. row.max_level .. ')') or '')
  end
  table.sort(ordered, function(a, b)
    -- unknown names after the known ones, raw lines last
    local aa, bb = a.is_raw and 100 or PRIORITY[a.name] or 99, b.is_raw and 100 or PRIORITY[b.name] or 99
    return aa == bb and a._order < b._order or aa < bb
  end)
  return ordered
end

-- Compact columns, measured from the font instead of relying on monospaced text. All drawing and
-- width-dependent measurement stays here and runs every frame (the window is resizable).
local function drawEffects(ordered, width, s)
  if not ordered then return end
  ui.Dummy(0, 8 * s)
  colored('Effects', C.muted)
  local panelX, panelY = ui.GetCursorScreenPos()
  ui.Dummy(0, 5 * s)
  local nameW = 0
  for _, row in ipairs(ordered) do
    if type(row.name) == 'string' and not row.is_raw then
      nameW = math.max(nameW, T.TextSize(row.name, T.font.small))
    end
  end
  nameW = math.min(nameW + 14 * s, width * 0.42)
  local minW = T.TextSize('+100% (L100)', T.font.small) + 12 * s
  local arrowW = 20 * s
  local compact = width < nameW + minW * 2 + arrowW
  local hasMax = false
  for _, row in ipairs(ordered) do if row.max and not row.is_raw then hasMax = true end end
  if not compact and hasMax then
    local x, y = ui.GetCursorScreenPos()
    local _, th = T.TextSize('Ag', T.font.small)
    T.Text(x + nameW, y, 'MINIMUM', C.muted, T.font.small)
    T.Text(x + nameW + minW + arrowW, y, 'MAXIMUM', C.muted, T.font.small)
    ui.Dummy(width, th + 4 * s)
  end
  for _, row in ipairs(ordered) do
    if row.is_raw then
      colored(row.min or row.name or '', EXTRA_COLOR)
    else
      local x, y = ui.GetCursorScreenPos()
      local _, th = T.TextSize('Ag', T.font.small)
      T.Text(x, y, row.name or '', EXTRA_COLOR, T.font.small)
      T.Text(x + nameW, y, row._minText, EXTRA_COLOR, T.font.small)
      if row.max and not compact then
        -- The default game font lacks the Unicode arrow glyph.
        local ax, ay = x + nameW + minW, y + th * 0.5
        ui.DrawLine(ax, ay, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        ui.DrawLine(ax + 5 * s, ay - 3 * s, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        ui.DrawLine(ax + 5 * s, ay + 3 * s, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        T.Text(x + nameW + minW + arrowW, y, row._maxText, EXTRA_COLOR, T.font.small)
      end
      ui.Dummy(width, th + 3 * s)
      if row.max and compact then
        local nx, ny = ui.GetCursorScreenPos()
        T.Text(nx + nameW, ny, '- ' .. row._maxText, EXTRA_COLOR, T.font.small)
        ui.Dummy(width, th + 3 * s)
      end
      if row.skill or row.scale or row.note then
        local nx, ny = ui.GetCursorScreenPos()
        if row.skill then T.Text(nx, ny, row.skill, C.muted, T.font.small) end
        local detail = row.scale or row.note
        if detail then T.Text(nx + nameW, ny, detail, C.muted, T.font.small) end
        ui.Dummy(width, th + 3 * s)
        if row.scale and row.note then
          nx, ny = ui.GetCursorScreenPos()
          T.Text(nx + nameW, ny, row.note, C.muted, T.font.small)
          ui.Dummy(width, th + 3 * s)
        end
      end
    end
  end
  local _, panelBottom = ui.GetCursorScreenPos()
  ui.DrawRectFilled(panelX, panelY, panelX + width, panelBottom + 2 * s, 0, 1, 1, 0.025, 5 * s)
  ui.Dummy(0, 5 * s)
  local anyLevel = false
  for _, row in ipairs(ordered) do if row.min_level or row.max_level then anyLevel = true end end
  if anyLevel then colored('L = caster level', C.muted) end
end

-- Compact metadata, keeping uncommon fields instead of discarding them.
local function metadata(text)
  local fields, other = {}, {}
  for line in (text or ''):gmatch('[^\n]+') do
    local label, value = line:match('^([^:]+):%s*(.*)$')
    if label then fields[label] = value else other[#other + 1] = line end
  end
  return fields, other
end

local function metadataLine(fields, labels, color)
  local parts = {}
  for _, label in ipairs(labels) do
    local value = fields[label]
    if value and value ~= '' then
      parts[#parts + 1] = label .. ': ' .. value
      fields[label] = nil
    end
  end
  if #parts > 0 then colored(table.concat(parts, '    '), color) end
end

local function drawMetadata(fields, other, technical)
  if technical then
    metadataLine(fields, META_TECHNICAL, C.muted)
    return
  end
  metadataLine(fields, META_TIMING, EXTRA_COLOR)
  if fields['AE range'] == '0' or fields['AE range'] == '0.0' then fields['AE range'] = nil end
  metadataLine(fields, META_RANGE, EXTRA_COLOR)
  for _, label in ipairs(META_COMMON) do
    metadataLine(fields, {label}, EXTRA_COLOR)
  end
  local remaining = {}
  for label in pairs(fields) do
    if label ~= 'Spell ID' then
      remaining[#remaining + 1] = label
    end
  end
  table.sort(remaining)
  for _, label in ipairs(remaining) do metadataLine(fields, {label}, EXTRA_COLOR) end
  for _, line in ipairs(other) do colored(line, EXTRA_COLOR) end
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
        metadataLine(fields, META_SUMMARY, C.text)
        summaryShown = true
      elseif label and known[label] then
        if not summaryShown then
          metadataLine(fields, META_REMAINING, C.text)
          summaryShown = true
        end
      else
        if not summaryShown then
          metadataLine(fields, META_REMAINING, C.text)
          summaryShown = true
        end
        stml.DrawLine(line, width, function(link) eq.StmlLink(window, "SDW_SpellDescription", link[1], link[2]) end)
      end
    end
    if not summaryShown then metadataLine(fields, META_REMAINING, C.text) end
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
