-- Shared spell rendering for the spell display and the item display's "Spell info" section: the effect
-- columns (MINIMUM / MAXIMUM with caster levels) and the grouped metadata lines. Only preparation and
-- drawing live here; which spell to show and how the game's own text is interleaved stay in each window.
-- Loaded with dofile from both windows (UI dofile resolves next to them, in the add-on's ui/modern).
local hud = dofile("lib/hud.lua")
local T = hud.T
local C = T.color

local M = {}
-- MQ2ItemDisplay's default spell information colour.
local EXTRA_COLOR = { 0, 1, 1, 1 }
M.EXTRA_COLOR = EXTRA_COLOR
-- Sort order for the known effect names; unknown effects and raw lines sort after these.
local PRIORITY = { Haste = 1, Strength = 2, ['Armor Class'] = 3, Attack = 4, Accuracy = 5, Strikethrough = 6 }
M.PRIORITY = PRIORITY
-- Focus modifiers, then the one limits row, then unknown names, then raw lines.
local function rank(row)
  if row.is_raw then return 100 end
  if row.is_limit then return 98 end
  if row.is_focus then return 97 end
  return PRIORITY[row.name] or 99
end
-- Constant metadata label groups (kept at module scope instead of rebuilt every frame).
local META_TECHNICAL = { 'Spell ID' }
local META_TIMING = { 'Cast', 'Recovery', 'Recast' }
local META_RANGE = { 'Range', 'AE range', 'Pushback' }
local META_COMMON = { 'Level', 'Endurance', 'Resist type', 'Modifier', 'Skill' }
M.META_SUMMARY = { 'Duration', 'Mana', 'Classes' }
M.META_EFFICIENCY = { 'Damage per mana' }
local META_EFFICIENCY = M.META_EFFICIENCY
M.META_REMAINING = { 'Mana', 'Classes' }

function M.shallowCopy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function colored(text, color)
  ui.PushTextWrapPos(0)
  ui.TextColored(color[1], color[2], color[3], color[4], text)
  ui.PopTextWrapPos()
end
M.colored = colored

-- Prepare the effect rows once per spell: copy them (never mutate plugin-owned tables), keep a
-- stable original order for ties, and sort known effects first / raw lines last.
function M.prepareEffects(rows)
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
    -- known effects first, then focus modifiers, the limits row, unknown names, raw lines last
    local aa, bb = rank(a), rank(b)
    return aa == bb and a._order < b._order or aa < bb
  end)
  return ordered
end

-- Compact columns, measured from the font instead of relying on monospaced text. All drawing and
-- width-dependent measurement stays here and runs every frame (the windows are resizable).
function M.drawEffects(ordered, width, s)
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
    if row.is_limit then
      -- one muted, wrapped row: no MINIMUM/MAXIMUM columns
      local x, y = ui.GetCursorScreenPos()
      local _, th = T.TextSize('Ag', T.font.small)
      T.Text(x, y, row.name or '', C.muted, T.font.small)
      ui.SetCursorScreenPos(x + nameW, y)
      ui.PushFont(T.font.small)
      ui.PushTextWrapPos(0)
      ui.TextColored(C.muted[1], C.muted[2], C.muted[3], C.muted[4], row.min or '')
      ui.PopTextWrapPos()
      ui.PopFont()
      local _, ny = ui.GetCursorScreenPos()
      ui.SetCursorScreenPos(x, ny + 3 * s)
    elseif row.is_raw then
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
function M.metadata(text)
  local fields, other = {}, {}
  for line in (text or ''):gmatch('[^\n]+') do
    local label, value = line:match('^([^:]+):%s*(.*)$')
    if label then fields[label] = value else other[#other + 1] = line end
  end
  return fields, other
end

-- Draws and removes the given labels from `fields` (callers pass a per-frame copy).
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
M.metadataLine = metadataLine

function M.drawMetadata(fields, other, technical)
  if technical then
    metadataLine(fields, META_TECHNICAL, C.muted)
    return
  end
  -- The efficiency line opens the blue metadata block, above the timing line.
  metadataLine(fields, META_EFFICIENCY, EXTRA_COLOR)
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

return M
