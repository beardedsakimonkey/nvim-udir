local api = vim.api

local function assert_eq(actual, expected, msg)
    assert(actual == expected, msg or ('expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual)))
end

local function assert_match(str, pattern, msg)
    assert(str:match(pattern), msg or (vim.inspect(str) .. ' does not match ' .. vim.inspect(pattern)))
end

local fs = require'udir.fs'
local prompt = require'udir.prompt'
local core = require'udir.core'
local store = require'udir.store'
local util = require'udir.util'

local cwd = assert(vim.loop.cwd())

local function touch(path)
    local fd = assert(vim.loop.fs_open(path, 'w', tonumber('644', 8)))
    assert(vim.loop.fs_close(fd))
end

local function mark_count(state)
    local count = 0
    for _ in pairs(state.marks) do
        count = count + 1
    end
    return count
end

local function lines()
    return api.nvim_buf_get_lines(0, 0, -1, false)
end

local function set_cursor_line(pattern)
    for i, line in ipairs(lines()) do
        if line:match(pattern) then
            api.nvim_win_set_cursor(0, {i, 0})
            return
        end
    end
    error('could not find line matching ' .. pattern)
end

local function has_highlight(state, hl_group)
    local marks = api.nvim_buf_get_extmarks(state.buf, state.ns, 0, -1, {details = true})
    for _, mark in ipairs(marks) do
        if mark[4].hl_group == hl_group then
            return true
        end
    end
    return false
end

local function has_high_priority_highlight(state, hl_group)
    local marks = api.nvim_buf_get_extmarks(state.buf, state.ns, 0, -1, {details = true})
    for _, mark in ipairs(marks) do
        if mark[4].hl_group == hl_group and mark[4].priority == 10000 then
            return true
        end
    end
    return false
end

do
    local p = prompt.input({
        prompt = 'Smoke',
        cwd = cwd,
        validate = function(input)
            assert(input ~= 'bad')
            return input .. '-ok'
        end,
    }, function(input, result)
        vim.g.udir_smoke_input = input or 'nil'
        vim.g.udir_smoke_result = result or 'nil'
    end)

    local cfg = api.nvim_win_get_config(p.input_win)
    assert_eq(cfg.relative, 'editor')
    assert_eq(cfg.anchor, 'NW')
    assert_eq(cfg.border[1][1], '╭')
    assert(not p.list_win, 'prompt should not create a completion window')
    assert_eq(type(vim.fn.maparg('<Esc>', 'i', false, true).callback), 'function')
    assert_eq(type(vim.fn.maparg('<Esc>', 'n', false, true).callback), 'function')

    p:set_input('bad', 3)
    p:redraw()
    assert_eq(p.is_valid, false)

    p:set_input('u', 1)
    p:redraw()
    assert_eq(p.completion.word, 'UNLICENSE')
    assert_eq(p.completion.suffix, 'NLICENSE')
    p:accept_completion()
    assert_eq(p:get_input(), 'UNLICENSE')

    p:set_input('lua/u', 5)
    p:redraw()
    assert_eq(p.completion.word, 'lua/udir/')
    assert_eq(p.completion.suffix, 'dir/')
    p:accept_completion()
    assert_eq(p:get_input(), 'lua/udir/')

    p:set_input('abc', 3)
    p:confirm()
    assert_eq(vim.g.udir_smoke_input, 'abc')
    assert_eq(vim.g.udir_smoke_result, 'abc-ok')
end

do
    local p = prompt.input({
        prompt = 'Escape non-empty',
        cwd = cwd,
        validate = function(input)
            return input
        end,
    }, function(input)
        vim.g.udir_smoke_escape_non_empty = input == nil
    end)

    p:set_input('abc', 3)
    p:escape_insert()
    assert(not p.closed, 'escape with input should leave prompt open')
    p:cancel()
    assert_eq(vim.g.udir_smoke_escape_non_empty, true)
end

do
    local p = prompt.input({
        prompt = 'Escape empty',
        cwd = cwd,
        validate = function(input)
            return input
        end,
    }, function(input)
        vim.g.udir_smoke_escape_empty = input == nil
    end)

    p:set_input('', 0)
    p:escape_insert()
    assert(p.closed, 'escape with empty input should close prompt')
    assert_eq(vim.g.udir_smoke_escape_empty, true)
end

do
    local p = prompt.input({
        prompt = 'Cancel',
        cwd = cwd,
        validate = function(input)
            return input
        end,
    }, function(input)
        vim.g.udir_smoke_cancelled = input == nil
    end)

    p:cancel()
    assert_eq(vim.g.udir_smoke_cancelled, true)
end

assert_match(fs.validate_create('x-new-file', cwd), 'x%-new%-file$')
assert_match(fs.validate_create('x-new-dir/', cwd), 'x%-new%-dir/$')
assert(not pcall(fs.validate_create, '/tmp/x', cwd), 'create paths should stay relative')
assert_match(fs.resolve_copy_or_move_dest(false, cwd, '/tmp', cwd), '/tmp/[^/]+$')

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/dest', tonumber('755', 8)))
    touch(tmp .. '/a')
    touch(tmp .. '/b')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    util.set_cursor_pos('a')
    core.toggle_mark()
    util.set_cursor_pos('b')
    core.toggle_mark()
    assert_eq(mark_count(state), 2)
    assert(state.marks[state.cwd .. '/a'], 'a should be marked')
    assert(state.marks[state.cwd .. '/b'], 'b should be marked')
    local marks = api.nvim_buf_get_extmarks(state.buf, state.ns, 0, -1, {details = true})
    local has_prefix = false
    for _, mark in ipairs(marks) do
        local details = mark[4]
        if details.virt_text and details.virt_text[1] and details.virt_text[1][1] == '> ' then
            has_prefix = true
            break
        end
    end
    assert(has_prefix, 'marked rows should render a visible prefix')

    local old_input = prompt.input
    prompt.input = function(opts, cb)
        local dest = opts.validate('dest')
        cb('dest', dest)
    end
    core.copy()
    prompt.input = old_input

    assert(fs.exists(tmp .. '/dest/a'), 'bulk copy should copy a')
    assert(fs.exists(tmp .. '/dest/b'), 'bulk copy should copy b')
    assert_eq(mark_count(state), 0)

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    touch(tmp .. '/a')
    touch(tmp .. '/b')
    touch(tmp .. '/c')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    vim.fn.setpos("'<", {0, 1, 1, 0})
    vim.fn.setpos("'>", {0, 2, 1, 0})
    core.toggle_mark_visual()
    assert_eq(mark_count(state), 2)
    assert(state.marks[state.cwd .. '/a'], 'visual toggle should mark first selected row')
    assert(state.marks[state.cwd .. '/b'], 'visual toggle should mark second selected row')
    assert(not state.marks[state.cwd .. '/c'], 'visual toggle should not mark unselected rows')

    vim.fn.setpos("'<", {0, 2, 1, 0})
    vim.fn.setpos("'>", {0, 1, 1, 0})
    core.toggle_mark_visual()
    assert_eq(mark_count(state), 0, 'visual toggle should handle reversed ranges')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    touch(tmp .. '/a')
    touch(tmp .. '/b')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    vim.fn.setpos("'<", {0, 1, 1, 0})
    vim.fn.setpos("'>", {0, 1, 1, 0})
    api.nvim_win_set_cursor(0, {2, 0})
    api.nvim_feedkeys(api.nvim_replace_termcodes('V<Tab>', true, false, true), 'xt', false)
    assert_eq(mark_count(state), 1)
    assert(not state.marks[state.cwd .. '/a'], 'live visual toggle should not use stale visual marks')
    assert(state.marks[state.cwd .. '/b'], 'live visual toggle should mark the selected cursor line')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/alpha', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/alpha/one', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/alpha/two', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/beta', tonumber('755', 8)))
    touch(tmp .. '/alpha/one/file.txt')
    touch(tmp .. '/root.txt')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()
    local root = state.cwd

    util.set_cursor_pos('alpha')
    core.expand()
    assert(vim.tbl_contains(lines(), '├── one/'), 'first expand should show alpha children')
    assert(vim.tbl_contains(lines(), '└── two/'), 'first expand should show all alpha children')
    assert(not vim.tbl_contains(lines(), '│   └── file.txt'), 'first expand should not expand grandchildren')
    assert(has_highlight(state, 'UdirDirectory'), 'directory rows should be highlighted')
    assert(has_high_priority_highlight(state, 'UdirTree'), 'tree prefixes should be highlighted')
    assert(has_high_priority_highlight(state, 'UdirVirtText'), 'directory suffixes should be highlighted')

    core.expand()
    assert(vim.tbl_contains(lines(), '│   └── file.txt'), 'second expand should expand another level')

    set_cursor_line('file%.txt$')
    core.toggle_mark()
    assert(state.marks[root .. '/alpha/one/file.txt'], 'nested row should mark its real path')

    util.set_cursor_pos('alpha')
    core.collapse()
    assert(not vim.tbl_contains(lines(), '├── one/'), 'collapse should hide children')
    assert(state.expanded_dirs[root .. '/alpha/one'], 'collapse should remember descendant state')

    core.expand()
    assert(vim.tbl_contains(lines(), '│   └── file.txt'), 're-expand should restore previous tree state')

    set_cursor_line('one/$')
    core.collapse()
    assert(not vim.tbl_contains(lines(), '│   └── file.txt'), 'collapsing child should hide child contents')
    assert(state.expanded_dirs[root .. '/alpha'], 'collapsing child should leave parent expanded')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/empty', tonumber('755', 8)))

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    util.set_cursor_pos('empty')
    core.expand()
    assert(vim.tbl_contains(lines(), '└── (empty)'), 'empty directories should render a placeholder')
    assert(has_highlight(state, 'UdirTree'), 'empty placeholder should be highlighted as tree text')

    set_cursor_line('%(empty%)$')
    core.toggle_mark()
    assert_eq(mark_count(state), 0, 'empty placeholder should not be markable')

    util.set_cursor_pos('empty')
    core.collapse()
    assert(not vim.tbl_contains(lines(), '└── (empty)'), 'collapsing empty directory should hide placeholder')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/unreadable', tonumber('755', 8)))

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local old_list = fs.list
    fs.list = function(path)
        if path:match('/unreadable$') then
            error('permission denied')
        end
        return old_list(path)
    end

    util.set_cursor_pos('unreadable')
    local ok, msg = pcall(core.expand)
    fs.list = old_list
    assert(ok, msg)

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

vim.cmd('Udir ' .. vim.fn.fnameescape(cwd))
local state = store.get()
assert_eq(state.cwd, fs.realpath(cwd))
assert(api.nvim_buf_get_var(0, 'is_udir'), 'Udir buffer should be marked')
assert(#api.nvim_buf_get_lines(0, 0, -1, false) > 0, 'Udir buffer should render entries')
core.quit()

print('[udir] smoke ok')
