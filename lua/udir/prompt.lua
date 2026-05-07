local api = vim.api
local uv = vim.loop
local util = require'udir.util'

local M = {}

local function valid_win(win)
    return win and api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
    return buf and api.nvim_buf_is_valid(buf)
end

local function make_border(hl)
    return {
        {'╭', hl}, {'─', hl}, {'╮', hl}, {'│', hl},
        {'╯', hl}, {'─', hl}, {'╰', hl}, {'│', hl},
    }
end

local function win_layout(prompt, width)
    local title = prompt and (' ' .. prompt .. ' ') or nil
    width = math.min(width, math.max(20, vim.o.columns - 4))
    return {
        relative = 'editor',
        anchor = 'NW',
        row = math.max(0, math.floor((vim.o.lines - 3) / 2)),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = 1,
        border = make_border('UdirPromptBorder'),
        title = title,
        title_pos = title and 'left' or nil,
        style = 'minimal',
        noautocmd = true,
    }
end

local function pesc(str)
    return (str:gsub('([^%w])', '%%%1'))
end

local function path_segment(input, col)
    local before = input:sub(1, col)
    local sep = pesc(util.sep)
    local dir, base = before:match('^(.*' .. sep .. ')([^' .. sep .. ']*)$')
    if dir then
        return dir, base, #dir
    end
    return '', before, 0
end

local function normalize_dir(input, cwd)
    if input == '' then
        return cwd
    end
    input = input:gsub('^~', os.getenv'HOME')
    if input:sub(1, 1) == util.sep then
        return input
    end
    return util.join_path(cwd, input)
end

local function completion(input, col, cwd)
    if input == '' then
        return nil
    end
    local dir, base, start_col = path_segment(input, col)
    if base == '' then
        return nil
    end
    local scanner = uv.fs_scandir(normalize_dir(dir, cwd))
    if not scanner then
        return nil
    end
    local base_lower = base:lower()
    local matches = {}
    while true do
        local name, type = uv.fs_scandir_next(scanner)
        if not name then
            break
        end
        if vim.startswith(name:lower(), base_lower) and name ~= base then
            local is_dir = type == 'directory'
            matches[#matches+1] = {
                word = dir .. name .. (is_dir and util.sep or ''),
                type = type,
            }
        end
    end
    table.sort(matches, function(a, b)
        if (a.type == 'directory') == (b.type == 'directory') then
            return a.word < b.word
        end
        return a.type == 'directory'
    end)
    local match = matches[1]
    if not match then
        return nil
    end
    local suffix = match.word:sub(col + 1)
    if suffix == '' then
        return nil
    end
    return {
        word = match.word,
        suffix = suffix,
        start_col = start_col,
    }
end

local Prompt = {}

function Prompt:close()
    if self.closed then
        return
    end
    self.closed = true
    for _, au in ipairs(self.autocmds) do
        pcall(api.nvim_del_autocmd, au)
    end
    if valid_win(self.input_win) then
        pcall(api.nvim_win_close, self.input_win, true)
    end
    if valid_buf(self.input_buf) then
        pcall(api.nvim_buf_delete, self.input_buf, {force = true})
    end
    if valid_win(self.origin_win) then
        pcall(api.nvim_set_current_win, self.origin_win)
    end
    vim.cmd'stopinsert'
end

function Prompt:get_input()
    return api.nvim_buf_get_lines(self.input_buf, 0, 1, false)[1] or ''
end

function Prompt:set_input(input, col)
    api.nvim_buf_set_lines(self.input_buf, 0, 1, false, {input})
    api.nvim_win_set_cursor(self.input_win, {1, col})
end

function Prompt:validate()
    local ok, result = pcall(self.opts.validate, self:get_input())
    self.is_valid = ok
    self.valid_result = ok and result or nil
    local hl = ok and 'UdirPromptBorderValid' or 'UdirPromptBorderInvalid'
    if valid_win(self.input_win) then
        local cfg = api.nvim_win_get_config(self.input_win)
        cfg.border = make_border(hl)
        api.nvim_win_set_config(self.input_win, cfg)
    end
