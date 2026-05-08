local api = vim.api
local uv = vim.loop

local float = require'udir.float'
local fs = require'udir.fs'
local util = require'udir.util'

local M = {}

local MAX_DELETE_PATHS = 10

---@class UdirDeleteConfirmItem
---@field display string
---@field file_start_col integer
---@field file_end_col integer
---@field file_hl string
---@field directory_suffix_col? integer

---@param path string
---@return string
local function file_hl(path)
    if uv.fs_readlink(path) then
        return 'UdirSymlink'
    end
    local stat = uv.fs_stat(path)
    if stat and stat.type == 'directory' then
        return 'UdirDirectory'
    end
    if uv.fs_access(path, 'X') then
        return 'UdirExecutable'
    end
    return 'UdirFile'
end

---@param path string
---@param cwd string
---@return string
local function relative_display_path(path, cwd)
    if cwd == util.sep and vim.startswith(path, util.sep) then
        return path:sub(2)
    end
    local cwd_prefix = cwd .. util.sep
    if vim.startswith(path, cwd_prefix) then
        return path:sub(#cwd_prefix + 1)
    end
    return util.display_path(path)
end

---@param path string
---@param cwd string
---@return UdirDeleteConfirmItem
local function item(path, cwd)
    local display = relative_display_path(path, cwd)
    local basename = fs.basename(path)
    local file_start_col = math.max(0, #display - #basename)
    local directory_suffix_col
    local hl = file_hl(path)
    if hl == 'UdirDirectory' then
        directory_suffix_col = #display
        display = display .. util.sep
    end
    return {
        display = display,
        file_start_col = file_start_col,
        file_end_col = directory_suffix_col or #display,
        file_hl = hl,
        directory_suffix_col = directory_suffix_col,
    }
end

---@param paths string[]
---@param cwd string
---@return UdirDeleteConfirmItem[]
local function items(paths, cwd)
    local ret = {}
    for i = 1, math.min(#paths, MAX_DELETE_PATHS) do
        ret[#ret+1] = item(paths[i], cwd)
    end
    return ret
end

---@param count integer
---@return string
local function title(count)
    if count == 1 then
        return 'Delete? (y/n)'
    end
    return string.format('Delete %d %s? (y/n)', count, count == 1 and 'file' or 'files')
end

---@param confirm_items UdirDeleteConfirmItem[]
---@param overflow integer
---@return string[]
local function lines(confirm_items, overflow)
    local ret = {}
    for _, confirm_item in ipairs(confirm_items) do
        ret[#ret+1] = '  ' .. confirm_item.display
    end
    if overflow > 0 then
        ret[#ret+1] = string.format('  ... and %d more', overflow)
    end
    return ret
end

---@param buf integer
---@param ns integer
---@param confirm_items UdirDeleteConfirmItem[]
---@param overflow integer
local function render(buf, ns, confirm_items, overflow)
    local rendered_lines = lines(confirm_items, overflow)
    api.nvim_buf_set_lines(buf, 0, -1, false, rendered_lines)
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, confirm_item in ipairs(confirm_items) do
        local line_prefix_len = 2
        local path_start_col = line_prefix_len
        local file_start_col = line_prefix_len + confirm_item.file_start_col
        local file_end_col = line_prefix_len + confirm_item.file_end_col
        if path_start_col < file_start_col then
            api.nvim_buf_set_extmark(buf, ns, i - 1, path_start_col, {
                end_col = file_start_col,
                hl_group = 'UdirDeletePath',
            })
        end
        api.nvim_buf_set_extmark(buf, ns, i - 1, file_start_col, {
            end_col = file_end_col,
            hl_group = confirm_item.file_hl,
            priority = 10000,
        })
        if confirm_item.directory_suffix_col then
            local suffix_col = line_prefix_len + confirm_item.directory_suffix_col
            api.nvim_buf_set_extmark(buf, ns, i - 1, suffix_col, {
                end_col = file_end_col + 1,
                hl_group = 'UdirVirtText',
                priority = 10000,
            })
        end
    end
    if overflow > 0 then
        local row = #rendered_lines - 1
        api.nvim_buf_set_extmark(buf, ns, row, 2, {
            end_col = #rendered_lines[#rendered_lines],
            hl_group = 'UdirDeleteMore',
        })
    end
end

---@param confirm_title string
---@param rendered_lines string[]
---@return integer
local function width(confirm_title, rendered_lines)
    local max_width = #confirm_title
    for _, line in ipairs(rendered_lines) do
        max_width = math.max(max_width, #line)
    end
    return math.max(32, math.min(96, max_width))
end

---@param paths string[]
---@param cwd string
---@param cb fun(confirmed: boolean)
function M.delete(paths, cwd, cb)
    if #paths == 0 then
        cb(false)
        return
    end
    local confirm_items = items(paths, cwd)
    local overflow = math.max(0, #paths - #confirm_items)
    local rendered_lines = lines(confirm_items, overflow)
    local confirm_title = title(#paths)
    local origin_win = api.nvim_get_current_win()
    local guicursor = vim.o.guicursor
    local autocmds = {}
    local closed = false
    local buf = api.nvim_create_buf(false, true)
    local ns = api.nvim_create_namespace('udir/delete-confirm.' .. buf)

    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].modifiable = true
    render(buf, ns, confirm_items, overflow)
    vim.bo[buf].modifiable = false

    local function layout()
        return float.centered_layout({
            title = confirm_title,
            width = width(confirm_title, rendered_lines),
            height = #rendered_lines,
            border_hl = 'UdirPromptBorderInvalid',
        })
    end

    local win = api.nvim_open_win(buf, true, layout())
    vim.o.guicursor = 'a:block-UdirDeleteCursor'
    vim.wo[win].winhighlight = 'NormalFloat:Normal,FloatBorder:UdirPromptBorderInvalid,Cursor:UdirDeleteCursor'
    vim.wo[win].wrap = false

    local function finish(confirmed)
        if closed then
            return
        end
        closed = true
        for _, au in ipairs(autocmds) do
            pcall(api.nvim_del_autocmd, au)
        end
        vim.o.guicursor = guicursor
        float.close(buf, win)
        if float.valid_win(origin_win) then
            pcall(api.nvim_set_current_win, origin_win)
        end
        cb(confirmed)
    end

    for _, lhs in ipairs({'y', 'Y'}) do
        vim.keymap.set('n', lhs, function() finish(true) end, {buffer = buf, silent = true, nowait = true})
    end
    for _, lhs in ipairs({'n', 'N', 'q', '<Esc>', '<C-c>'}) do
        vim.keymap.set('n', lhs, function() finish(false) end, {buffer = buf, silent = true, nowait = true})
    end

    autocmds[#autocmds+1] = api.nvim_create_autocmd('VimResized', {
        callback = function()
            if float.valid_win(win) then
                api.nvim_win_set_config(win, layout())
            end
        end,
    })
    autocmds[#autocmds+1] = api.nvim_create_autocmd('WinClosed', {
        callback = function(args)
            if tonumber(args.match) == win then
                finish(false)
            end
        end,
    })
end

return M
