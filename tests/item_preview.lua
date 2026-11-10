-- request_item_preview: one validated, click-only server request inside QoL's own capability scope.
local functions, messages, requests, servers = {}, {}, {}, 0
local options, saved = {}, nil
local hs = {
  option = function(option) options[option.name] = option end,
  ui_function = function(name, fn) functions[name] = fn end,
  chat = function(text) messages[#messages + 1] = text end,
}
package.preload.hailstone = function() return hs end
package.preload.mq = function()
  return {pickle = function(_, value) saved = value end}
end
dofile('init.lua')
assert(#messages == 0, 'loading QoL must not request or report a preview')
local request = assert(functions.request_item_preview)
assert(functions.test_item_preview == nil, 'the temporary fixed-id diagnostic must be gone')

-- The experiment is opt-in: requests stay disabled until its option is on.
assert(options.item_preview and options.item_preview.get() == 0)
assert(request(1000001).kind == 'disabled' and servers == 0)
options.item_preview.set(1)
assert(options.item_preview.get() == 1 and saved.item_preview == true)

local function triune()
  return {name = 'Project Triune', host = 'eq-emulator.com', port = 5999,
    world = 'Project Triune', world_host = 'world.example'}
end
hs.server = function() servers = servers + 1 return triune() end
hs.inspect_item = function(id) requests[#requests + 1] = id end

-- Only a finite positive integer inside uint32 may reach the client.
assert(request(nil).kind == 'invalid_id')
for _, invalid in ipairs({false, 0, -1, 1.5, '100', {}, math.huge, -math.huge, 0 / 0,
    4294967296}) do
  local result = request(invalid)
  assert(type(result) == 'table' and result.ok == false and result.kind == 'invalid_id')
end
assert(#requests == 0, 'an invalid id must not reach inspect_item')
assert(servers == 0, 'an invalid id is rejected before any server or client call')

-- A missing, failing or non-Triune server identity is reported, not silently allowed or refused.
hs.server = nil
local result = request(1000001)
assert(result.ok == false and result.kind == 'server' and result.error:find('hs.server', 1, true))
assert(#requests == 0)
hs.server = function() error('server read denied') end
result = request(1000001)
assert(result.ok == false and result.kind == 'server' and result.error:find('server read denied', 1, true))
assert(#requests == 0)
hs.server = function() return nil end
result = request(1000001)
assert(result.ok == false and result.kind == 'server' and result.error:find('server identity', 1, true))
assert(#requests == 0)
hs.server = function() return {name = 'Triune Vanilla', world = 'Triune Vanilla'} end
result = request(1000001)
assert(result.ok == false and result.kind == 'server' and result.error:find('not recognized', 1, true))
assert(#requests == 0, 'another server must not receive the request')

-- The saved profile folder id is accepted as the same server.
hs.server = function() return {name = 'project-triune'} end
hs.inspect_item = function(id) requests[#requests + 1] = id end
result = request(1051907)
assert(result.ok == true and #requests == 1 and requests[1] == 1051907)
requests = {}

-- On Project Triune, a missing inspect_item is a distinct, visible failure.
hs.server = function() return triune() end
hs.inspect_item = nil
result = request(1000001)
assert(result.ok == false and result.kind == 'missing_api' and result.error:find('inspect_item', 1, true))
assert(#requests == 0)

-- A client refusal is passed through; the request is not retried.
hs.inspect_item = function() error("needs the 'actions' permission") end
result = request(1000001)
assert(result.ok == false and result.kind == 'refused'
  and result.error:find("needs the 'actions' permission", 1, true))
assert(#requests == 0)

-- A successful call is exactly one request per click, including the largest uint32 id.
hs.inspect_item = function(id) requests[#requests + 1] = id end
result = request(2051907)
assert(result.ok == true and result.id == 2051907)
assert(#requests == 1 and requests[1] == 2051907)
result = request(4294967295)
assert(result.ok == true and #requests == 2 and requests[2] == 4294967295)
assert(#messages == 0, 'the callback reports through its return value, not chat')
print('item preview request: ok')
