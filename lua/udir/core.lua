local fs = require'udir.fs'
local help = require'udir.help'
local confirm = require'udir.confirm'
local info = require'udir.info'
local prompt = require'udir.prompt'
local store = require'udir.store'
local util = require'udir.util'
local config = require'udir'.config

local api = vim.api
local uv = vim.loop

local M = {}

local EMPTY_LABEL = '(empty)'

---@alias UdirCwdScope 'window'|'tab'|'global'

---@class UdirTreeRow
---@field name string
---@field display_name string
---@field path? string
---@field type UdirFileType|'placeholder'
---@field depth integer
---@field tree_prefix_len integer
---@field name_start_col? integer
---@field name_end_col? integer
---@field directory_suffix_col? integer

---@class UdirCwdRestore
---@field cwd string
---@field scope UdirCwdScope

---@class UdirState
---@field buf integer
---@field origin_buf integer
---@field alt_buf? integer
---@field cwd string
---@field sync_local_cwd boolean
---@field cwd_restore? UdirCwdRestore
---@field ns integer
---@field hovered_files table<string, string>
---@field expanded_dirs table<string, true>
---@field rows UdirTreeRow[]
---@field marks table<string, true>

-- Render ----------------------------------------------------------------------

---@param files UdirFile[]
local function sort_by_name(files)
    table.sort(files, function(a, b)
        if (a.type == 'directory') == (b.type == 'directory') then
            return a.name < b.name
        else
            return a.type == 'directory'
        end
    end)
end

---@param dir string
---@return UdirFile[]
local function visible_files(dir)
    local ok, all_files = pcall(fs.list, dir)
    if not ok then
        util.warn(tostring(all_files))
        return {}
    end
    local files = vim.tbl_filter(function(file)
        if config.show_hidden_files then
            return true
        else
            return not config.is_file_hidden(file, all_files, dir)
        end
    end, all_files)
    local sort_fn = config.sort or sort_by_name
    sort_fn(files)
    return files
end

---@param state UdirState
---@return UdirTreeRow[]
local function build_tree_rows(state)
    local rows = {}

    ---@param dir string
    ---@param prefix string
    ---@param depth integer
    local function add_dir(dir, prefix, depth)
        local files = visible_files(dir)
        if depth > 0 and #files == 0 then
            local tree_prefix = prefix .. '└── '
            rows[#rows+1] = {
                name = EMPTY_LABEL,
                display_name = tree_prefix .. EMPTY_LABEL,
                path = nil,
                type = 'placeholder',
                depth = depth,
                tree_prefix_len = #tree_prefix,
            }
            return
        end
        for i, file in ipairs(files) do
            local is_last = i == #files
            local connector = depth == 0 and '' or (is_last and '└── ' or '├── ')
            local child_prefix = depth == 0 and '' or prefix .. (is_last and '    ' or '│   ')
            local path = util.join_path(dir, file.name)
            local tree_prefix = prefix .. connector
            local display_name = tree_prefix .. file.name
            local directory_suffix_col
            if file.type == 'directory' then
                directory_suffix_col = #display_name
                display_name = display_name .. util.sep
            end
            rows[#rows+1] = {
                name = file.name,
                display_name = display_name,
                path = path,
                type = file.type,
                depth = depth,
                tree_prefix_len = #tree_prefix,
                name_start_col = #tree_prefix,
                name_end_col = #tree_prefix + #file.name,
                directory_suffix_col = directory_suffix_col,
            }
            if file.type == 'directory' and state.expanded_dirs[path] then
                add_dir(path, child_prefix, depth + 1)
            end
        end
    end

    add_dir(state.cwd, '', 0)
    return rows
end

