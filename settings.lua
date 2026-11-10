local M = {}

local VERSION = 1
local FILE = 'qol.lua'
local DEFAULTS = {
  nameplate_level = true,
  target_level = true,
  npc_class = true,
  spell_info = true,
  item_info = true,
  item_preview = false,
  map_target_line = true,
  map_npcs = true,
}

local function defaults()
  local values = {}
  for name, value in pairs(DEFAULTS) do values[name] = value end
  return values
end

local function fromConfig(config)
  local values = defaults()
  if type(config) ~= 'table' or config.version ~= VERSION then return values end
  for name in pairs(DEFAULTS) do
    if type(config[name]) == 'boolean' then values[name] = config[name] end
  end
  return values
end

function M.new(mq, readConfig, onError)
  local load = readConfig or dofile
  local ok, config = pcall(load, FILE)
  local values = fromConfig(ok and config or nil)

  local function save()
    local config = {version = VERSION}
    for name in pairs(DEFAULTS) do config[name] = values[name] end
    local saved, err = pcall(mq.pickle, FILE, config)
    if not saved and onError then pcall(onError, err) end
    return saved
  end

  return {
    get = function(name)
      return values[name]
    end,
    set = function(name, value)
      if DEFAULTS[name] == nil or type(value) ~= 'boolean' then return false end
      if values[name] == value then return true end
      values[name] = value
      return save()
    end,
  }
end

return M
