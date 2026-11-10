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

local function colored(text, color)
  ui.PushTextWrapPos(0)
  ui.TextColored(color[1], color[2], color[3], color[4], text)
  ui.PopTextWrapPos()
end

-- Compact columns, measured from the font instead of relying on monospaced text.
local function effects(rows, width, s)
  if type(rows) ~= 'table' or #rows == 0 then return end
  ui.Dummy(0, 8 * s)
  colored('Effects', C.muted)
  local ordered = {}
  for _, row in ipairs(rows) do ordered[#ordered + 1] = row end
  local priority = { Haste = 1, Strength = 2, ['Armor Class'] = 3, Attack = 4, Accuracy = 5, Strikethrough = 6 }
  -- Keep unknown effects in their original relative order.
  for i, row in ipairs(ordered) do row._order = i end
  table.sort(ordered, function(a, b)
    -- unknown names after the known ones, raw lines last
    local aa, bb = a.is_raw and 100 or priority[a.name] or 99, b.is_raw and 100 or priority[b.name] or 99
    return aa == bb and a._order < b._order or aa < bb
  end)
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
  local function value(text, level)
    return (text or '') .. (level and (' (L' .. level .. ')') or '')
  end
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
      T.Text(x + nameW, y, value(row.min, row.min_level), EXTRA_COLOR, T.font.small)
      if row.max and not compact then
        -- The default game font lacks the Unicode arrow glyph.
        local ax, ay = x + nameW + minW, y + th * 0.5
        ui.DrawLine(ax, ay, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        ui.DrawLine(ax + 5 * s, ay - 3 * s, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        ui.DrawLine(ax + 5 * s, ay + 3 * s, ax + 8 * s, ay, C.muted[1], C.muted[2], C.muted[3], 1, 1)
        T.Text(x + nameW + minW + arrowW, y, value(row.max, row.max_level), EXTRA_COLOR, T.font.small)
      end
      ui.Dummy(width, th + 3 * s)
      if row.max and compact then
        local nx, ny = ui.GetCursorScreenPos()
        T.Text(nx + nameW, ny, '- ' .. value(row.max, row.max_level), EXTRA_COLOR, T.font.small)
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
    metadataLine(fields, {'Spell ID'}, C.muted)
    return
  end
  metadataLine(fields, {'Cast', 'Recovery', 'Recast'}, EXTRA_COLOR)
  if fields['AE range'] == '0' or fields['AE range'] == '0.0' then fields['AE range'] = nil end
  metadataLine(fields, {'Range', 'AE range', 'Pushback'}, EXTRA_COLOR)
  for _, label in ipairs({'Level', 'Endurance', 'Resist type', 'Modifier', 'Skill'}) do
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
    local details = plugin and id and plugin.spell_view(id)
    ui.BeginChild("##qolspell", 0, math.max(1, y + h - ly - 6 * s), false)
    local width = ui.GetContentRegionAvail()
    local raw = W.Text(window, "SDW_SpellDescription") or ""
    local fields, other = metadata(details and details.metadata)
    local desc = descriptions[window]
    if not desc or desc.raw ~= raw then
      desc = { raw = raw, lines = stml.Lines(raw, C.text) }
      descriptions[window] = desc
    end
    -- labels this window already shows from the addon's own data: the game's copy of them is dropped
    local known = {}
    for label in pairs(fields) do known[label] = true end
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
        metadataLine(fields, {'Duration', 'Mana', 'Classes'}, C.text)
        summaryShown = true
      elseif label and known[label] then
        if not summaryShown then
          metadataLine(fields, {'Mana', 'Classes'}, C.text)
          summaryShown = true
        end
      else
        if not summaryShown then
          metadataLine(fields, {'Mana', 'Classes'}, C.text)
          summaryShown = true
        end
        stml.DrawLine(line, width, function(link) eq.StmlLink(window, "SDW_SpellDescription", link[1], link[2]) end)
      end
    end
    if not summaryShown then metadataLine(fields, {'Mana', 'Classes'}, C.text) end
    if details then
      effects(details.effects, width, s)
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
