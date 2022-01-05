(when (not vim.b.did_ftplugin)
  (set vim.b.did_ftplugin 1)
  ;; Using `opt` instead of `opt_local` somemtimes causes options to persist.
  (set vim.opt_local.cursorline true)
  (set vim.opt_local.buftype :nofile)
  (set vim.opt_local.modifiable false)
  (set vim.b.undo_ftplugin "setl cursorline< buftype< modifiable<"))

