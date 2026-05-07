local M = {}

---@type table<string, UdirState>
local buf_states = {}

---@param buf integer
---@param state UdirState
function M.set(buf, state)
    buf_states[tostring(buf)] = state
end

---@param buf integer
function M.remove(buf)
    buf_states[tostring(buf)] = nil
end

---@param buf? integer
---@return UdirState
function M.get(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    assert(buf ~= -1)
    local state = assert(buf_states[tostring(buf)])
    return state
end

return M
