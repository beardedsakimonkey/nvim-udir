local api = vim.api

local M = {}

---@param win integer?
---@return boolean
function M.valid_win(win)
    return win ~= nil and api.nvim_win_is_valid(win)
end

---@param buf integer?
---@return boolean
function M.valid_buf(buf)
    return buf ~= nil and api.nvim_buf_is_valid(buf)
end

---@param hl string
---@return table
function M.border(hl)
    return {
        {'╭', hl}, {'─', hl}, {'╮', hl}, {'│', hl},
        {'╯', hl}, {'─', hl}, {'╰', hl}, {'│', hl},
    }
end

---@class UdirFloatLayoutOptions
---@field title? string
---@field title_pos? 'left'|'center'|'right'
---@field width integer
---@field height integer
---@field border_hl? string
---@field min_width? integer

---@param opts UdirFloatLayoutOptions
---@return table
function M.centered_layout(opts)
    local width = math.min(opts.width, math.max(opts.min_width or 20, vim.o.columns - 4))
    local height = math.min(opts.height, math.max(1, vim.o.lines - 4))
    local title = opts.title and (' ' .. opts.title .. ' ') or nil
    return {
        relative = 'editor',
        anchor = 'NW',
        row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        border = M.border(opts.border_hl or 'UdirPromptBorder'),
        title = title,
        title_pos = title and (opts.title_pos or 'left') or nil,
        style = 'minimal',
        noautocmd = true,
    }
end

---@param buf integer?
---@param win integer?
function M.close(buf, win)
    if M.valid_win(win) then
        pcall(api.nvim_win_close, win, true)
    end
    if M.valid_buf(buf) then
        pcall(api.nvim_buf_delete, buf, {force = true})
    end
end

return M
