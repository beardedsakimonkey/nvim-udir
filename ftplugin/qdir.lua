if not vim.b.did_ftplugin then
  vim.b.did_ftplugin = 1
  vim.opt.cursorline = true
  vim.opt.foldenable = false
  vim.opt.buftype = "nofile"
  vim.opt_local.modifiable = false
  vim.opt.list = true
  vim.opt.listchars = {tab = "| "}
  vim.opt.expandtab = false
  vim.opt.tabstop = 4
  vim.opt.shiftwidth = 4
  vim.opt.softtabstop = 0
  vim.b.undo_ftplugin = "setl cul< fen< bt< modifiable< list< listchars< et< ts< sw< sts<"
  return nil
end