end

function Prompt:update_completion()
    api.nvim_buf_clear_namespace(self.input_buf, self.ns, 0, -1)
    self.completion = nil
    if not valid_win(self.input_win) then
        return
    end
    local input = self:get_input()
    local col = api.nvim_win_get_cursor(self.input_win)[2]
    self.completion = completion(input, col, self.opts.cwd)
    if self.completion then
        api.nvim_buf_set_extmark(self.input_buf, self.ns, 0, col, {
            virt_text = {{self.completion.suffix, 'UdirPromptCompletion'}},
            virt_text_pos = 'inline',
        })
    end
end

function Prompt:redraw()
    self:validate()
    self:update_completion()
end

function Prompt:accept_completion()
    if not self.completion or not valid_win(self.input_win) then
        return
    end
    local input = self:get_input()
    local col = api.nvim_win_get_cursor(self.input_win)[2]
    local new_input = self.completion.word .. input:sub(col + 1)
    self:set_input(new_input, #self.completion.word)
    self:redraw()
end

function Prompt:confirm()
    self:validate()
    if not self.is_valid then
        return
    end
    local input = self:get_input()
    self:close()
    self.cb(input, self.valid_result)
end

function Prompt:cancel()
    self:close()
    self.cb(nil)
end

function Prompt:escape_insert()
    if self:get_input() == '' then
        self:cancel()
        return
    end
    vim.cmd'stopinsert'
end

function Prompt:relayout()
    if valid_win(self.input_win) then
        api.nvim_win_set_config(self.input_win, win_layout(self.opts.prompt, self.width))
        self:redraw()
    end
end

local function keymap(buf, mode, lhs, rhs)
    vim.keymap.set(mode, lhs, rhs, {buffer = buf, silent = true, nowait = true})
end

function M.input(opts, cb)
    local self = setmetatable({
        opts = opts,
        cb = cb,
        origin_win = api.nvim_get_current_win(),
        width = opts.width or 64,
        autocmds = {},
        ns = api.nvim_create_namespace('udir/prompt'),
    }, {__index = Prompt})

    self.input_buf = api.nvim_create_buf(false, true)
    vim.bo[self.input_buf].buftype = 'nofile'
    vim.bo[self.input_buf].bufhidden = 'wipe'

    self.input_win = api.nvim_open_win(self.input_buf, true, win_layout(opts.prompt, self.width))
    vim.wo[self.input_win].winhighlight = 'NormalFloat:Normal,FloatBorder:UdirPromptBorder'

    api.nvim_buf_set_lines(self.input_buf, 0, -1, false, {opts.default or ''})
    api.nvim_win_set_cursor(self.input_win, {1, #(opts.default or '')})

    keymap(self.input_buf, 'i', '<Esc>', function() self:escape_insert() end)
    keymap(self.input_buf, 'n', '<Esc>', function() self:cancel() end)
    keymap(self.input_buf, {'i', 'n'}, '<C-c>', function() self:cancel() end)
    keymap(self.input_buf, {'i', 'n'}, '<CR>', function() self:confirm() end)
    keymap(self.input_buf, 'i', '<Tab>', function() self:accept_completion() end)

    self.autocmds[#self.autocmds+1] = api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
        buffer = self.input_buf,
        callback = function() self:redraw() end,
    })
    self.autocmds[#self.autocmds+1] = api.nvim_create_autocmd('CursorMovedI', {
        buffer = self.input_buf,
        callback = function() self:update_completion() end,
    })
    self.autocmds[#self.autocmds+1] = api.nvim_create_autocmd('VimResized', {
        callback = function() self:relayout() end,
    })
    self.autocmds[#self.autocmds+1] = api.nvim_create_autocmd('WinClosed', {
        callback = function(args)
            if tonumber(args.match) == self.input_win then
                self:cancel()
            end
        end,
    })

    self:redraw()
    vim.cmd'startinsert'
    return self
end

return M
