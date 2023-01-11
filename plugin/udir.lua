if vim.g.loaded_udir then
    return
end
vim.g.loaded_udir = 1

vim.cmd 'hi default link UdirFile       Normal'
vim.cmd 'hi default link UdirDirectory  Directory'
vim.cmd 'hi default link UdirSymlink    Constant'
vim.cmd 'hi default link UdirExecutable Special'
vim.cmd 'hi default link UdirVirtText   Comment'

vim.api.nvim_create_user_command('Udir', function(o)
    require'udir'.udir(o.args)
end, {bar=true, nargs='?', complete='dir'})

local function buf_has_var(buf, var_name)
    local ok, ret = pcall(vim.api.nvim_buf_get_var, buf, var_name)
    return ok and ret or false
end

-- Automatically open Udir when editing a directory
vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('udir', {}),
    callback = function()
        local path = vim.fn.expand('%')
        if not buf_has_var(0, 'is_udir') and vim.fn.isdirectory(path) == 1 then
            require'udir'.udir('', true)
        end
    end,
})
