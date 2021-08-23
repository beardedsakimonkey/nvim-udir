(when (not vim.g.loaded_qdir)
  (set vim.g.loaded_qdir 1)
  (vim.cmd "com! -bar -nargs=? -complete=dir Qdir call luaeval('require\"qdir\".qdir(_A)', <q-args>)"))

