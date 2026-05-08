local M = {}

---@alias UdirFileType 'file'|'directory'|'link'
---@alias UdirOpenCommand 'edit'|'split'|'vsplit'|'tabedit'|string
---@alias UdirKeymapAction string|function
---@alias UdirKeymapSpec UdirKeymapAction|{[1]: UdirKeymapAction, desc?: string}

---@class UdirFile
---@field name string
---@field type UdirFileType

---@class UdirConfig
---@field keymaps table<string, UdirKeymapSpec>
---@field visual_keymaps table<string, UdirKeymapSpec>
---@field show_hidden boolean
---@field sync_local_cwd boolean
---@field hidden_filter fun(file: UdirFile, files: UdirFile[], dir: string): boolean
---@field sort? fun(files: UdirFile[])

---@type UdirConfig
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
        gx = {"<Cmd>lua require'udir.core'.open_external()<CR>", desc="Open externally"},
        R = {"<Cmd>lua require'udir.core'.reload()<CR>", desc="Reload"},
        i = {"<Cmd>lua require'udir.core'.info()<CR>", desc="Show info"},
        y = {"<Cmd>lua require'udir.core'.yank_path()<CR>", desc="Yank path"},
        Y = {"<Cmd>lua require'udir.core'.yank_path('+')<CR>", desc="Yank path to clipboard"},
        d = {"<Cmd>lua require'udir.core'.delete()<CR>", desc="Delete"},
        a = {"<Cmd>lua require'udir.core'.create()<CR>", desc="Create"},
        m = {"<Cmd>lua require'udir.core'.move()<CR>", desc="Move"},
        c = {"<Cmd>lua require'udir.core'.copy()<CR>", desc="Copy"},
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark()<CR>", desc="Toggle mark"},
        ['<S-Tab>'] = {"<Cmd>lua require'udir.core'.clear_marks()<CR>", desc="Clear marks"},
        gh = {"<Cmd>lua require'udir.core'.toggle_hidden_files()<CR>", desc="Toggle hidden files"},
        ['g?'] = {"<Cmd>lua require'udir.core'.help()<CR>", desc="Show help"},
    },
    visual_keymaps = {
        ['<Tab>'] = {"<Cmd>lua require'udir.core'.toggle_mark_visual()<CR>", desc="Toggle marks"},
    },
    -- Whether hidden files should be shown when udir opens
    show_hidden = true,
    -- Whether to sync the window's current directory with udir's current path
    sync_local_cwd = false,
    -- Function used to determine what files should be hidden behind `gh`
    hidden_filter = function(file) return vim.startswith(file.name, '.') end,
    -- Function used to sort files
    sort = nil,
}

---@param dir? string
---@param from_au? boolean
function M.udir(dir, from_au)
    require'udir.core'.udir(dir, from_au)
end

return M
