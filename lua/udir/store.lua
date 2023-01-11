local M = {}

local buf_states = {}

function M.set(buf, state)
    buf_states[tostring(buf)] = state
end

function M.remove(buf)
    buf_states[tostring(buf)] = nil
end

function M.get(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    assert(buf ~= -1)
    local state = buf_states[tostring(buf)]
    return assert(state)
end

return M
