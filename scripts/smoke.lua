local api = vim.api

local function assert_eq(actual, expected, msg)
    assert(actual == expected, msg or ('expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual)))
end

local function assert_match(str, pattern, msg)
    assert(str:match(pattern), msg or (vim.inspect(str) .. ' does not match ' .. vim.inspect(pattern)))
end

local fs = require'udir.fs'
local config = require'udir'.config
local confirm = require'udir.confirm'
local prompt = require'udir.prompt'
local core = require'udir.core'
local store = require'udir.store'
local util = require'udir.util'

local cwd = assert(vim.loop.cwd())

local function touch(path)
    local fd = assert(vim.loop.fs_open(path, 'w', tonumber('644', 8)))
    assert(vim.loop.fs_close(fd))
end

local function write_file(path, contents)
    local fd = assert(vim.loop.fs_open(path, 'w', tonumber('644', 8)))
    assert(vim.loop.fs_write(fd, contents, 0))
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

local function current_line()
    return api.nvim_get_current_line()
end

local function win_title(win)
    local title = api.nvim_win_get_config(win).title
    if type(title) == 'string' then
        return title
    end
    if type(title) == 'table' then
        local chunks = {}
        for _, chunk in ipairs(title) do
            chunks[#chunks+1] = type(chunk) == 'table' and chunk[1] or tostring(chunk)
        end
        return table.concat(chunks)
    end
    return ''
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
    local origin_win = api.nvim_get_current_win()
    local old_guicursor = vim.o.guicursor
    local tmp = vim.fn.tempname()
    local paths = {tmp .. '/foo.js', tmp .. '/dir/bar.lua'}
    for i = 3, 12 do
        paths[#paths+1] = tmp .. '/dir/file-' .. i .. '.txt'
    end

    confirm.delete(paths, tmp, function(confirmed)
        vim.g.udir_smoke_confirm_delete = confirmed
    end)
    local confirm_win = api.nvim_get_current_win()
    local confirm_buf = api.nvim_get_current_buf()
    local confirm_cfg = api.nvim_win_get_config(confirm_win)
    local confirm_lines = api.nvim_buf_get_lines(confirm_buf, 0, -1, false)

    assert_eq(confirm_cfg.border[1][2], 'UdirPromptBorderInvalid')
    assert_match(vim.wo[confirm_win].winhighlight, 'Cursor:UdirDeleteCursor')
    assert_eq(vim.o.guicursor, 'a:block-UdirDeleteCursor')
    assert_match(win_title(confirm_win), 'Delete 12 files%? %(y/n%)')
    assert_eq(#confirm_lines, 11, 'delete confirmation should cap visible files')
    assert_eq(confirm_lines[1], '  ./foo.js')
    assert_eq(confirm_lines[2], '  ./dir/bar.lua')
    assert_eq(confirm_lines[11], '  ... and 2 more')

    local marks = api.nvim_buf_get_extmarks(confirm_buf, -1, 0, -1, {details=true})
    local has_path, has_file, has_more = false, false, false
    for _, mark in ipairs(marks) do
        local row, col, details = mark[2], mark[3], mark[4]
        has_path = has_path
            or row == 0 and col == 2 and details.end_col == 4 and details.hl_group == 'UdirDeletePath'
        has_file = has_file
            or row == 0 and col == 4 and details.end_col == 10 and details.hl_group == 'UdirDeleteFile'
        has_more = has_more
            or row == 10 and details.hl_group == 'UdirDeleteMore'
    end
    assert(has_path, 'delete confirmation should dim the path portion')
    assert(has_file, 'delete confirmation should highlight the file name')
    assert(has_more, 'delete confirmation should highlight the overflow row')

    api.nvim_feedkeys('n', 'xt', false)
    assert_eq(vim.g.udir_smoke_confirm_delete, false)
    assert_eq(api.nvim_get_current_win(), origin_win)
    assert_eq(vim.o.guicursor, old_guicursor)
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
    ---@cast p UdirPrompt

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
    assert(p.completion)
    assert_eq(p.completion.word, 'UNLICENSE')
    assert_eq(p.completion.suffix, 'NLICENSE')
    p:accept_completion()
    assert_eq(p:get_input(), 'UNLICENSE')

    p:set_input('lua/u', 5)
    p:redraw()
    assert(p.completion)
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
    ---@cast p UdirPrompt

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
    ---@cast p UdirPrompt

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
    ---@cast p UdirPrompt

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
    assert(vim.loop.fs_mkdir(tmp .. '/dir', tonumber('755', 8)))
    touch(tmp .. '/a')
    touch(tmp .. '/dir/nested.js')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    util.set_cursor_pos('a')
    core.toggle_mark()
    util.set_cursor_pos('dir')
    core.expand()
    set_cursor_line('nested%.js$')
    core.toggle_mark()
    core.delete()

    local confirm_win = api.nvim_get_current_win()
    local confirm_buf = api.nvim_get_current_buf()
    local confirm_lines = table.concat(api.nvim_buf_get_lines(confirm_buf, 0, -1, false), '\n')
    assert_match(win_title(confirm_win), 'Delete 2 files%? %(y/n%)')
    assert_match(confirm_lines, '%./a')
    assert_match(confirm_lines, '%./dir/nested%.js')

    api.nvim_feedkeys('y', 'xt', false)
    assert(not api.nvim_win_is_valid(confirm_win), 'confirming delete should close the confirmation window')
    assert(not fs.exists(tmp .. '/a'), 'confirmed delete should remove top-level file')
    assert(not fs.exists(tmp .. '/dir/nested.js'), 'confirmed delete should remove nested marked file')
    assert_eq(mark_count(state), 0)

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

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
    local has_sign, has_file_hl = false, false
    for _, mark in ipairs(marks) do
        local details = mark[4]
        has_sign = has_sign
            or details.sign_text and vim.startswith(details.sign_text, '▌') and details.sign_hl_group == 'UdirMarkedSign'
        has_file_hl = has_file_hl or details.hl_group == 'UdirMarkedFile'
    end
    assert(has_sign, 'marked rows should render a sign marker')
    assert(has_file_hl, 'marked rows should highlight filenames')

    local old_input = prompt.input
    ---@diagnostic disable-next-line: duplicate-set-field
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
    local home = assert(os.getenv'HOME')
    assert(vim.loop.fs_symlink(home, tmp .. '/home-link'))

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()
    local marks = api.nvim_buf_get_extmarks(state.buf, state.ns, 0, -1, {details = true})
    local has_home_link = false
    for _, mark in ipairs(marks) do
        local virt_text = mark[4].virt_text
        has_home_link = has_home_link
            or virt_text and virt_text[1] and virt_text[1][1] == '@ → ~'
    end
    assert(has_home_link, 'symlink virtual text should abbreviate home directory')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    vim.cmd('Udir ' .. vim.fn.fnameescape(cwd))
    assert_eq(vim.fn.maparg('q', 'n', false, true).desc, 'Quit')
    assert_eq(vim.fn.maparg('i', 'n', false, true).desc, 'Show info')
    assert_eq(vim.fn.maparg('H', 'n', false, true).desc, 'Show help')
    assert_eq(vim.fn.maparg('<Tab>', 'x', false, true).desc, 'Toggle marks')
    core.quit()
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    write_file(tmp .. '/alpha.txt', 'hello')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local origin_win = api.nvim_get_current_win()
    core.info()
    local info_win = api.nvim_get_current_win()
    local info_buf = api.nvim_get_current_buf()
    local info_cfg = api.nvim_win_get_config(info_win)
    local info_lines = api.nvim_buf_get_lines(info_buf, 0, -1, false)
    local info_text = table.concat(info_lines, '\n')

    assert(info_win ~= origin_win, 'info should open in a floating window')
    assert_eq(info_cfg.border[1][2], 'UdirPromptBorder')
    assert_match(win_title(info_win), 'Info')
    assert_match(info_text, 'Name%s+alpha%.txt')
    assert_match(info_text, 'Type%s+File')
    assert_match(info_text, 'Size%s+5 B')
    assert_match(info_text, 'Permissions%s+rw%-r%-%-r%-%-')
    assert(info_text:find(tmp .. '/alpha.txt', 1, true), 'info should show the selected path')

    local marks = api.nvim_buf_get_extmarks(info_buf, -1, 0, -1, {details=true})
    local has_label, has_value = false, false
    for _, mark in ipairs(marks) do
        local hl = mark[4].hl_group
        has_label = has_label or hl == 'UdirInfoLabel'
        has_value = has_value or hl == 'UdirInfoValue'
    end
    assert(has_label, 'info should highlight labels')
    assert(has_value, 'info should highlight values')

    api.nvim_feedkeys('q', 'xt', false)
    assert_eq(api.nvim_get_current_win(), origin_win, 'closing info should restore origin window')
    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    vim.cmd('Udir ' .. vim.fn.fnameescape(cwd))
    local origin_win = api.nvim_get_current_win()
    core.help()
    local help_win = api.nvim_get_current_win()
    local help_buf = api.nvim_get_current_buf()
    assert(help_win ~= origin_win, 'help should open in a floating window')
    local help_lines = api.nvim_buf_get_lines(help_buf, 0, -1, false)
    local help_cfg = api.nvim_win_get_config(help_win)
    assert_eq(help_cfg.height, math.min(#help_lines, math.max(1, vim.o.lines - 4)))
    assert(vim.tbl_contains(help_lines, 'Normal'), 'help should show normal mappings')
    assert(vim.tbl_contains(help_lines, 'Visual'), 'help should show visual mappings')
    assert(table.concat(help_lines, '\n'):match('H%s+Show help'), 'help should include described mappings')
    assert(table.concat(help_lines, '\n'):match('i%s+Show info'), 'help should include the info mapping')

    local marks = api.nvim_buf_get_extmarks(help_buf, -1, 0, -1, {details=true})
    local has_header, has_key, has_desc = false, false, false
    for _, mark in ipairs(marks) do
        local hl = mark[4].hl_group
        has_header = has_header or hl == 'UdirHelpHeader'
        has_key = has_key or hl == 'UdirHelpKey'
        has_desc = has_desc or hl == 'UdirHelpDesc'
    end
    assert(has_header, 'help should highlight section headers')
    assert(has_key, 'help should highlight keys')
    assert(has_desc, 'help should highlight descriptions')

    api.nvim_feedkeys('q', 'xt', false)
    assert_eq(api.nvim_get_current_win(), origin_win, 'closing help should restore origin window')
    core.quit()
end

do
    local old_keymaps = config.keymaps
    local old_visual_keymaps = config.visual_keymaps
    config.keymaps = {
        x = "<Cmd>lua vim.g.udir_smoke_legacy_keymap = 'normal'<CR>",
    }
    config.visual_keymaps = {
        y = "<Cmd>lua vim.g.udir_smoke_legacy_keymap = 'visual'<CR>",
    }

    vim.cmd('Udir ' .. vim.fn.fnameescape(cwd))
    assert_eq(vim.fn.maparg('x', 'n', false, true).rhs, "<Cmd>lua vim.g.udir_smoke_legacy_keymap = 'normal'<CR>")
    assert_eq(vim.fn.maparg('y', 'x', false, true).rhs, "<Cmd>lua vim.g.udir_smoke_legacy_keymap = 'visual'<CR>")
    core.help()
    local help_lines = table.concat(api.nvim_buf_get_lines(0, 0, -1, false), '\n')
    assert(help_lines:match("x%s+<Cmd>lua vim%.g%.udir_smoke_legacy_keymap = 'normal'<CR>"), 'help should include legacy normal mappings')
    assert(help_lines:match("y%s+<Cmd>lua vim%.g%.udir_smoke_legacy_keymap = 'visual'<CR>"), 'help should include legacy visual mappings')
    api.nvim_feedkeys('q', 'xt', false)
    core.quit()

    config.keymaps = old_keymaps
    config.visual_keymaps = old_visual_keymaps
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/alpha', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/alpha/nested', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/beta', tonumber('755', 8)))
    touch(tmp .. '/alpha/file.txt')
    touch(tmp .. '/top.txt')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()

    util.set_cursor_pos('alpha')
    core.expand()
    set_cursor_line('top%.txt$')
    core.prev_directory()
    assert_eq(current_line(), 'beta/', 'K should jump to previous visible directory')
    core.prev_directory()
    assert_eq(current_line(), '├── nested/', 'K should skip files')
    core.prev_directory()
    assert_eq(current_line(), 'alpha/', 'K should keep moving to previous directories')
    core.next_directory()
    assert_eq(current_line(), '├── nested/', 'J should jump to next visible directory')
    core.next_directory()
    assert_eq(current_line(), 'beta/', 'J should skip nested files')
    core.next_directory()
    assert_eq(current_line(), 'beta/', 'J should stop when no next directory exists')

    set_cursor_line('file%.txt$')
    core.next_directory()
    assert_eq(current_line(), 'beta/', 'J should work from file rows')

    core.quit()
    assert_eq(vim.fn.delete(tmp, 'rf'), 0)
end

do
    local tmp = vim.fn.tempname()
    assert(vim.loop.fs_mkdir(tmp, tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/root', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/root/a', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/root/a/b', tonumber('755', 8)))
    assert(vim.loop.fs_mkdir(tmp .. '/root/empty', tonumber('755', 8)))
    touch(tmp .. '/root/a/b/file.txt')

    vim.cmd('Udir ' .. vim.fn.fnameescape(tmp))
    local state = store.get()
    local root = state.cwd

    util.set_cursor_pos('root')
    core.expand_recursive()
    assert(vim.tbl_contains(lines(), '├── a/'), 'recursive expand should show child directories')
    assert(vim.tbl_contains(lines(), '│   └── b/'), 'recursive expand should show nested directories')
    assert(vim.tbl_contains(lines(), '│       └── file.txt'), 'recursive expand should show nested files')
    assert(vim.tbl_contains(lines(), '└── empty/'), 'recursive expand should show empty child directories')
    assert(vim.tbl_contains(lines(), '    └── (empty)'), 'recursive expand should show empty placeholders')
    assert(state.expanded_dirs[root .. '/root'], 'recursive expand should expand selected directory')
    assert(state.expanded_dirs[root .. '/root/a'], 'recursive expand should expand descendants')
    assert(state.expanded_dirs[root .. '/root/a/b'], 'recursive expand should expand nested descendants')
    assert(state.expanded_dirs[root .. '/root/empty'], 'recursive expand should expand empty descendants')

    util.set_cursor_pos('root')
    core.collapse_reset()
    assert(not state.expanded_dirs[root .. '/root'], 'reset collapse should clear selected directory')
    assert(not state.expanded_dirs[root .. '/root/a'], 'reset collapse should clear descendants')
    assert(not state.expanded_dirs[root .. '/root/a/b'], 'reset collapse should clear nested descendants')
    assert(not state.expanded_dirs[root .. '/root/empty'], 'reset collapse should clear empty descendants')
    assert(not vim.tbl_contains(lines(), '├── a/'), 'reset collapse should hide children')

    core.expand()
    assert(vim.tbl_contains(lines(), '├── a/'), 'expand after reset should show one level')
    assert(not vim.tbl_contains(lines(), '│   └── b/'), 'expand after reset should not restore recursive state')

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
    ---@diagnostic disable-next-line: duplicate-set-field
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
