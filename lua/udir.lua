local M = {}

---@alias File {name: string, type: 'file'|'directory'|'link'}
M.config = {
    keymaps = {
        q = {"<Cmd>lua require'udir.core'.quit()<CR>", desc="Quit"},
        h = {"<Cmd>lua require'udir.core'.up_dir()<CR>", desc="Up directory"},
        ['-'] = {"<Cmd>lua require'udir.core'.up_dir()<CR>", desc="Up directory"},
        J = {"<Cmd>lua require'udir.core'.next_directory()<CR>", desc="Next directory"},
        K = {"<Cmd>lua require'udir.core'.prev_directory()<CR>", desc="Previous directory"},
        o = {"<Cmd>lua require'udir.core'.expand()<CR>", desc="Expand"},
        O = {"<Cmd>lua require'udir.core'.expand_recursive()<CR>", desc="Expand recursively"},
        u = {"<Cmd>lua require'udir.core'.collapse()<CR>", desc="Collapse"},
        U = {"<Cmd>lua require'udir.core'.collapse_reset()<CR>", desc="Collapse and reset"},
        l = {"<Cmd>lua require'udir.core'.open()<CR>", desc="Open"},
        ['<CR>'] = {"<Cmd>lua require'udir.core'.open()<CR>", desc="Open"},
        s = {"<Cmd>lua require'udir.core'.open('split')<CR>", desc="Open in split"},
        v = {"<Cmd>lua require'udir.core'.open('vsplit')<CR>", desc="Open in vertical split"},
        t = {"<Cmd>lua require'udir.core'.open('tabedit')<CR>", desc="Open in tab"},
        R = {"<Cmd>lua require'udir.core'.reload()<CR>", desc="Reload"},
        d = {"<Cmd>lua require'udir.core'.delete()<CR>", desc="Delete"},
        ['+'] = {"<Cmd>lua require'udir.core'.create()<CR>", desc="Create"},
        m = {"<Cmd>lua require'udir.core'.move()<CR>", desc="Move"},
        c = {"<Cmd>lua require'udir.core'.copy()<CR>", desc="Copy"},
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark()<CR>", desc="Toggle mark"},
        ['.'] = {"<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>", desc="Toggle hidden files"},
    },
    visual_keymaps = {
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark_visual()<CR>", desc="Toggle marks"},
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
