(when (not vim.g.loaded_udir)
  (set vim.g.loaded_udir 1)
  (vim.cmd "com! -bar -nargs=? -complete=dir Udir call luaeval('require\"udir\".udir(_A)', <q-args>)"))

