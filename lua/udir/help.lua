local util = require'udir.util'

local api = vim.api

local M = {}

---@class UdirHelpRow
---@field lhs? string
---@field desc? string
---@field label? string
---@field header? boolean
---@field blank? boolean

---@param hl string
---@return table
local function make_border(hl)
    return {
        {'╭', hl}, {'─', hl}, {'╮', hl}, {'│', hl},
        {'╯', hl}, {'─', hl}, {'╰', hl}, {'│', hl},
    }
end

---@param buf integer?
---@param win integer?
local function close_float(buf, win)
    if win and api.nvim_win_is_valid(win) then
        pcall(api.nvim_win_close, win, true)
    end
    if buf and api.nvim_buf_is_valid(buf) then
        pcall(api.nvim_buf_delete, buf, {force=true})
    end
end

---@param width integer
---@param height integer
---@return table
local function layout(width, height)
    width = math.min(width, math.max(20, vim.o.columns - 4))
    height = math.min(height, math.max(1, vim.o.lines - 4))
    return {
        relative = 'editor',
        anchor = 'NW',
        row = math.max(0, math.floor((vim.o.lines - height - 2) / 2)),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        border = make_border('UdirPromptBorder'),
        title = ' Help ',
        title_pos = 'left',
        style = 'minimal',
        noautocmd = true,
    }
end

---@param label string
---@param keymaps? table<string, UdirKeymapSpec>
---@return UdirHelpRow[]
local function keymap_rows(label, keymaps)
    local rows = {}
    for lhs, rhs in pairs(keymaps or {}) do
        local action = type(rhs) == 'table' and rhs[1] or rhs
        local desc = type(rhs) == 'table' and rhs.desc or nil
        rows[#rows+1] = {lhs=lhs, desc=desc or tostring(action)}
    end
    table.sort(rows, function(a, b) return a.lhs < b.lhs end)
    if #rows == 0 then
        return {}
    end
    local section = {{label=label, header=true}}
    vim.list_extend(section, rows)
    return section
end

---@param config UdirConfig
---@return UdirHelpRow[]
local function rows(config)
    local normal_rows = keymap_rows('Normal', config.keymaps)
    local visual_rows = keymap_rows('Visual', config.visual_keymaps)
    if #normal_rows > 0 and #visual_rows > 0 then
        normal_rows[#normal_rows+1] = {blank=true}
    end
    vim.list_extend(normal_rows, visual_rows)
    return normal_rows
end

---@param buf integer
---@param ns integer
---@param help_rows UdirHelpRow[]
local function render(buf, ns, help_rows)
    local key_width = 1
    for _, row in ipairs(help_rows) do
        if row.lhs then
            key_width = math.max(key_width, #row.lhs)
        end
    end

    local lines = {}
    for _, row in ipairs(help_rows) do
        if row.blank then
            lines[#lines+1] = ''
        elseif row.header then
            lines[#lines+1] = row.label
        else
            lines[#lines+1] = ('  %-' .. key_width .. 's  %s'):format(row.lhs, row.desc)
        end
    end

    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, row in ipairs(help_rows) do
        local lnum = i - 1
        if row.header then
            api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
                end_col = #row.label,
                hl_group = 'UdirHelpHeader',
            })
        elseif row.lhs then
            api.nvim_buf_set_extmark(buf, ns, lnum, 2, {
                end_col = 2 + key_width,
                hl_group = 'UdirHelpKey',
            })
            api.nvim_buf_set_extmark(buf, ns, lnum, 2 + key_width + 2, {
                end_col = #lines[i],
                hl_group = 'UdirHelpDesc',
            })
        end
    end
end

---@param config UdirConfig
function M.open(config)
    local help_rows = rows(config)
    if #help_rows == 0 then
        util.warn('No keymap descriptions configured')
        return
    end

    local key_width = 1
    local desc_width = 1
    for _, row in ipairs(help_rows) do
        if row.lhs then
            key_width = math.max(key_width, #row.lhs)
            desc_width = math.max(desc_width, #row.desc)
        end
    end

    local width = math.max(32, math.min(72, key_width + desc_width + 6))
    local height = #help_rows
    local origin_win = api.nvim_get_current_win()
    local buf = api.nvim_create_buf(false, true)
    local ns = api.nvim_create_namespace('udir/help.' .. buf)

    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].modifiable = true
    render(buf, ns, help_rows)
    vim.bo[buf].modifiable = false

    local win = api.nvim_open_win(buf, true, layout(width, height))
    vim.wo[win].winhighlight = 'NormalFloat:Normal,FloatBorder:UdirPromptBorder'
    vim.wo[win].cursorline = true

    local function close()
        close_float(buf, win)
        if api.nvim_win_is_valid(origin_win) then
            pcall(api.nvim_set_current_win, origin_win)
        end
    end
    for _, lhs in ipairs({'H', '?', 'q', '<Esc>', '<C-c>', '<CR>'}) do
        vim.keymap.set('n', lhs, close, {buffer=buf, silent=true, nowait=true})
    end
end

return M
