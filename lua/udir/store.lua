local api = vim.api
local buf_states = {}
local function set_21(buf, state)
  buf_states[tostring(buf)] = state
  return nil
end
local function remove_21(buf)
  buf_states[tostring(buf)] = nil
  return nil
end
local function get(_3fbuf)
  local buf = (_3fbuf or api.nvim_get_current_buf())
  assert(not (-1 == buf))
  local state = buf_states[tostring(buf)]
  return assert(state)
end
return {["set!"] = set_21, ["remove!"] = remove_21, get = get}