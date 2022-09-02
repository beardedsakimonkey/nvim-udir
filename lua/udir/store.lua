local api = vim.api
local M = {}
local buf_states = {}
M["set!"] = function(buf, state)
  buf_states[tostring(buf)] = state
  return nil
end
M["remove!"] = function(buf)
  buf_states[tostring(buf)] = nil
  return nil
end
M.get = function(_3fbuf)
  local buf = (_3fbuf or api.nvim_get_current_buf())
  assert(not (-1 == buf))
  local state = buf_states[tostring(buf)]
  return assert(state)
end
return M