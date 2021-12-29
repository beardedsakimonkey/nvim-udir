(when (not vim.b.did_ftplugin)
  (set vim.b.did_ftplugin 1)
  (set vim.opt.cursorline true)
  (set vim.opt.foldenable false)
  (set vim.opt.buftype :nofile)
  ;; For some reason, using `opt` instead of `opt_local` causes problems when
  ;; e.g. opening snap from a Qdir buffer
  (set vim.opt_local.modifiable false)
  (set vim.opt.list true)
  (set vim.opt.listchars {:tab "| "})
  (set vim.opt.expandtab false)
  (set vim.opt.tabstop 4)
  (set vim.opt.shiftwidth 4)
  (set vim.opt.softtabstop 0)
  (set vim.b.undo_ftplugin
       "setl cul< fen< bt< modifiable< list< listchars< et< ts< sw< sts<"))

