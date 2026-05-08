local api = vim.api
local uv = vim.loop

local float = require'udir.float'
local fs = require'udir.fs'
local util = require'udir.util'

local M = {}

---@class UdirInfoRow
---@field label string
---@field value string

---@param bytes integer
---@return string
local function format_size(bytes)
    if bytes < 1024 then
        return string.format('%d B', bytes)
    end
    local size = bytes
    for _, unit in ipairs({'KiB', 'MiB', 'GiB', 'TiB'}) do
        size = size / 1024
        if size < 1024 then
            return string.format('%.1f %s (%d bytes)', size, unit, bytes)
        end
    end
    return string.format('%.1f PiB (%d bytes)', size / 1024, bytes)
end

---@param timestamp table?
---@return string
local function format_time(timestamp)
    if not timestamp or not timestamp.sec then
        return 'unknown'
    end
    return os.date('%Y-%m-%d %H:%M:%S', timestamp.sec) or 'unknown'
end

---@param mode integer
---@return string
local function format_mode(mode)
    local perms = mode % 512
    local ret = {}
    for _, shift in ipairs({64, 8, 1}) do
        local digit = math.floor(perms / shift) % 8
        ret[#ret+1] = digit >= 4 and 'r' or '-'
        ret[#ret+1] = digit % 4 >= 2 and 'w' or '-'
        ret[#ret+1] = digit % 2 == 1 and 'x' or '-'
    end
    return string.format('%s (%03o)', table.concat(ret), perms)
end

---@param type string
---@return string
local function format_type(type)
    return ({
        file = 'File',
        directory = 'Directory',
        link = 'Symlink',
        fifo = 'FIFO',
        socket = 'Socket',
        char = 'Character device',
        block = 'Block device',
    })[type] or type
end

---@param rows UdirInfoRow[]
---@param label string
---@param value any
local function add(rows, label, value)
    if value ~= nil then
        rows[#rows+1] = {label = label, value = tostring(value)}
    end
end

---@param path string
---@param stat table
---@return UdirInfoRow[]
local function rows(path, stat)
    local ret = {}
    add(ret, 'Name', fs.basename(path))
    add(ret, 'Type', format_type(stat.type))
    add(ret, 'Path', util.display_path(path))
    add(ret, 'Size', format_size(stat.size or 0))
    add(ret, 'Permissions', format_mode(stat.mode or 0))
    if stat.type == 'file' then
        add(ret, 'Executable', uv.fs_access(path, 'X') and 'yes' or 'no')
    end

    local link_target = stat.type == 'link' and uv.fs_readlink(path) or nil
    if link_target then
        add(ret, 'Target', vim.startswith(link_target, util.sep) and util.display_path(link_target) or link_target)
        local target_stat = uv.fs_stat(path)
        add(ret, 'Target type', target_stat and format_type(target_stat.type) or 'missing')
    end

    add(ret, 'Modified', format_time(stat.mtime))
    add(ret, 'Accessed', format_time(stat.atime))
    add(ret, 'Created', format_time(stat.birthtime))
    add(ret, 'Owner', stat.uid and stat.gid and (stat.uid .. ':' .. stat.gid) or nil)
    add(ret, 'Links', stat.nlink)
    add(ret, 'Inode', stat.ino)
    return ret
end

---@param info_rows UdirInfoRow[]
---@return integer
local function label_width(info_rows)
    local width = 1
    for _, row in ipairs(info_rows) do
        width = math.max(width, #row.label)
    end
    return width
end

---@param info_rows UdirInfoRow[]
---@param label_len integer
---@return string[]
local function lines(info_rows, label_len)
    local ret = {}
    local format = '%-' .. label_len .. 's  %s'
    for _, row in ipairs(info_rows) do
        ret[#ret+1] = format:format(row.label, row.value)
    end
    return ret
end

---@param rendered_lines string[]
---@return integer
local function width(rendered_lines)
    local max_width = 32
    for _, line in ipairs(rendered_lines) do
        max_width = math.max(max_width, #line)
    end
    return math.min(96, max_width)
end

---@param buf integer
---@param ns integer
---@param info_rows UdirInfoRow[]
---@param label_len integer
local function render(buf, ns, info_rows, label_len)
    local rendered_lines = lines(info_rows, label_len)
    api.nvim_buf_set_lines(buf, 0, -1, false, rendered_lines)
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, line in ipairs(rendered_lines) do
        api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
            end_col = label_len,
            hl_group = 'UdirInfoLabel',
        })
        api.nvim_buf_set_extmark(buf, ns, i - 1, label_len + 2, {
            end_col = #line,
            hl_group = 'UdirInfoValue',
        })
    end
end

---@param path string
function M.open(path)
    local stat, msg = uv.fs_lstat(path)
    if not stat then
        util.err(msg or ('Could not stat ' .. path))
        return
    end

    local info_rows = rows(path, stat)
    local label_len = label_width(info_rows)
    local rendered_lines = lines(info_rows, label_len)
    local origin_win = api.nvim_get_current_win()
    local buf = api.nvim_create_buf(false, true)
    local ns = api.nvim_create_namespace('udir/info.' .. buf)

    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].modifiable = true
    render(buf, ns, info_rows, label_len)
    vim.bo[buf].modifiable = false

    local win = api.nvim_open_win(buf, true, float.centered_layout({
        title = 'Info',
        width = width(rendered_lines),
        height = #rendered_lines,
        border_hl = 'UdirPromptBorder',
    }))
    vim.wo[win].winhighlight = 'NormalFloat:Normal,FloatBorder:UdirPromptBorder'
    vim.wo[win].wrap = false

    local function close()
        float.close(buf, win)
        if api.nvim_win_is_valid(origin_win) then
            pcall(api.nvim_set_current_win, origin_win)
        end
    end
    for _, lhs in ipairs({'i', 'q', '<Esc>', '<C-c>', '<CR>'}) do
        vim.keymap.set('n', lhs, close, {buffer = buf, silent = true, nowait = true})
    end
end

return M
