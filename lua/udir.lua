local M = {}

---@alias File {name: string, type: 'file'|'directory'|'link'}
M.config = {
    keymaps = {
        q = "<Cmd>lua require'udir.core'.quit()<CR>",
        h = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        ['-'] = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        l = "<Cmd>lua require'udir.core'.open()<CR>",
        ['<CR>'] = "<Cmd>lua require'udir.core'.open()<CR>",
        s = "<Cmd>lua require'udir.core'.open('split')<CR>",
        v = "<Cmd>lua require'udir.core'.open('vsplit')<CR>",
        t = "<Cmd>lua require'udir.core'.open('tabedit')<CR>",
        R = "<Cmd>lua require'udir.core'.reload()<CR>",
        d = "<Cmd>lua require'udir.core'.delete()<CR>",
        ['+'] = "<Cmd>lua require'udir.core'.create()<CR>",
        m = "<Cmd>lua require'udir.core'.move()<CR>",
        c = "<Cmd>lua require'udir.core'.copy()<CR>",
        ['.'] = "<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>",
    },
    -- Whether hidden files should be shown by default
    show_hidden_files = true,
    -- Function used to determine what files should be hidden
    ---@type fun(file: File, files: File[], dir: string): boolean
    is_file_hidden = function() return false end,
    -- Function used to sort files
    ---@type fun(files: File[])
    sort = nil,
}

function M.udir(dir, from_au)
    require'udir.core'.udir(dir, from_au)
end

return M
