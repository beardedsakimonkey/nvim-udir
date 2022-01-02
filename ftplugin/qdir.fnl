(when (not vim.b.did_ftplugin)
  (set vim.b.did_ftplugin 1)
  (set vim.opt_local.cursorline true)
  (set vim.opt_local.buftype :nofile)
  ;; For some reason, using `opt` instead of `opt_local` causes problems when
  ;; e.g. opening snap from a Qdir buffer
  (set vim.opt_local.modifiable false)
  (set vim.b.undo_ftplugin "setl cul< bt< modifiable<"))

