local api = vim.api
local M = {}
local buf_states = {}
M["set!"] = function(buf, state)
  assert((nil ~= state), string.format("Missing argument %s on %s:%s", "state", "lua/qdir/store.fnl", 16))
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir/store.fnl", 16))
  do end (buf_states)[tostring(buf)] = state
  return nil
end
M.remove = function(buf)
  assert((nil ~= buf), string.format("Missing argument %s on %s:%s", "buf", "lua/qdir/store.fnl", 20))
  table.remove(buf_states, tostring(buf))
  return nil
end
M.get = function()
  local buf = api.nvim_get_current_buf()
  assert(not (buf == -1))
  local state = buf_states[tostring(buf)]
  return assert(state)
end
return M
