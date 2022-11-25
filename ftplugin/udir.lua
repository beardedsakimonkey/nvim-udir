if not vim.b.did_ftplugin then
  vim.b.did_ftplugin = 1
  vim.opt_local.buftype = "nofile"
  vim.opt_local.modifiable = false
  vim.opt_local.swapfile = false
  vim.opt_local.colorcolumn = ""
  vim.b.undo_ftplugin = "setl buftype< modifiable< swapfile<"
  return nil
else
  return nil
end
