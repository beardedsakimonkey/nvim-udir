local M = {}

local api = vim.api

local function find_index(list, fn)
    for idx, item in ipairs(list) do
        if fn(item) then
            return idx
        end
    end
end

-- Returns the first line number that matches the predicate, otherwise nil
local function find_line(fn)
    local lines = api.nvim_buf_get_lines(0, 0, -1, false)
    return find_index(lines, fn)
end

local function buf_has_var(buf, var_name)
    local ok, ret = pcall(api.nvim_buf_get_var, buf, var_name)
    return ok and ret or false
end

-- Problem: We'd like udir buffers to be completely unique (udir instances in
-- two different windows should be isolated), and also have a buffer name that
-- we can `:cd %` to.
--
-- If we use the absolute path as the buffer name, buffers won't be unique. That
-- is, if we have two windows opened to the same path, they will share the
-- same buffer, and so actions performed in one would affect the other.
--
-- One idea to work around this is to suffix buffer names that would otherwise
-- be unique with a number of repeated "/." in order to be unique. However,
-- vim's implementation of buffer renaming tries to fully resolve the name if
-- it's a path, so it will end up reusing the existing buffer.
--
-- However, vim doesn't perform this resolution if the buffer name is a URI,
-- such as "file:///Users/blah", so we could use the suffix trick with that.
-- But, alas, `:cd`ing to a URI isn't supported.
--
-- So, the best we can do is name a buffer by its path if it isn't currently
-- loaded, or otherwise name it by its path with an appended id, which makes it
-- unique but not `:cd`able.
local function create_buf_name(cwd)
    local loaded_bufs = {}
    for _, buf in ipairs(vim.fn.getbufinfo()) do
        -- Don't filter out hidden buffers; that leads to occasional errors.
        if buf.loaded == 1 then
            table.insert(loaded_bufs, buf.name)
        end
    end
    local new_name = cwd
    local i = 0
    while vim.tbl_contains(loaded_bufs, new_name) do
        i = i + 1
        new_name = cwd .. ' [' .. i .. ']'
    end
    return new_name
end

function M.create_buf(cwd)
    local existing_buf = vim.fn.bufnr('^' .. cwd .. '$')
    local buf
    if existing_buf ~= -1 then
        if buf_has_var(existing_buf, 'is_udir') then
            -- If buffer exists and it's a udir buffer, create a new buffer
            buf = api.nvim_create_buf(false, true)
            api.nvim_buf_set_name(buf, create_buf_name(cwd))
        else
            -- If buffer exists and it's not a udir buffer, reuse it. This can
            -- happen when launching nvim with a directory arg.
            buf = existing_buf
            -- Canonicalize the buffer name when launching nvim with a directory
            -- arg.
            if api.nvim_get_current_buf() == existing_buf then
                vim.cmd('sil file' .. vim.fn.fnameescape(cwd))
            end
        end
    else
        -- Buffer doesn't exist yet, so create it
        buf = api.nvim_create_buf(false, true)
        api.nvim_buf_set_name(buf, cwd)
    end
    assert(buf ~= 0)
    api.nvim_buf_set_var(buf, 'is_udir', true)
    -- Triggers BufEnter
    api.nvim_set_current_buf(buf)
    -- Triggers ftplugin, so must get called after setting the current buffer
    api.nvim_buf_set_option(buf, 'filetype', 'udir')
    return buf
end

function M.delete_buffers(name)
    for _, buf in pairs(vim.fn.getbufinfo()) do
        if buf.name == name then
            pcall(api.nvim_buf_delete, buf.bufnr, {})
        end
    end
end

function M.update_buf_name(cwd)
    local old_name = vim.fn.bufname
    local new_name = create_buf_name(cwd)
    vim.cmd('sil keepalt file ' .. vim.fn.fnameescape(new_name))
    -- Renaming a buffer creates a new buffer with the old name. Delete it.
    M.delete_buffers(old_name)
end

function M.set_current_buf(buf)
    if vim.fn.bufexists(buf) then
        vim.cmd('sil! keepj buffer' .. buf)
    end
end

function M.set_lines(buf, lines)
    vim.opt_local.modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.opt_local.modifiable = false
end

function M.get_line()
    local row = api.nvim_win_get_cursor(0)[1]
    return api.nvim_buf_get_lines(0, row-1, row, true)[1]
end

function M.rename_buffers(old_name, new_name)
    -- If we're clobbering an existing file for which we have a buffer, delete
    -- the buffer first
    if vim.fn.bufexists(new_name) then
        M.delete_buffers(new_name)
    end
    for _, buf in pairs(vim.fn.getbufinfo()) do
        if buf.name == old_name then
            api.nvim_buf_set_name(buf.bufnr, new_name)
            api.nvim_buf_call(buf.bufnr, function() vim.cmd 'sil! w!' end)
        end
    end
end

function M.clear_prompt()
    vim.cmd 'norm! :'
end

M.sep = package.config:sub(1, 1)

function M.join_path(fst, snd)
    return fst .. M.sep .. snd
end

function M.set_cursor_pos(filename, or_top)
    local line = or_top and 1 or nil
    if filename then
        local found = find_line(function(l) return l == filename end)
        if found then
            line = found
        end
    end
    if line then
        api.nvim_win_set_cursor(0, {line, 0})
    end
end

function M.err(msg)  vim.notify('[udir] ' .. msg, vim.log.levels.ERROR) end
function M.warn(msg) vim.notify('[udir] ' .. msg, vim.log.levels.WARN) end

function M.trim_start(str)
    return (str:gsub('^%s*', ''))
end

return M
