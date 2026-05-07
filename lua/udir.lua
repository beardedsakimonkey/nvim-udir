local M = {}

---@alias File {name: string, type: 'file'|'directory'|'link'}
M.config = {
    keymaps = {
        q = "<Cmd>lua require'udir.core'.quit()<CR>",
        h = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        ['-'] = "<Cmd>lua require'udir.core'.up_dir()<CR>",
        J = "<Cmd>lua require'udir.core'.next_directory()<CR>",
        K = "<Cmd>lua require'udir.core'.prev_directory()<CR>",
        o = "<Cmd>lua require'udir.core'.expand()<CR>",
        O = "<Cmd>lua require'udir.core'.expand_recursive()<CR>",
        u = "<Cmd>lua require'udir.core'.collapse()<CR>",
        U = "<Cmd>lua require'udir.core'.collapse_reset()<CR>",
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
        ['<Tab>'] = "<Cmd>lua require'udir.core'.toggle_mark()<CR>",
        ['.'] = "<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>",
    },
    visual_keymaps = {
        ['<Tab>'] = "<Cmd>lua require'udir.core'.toggle_mark_visual()<CR>",
    },
    -- Whether hidden files should be shown by default
    show_hidden_files = true,
    -- Whether to sync the window's current directory with udir's current path
    sync_local_cwd = false,
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
