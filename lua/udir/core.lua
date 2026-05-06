local fs = require'udir.fs'
local prompt = require'udir.prompt'
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
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
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
        if state.marks[path] then
            api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
                virt_text = {{'> ', 'UdirMarkedText'}},
                virt_text_pos = 'inline',
            })
        end
    end
end

local function count_marks(state)
    local count = 0
    for _ in pairs(state.marks) do
        count = count + 1
    end
    return count
end

local function current_path(state)
    local filename = util.get_line()
    if filename == '' then
        return nil, 'Empty filename'
    end
    return util.join_path(state.cwd, filename)
end

local function selected_paths(state)
    if count_marks(state) == 0 then
        local path, msg = current_path(state)
        if not path then
            return nil, msg
        end
        return {path}, false
    end
    local paths = {}
    for path in pairs(state.marks) do
        paths[#paths+1] = path
    end
    table.sort(paths)
    return paths, true
end

local function clear_marks(state)
    state.marks = {}
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

local function get_cwd_scope()
    if vim.fn.haslocaldir(0, 0) == 1 then
        return 'window'
    elseif vim.fn.haslocaldir(-1, 0) == 1 then
        return 'tab'
    else
        return 'global'
    end
end

local function save_cwd()
    return {
        cwd = vim.fn.getcwd(0, 0),
        scope = get_cwd_scope(),
    }
end

local function cd_cmd(scope)
    return ({
        window = 'lcd',
        tab = 'tcd',
        global = 'cd',
    })[scope]
end

local function set_cwd(scope, cwd)
    vim.cmd(('sil %s %s'):format(cd_cmd(scope), vim.fn.fnameescape(cwd)))
end

local function sync_local_cwd(state)
    if state.sync_local_cwd then
        local ok, msg = pcall(set_cwd, 'window', state.cwd)
        if not ok then
            util.warn(msg)
        end
    end
end

local function restore_cwd(state)
    if state.cwd_restore then
        local restore = state.cwd_restore
        state.cwd_restore = nil
        local ok, msg = pcall(set_cwd, restore.scope, restore.cwd)
        if not ok then
            util.warn(msg)
        end
    end
end

function M.quit()
    local state = store.get()
    restore_cwd(state)
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
    sync_local_cwd(state)
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
                sync_local_cwd(state)
                local hovered_file = state.hovered_files[path]
                util.set_cursor_pos(hovered_file, --[[or_top]]true)
            end
        else
            restore_cwd(state)
            util.set_current_buf(state.origin_buf)  -- update the altfile
            vim.cmd((cmd or 'edit') .. ' ' .. vim.fn.fnameescape(path))
            cleanup(state)
        end
    end
end

function M.toggle_mark()
    local state = store.get()
    local path, msg = current_path(state)
    if not path then
        util.err(msg)
        return
    end
    if state.marks[path] then
        state.marks[path] = nil
    else
        state.marks[path] = true
    end
    render(state)
end

function M.delete()
    local state = store.get()
    local paths, is_bulk = selected_paths(state)
    if not paths then
        util.err(is_bulk)
        return
    end
    local message = is_bulk
        and string.format('Are you sure you want to delete %d marked files? (y/n)', #paths)
        or string.format('Are you sure you want to delete %q? (y/n)', paths[1])
    print(message)
    local input = vim.fn.getchar()
    local confirmed = vim.fn.nr2char(input) == 'y'
    util.clear_prompt()
    if confirmed then
        local ok, msg = pcall(function()
            for _, path in ipairs(paths) do
                fs.delete(path)
            end
        end)
        if not ok then
            util.err(msg)
        else
            if is_bulk then
                clear_marks(state)
            end
            render(state)
        end
    end
end

local function copy_or_move(is_move)
    local state = store.get()
    local paths, is_bulk = selected_paths(state)
    if not paths then
        util.err(is_bulk)
        return
    end
    local prompt_label = is_move and 'Move to' or 'Copy to'
    prompt.input({
        prompt = prompt_label,
        cwd = state.cwd,
        validate = function(input)
            if is_bulk then
                local dest = fs.normalize_path(input, state.cwd)
                assert(fs.is_dir(dest), 'Bulk destination must be an existing directory')
                for _, src in ipairs(paths) do
                    fs.resolve_copy_or_move_dest(is_move, src, dest, state.cwd)
                end
                return dest
            end
            return fs.resolve_copy_or_move_dest(is_move, paths[1], input, state.cwd)
        end,
    }, function(input, dest)
        if not input then
            return
        end
        local ok, msg = pcall(function()
            for _, src in ipairs(paths) do
                fs.copy_or_move(is_move, src, is_bulk and dest or input, state.cwd)
            end
        end)
        if not ok then
            util.err(msg)
        else
            if is_bulk then
                clear_marks(state)
            end
            render(state)
            util.set_cursor_pos(fs.basename(dest))
        end
    end)
end

function M.move() copy_or_move(true) end
function M.copy() copy_or_move(false) end

function M.create()
    local state = store.get()
    prompt.input({
        prompt = 'New file',
        cwd = state.cwd,
        validate = function(input)
            return fs.validate_create(input, state.cwd)
        end,
    }, function(input, path)
        if input then
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
    end)
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
    local sync = config.sync_local_cwd
    local cwd_restore = sync and save_cwd() or nil
    local buf = util.create_buf(cwd)
    local ns = api.nvim_create_namespace('udir.' .. buf)
    local state = {
        buf = buf,
        origin_buf = origin_buf,
        alt_buf = alt_buf,
        cwd = cwd,
        sync_local_cwd = sync,
        cwd_restore = cwd_restore,
        ns = ns,
        hovered_files = {},  -- map<realpath, filename>
        marks = {},  -- map<path, true>
    }
    setup_keymaps(buf)
    store.set(buf, state)
    sync_local_cwd(state)
    render(state)
    util.set_cursor_pos(origin_filename)
end

return M
