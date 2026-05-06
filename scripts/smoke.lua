local api = vim.api

local function assert_eq(actual, expected, msg)
    assert(actual == expected, msg or ('expected ' .. vim.inspect(expected) .. ', got ' .. vim.inspect(actual)))
end

local function assert_match(str, pattern, msg)
    assert(str:match(pattern), msg or (vim.inspect(str) .. ' does not match ' .. vim.inspect(pattern)))
end

require'udir.core'
local fs = require'udir.fs'
local prompt = require'udir.prompt'

local cwd = assert(vim.loop.cwd())

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

vim.cmd('Udir ' .. vim.fn.fnameescape(cwd))
local state = require'udir.store'.get()
assert_eq(state.cwd, fs.realpath(cwd))
assert(api.nvim_buf_get_var(0, 'is_udir'), 'Udir buffer should be marked')
assert(#api.nvim_buf_get_lines(0, 0, -1, false) > 0, 'Udir buffer should render entries')
require'udir.core'.quit()

print('[udir] smoke ok')
