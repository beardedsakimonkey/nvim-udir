(when (not vim.b.did_ftplugin)
  (set vim.b.did_ftplugin 1)
  (set vim.opt_local.buftype :nofile)
  (set vim.opt_local.modifiable false)
  (set vim.opt_local.swapfile false)
  (set vim.opt_local.colorcolumn "")
  (set vim.b.undo_ftplugin "setl buftype< modifiable< swapfile<"))
