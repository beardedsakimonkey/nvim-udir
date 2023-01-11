local fs = require'udir.fs'
local store = require'udir.store'
local util = require'udir.util'
local config = require'udir'.config

local api = vim.api
local uv = vim.loop

local M = {}

-- Render ----------------------------------------------------------------------

local function sort_by_name(files)
    table.sort(files, function(a, b)
        if (a.type == 'directory') == (b.type == 'directory') then
            return a.name < b.name
        else
            return a.type == 'directory'
        end
    end)
end

local function render(state)
    local cwd, buf, ns = state.cwd, state.buf, state.ns
    local all_files = fs.list(cwd)
    -- Get visible files
    local files = vim.tbl_filter(function(file)
        if config.show_hidden_files then
            return true
        else
            return not config.is_file_hidden(file, all_files, cwd)
        end
    end, all_files)
    local sort_fn = config.sort or sort_by_name
    sort_fn(files)
    util.set_lines(buf, vim.tbl_map(function(f)
        return f.name
    end, files))
    -- Add virttext and highlights
    api.nvim_buf_clear_namespace(0, ns, 0, -1)
    for i, file in ipairs(files) do
        local path = util.join_path(cwd, file.name)
        local virttext, hl
        if file.type == 'directory' then
            virttext, hl = util.sep, 'UdirDirectory'
        elseif file.type == 'link' then
            virttext = '@ → ' .. (uv.fs_readlink(path) or '???')
            hl = 'UdirSymlink'
        elseif uv.fs_access(path, 'X') then
            virttext, hl = '*', 'UdirExecutable'
        else
            virttext, hl = nil, 'UdirFile'
        end
        if virttext then
            api.nvim_buf_set_extmark(0, ns, i-1, #file.name, {
                virt_text = {{virttext, 'UdirVirtText'}},
                virt_text_pos = 'overlay',
            })
            api.nvim_buf_set_extmark(0, ns, i-1, 0, {
                end_col = #file.name,
                hl_group = hl,
            })
        end
    end
end

-- Keymaps ---------------------------------------------------------------------

local function setup_keymaps(buf)
    for lhs, rhs in pairs(config.keymaps) do
        vim.keymap.set('n', lhs, rhs, {nowait=true, silent=true, buffer=buf})
    end
end

local function cleanup(state)
    api.nvim_buf_delete(state.buf, {force=true})
    store.remove(state.buf)
end

function M.quit()
    local state = store.get()
    if state.alt_buf then
        util.set_current_buf(state.alt_buf)
    end
    util.set_current_buf(state.origin_buf)
    cleanup(state)
end

function M.up_dir()
    local state = store.get()
    local cwd = state.cwd
    local parent_dir = fs.get_parent_dir(state.cwd)
    local hovered_file = util.get_line()
    if hovered_file then
        state.hovered_files[state.cwd] = hovered_file
    end
    state.cwd = parent_dir
    render(state)
    util.update_buf_name(state.cwd)
    util.set_cursor_pos(fs.basename(cwd), --[[or_top]]true)
end

function M.open(cmd)
    local state = store.get()
    local filename = util.get_line()
    if filename == '' then
        return
    end
    -- fs_realpath also checks file existence
    local path, msg = uv.fs_realpath(util.join_path(state.cwd, filename))
    if not path then
        util.err(msg)
    else
        if fs.is_dir(path) then
            if cmd then
                vim.cmd(cmd .. ' ' .. vim.fn.fnameescape(path))
            else
                state.cwd = path
                render(state)
                util.update_buf_name(state.cwd)
                local hovered_file = state.hovered_files[path]
                util.set_cursor_pos(hovered_file, --[[or_top]]true)
            end
        else
            util.set_current_buf(state.origin_buf)  -- update the altfile
            vim.cmd((cmd or 'edit') .. ' ' .. vim.fn.fnameescape(path))
            cleanup(state)
        end
    end
end

function M.delete()
    local filename = util.get_line()
    if filename == '' then
        util.err'Empty filename'
        return
    end
    local state = store.get()
    local path = util.join_path(state.cwd, filename)
    print(string.format("Are you sure you want to delete %q? (y/n)", path))
    local input = vim.fn.getchar()
    local confirmed = vim.fn.nr2char(input) == 'y'
    util.clear_prompt()
    if confirmed then
        local ok, msg = pcall(fs.delete, path)
        if not ok then
            util.err(msg)
        else
            render(state)
        end
    end
end

local function copy_or_move(is_move)
    local filename = util.get_line()
    if filename == '' then
        util.err'Empty filename'
        return
    end
    local state = store.get()
    local prompt = is_move and 'Move to: ' or 'Copy to: '
    vim.ui.input({prompt=prompt, completion='file'}, function(input)
        util.clear_prompt()
        local src = util.join_path(state.cwd, filename)
        local ok, msg = pcall(fs.copy_or_move, is_move, src, input, state.cwd)
        if not ok then
            util.err(msg)
        else
            render(state)
            util.set_cursor_pos(fs.basename(input))
        end
    end)
end

function M.move() copy_or_move(true) end
function M.copy() copy_or_move(false) end

function M.create()
    local state = store.get()
    local path_saved = vim.opt_local.path
    vim.opt_local.path = state.cwd
    vim.ui.input(
        {prompt='New file: ', completion='file_in_path'},
        function(input)
            vim.opt_local.path = path_saved
            util.clear_prompt()
            if input then
                local path = util.join_path(state.cwd, input)
                local ok, msg
                if vim.endswith(input, util.sep) then
                    ok, msg = pcall(fs.create_dir, path)
                else
                    ok, msg = pcall(fs.create_file, path)
                end
                if not ok then
                    util.err(msg)
                else
                    render(state)
                    util.set_cursor_pos(fs.basename(path))
                end
            end
        end
    )
end

function M.toggle_hidden_files()
    local state = store.get()
    local hovered_file = util.get_line()
    config.show_hidden_files = not config.show_hidden_files
    render(state)
    util.set_cursor_pos(hovered_file)
end

function M.reload()
    render(store.get())
end

-- Initialization --------------------------------------------------------------

local function getcwd(dir)
    if dir ~= '' then return fs.realpath(vim.fn.expand(dir)) end
    local p = vim.fn.expand'%:p:h'
    if p ~= '' then return fs.realpath(p) end
    -- `expand('%')` can be empty if in an unnamed buffer, like `:enew`, so
    -- fallback to the cwd.
    return assert(uv.cwd())
end

function M.udir(dir, from_au)
    -- If we're executing from the BufEnter autocmd, the current buffer has
    -- already changed, so the origin_buf is actually the altbuf, and we don't
    -- know what the origin-buf's altbuf is.
    local has_altbuf = vim.fn.bufexists(0) ~= 0
    local origin_buf = (from_au and has_altbuf)
        and vim.fn.bufnr'#'
        or api.nvim_get_current_buf()
    local alt_buf = (not from_au and has_altbuf) and vim.fn.bufnr'#' or nil
    local cwd = getcwd(dir)
    local origin_filename = vim.fn.expand'%:p:t'
    origin_filename = origin_filename ~= '' and origin_filename or nil
    local buf = util.create_buf(cwd)
    local ns = api.nvim_create_namespace('udir.' .. buf)
    local state = {
        buf = buf,
        origin_buf = origin_buf,
        alt_buf = alt_buf,
        cwd = cwd,
        ns = ns,
        hovered_files = {},  -- map<realpath, filename>
    }
    setup_keymaps(buf)
    store.set(buf, state)
    render(state)
    util.set_cursor_pos(origin_filename)
end

return M
