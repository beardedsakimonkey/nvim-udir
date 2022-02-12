if not vim.b.did_ftplugin then
  vim.b.did_ftplugin = 1
  vim.opt_local.buftype = "nofile"
  vim.opt_local.modifiable = false
  vim.b.undo_ftplugin = "setl buftype< modifiable<"
  return nil
else
  return nil
end