---@param state UdirState
local function render(state)
    local buf, ns = state.buf, state.ns
    local rows = build_tree_rows(state)
    state.rows = rows
    util.set_lines(buf, vim.tbl_map(function(f)
        return f.display_name
    end, rows))
    -- Add virttext and highlights
    api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    for i, file in ipairs(rows) do
        local path = file.path
        local virttext, hl
        if file.type == 'directory' then
            virttext, hl = nil, 'UdirDirectory'
        elseif file.type == 'placeholder' then
            virttext, hl = nil, 'UdirTree'
        elseif file.type == 'link' then
            local link = uv.fs_readlink(path)
            virttext = '@ → ' .. (link and util.display_path(link) or '???')
            hl = 'UdirSymlink'
        elseif uv.fs_access(path, 'X') then
            virttext, hl = '*', 'UdirExecutable'
        else
            virttext, hl = nil, 'UdirFile'
        end
        api.nvim_buf_set_extmark(0, ns, i-1, 0, {
            end_col = #file.display_name,
            hl_group = hl,
        })
        if virttext then
            api.nvim_buf_set_extmark(0, ns, i-1, #file.display_name, {
                virt_text = {{virttext, 'UdirVirtText'}},
                virt_text_pos = 'overlay',
            })
        end
        if file.tree_prefix_len > 0 then
            api.nvim_buf_set_extmark(0, ns, i-1, 0, {
                end_col = file.tree_prefix_len,
                hl_group = 'UdirTree',
                priority = 10000,
            })
        end
        if file.directory_suffix_col then
            api.nvim_buf_set_extmark(0, ns, i-1, file.directory_suffix_col, {
                end_col = #file.display_name,
                hl_group = 'UdirVirtText',
                priority = 10000,
            })
        end
        if path and state.marks[path] then
            api.nvim_buf_set_extmark(buf, ns, i-1, 0, {
                sign_text = '▌',
                sign_hl_group = 'UdirMarkedSign',
            })
            api.nvim_buf_set_extmark(buf, ns, i-1, file.name_start_col, {
                end_col = file.name_end_col,
                hl_group = 'UdirMarkedFile',
                priority = 10000,
            })
        end
    end
end

---@param state UdirState
---@return UdirTreeRow?
local function current_row(state)
    local row = api.nvim_win_get_cursor(0)[1]
    return state.rows and state.rows[row] or nil
end

---@param state UdirState
---@param step integer
local function move_to_directory(state, step)
    local line = api.nvim_win_get_cursor(0)[1] + step
    while line >= 1 and line <= #state.rows do
        local row = state.rows[line]
        if row and row.type == 'directory' then
            api.nvim_win_set_cursor(0, {line, 0})
            return
        end
        line = line + step
    end
end

---@param state UdirState
---@return integer
local function count_marks(state)
    local count = 0
    for _ in pairs(state.marks) do
        count = count + 1
    end
    return count
end

---@param state UdirState
---@return string? path
---@return string? error
local function current_path(state)
    local row = current_row(state)
    if not row then
        return nil, 'Empty filename'
    end
    if not row.path then
        return nil, 'No file selected'
    end
    return row.path
end

---@param state UdirState
---@return string[]? paths
---@return boolean|string? is_bulk_or_error
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

---@param state UdirState
local function clear_marks(state)
    state.marks = {}
end

