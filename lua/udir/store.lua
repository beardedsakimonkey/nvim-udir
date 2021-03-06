local api = vim.api
local M = {}
local buf_states = {}
M["set!"] = function(buf, state)
  _G.assert((nil ~= state), "Missing argument state on lua/udir/store.fnl:7")
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/store.fnl:7")
  do end (buf_states)[tostring(buf)] = state
  return nil
end
M["remove!"] = function(buf)
  _G.assert((nil ~= buf), "Missing argument buf on lua/udir/store.fnl:11")
  do end (buf_states)[tostring(buf)] = nil
  return nil
end
M.get = function()
  local buf = api.nvim_get_current_buf()
  assert(not (-1 == buf))
  local state = buf_states[tostring(buf)]
  return assert(state)
end
return M