---@param state UdirState
---@param path string
---@return boolean changed
local function expand_next_level(state, path)
    if not state.expanded_dirs[path] then
        state.expanded_dirs[path] = true
        return true
    end

    local frontier = {}
    local frontier_depth

    ---@param dir string
    ---@param depth integer
    local function visit(dir, depth)
        for _, file in ipairs(visible_files(dir)) do
            if file.type == 'directory' then
                local child_path = util.join_path(dir, file.name)
                if state.expanded_dirs[child_path] then
                    visit(child_path, depth + 1)
                elseif not frontier_depth or depth < frontier_depth then
                    frontier_depth = depth
                    frontier = {child_path}
                elseif depth == frontier_depth then
                    frontier[#frontier+1] = child_path
                end
            end
        end
    end

    visit(path, 1)
    for _, dir in ipairs(frontier) do
        state.expanded_dirs[dir] = true
    end
    return #frontier > 0
end

---@param state UdirState
---@param path string
---@return boolean changed
local function expand_all_dirs(state, path)
    local changed = not state.expanded_dirs[path]
    state.expanded_dirs[path] = true
    for _, file in ipairs(visible_files(path)) do
        if file.type == 'directory' then
            local child_path = util.join_path(path, file.name)
            if expand_all_dirs(state, child_path) then
                changed = true
            end
        end
    end
    return changed
end

---@param state UdirState
---@param path string
---@return boolean changed
local function clear_expanded_subtree(state, path)
    local prefix = path .. util.sep
    local changed = false
    for expanded_path in pairs(state.expanded_dirs) do
        if expanded_path == path or vim.startswith(expanded_path, prefix) then
            state.expanded_dirs[expanded_path] = nil
            changed = true
        end
    end
    return changed
end

-- Keymaps ---------------------------------------------------------------------

---@param rhs UdirKeymapSpec
---@return UdirKeymapAction action
---@return string? desc
local function normalize_keymap(rhs)
    if type(rhs) == 'table' then
        assert(rhs[1], 'keymap table must include an action at index 1')
        return rhs[1], rhs.desc
    end
    return rhs, nil
end

---@param buf integer
local function setup_keymaps(buf)
    for lhs, rhs in pairs(config.keymaps) do
        local action, desc = normalize_keymap(rhs)
        vim.keymap.set('n', lhs, action, {nowait=true, silent=true, buffer=buf, desc=desc})
    end
    for lhs, rhs in pairs(config.visual_keymaps or {}) do
        local action, desc = normalize_keymap(rhs)
        vim.keymap.set('x', lhs, action, {nowait=true, silent=true, buffer=buf, desc=desc})
    end
end

---@param state UdirState
local function cleanup(state)
    api.nvim_buf_delete(state.buf, {force=true})
    store.remove(state.buf)
end

---@return UdirCwdScope
local function get_cwd_scope()
    if vim.fn.haslocaldir(0, 0) == 1 then
        return 'window'
    elseif vim.fn.haslocaldir(-1, 0) == 1 then
        return 'tab'
    else
        return 'global'
    end
end

---@return UdirCwdRestore
local function save_cwd()
    return {
        cwd = vim.fn.getcwd(0, 0),
        scope = get_cwd_scope(),
    }
end

---@param scope UdirCwdScope
---@return 'lcd'|'tcd'|'cd'
local function cd_cmd(scope)
    return ({
        window = 'lcd',
        tab = 'tcd',
        global = 'cd',
    })[scope]
end

---@param scope UdirCwdScope
---@param cwd string
local function set_cwd(scope, cwd)
    vim.cmd(('sil %s %s'):format(cd_cmd(scope), vim.fn.fnameescape(cwd)))
end

---@param state UdirState
local function sync_local_cwd(state)
    if state.sync_local_cwd then
        local ok, msg = pcall(set_cwd, 'window', state.cwd)
        if not ok then
            util.warn(msg)
        end
    end
end

---@param state UdirState
local function restore_cwd(state)
    if state.cwd_restore then
        local restore = assert(state.cwd_restore)
        local ok, msg = pcall(set_cwd, restore.scope, restore.cwd)
        state.cwd_restore = nil
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
    local row = current_row(state)
    if row then
        state.hovered_files[state.cwd] = row.name
    end
    state.cwd = parent_dir
    render(state)
    util.update_buf_name(state.cwd)
    sync_local_cwd(state)
    util.set_cursor_pos(fs.basename(cwd), --[[or_top]]true)
end

function M.next_directory()
    move_to_directory(store.get(), 1)
end

function M.prev_directory()
    move_to_directory(store.get(), -1)
end

function M.help()
    help.open(config)
end

function M.info()
    local state = store.get()
    local path, msg = current_path(state)
    if not path then
        util.err(msg)
        return
    end
    info.open(path)
end

---@param cmd? UdirOpenCommand
function M.open(cmd)
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path then
        return
    end
    -- fs_realpath also checks file existence
    local path, msg = uv.fs_realpath(row.path)
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

function M.open_external()
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path or not fs.exists(row.path) then
        return
    end
    pcall(vim.ui.open, row.path)
end

function M.expand()
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path or row.type ~= 'directory' then
        return
    end
    local changed = expand_next_level(state, row.path)
    if changed then
        render(state)
        util.set_cursor_pos(row.display_name)
    end
end

function M.expand_recursive()
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path or row.type ~= 'directory' then
        return
    end
    local changed = expand_all_dirs(state, row.path)
    if changed then
        render(state)
        util.set_cursor_pos(row.display_name)
    end
end

function M.collapse()
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path or row.type ~= 'directory' or not state.expanded_dirs[row.path] then
        return
    end
    state.expanded_dirs[row.path] = nil
    render(state)
    util.set_cursor_pos(row.display_name)
end

function M.collapse_reset()
    local state = store.get()
    local row = current_row(state)
    if not row or not row.path or row.type ~= 'directory' then
        return
    end
    local changed = clear_expanded_subtree(state, row.path)
    if changed then
        render(state)
        util.set_cursor_pos(row.display_name)
    end
end

function M.toggle_mark()
    local state = store.get()
    local row = current_row(state)
    if row and not row.path then
        return
    end
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

function M.toggle_mark_visual()
    local state = store.get()
    local mode = vim.fn.mode()
    local is_visual = mode == 'v' or mode == 'V' or mode == '\22'
    local start_line = is_visual and vim.fn.line('v') or vim.fn.line("'<")
    local end_line = is_visual and vim.fn.line('.') or vim.fn.line("'>")
    if start_line > end_line then
        start_line, end_line = end_line, start_line
    end
    for line = start_line, end_line do
        local row = state.rows and state.rows[line]
        if row and row.path then
            if state.marks[row.path] then
                state.marks[row.path] = nil
            else
                state.marks[row.path] = true
            end
        end
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
    confirm.delete(paths, state.cwd, function(confirmed)
        if not confirmed then
            return
        end
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
    end)
end

---@param is_move boolean
local function copy_or_move(is_move)
    local state = store.get()
    local paths, is_bulk = selected_paths(state)
    if not paths then
        util.err(is_bulk)
        return
    end
    local prompt_label = is_move and 'Move to' or 'Copy to'
    if is_bulk then
        local noun = #paths == 1 and 'file' or 'files'
        prompt_label = string.format('%s %d %s to', is_move and 'Move' or 'Copy', #paths, noun)
    end
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
    local row = current_row(state)
    local hovered_file = row and row.display_name or nil
    config.show_hidden_files = not config.show_hidden_files
    render(state)
    util.set_cursor_pos(hovered_file)
end

function M.reload()
    render(store.get())
end

-- Initialization --------------------------------------------------------------

---@param dir? string
---@return string
local function getcwd(dir)
    dir = dir or ''
    if dir ~= '' then return fs.realpath(vim.fn.expand(dir)) end
    local p = vim.fn.expand'%:p:h'
    if p ~= '' then return fs.realpath(p) end
    -- `expand('%')` can be empty if in an unnamed buffer, like `:enew`, so
    -- fallback to the cwd.
    return assert(uv.cwd())
end

---@param dir? string
---@param from_au? boolean
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
        expanded_dirs = {},  -- map<realpath, true>
        rows = {},
        marks = {},  -- map<path, true>
    }
    setup_keymaps(buf)
    store.set(buf, state)
    sync_local_cwd(state)
    render(state)
    util.set_cursor_pos(origin_filename)
end

return M
